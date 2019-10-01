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

#include "_obj/_cgo_export.h"

#include "foreign/foreign.h"
#include "lib/stringinfo.h"
#include "nodes/relation.h"
#include "utils/rel.h"

#define WAIT_TIMEOUT		0
#define INTERACTIVE_TIMEOUT 0
#define INFLUXDB_TIME_COLUMN "time"
#define INFLUXDB_TIME_TEXT_COLUMN "time_text"
#define INFLUXDB_IS_TIME_COLUMN(X) (strcmp(X,INFLUXDB_TIME_COLUMN) == 0 || \
						  strcmp(X,INFLUXDB_TIME_TEXT_COLUMN) == 0)
#define CR_NO_ERROR 0

/*
 * Options structure to store the InfluxDB
 * server information
 */
typedef struct influxdb_opt
{
	char	   *svr_database;	/* InfluxDB database name */
	char	   *svr_table;		/* InfluxDB table name */
	char	   *svr_address;	/* MySQL server ip address */
	int			svr_port;		/* InfluxDB port number */
	char	   *svr_username;	/* MySQL user name */
	char	   *svr_password;	/* MySQL password */
}			influxdb_opt;


/*
 * FDW-specific information for ForeignScanState
 * fdw_state.
 */
typedef struct InfluxDBFdwExecState
{
	char	   *query;			/* Query string */
	Relation	rel;			/* relcache entry for the foreign table */
	Oid			relid;			/* relation oid */
	List	   *retrieved_attrs;	/* list of target attribute numbers */

	char	  **params;
	bool		cursor_exists;	/* have we created the cursor? */
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */
	Oid		   *param_types;	/* type of query parameters */
	InfluxDBType *param_influxdb_types; /* influxdb type of query parameters */
	InfluxDBValue *param_influxdb_values;	/* values for influxdb */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */

	influxdb_opt *influxdbFdwOptions;	/* InfluxDB FDW options */

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
	/* Estimated size and cost for a scan or join. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	/* Costs excluding costs for transferring data from the foreign server */
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;
	List	   *shippable_extensions;	/* OIDs of whitelisted extensions */
	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* Cost and selectivity of local_conds. */
	Selectivity local_conds_sel;


	/* Join information */
	RelOptInfo *outerrel;
	RelOptInfo *innerrel;
	JoinType	jointype;
	List	   *joinclauses;

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;

	/*
	 * Name of the relation while EXPLAINing ForeignScan. It is used for join
	 * relations but is set for all relations. For join relation, the name
	 * indicates which foreign tables are being joined and the join type used.
	 */
	StringInfo	relation_name;

	/* Grouping information */
	List	   *grouped_tlist;
}			InfluxDBFdwRelationInfo;


extern bool influxdb_is_foreign_expr(PlannerInfo *root,
									 RelOptInfo *baserel,
									 Expr *expr);


/* option.c headers */
extern influxdb_opt * influxdb_get_options(Oid foreigntableid);

/* depare.c headers */
extern void influxdbDeparseSelectStmtForRel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
											List *tlist, List *remote_conds, List *pathkeys,
											bool is_subquery, List **retrieved_attrs,
											List **params_list);
extern void influxdb_deparse_insert(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *targetAttrs);
extern void influxdb_deparse_update(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *targetAttrs, List *attname);
extern void influxdb_deparse_delete(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel, List *name);
extern void influxdb_append_where_clause(StringInfo buf, PlannerInfo *root, RelOptInfo *baserel, List *exprs,
										 bool is_first, List **params);
extern void influxdb_deparse_analyze(StringInfo buf, char *dbname, char *relname);
extern void influxdb_deparse_string_literal(StringInfo buf, const char *val);
extern List *influxdb_build_tlist_to_deparse(RelOptInfo *foreignrel);
extern int	influxdb_set_transmission_modes(void);
extern void influxdb_reset_transmission_modes(int nestlevel);

extern Datum influxdb_convert_to_pg(Oid pgtyp, int pgtypmod, char **row, int attnum);

extern void influxdb_bind_sql_var(Oid type, int attnum, Datum value, bool *isnull,
								  InfluxDBType * param_influxdb_types, InfluxDBValue * param_influxdb_values);
extern char *influxdb_get_function_name(Oid funcid);

#endif							/* InfluxDB_FDW_H */
