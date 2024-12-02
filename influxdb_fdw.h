/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        influxdb_fdw.h
 *
 *-------------------------------------------------------------------------
 */

#ifndef INFLUXDB_FDW_H
#define INFLUXDB_FDW_H

#ifdef GO_CLIENT
#include "_obj/_cgo_export.h"
#else
#ifdef CXX_CLIENT
#include "query_cxx.h"
#endif
#endif

#include "foreign/foreign.h"
#include "lib/stringinfo.h"

#if (PG_VERSION_NUM >= 120000)
#include "nodes/pathnodes.h"
#include "utils/float.h"
#include "optimizer/optimizer.h"
#include "access/table.h"
#include "fmgr.h"
#else
#include "nodes/relation.h"
#include "optimizer/var.h"
#endif

#include "utils/rel.h"

#define WAIT_TIMEOUT		0
#define INTERACTIVE_TIMEOUT 0
#define INFLUXDB_TIME_COLUMN "time"
#define INFLUXDB_TIME_TEXT_COLUMN "time_text"
#define INFLUXDB_TAGS_COLUMN "tags"
#define INFLUXDB_FIELDS_COLUMN "fields"
#define INFLUXDB_TAGS_PGTYPE "jsonb"
#define INFLUXDB_FIELDS_PGTYPE "jsonb"
#define INFLUXDB_IS_TIME_COLUMN(X) (strcmp(X, INFLUXDB_TIME_COLUMN) == 0 || \
									strcmp(X, INFLUXDB_TIME_TEXT_COLUMN) == 0)
#define INFLUXDB_IS_TIME_TYPE(typeoid) ((typeoid == TIMESTAMPTZOID) || \
										(typeoid == TIMEOID) ||        \
										(typeoid == TIMESTAMPOID))
#define CR_NO_ERROR 0

/* Define some typeArray for low version */
#ifndef BOOLARRAYOID
#define BOOLARRAYOID 1000
#endif
#ifndef INT8ARRAYOID
#define INT8ARRAYOID 1016
#endif
#ifndef FLOAT8ARRAYOID
#define FLOAT8ARRAYOID 1022
#endif

#if (PG_VERSION_NUM < 120000)
#define table_close(rel, lock)	heap_close(rel, lock)
#define table_open(rel, lock)	heap_open(rel, lock)
#define exec_rt_fetch(rtindex, estate)	rt_fetch(rtindex, estate->es_range_table)
#endif

/*
 * Definitions to check mixing aggregate function
 * and non-aggregate function in target list
 */
#define INFLUXDB_TARGETS_MARK_COLUMN			(1u << 0)
#define INFLUXDB_TARGETS_MARK_AGGREF			(1u << 1)
#define INFLUXDB_TARGETS_MIXING_AGGREF_UNSAFE	(INFLUXDB_TARGETS_MARK_COLUMN | INFLUXDB_TARGETS_MARK_AGGREF)
#define INFLUXDB_TARGETS_MIXING_AGGREF_SAFE		(0u)

#define CODE_VERSION 20100

#ifdef CXX_CLIENT
#define INFLUXDB_VERSION_1    1
#define INFLUXDB_VERSION_2    2
#endif

/*
 * Options structure to store the InfluxDB
 * server information
 */
typedef struct influxdb_opt
{
	char	   *svr_database;	/* InfluxDB database name */
	char	   *svr_table;		/* InfluxDB table name */
	char	   *svr_address;	/* InfluxDB server ip address */
	int			svr_port;		/* InfluxDB port number */
	char	   *svr_username;	/* InfluxDB user name */
	char	   *svr_password;	/* InfluxDB password */
	List	   *tags_list;		/* Contain tag keys of a foreign table */
	int			schemaless;		/* Schemaless mode */
#ifdef CXX_CLIENT
	int			svr_version;	/* InfluxDB version. Only be 1 or 2 */
	char	   *svr_token;		/* Token for InfluxDB V2 Token authentication */
	char	   *svr_retention_policy;	/* Retention policy of target database */
#endif
}			influxdb_opt;

typedef struct schemaless_info
{
	bool		schemaless;		/* Enable schemaless check */
	Oid			slcol_type_oid; /* Schemaless column's jsonb type OID */
	Oid			jsonb_op_oid;	/* Jsonb type "->>" arrow operator OID */

	Oid			relid;			/* OID of the relation */
}			schemaless_info;

/*
 * FDW-specific information for ForeignScanState
 * fdw_state.
 */
typedef struct InfluxDBFdwExecState
{
	char	   *query;			/* Query string */
	Relation	rel;			/* relcache entry for the foreign table */
	Oid			relid;			/* relation oid */
	UserMapping *user;			/* User mapping of foreign server */
	List	   *retrieved_attrs;	/* list of target attribute numbers */

	char	  **params;
	bool		cursor_exists;	/* have we created the cursor? */
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */
	Oid		   *param_types;	/* type of query parameters */
	InfluxDBType *param_influxdb_types; /* InfluxDB type of query parameters */
	InfluxDBValue *param_influxdb_values;	/* values for InfluxDB */
	InfluxDBColumnInfo *param_column_info;	/* information of columns */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */

	influxdb_opt *influxdbFdwOptions;	/* InfluxDB FDW options */

	int			batch_size;		/* value of FDW option "batch_size" */
	List	   *attr_list;		/* query attribute list */
	List	   *column_list;	/* Column list of InfluxDB Column structures */

	int64		row_nums;		/* number of rows */
	Datum	  **rows;			/* all rows of scan */
	int64		rowidx;			/* current index of rows */
	bool	  **rows_isnull;	/* is null */
	bool		for_update;		/* true if this scan is update target */
	bool		is_agg;			/* scan is aggregate or not */
	List	   *tlist;			/* target list */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
	AttrNumber *junk_idx;

	/* for update row movement if subplan result rel */
	struct InfluxDBFdwExecState *aux_fmstate;	/* foreign-insert state, if
												 * created */

	/* Function pushdown support in target list */
	bool		is_tlist_func_pushdown;

	/* Schemaless info */
	schemaless_info slinfo;

	void	   *temp_result;
}			InfluxDBFdwExecState;

typedef struct InfluxDBFdwRelationInfo
{
	/*
	 * True means that the relation can be pushed down. Always true for simple
	 * foreign scan.
	 */
	bool		pushdown_safe;

	/* baserestrictinfo clauses, broken down into safe and unsafe subsets. */
	List	   *remote_conds;
	List	   *local_conds;

	/* Actual remote restriction clauses for scan (sans RestrictInfos) */
	List	   *final_remote_exprs;

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* True means that the query_pathkeys is safe to push down */
	bool		qp_is_pushdown_safe;

	/* Cost and selectivity of local_conds. */
	QualCost	local_conds_cost;
	Selectivity local_conds_sel;

	/* Selectivity of join conditions */
	Selectivity joinclause_sel;

	/* Estimated size and cost for a scan or join. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/* Costs excluding costs for transferring data from the foreign server */
	double		retrieved_rows;
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;
	List	   *shippable_extensions;	/* OIDs of whitelisted extensions */

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */

	int			fetch_size;		/* fetch size for this remote table */

	/*
	 * Name of the relation, for use while EXPLAINing ForeignScan.  It is used
	 * for join and upper relations but is set for all relations.  For a base
	 * relation, this is really just the RT index as a string; we convert that
	 * while producing EXPLAIN output.  For join and upper relations, the name
	 * indicates which base foreign tables are included and the join type or
	 * aggregation type used.
	 */
	char	   *relation_name;

	/* Join information */
	RelOptInfo *outerrel;
	RelOptInfo *innerrel;
	JoinType	jointype;
	/* joinclauses contains only JOIN/ON conditions for an outer join */
	List	   *joinclauses;	/* List of RestrictInfo */

	/* Upper relation information */
	UpperRelationKind stage;

	/* Grouping information */
	List	   *grouped_tlist;

	/* Subquery information */
	bool		make_outerrel_subquery; /* do we deparse outerrel as a
										 * subquery? */
	bool		make_innerrel_subquery; /* do we deparse innerrel as a
										 * subquery? */
	Relids		lower_subquery_rels;	/* all relids appearing in lower
										 * subqueries */

	/*
	 * Index of the relation.  It is used to create an alias to a subquery
	 * representing the relation.
	 */
	int			relation_index;

	/* Function pushdown support in target list */
	bool		is_tlist_func_pushdown;

	/* True means tlist is all except time column */
	bool		all_fieldtag;
	/* Schemaless info */
	schemaless_info slinfo;
	/* JsonB column list */
	List	   *slcols;
}			InfluxDBFdwRelationInfo;

extern bool influxdb_is_foreign_expr(PlannerInfo *root,
									 RelOptInfo *baserel,
									 Expr *expr,
									 bool for_tlist);
extern bool influxdb_is_foreign_function_tlist(PlannerInfo *root,
											   RelOptInfo *baserel,
											   List *tlist);


/* option.c headers */
extern influxdb_opt * influxdb_get_options(Oid foreigntableid, Oid userid);
#ifdef CXX_CLIENT
extern int influxdb_get_version_option(influxdb_opt *opt);
#endif

/* depare.c headers */
extern void influxdb_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
												 List *tlist, List *remote_conds, List *pathkeys,
												 bool is_subquery, List **retrieved_attrs,
												 List **params_list, bool has_limit);
extern void influxdb_deparse_insert(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *targetAttrs);
extern void influxdb_deparse_update(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *targetAttrs, List *attname);
extern void influxdb_deparse_delete(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *attname);
extern bool influxdb_deparse_direct_delete_sql(StringInfo buf, PlannerInfo *root,
											   Index rtindex, Relation rel,
											   RelOptInfo *foreignrel,
											   List *remote_conds,
											   List **params_list,
											   List **retrieved_attrs);
extern void influxdb_deparse_drop_measurement_stmt(StringInfo buf, Relation rel);
extern void influxdb_append_where_clause(StringInfo buf, PlannerInfo *root, RelOptInfo *baserel, List *exprs,
										 bool is_first, List **params);
extern void influxdb_deparse_analyze(StringInfo buf, char *dbname, char *relname);
extern void influxdb_deparse_string_literal(StringInfo buf, const char *val);
extern List *influxdb_build_tlist_to_deparse(RelOptInfo *foreignrel);
extern int	influxdb_set_transmission_modes(void);
extern void influxdb_reset_transmission_modes(int nestlevel);

extern Datum influxdb_convert_to_pg(Oid pgtyp, int pgtypmod, char *value);
extern Datum influxdb_convert_record_to_datum(Oid pgtyp, int pgtypmod, char **row, int attnum, int ntags, int nfield,
											  char **column, char *opername, Oid relid, int ncol, bool is_schemaless);

extern void influxdb_bind_sql_var(Oid type, int attnum, Datum value, InfluxDBColumnInfo *param_column_info,
								  InfluxDBType * param_influxdb_types, InfluxDBValue * param_influxdb_values);
extern char *influxdb_get_data_type_name(Oid data_type_id);
extern bool influxdb_is_mixing_aggref(List *tlist);
extern bool influxdb_is_tag_key(const char *colname, Oid reloid);
extern char *influxdb_get_column_name(Oid relid, int attnum);
extern char *influxdb_get_table_name(Relation rel);
extern int	influxdb_get_number_field_key_match(Oid relid, char *regex);
extern int	influxdb_get_number_tag_key(Oid relid, schemaless_info * pslinfo);
extern bool influxdb_is_builtin(Oid oid);
extern bool influxdb_is_regex_argument(Const *node, char **extval);
extern bool influxdb_is_star_func(Oid funcid, char *in);
extern List *influxdb_pull_func_clause(Node *node);
extern bool influxdb_is_grouping_target(TargetEntry *tle, Query *query);
extern char *influxdb_escape_json_string(char *string);
extern char *influxdb_escape_record_string(char *string);

extern List *influxdb_pull_slvars(Expr *expr, Index varno, List *columns, bool extract_raw, List *remote_exprs, schemaless_info * pslinfo);
extern void influxdb_get_schemaless_info(schemaless_info * pslinfo, bool schemaless, Oid reloid);
extern char *influxdb_get_slvar(Expr *node, schemaless_info * slinfo);

extern bool influxdb_is_select_all(RangeTblEntry *rte, List *tlist, schemaless_info * pslinfo);
extern bool influxdb_is_slvar(Oid oid, int attnum, schemaless_info * pslinfo, bool *is_tags, bool *is_fields);
extern bool influxdb_is_slvar_fetch(Node *node, schemaless_info * pslinfo);
extern bool influxdb_is_param_fetch(Node *node, schemaless_info * pslinfo);

#ifdef CXX_CLIENT
/* InfluxDBSchemaInfo returns information of table if success */
extern struct InfluxDBSchemaInfo_return InfluxDBSchemaInfo(UserMapping *user, influxdb_opt *opts);
/* InfluxDBFreeSchemaInfo returns nothing */
extern void InfluxDBFreeSchemaInfo(struct TableInfo* tableInfo, long long length);
/* InfluxDBQuery returns result set */
extern struct InfluxDBQuery_return InfluxDBQuery(char *query, UserMapping *user, influxdb_opt *opts, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum);
/* InfluxDBFreeResult returns nothing */
extern void InfluxDBFreeResult(InfluxDBResult* result);
/* InfluxDBInsert returns nil if success */
extern char* InfluxDBInsert(char *table_name, UserMapping *user, influxdb_opt *opts, struct InfluxDBColumnInfo* ccolumns, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum, int cnumSlots);
/* If version not set, check to which version can be connected  */
extern int check_connected_influxdb_version(char* addr, int port, char* user, char* pass, char* db, char* auth_token, char* retention_policy);
/* clean up all cache connections of influx cxx client */
extern void cleanup_cxx_client_connection(void);
#endif		/* CXX_CLIENT */

extern
#if (PG_VERSION_NUM >= 160000)
PGDLLEXPORT
#endif
int	ExecForeignDDL(Oid serverOid,
						   Relation rel,
						   int operation,
						   bool if_not_exists);
#endif							/* InfluxDB_FDW_H */
