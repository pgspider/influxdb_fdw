/*-------------------------------------------------------------------------
 *
 * connection.cpp
 *		  Connection management functions for influxdb_fdw cxx-client
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *		  contrib/influxdb_fdw/connection.cpp
 *
 *-------------------------------------------------------------------------
 */
extern "C"
{
#include "postgres.h"
#include "access/htup_details.h"
#include "catalog/pg_user_mapping.h"
#include "commands/defrem.h"
#include "mb/pg_wchar.h"
#include "miscadmin.h"
#include "storage/fd.h"
#include "storage/latch.h"
#include "utils/hsearch.h"
#include "utils/inval.h"
#include "utils/memutils.h"
#include "utils/syscache.h"
}

#include "connection.hpp"

/*
 * Connection cache hash table entry
 *
 * The lookup key in this hash table is the user mapping OID. We use just one
 * connection per user mapping ID, which ensures that all the scans use the
 * same snapshot during a query.  Using the user mapping OID rather than
 * the foreign server OID + user OID avoids creating multiple connections when
 * the public user mapping applies to all user OIDs.
 *
 * The "conn" pointer can be NULL if we don't currently have a live connection.
 * When we do have a connection, xact_depth tracks the current depth of
 * transactions and subtransactions open on the remote side.  We need to issue
 * commands at the same nesting depth on the remote as we're executing at
 * ourselves, so that rolling back a subtransaction will kill the right
 * queries and not the wrong ones.
 */
typedef Oid ConnCacheKey;

typedef struct ConnCacheEntry
{
    ConnCacheKey		key;				/* hash key (must be first) */
    influxdb::InfluxDB *conn;				/* connection to foreign server, or nullptr */
    bool				invalidated;		/* true if reconnect is pending */
	uint32				server_hashvalue;	/* hash value of foreign server OID */
	uint32				mapping_hashvalue;	/* hash value of user mapping OID */
} ConnCacheEntry;

/*
 * Connection cache (initialized on first use)
 */
static HTAB *ConnectionHash = NULL;

/* prototypes of private functions */
static void influx_make_new_connection(ConnCacheEntry *entry, UserMapping *user, influxdb_opt *options);
static std::unique_ptr<influxdb::InfluxDB> influx_connect_server(influxdb_opt *options);
static void influx_disconnect_server(ConnCacheEntry *entry);
static void influx_inval_callback(Datum arg, int cacheid, uint32 hashvalue);

/*
 * influxdb_get_connection
 *
 * Get a connection which can be used to execute queries on
 * the remote InfluxDB with the user's authorization. A new connection
 * is established if we don't already have a suitable one.
 */
influxdb::InfluxDB *
influxdb_get_connection(UserMapping *user, influxdb_opt *options)
{
	bool		found;
	ConnCacheEntry *entry;
	ConnCacheKey key;

	/* First time through, initialize connection cache hashtable */
	if (ConnectionHash == NULL)
	{
		HASHCTL		ctl;

		ctl.keysize = sizeof(ConnCacheKey);
		ctl.entrysize = sizeof(ConnCacheEntry);
		ConnectionHash = hash_create("influxdb_fdw cxx client connections", 8,
									 &ctl,
									 HASH_ELEM | HASH_BLOBS);

		/*
		 * Register some callback functions that manage connection cleanup.
		 * This should be done just once in each backend.
		 */
		CacheRegisterSyscacheCallback(FOREIGNSERVEROID,
									  influx_inval_callback, (Datum) 0);
		CacheRegisterSyscacheCallback(USERMAPPINGOID,
									  influx_inval_callback, (Datum) 0);
	}

	/* Create hash key for the entry.  Assume no pad bytes in key struct */
	key = user->umid;

	/*
	 * Find or create cached entry for requested connection.
	 */
	entry = (ConnCacheEntry *)hash_search(ConnectionHash, &key, HASH_ENTER, &found);
	if (!found)
	{
		/*
		 * We need only clear "conn" here; remaining fields will be filled
		 * later when "conn" is set.
		 */
		entry->conn = NULL;
	}

	/*
	 * If the connection needs to be remade due to invalidation, disconnect it.
	 */
	if (entry->conn != NULL && entry->invalidated)
	{
		elog(DEBUG3, "influxdb_fdw: closing connection %p for option changes to take effect",
			 entry->conn);
		influx_disconnect_server(entry);
	}

	/*
	 * If cache entry doesn't have a connection, we have to establish a new
	 * connection.  (If influx_connect_server throws an error, the cache entry
	 * will remain in a valid empty state, ie conn == NULL.)
	 */
	if (entry->conn == NULL)
		influx_make_new_connection(entry, user, options);

	return entry->conn;
}

/*
 * Reset all transient state fields in the cached connection entry and
 * establish new connection to the remote server.
 */
static void
influx_make_new_connection(ConnCacheEntry *entry, UserMapping *user, influxdb_opt *opts)
{
	ForeignServer *server = GetForeignServer(user->serverid);

	Assert(entry->conn == NULL);

	/* Reset all transient state fields, to be sure all are clean */
	entry->invalidated = false;
	entry->server_hashvalue =
		GetSysCacheHashValue1(FOREIGNSERVEROID,
								ObjectIdGetDatum(server->serverid));
	entry->mapping_hashvalue =
		GetSysCacheHashValue1(USERMAPPINGOID,
								ObjectIdGetDatum(user->umid));

	/* Now try to make the connection */
	entry->conn = influx_connect_server(opts).release();

	elog(DEBUG3, "influxdb_fdw: new InfluxDB connection %p for server \"%s\" (user mapping oid %u, userid %u)",
			entry->conn, server->servername, user->umid, user->userid);
}

/* Provides InfluxDB client which can connect to InfluxDB server */
std::unique_ptr<influxdb::InfluxDB>
create_influxDB_client(char* addr, int port, char* user, char* pass, char* db, int version, char* auth_token, char* retention_policy)
{
    auto influx = [&]() -> std::unique_ptr<influxdb::InfluxDB>
        {
            if (version == INFLUXDB_VERSION_2)
                return influxdb::InfluxDBFactory::GetV2(std::string(addr), port, std::string(db), std::string(auth_token), std::string(retention_policy));
            else
                return influxdb::InfluxDBFactory::GetV1(std::string(addr), port, std::string(db), std::string(user), std::string(pass));
        }();

    if (!influx)
            elog(ERROR, "influxdb_fdw: fail to create influxDB client");

    return influx;
}

/*
 * Connect to remote server using specified server and user mapping properties.
 */
static std::unique_ptr<influxdb::InfluxDB>
influx_connect_server(influxdb_opt *opts)
{
	return create_influxDB_client(opts->svr_address, opts->svr_port, opts->svr_username, opts->svr_password,
                                  opts->svr_database, opts->svr_version, opts->svr_token, opts->svr_retention_policy);
}

/*
 * Disconnect any open connection for a connection cache entry.
 */
static void
influx_disconnect_server(ConnCacheEntry *entry)
{
	if (entry && entry->conn != NULL)
	{
		delete entry->conn;
		entry->conn = NULL;
	}
}

/*
 * Connection invalidation callback function
 *
 * After a change to a pg_foreign_server or pg_user_mapping catalog entry,
 * close connections depending on that entry immediately if current transaction
 * has not used those connections yet. Otherwise, mark those connections as
 * invalid and then closed connections will be remade at the next opportunity if
 * necessary.
 *
 * Although most cache invalidation callbacks blow away all the related stuff
 * regardless of the given hashvalue, connections are expensive enough that
 * it's worth trying to avoid that.
 *
 * NB: We could avoid unnecessary disconnection more strictly by examining
 * individual option values, but it seems too much effort for the gain.
 */
static void
influx_inval_callback(Datum arg, int cacheid, uint32 hashvalue)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	Assert(cacheid == FOREIGNSERVEROID || cacheid == USERMAPPINGOID);

	/* ConnectionHash must exist already, if we're registered */
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore invalid entries */
		if (entry->conn == nullptr)
			continue;

		/* hashvalue == 0 means a cache reset, must clear all state */
		if (hashvalue == 0 ||
			(cacheid == FOREIGNSERVEROID &&
			 entry->server_hashvalue == hashvalue) ||
			(cacheid == USERMAPPINGOID &&
			 entry->mapping_hashvalue == hashvalue))
		{
			/*
			 * Close the connection immediately if it's not used yet in this
			 * transaction. Otherwise mark it as invalid so that
			 * pgfdw_xact_callback() can close it at the end of this
			 * transaction.
			 */
			entry->invalidated = true;
			elog(DEBUG3, "influxdb_fdw: discarding connection %p", entry->conn);
			influx_disconnect_server(entry);
		}
	}
}

/*
 * influx_cleanup_connection:
 * Delete all the cache entries on backend exists.
 */
void
influx_cleanup_connection(void)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	if (ConnectionHash == NULL)
		return;

	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		if (entry->conn == NULL)
			continue;

		influx_disconnect_server(entry);
	}
}
