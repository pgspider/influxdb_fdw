/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        option.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "influxdb_fdw.h"

#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

#include "funcapi.h"
#include "access/reloptions.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "commands/explain.h"
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#include "miscadmin.h"
#include "mb/pg_wchar.h"
#include "storage/fd.h"
#include "utils/array.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/rel.h"
#include "utils/lsyscache.h"
#include "optimizer/cost.h"
#include "optimizer/pathnode.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/planmain.h"
#include "utils/varlena.h"

#ifdef CXX_CLIENT
#include "query_cxx.h"
#endif

/*
 * Describes the valid options for objects that use this wrapper.
 */
struct InfluxDBFdwOption
{
	const char *optname;
	Oid			optcontext;		/* Oid of catalog in which option may appear */
};


/*
 * Valid options for influxdb_fdw.
 */
static struct InfluxDBFdwOption valid_options[] =
{
	{"host", ForeignServerRelationId},
	{"port", ForeignServerRelationId},
	{"dbname", ForeignServerRelationId},
#ifdef CXX_CLIENT
	{"version", ForeignServerRelationId},
	{"retention_policy", ForeignServerRelationId},
	{"auth_token", UserMappingRelationId},
#endif
	{"user", UserMappingRelationId},
	{"password", UserMappingRelationId},

	{"table", ForeignTableRelationId},
	{"column_name", AttributeRelationId},
	{"tags", ForeignTableRelationId},
	{"schemaless", ForeignTableRelationId},

#if (PG_VERSION_NUM >= 140000)
	/* batch_size is available on both server and table */
	{"batch_size", ForeignServerRelationId},
	{"batch_size", ForeignTableRelationId},
#endif

	{"tags", AttributeRelationId},
	{"fields", AttributeRelationId},

	/* Sentinel */
	{NULL, InvalidOid}
};

static List *influxdbExtractTagsList(char *in_string);

extern Datum influxdb_fdw_validator(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(influxdb_fdw_validator);
bool		influxdb_is_valid_option(const char *option, Oid context);

/*
 * Validate the generic options given to a FOREIGN DATA WRAPPER, SERVER,
 * USER MAPPING or FOREIGN TABLE that uses influxdb_fdw.
 *
 * Raise an ERROR if the option or its value is considered invalid.
 */
Datum
influxdb_fdw_validator(PG_FUNCTION_ARGS)
{
	List	   *options_list = untransformRelOptions(PG_GETARG_DATUM(0));
	Oid			catalog = PG_GETARG_OID(1);
	ListCell   *cell;

	/*
	 * Check that only options supported by influxdb_fdw, and allowed for the
	 * current object type, are given.
	 */
	foreach(cell, options_list)
	{
		DefElem    *def = (DefElem *) lfirst(cell);

		if (!influxdb_is_valid_option(def->defname, catalog))
		{
			struct InfluxDBFdwOption *opt;
			StringInfoData buf;

#if PG_VERSIION_NUM < 160000
			/*
			 * Unknown option specified, complain about it. Provide a hint
			 * with list of valid options for the object.
			 */
			initStringInfo(&buf);
			for (opt = valid_options; opt->optname; opt++)
			{
				if (catalog == opt->optcontext)
					appendStringInfo(&buf, "%s%s", (buf.len > 0) ? ", " : "",
									 opt->optname);
			}

			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname),
					 buf.len > 0
					 ? errhint("Valid options in this context are: %s",
							   buf.data)
					 : errhint("There are no valid options in this context.")));
#else
			/*
			 * Unknown option specified, complain about it. Provide a hint
			 * with list of valid options for the object.
			 */
			const char *closest_match;
			ClosestMatchState match_state;
			bool		has_valid_options = false;

			initClosestMatch(&match_state, def->defname, 4);
			for (opt = valid_options; opt->optname; opt++)
			{
				if (catalog == opt->optcontext)
				{
					has_valid_options = true;
					updateClosestMatch(&match_state, opt->optname);
				}
			}

			closest_match = getClosestMatch(&match_state);
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname),
					 has_valid_options ? closest_match ?
					 errhint("Perhaps you meant the option \"%s\".",
							 closest_match) : 0 :
					 errhint("There are no valid options in this context.")));
#endif
		}

		/*
		 * Validate option value, when we can do so without any context.
		 */
#if (PG_VERSION_NUM >= 140000)
		if (strcmp(def->defname, "batch_size") == 0)
		{
			char	   *value;
			int			int_val;
			bool		is_parsed;

			value = defGetString(def);
			is_parsed = parse_int(value, &int_val, 0, NULL);

			if (!is_parsed)
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("invalid value for integer option \"%s\": %s",
								def->defname, value)));

			if (int_val <= 0)
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("\"%s\" must be an integer value greater than zero",
								def->defname)));
		}
#endif

#ifdef CXX_CLIENT
		if(strcmp(def->defname, "version") == 0)
		{
			int int_val;

			int_val = atoi(defGetString(def));

			if(int_val != INFLUXDB_VERSION_1 && int_val !=INFLUXDB_VERSION_2)
				ereport(ERROR,
						(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
						 errmsg("InfluxDB only support versions from v1.x to 2.x. \"%s\" must be 1 or 2.",  def->defname)));
		}
#endif
	}
	PG_RETURN_VOID();
}

/*
 * Check if the provided option is one of the valid options.
 * context is the Oid of the catalog holding the object the option is for.
 */
bool
influxdb_is_valid_option(const char *option, Oid context)
{
	struct InfluxDBFdwOption *opt;

	for (opt = valid_options; opt->optname; opt++)
	{
		if (context == opt->optcontext && strcmp(opt->optname, option) == 0)
			return true;
	}
	return false;
}

/*
 * Fetch the options for a influxdb_fdw foreign table.
 */
influxdb_opt *
influxdb_get_options(Oid foreignoid, Oid userid)
{
	ForeignTable   *f_table = NULL;
	ForeignServer  *f_server = NULL;
	UserMapping    *f_mapping;
	List	   	   *options;
	ListCell   	   *lc;
	influxdb_opt   *opt;

	opt = (influxdb_opt *) palloc(sizeof(influxdb_opt));
	memset(opt, 0, sizeof(influxdb_opt));

	/*
	 * Extract options from FDW objects.
	 */
	PG_TRY();
	{
		f_table = GetForeignTable(foreignoid);
		f_server = GetForeignServer(f_table->serverid);
	}
	PG_CATCH();
	{
		f_table = NULL;
		f_server = GetForeignServer(foreignoid);
	}
	PG_END_TRY();

	f_mapping = GetUserMapping(userid, f_server->serverid);

	options = NIL;
	if (f_table)
		options = list_concat(options, f_table->options);
	options = list_concat(options, f_server->options);
	options = list_concat(options, f_mapping->options);

	/* Loop through the options, and get the server/port */
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "table") == 0)
			opt->svr_table = defGetString(def);

		if (strcmp(def->defname, "host") == 0)
			opt->svr_address = defGetString(def);

		if (strcmp(def->defname, "port") == 0)
			opt->svr_port = atoi(defGetString(def));

		if (strcmp(def->defname, "user") == 0)
			opt->svr_username = defGetString(def);

		if (strcmp(def->defname, "password") == 0)
			opt->svr_password = defGetString(def);

		if (strcmp(def->defname, "dbname") == 0)
			opt->svr_database = defGetString(def);

		if (strcmp(def->defname, "table_name") == 0)
			opt->svr_table = defGetString(def);

		if (strcmp(def->defname, "tags") == 0)
			opt->tags_list = influxdbExtractTagsList(defGetString(def));

		if (strcmp(def->defname, "schemaless") == 0)
			opt->schemaless = defGetBoolean(def);

#ifdef CXX_CLIENT
		if (strcmp(def->defname, "auth_token") == 0)
			opt->svr_token = defGetString(def);

		if (strcmp(def->defname, "version") == 0)
			opt->svr_version = atoi(defGetString(def));

		if (strcmp(def->defname, "retention_policy") == 0)
			opt->svr_retention_policy = defGetString(def);
#endif
	}

	if (!opt->svr_table && f_table)
		opt->svr_table = get_rel_name(foreignoid);

#ifdef CXX_CLIENT
	/* When using the influxdb-cxx API client, c++ not allow std::string(NULL). */
	if (opt->svr_address == NULL || strcmp(opt->svr_address, "") == 0)
		elog(ERROR, "influxdb_fdw: Server Host not specified");

	if (opt->svr_database == NULL || strcmp(opt->svr_database, "") == 0)
		elog(ERROR, "influxdb_fdw: Database not specified");

	if (opt->svr_username == NULL)
		opt->svr_username = "";

	if (opt->svr_password == NULL)
		opt->svr_password = "";

	if (opt->svr_token == NULL)
		opt->svr_token = "";

	if (opt->svr_retention_policy == NULL)
		opt->svr_retention_policy = "";
#endif

	return opt;
}

#ifdef CXX_CLIENT
/*
 * Fetch the version options for a influxdb_fdw foreign table.
 */
int
influxdb_get_version_option(influxdb_opt *opt)
{
	/* determine which version is connected to */
	return check_connected_influxdb_version(opt->svr_address, opt->svr_port, opt->svr_username, opt->svr_password, opt->svr_database,
														opt->svr_token, opt->svr_retention_policy);
}
#endif

/*
 * Parse a comma-separated string and return a list of tag keys of a foreign table.
 */
static List *
influxdbExtractTagsList(char *in_string)
{
	List	   *tags_list = NIL;

	/* SplitIdentifierString scribbles on its input, so pstrdup first */
	if (!SplitIdentifierString(pstrdup(in_string), ',', &tags_list))
	{
		/* Syntax error in tags list */
		ereport(ERROR,
				(errcode(ERRCODE_INVALID_PARAMETER_VALUE),
				 errmsg("parameter \"%s\" must be a list of tag keys",
						"tags")));
	}

	return tags_list;
}
