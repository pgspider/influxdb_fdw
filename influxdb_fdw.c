/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        influxdb_fdw.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "influxdb_fdw.h"

#include <stdio.h>

#include "access/reloptions.h"
#include "access/htup_details.h"
#include "access/sysattr.h"
#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#if (PG_VERSION_NUM >= 140000)
#include "optimizer/appendinfo.h"
#endif
#include "optimizer/pathnode.h"
#include "optimizer/planmain.h"
#include "optimizer/cost.h"
#include "optimizer/clauses.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/paths.h"
#include "optimizer/prep.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/tlist.h"
#include "funcapi.h"
#include "utils/builtins.h"
#include "utils/formatting.h"
#include "utils/rel.h"
#include "utils/lsyscache.h"
#include "utils/array.h"
#include "utils/date.h"
#include "utils/hsearch.h"
#include "utils/timestamp.h"
#include "utils/guc.h"
#include "utils/memutils.h"
#include "catalog/pg_collation.h"
#include "catalog/pg_foreign_server.h"
#include "catalog/pg_foreign_table.h"
#include "catalog/pg_user_mapping.h"
#include "catalog/pg_aggregate.h"
#include "catalog/pg_type.h"
#include "catalog/pg_proc.h"
#include "commands/defrem.h"
#include "commands/explain.h"
#include "commands/vacuum.h"
#include "storage/ipc.h"
#include "storage/latch.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "parser/parsetree.h"
#include "utils/typcache.h"
#include "utils/selfuncs.h"
#include "utils/syscache.h"

extern PGDLLEXPORT void _PG_init(void);

bool		influxdb_load_library(void);
static void influxdb_fdw_exit(int code, Datum arg);

PG_MODULE_MAGIC;

 /* Default CPU cost to start up a foreign query. */
#define DEFAULT_FDW_STARTUP_COST    100.0

 /* Default CPU cost to process 1 row (above and beyond cpu_tuple_cost). */
#define DEFAULT_FDW_TUPLE_COST      0.01

 /* If no remote estimates, assume a sort costs 20% extra */
#define DEFAULT_FDW_SORT_MULTIPLIER 1.2

#define IS_KEY_COLUMN(A) ((strcmp(A->defname, "key") == 0) && \
						  (strcmp(((Value *)(A->arg))->val.str, "true") == 0))

extern Datum influxdb_fdw_handler(PG_FUNCTION_ARGS);
extern Datum influxdb_fdw_validator(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(influxdb_fdw_handler);
PG_FUNCTION_INFO_V1(influxdb_fdw_version);

static void influxdbGetForeignRelSize(PlannerInfo *root,
									  RelOptInfo *baserel,
									  Oid foreigntableid);

static void influxdbGetForeignPaths(PlannerInfo *root,
									RelOptInfo *baserel,
									Oid foreigntableid);

static ForeignScan *influxdbGetForeignPlan(PlannerInfo *root,
										   RelOptInfo *baserel,
										   Oid foreigntableid,
										   ForeignPath *best_path,
										   List *tlist,
										   List *scan_clauses,
										   Plan *outer_plan);

static void influxdbBeginForeignScan(ForeignScanState *node,
									 int eflags);

static TupleTableSlot *influxdbIterateForeignScan(ForeignScanState *node);

static void influxdbReScanForeignScan(ForeignScanState *node);

static void influxdbEndForeignScan(ForeignScanState *node);

static void influxdbAddForeignUpdateTargets(
#if (PG_VERSION_NUM < 140000)
											Query *parsetree,
#else
											PlannerInfo *root,
											Index rtindex,
#endif
											RangeTblEntry *target_rte,
											Relation target_relation);

static List *influxdbPlanForeignModify(PlannerInfo *root,
									   ModifyTable *plan,
									   Index resultRelation,
									   int subplan_index);

static void influxdbBeginForeignModify(ModifyTableState *mtstate,
									   ResultRelInfo *resultRelInfo,
									   List *fdw_private,
									   int subplan_index,
									   int eflags);

static TupleTableSlot *influxdbExecForeignInsert(EState *estate,
												 ResultRelInfo *resultRelInfo,
												 TupleTableSlot *slot,
												 TupleTableSlot *planSlot);
#if (PG_VERSION_NUM >= 140000)
static TupleTableSlot **influxdbExecForeignBatchInsert(EState *estate,
													   ResultRelInfo *resultRelInfo,
													   TupleTableSlot **slots,
													   TupleTableSlot **planSlots,
													   int *numSlots);
static int	influxdbGetForeignModifyBatchSize(ResultRelInfo *resultRelInfo);
#endif
static TupleTableSlot *influxdbExecForeignDelete(EState *estate,
												 ResultRelInfo *rinfo,
												 TupleTableSlot *slot,
												 TupleTableSlot *planSlot);

static void influxdbEndForeignModify(EState *estate,
									 ResultRelInfo *resultRelInfo);

#if (PG_VERSION_NUM >= 110000)
static void influxdbEndForeignInsert(EState *estate,
									 ResultRelInfo *resultRelInfo);
static void influxdbBeginForeignInsert(ModifyTableState *mtstate,
									   ResultRelInfo *resultRelInfo);
#endif

static bool influxdbPlanDirectModify(PlannerInfo *root,
									 ModifyTable *plan,
									 Index resultRelation,
									 int subplan_index);

static void influxdbBeginDirectModify(ForeignScanState *node, int eflags);

static TupleTableSlot *influxdbIterateDirectModify(ForeignScanState *node);

static void influxdbEndDirectModify(ForeignScanState *node);

static void influxdbExplainForeignScan(ForeignScanState *node,
									   struct ExplainState *es);

static void influxdbExplainForeignModify(ModifyTableState *mtstate,
										 ResultRelInfo *rinfo,
										 List *fdw_private,
										 int subplan_index,
										 struct ExplainState *es);

static void influxdbExplainDirectModify(ForeignScanState *node,
										struct ExplainState *es);

static bool influxdbAnalyzeForeignTable(Relation relation,
										AcquireSampleRowsFunc *func,
										BlockNumber *totalpages);

static List *influxdbImportForeignSchema(ImportForeignSchemaStmt *stmt,
										 Oid serverOid);

static void influxdbGetForeignUpperPaths(PlannerInfo *root,
										 UpperRelationKind stage,
										 RelOptInfo *input_rel,
										 RelOptInfo *output_rel
#if (PG_VERSION_NUM >= 110000)
										 ,void *extra
#endif
);

static void influxdb_to_pg_type(StringInfo str, char *typname);

static void prepare_query_params(PlanState *node,
								 List *fdw_exprs,
								 int numParams,
								 FmgrInfo **param_flinfo,
								 List **param_exprs,
								 const char ***param_values,
								 Oid **param_types,
								 InfluxDBType * *param_influxdb_types,
								 InfluxDBValue * *param_influxdb_values);

static void process_query_params(ExprContext *econtext,
								 FmgrInfo *param_flinfo,
								 List *param_exprs,
								 const char **param_values,
								 Oid *param_types,
								 InfluxDBType * param_influxdb_types,
								 InfluxDBValue * param_influxdb_values);

static void create_cursor(ForeignScanState *node);
static void execute_dml_stmt(ForeignScanState *node);
static TupleTableSlot **execute_foreign_insert_modify(EState *estate,
													  ResultRelInfo *resultRelInfo,
													  TupleTableSlot **slots,
													  TupleTableSlot **planSlots,
													  int numSlots);
static bool foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel);
static void add_foreign_grouping_paths(PlannerInfo *root,
									   RelOptInfo *input_rel,
									   RelOptInfo *grouped_rel);
static bool influxdb_contain_regex_star_functions_walker(Node *node, void *context);
static bool influxdb_contain_regex_star_functions(Node *clause);
#if (PG_VERSION_NUM >= 140000)
static int	influxdb_get_batch_size_option(Relation rel);
#endif

/*
 * This enum describes what's kept in the fdw_private list for a ForeignPath.
 * We store:
 *
 * 1) Boolean flag showing if the remote query has the final sort
 * 2) Boolean flag showing if the remote query has the LIMIT clause
 */
enum FdwPathPrivateIndex
{
	/* has-final-sort flag (as an integer Value node) */
	FdwPathPrivateHasFinalSort,
	/* has-limit flag (as an integer Value node) */
	FdwPathPrivateHasLimit
};

/*
 * Similarly, this enum describes what's kept in the fdw_private list for
 * a ModifyTable node referencing a influxdb_fdw foreign table.  We store:
 *
 * 1) DELETE statement text to be sent to the remote server
 * 2) Integer list of target attribute numbers for INSERT (NIL for a DELETE)
 */
enum FdwModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwModifyPrivateUpdateSql,
	/* Integer list of target attribute numbers */
	FdwModifyPrivateTargetAttnums
};

/*
 * Similarly, this enum describes what's kept in the fdw_private list for
 * a ForeignScan node that modifies a foreign table directly.  We store:
 *
 * 1) UPDATE/DELETE statement text to be sent to the remote server
 * 2) Boolean flag showing if the remote query has a RETURNING clause
 * 3) Integer list of attribute numbers retrieved by RETURNING, if any
 * 4) Boolean flag showing if we set the command es_processed
 */
enum FdwDirectModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwDirectModifyPrivateUpdateSql,
	/* has-returning flag (as an integer Value node) */
	FdwDirectModifyPrivateHasReturning,
	/* Integer list of attribute numbers retrieved by RETURNING */
	FdwDirectModifyPrivateRetrievedAttrs,
	/* set-processed flag (as an integer Value node) */
	FdwDirectModifyPrivateSetProcessed
};

/*
 * Execution state of a foreign scan that modifies a foreign table directly.
 */
typedef struct InfluxDBFdwDirectModifyState
{
	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */

	/* extracted fdw_private data */
	char	   *query;			/* text of UPDATE/DELETE command */
	bool		has_returning;	/* is there a RETURNING clause? */
	List	   *retrieved_attrs;	/* attr numbers retrieved by RETURNING */
	bool		set_processed;	/* do we set the command es_processed? */

	/* for remote query execution */
	char	  **params;
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */
	Oid		   *param_types;	/* type of query parameters */
	InfluxDBType *param_influxdb_types; /* InfluxDB type of query parameters */
	InfluxDBValue *param_influxdb_values;	/* values for InfluxDB */

	influxdb_opt *influxdbFdwOptions;	/* InfluxDB FDW options */

	/* for storing result tuples */
	int			num_tuples;		/* # of result tuples */
	int			next_tuple;		/* index of next one to return */
	Relation	resultRel;		/* relcache entry for the target relation */
	AttrNumber *attnoMap;		/* array of attnums of input user columns */
	AttrNumber	ctidAttno;		/* attnum of input ctid column */
	AttrNumber	oidAttno;		/* attnum of input oid column */
	bool		hasSystemCols;	/* are there system columns of resultRel? */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
}			InfluxDBFdwDirectModifyState;

/*
 * Library load-time initialization, sets on_proc_exit() callback for
 * backend shutdown.
 */
void
_PG_init(void)
{
	on_proc_exit(&influxdb_fdw_exit, PointerGetDatum(NULL));
}

/*
 * influxdb_fdw_exit: Exit callback function.
 */
static void
influxdb_fdw_exit(int code, Datum arg)
{
}

Datum
influxdb_fdw_version(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(CODE_VERSION);
}

Datum
influxdb_fdw_handler(PG_FUNCTION_ARGS)
{
	FdwRoutine *fdwroutine = makeNode(FdwRoutine);

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	fdwroutine->GetForeignRelSize = influxdbGetForeignRelSize;
	fdwroutine->GetForeignPaths = influxdbGetForeignPaths;
	fdwroutine->GetForeignPlan = influxdbGetForeignPlan;

	fdwroutine->BeginForeignScan = influxdbBeginForeignScan;
	fdwroutine->IterateForeignScan = influxdbIterateForeignScan;
	fdwroutine->ReScanForeignScan = influxdbReScanForeignScan;
	fdwroutine->EndForeignScan = influxdbEndForeignScan;

	/* Functions for updating foreign tables */
	fdwroutine->AddForeignUpdateTargets = influxdbAddForeignUpdateTargets;
	fdwroutine->PlanForeignModify = influxdbPlanForeignModify;
	fdwroutine->BeginForeignModify = influxdbBeginForeignModify;
#if (PG_VERSION_NUM >= 140000)
	fdwroutine->ExecForeignBatchInsert = influxdbExecForeignBatchInsert;
	fdwroutine->GetForeignModifyBatchSize = influxdbGetForeignModifyBatchSize;
#endif
	fdwroutine->ExecForeignInsert = influxdbExecForeignInsert;
	fdwroutine->ExecForeignDelete = influxdbExecForeignDelete;
	fdwroutine->EndForeignModify = influxdbEndForeignModify;
#if (PG_VERSION_NUM >= 110000)
	fdwroutine->BeginForeignInsert = influxdbBeginForeignInsert;
	fdwroutine->EndForeignInsert = influxdbEndForeignInsert;
#endif
	fdwroutine->PlanDirectModify = influxdbPlanDirectModify;
	fdwroutine->BeginDirectModify = influxdbBeginDirectModify;
	fdwroutine->IterateDirectModify = influxdbIterateDirectModify;
	fdwroutine->EndDirectModify = influxdbEndDirectModify;

	/* support for EXPLAIN */
	fdwroutine->ExplainForeignScan = influxdbExplainForeignScan;
	fdwroutine->ExplainForeignModify = influxdbExplainForeignModify;
	fdwroutine->ExplainDirectModify = influxdbExplainDirectModify;

	/* support for ANALYSE */
	fdwroutine->AnalyzeForeignTable = influxdbAnalyzeForeignTable;

	/* support for IMPORT FOREIGN SCHEMA */
	fdwroutine->ImportForeignSchema = influxdbImportForeignSchema;

	/* Support functions for upper relation push-down */
	fdwroutine->GetForeignUpperPaths = influxdbGetForeignUpperPaths;
	PG_RETURN_POINTER(fdwroutine);
}

/*
 * estimate_path_cost_size
 *		Get cost and size estimates for a foreign scan on given foreign relation
 *		either a base relation or a join between foreign relations.
 *
 * param_join_conds are the parameterization clauses with outer relations.
 * pathkeys specify the expected sort order if any for given path being costed.
 *
 * The function returns the cost and size estimates in p_row, p_width,
 * p_startup_cost and p_total_cost variables.
 */
static void
estimate_path_cost_size(PlannerInfo *root,
						RelOptInfo *foreignrel,
						List *param_join_conds,
						List *pathkeys,
						double *p_rows, int *p_width,
						Cost *p_startup_cost, Cost *p_total_cost)
{
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) foreignrel->fdw_private;
	double		rows;
	double		retrieved_rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	Cost		cpu_per_tuple;

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction+join clauses.  Otherwise,
	 * estimate rows using whatever statistics we have locally, in a way
	 * similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		ereport(ERROR, (errmsg("Remote estimation is unsupported")));
	}
	else
	{
		Cost		run_cost = 0;

		/*
		 * We don't support join conditions in this mode (hence, no
		 * parameterized paths can be made).
		 */
		Assert(param_join_conds == NIL);

		/*
		 * Use rows/width estimates made by set_baserel_size_estimates() for
		 * base foreign relations and set_joinrel_size_estimates() for join
		 * between foreign relations.
		 */
		rows = foreignrel->rows;
		width = foreignrel->reltarget->width;

		/* Back into an estimate of the number of retrieved rows. */
		retrieved_rows = clamp_row_est(rows / fpinfo->local_conds_sel);

		/*
		 * We will come here again and again with different set of pathkeys
		 * that caller wants to cost. We don't need to calculate the cost of
		 * bare scan each time. Instead, use the costs if we have cached them
		 * already.
		 */
		if (fpinfo->rel_startup_cost > 0 && fpinfo->rel_total_cost > 0)
		{
			startup_cost = fpinfo->rel_startup_cost;
			run_cost = fpinfo->rel_total_cost - fpinfo->rel_startup_cost;
		}
		else
		{
			Assert(foreignrel->reloptkind != RELOPT_JOINREL);
			/* Clamp retrieved rows estimates to at most foreignrel->tuples. */
			retrieved_rows = Min(retrieved_rows, foreignrel->tuples);

			/*
			 * Cost as though this were a seqscan, which is pessimistic.  We
			 * effectively imagine the local_conds are being evaluated
			 * remotely, too.
			 */
			startup_cost = 0;
			run_cost = 0;
			run_cost += seq_page_cost * foreignrel->pages;

			startup_cost += foreignrel->baserestrictcost.startup;
			cpu_per_tuple =
				cpu_tuple_cost + foreignrel->baserestrictcost.per_tuple;
			run_cost += cpu_per_tuple * foreignrel->tuples;
		}

		/*
		 * Without remote estimates, we have no real way to estimate the cost
		 * of generating sorted output.  It could be free if the query plan
		 * the remote side would have chosen generates properly-sorted output
		 * anyway, but in most cases it will cost something.  Estimate a value
		 * high enough that we won't pick the sorted path when the ordering
		 * isn't locally useful, but low enough that we'll err on the side of
		 * pushing down the ORDER BY clause when it's useful to do so.
		 */
		if (pathkeys != NIL)
		{
			startup_cost *= DEFAULT_FDW_SORT_MULTIPLIER;
			run_cost *= DEFAULT_FDW_SORT_MULTIPLIER;
		}

		total_cost = startup_cost + run_cost;
	}

	/*
	 * Cache the costs for scans without any pathkeys or parameterization
	 * before adding the costs for transferring data from the foreign server.
	 * These costs are useful for costing the join between this relation and
	 * another foreign relation or to calculate the costs of paths with
	 * pathkeys for this relation, when the costs can not be obtained from the
	 * foreign server. This function will be called at least once for every
	 * foreign relation without pathkeys and parameterization.
	 */
	if (pathkeys == NIL && param_join_conds == NIL)
	{
		fpinfo->rel_startup_cost = startup_cost;
		fpinfo->rel_total_cost = total_cost;
	}

	/*
	 * Add some additional cost factors to account for connection overhead
	 * (fdw_startup_cost), transferring data across the network
	 * (fdw_tuple_cost per retrieved row), and local manipulation of the data
	 * (cpu_tuple_cost per retrieved row).
	 */
	startup_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_tuple_cost * retrieved_rows;
	total_cost += cpu_tuple_cost * retrieved_rows;

	/* Return results. */
	*p_rows = rows;
	*p_width = width;
	*p_startup_cost = startup_cost;
	*p_total_cost = total_cost;
}

/*
 * influxdbGetForeignRelSize: Create a FdwPlan for a scan on the foreign table
 */
static void
influxdbGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	InfluxDBFdwRelationInfo *fpinfo;
	ListCell   *lc;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);
	fpinfo = (InfluxDBFdwRelationInfo *) palloc0(sizeof(InfluxDBFdwRelationInfo));
	baserel->fdw_private = (void *) fpinfo;

	/* Base foreign tables need to be pushed down always. */
	fpinfo->pushdown_safe = true;
	/* Look up foreign-table catalog info. */
	fpinfo->table = GetForeignTable(foreigntableid);
	fpinfo->server = GetForeignServer(fpinfo->table->serverid);

	/*
	 * Identify which baserestrictinfo clauses can be sent to the remote
	 * server and which can't.
	 */
	foreach(lc, baserel->baserestrictinfo)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		if (influxdb_is_foreign_expr(root, baserel, ri->clause, false))
			fpinfo->remote_conds = lappend(fpinfo->remote_conds, ri);
		else
			fpinfo->local_conds = lappend(fpinfo->local_conds, ri);
	}

	/*
	 * Identify which attributes will need to be retrieved from the remote
	 * server.
	 */
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid, &fpinfo->attrs_used);

	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);

		pull_varattnos((Node *) rinfo->clause, baserel->relid, &fpinfo->attrs_used);
	}

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path.  The best we can do for these
	 * conditions is to estimate selectivity on the basis of local statistics.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 baserel->relid,
													 JOIN_INNER,
													 NULL);

	/*
	 * Set cached relation costs to some negative value, so that we can detect
	 * when they are set to some sensible costs during one (usually the first)
	 * of the calls to estimate_path_cost_size().
	 */
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction clauses, as well as the
	 * average row width.  Otherwise, estimate using whatever statistics we
	 * have locally, in a way similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		ereport(ERROR, (errmsg("Remote estimation is unsupported")));
	}
	else
	{
		/*
		 * We can't do much if we're not allowed to consult the remote server,
		 * but we can use a hack similar to plancat.c's treatment of empty
		 * relations: use a minimum size estimate of 10 pages, and divide by
		 * the column-datatype-based width estimate to get the corresponding
		 * number of tuples.
		 */
#if (PG_VERSION_NUM < 140000)
		/*
		 * If the foreign table has never been ANALYZEd, it will have relpages
		 * and reltuples equal to zero, which most likely has nothing to do
		 * with reality.
		 */
		if (baserel->pages == 0 && baserel->tuples == 0)
#else
		/*
		 * If the foreign table has never been ANALYZEd, it will have
		 * reltuples < 0, meaning "unknown"
		 */
		if (baserel->tuples < 0)
#endif
		{
			baserel->pages = 10;
			baserel->tuples =
				(10 * BLCKSZ) / (baserel->reltarget->width +
								 MAXALIGN(SizeofHeapTupleHeader));
		}

		/* Estimate baserel size as best we can with local statistics. */
		set_baserel_size_estimates(root, baserel);

		/* Fill in basically-bogus cost estimates for use later. */
		estimate_path_cost_size(root, baserel, NIL, NIL,
								&fpinfo->rows, &fpinfo->width,
								&fpinfo->startup_cost, &fpinfo->total_cost);
	}

	/*
	 * Set the name of relation in fpinfo, while we are constructing it here.
	 * It will be used to build the string describing the join relation in
	 * EXPLAIN output. We can't know whether VERBOSE option is specified or
	 * not, so always schema-qualify the foreign table name.
	 */
	fpinfo->relation_name = psprintf("%u", baserel->relid);
}

/*
 * influxdbGetForeignPaths
 *		Create possible scan paths for a scan on the foreign table
 */
static void
influxdbGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid)
{
	Cost		startup_cost = 10;
	Cost		total_cost = baserel->rows + startup_cost;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);
	/* Estimate costs */
	total_cost = baserel->rows;

	/* Create a ForeignPath node and add it as only possible path */
	add_path(baserel, (Path *)
			 create_foreignscan_path(root, baserel,
									 NULL,	/* default pathtarget */
									 baserel->rows,
									 startup_cost,
									 total_cost,
									 NIL,	/* no pathkeys */
#if (PG_VERSION_NUM >= 120000)
									 baserel->lateral_relids,
#else
									 NULL,	/* no outer rel either */
#endif
									 NULL,	/* no extra plan */
									 NULL));	/* no fdw_private data */
}

/*
 * influxdbGetForeignPlan: Get a foreign scan plan node
 */
static ForeignScan *
influxdbGetForeignPlan(PlannerInfo *root,
					   RelOptInfo *baserel,
					   Oid foreigntableid,
					   ForeignPath *best_path,
					   List *tlist,
					   List *scan_clauses,
					   Plan *outer_plan)
{
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) baserel->fdw_private;
	Index		scan_relid = baserel->relid;
	List	   *fdw_private = NULL;
	List	   *local_exprs = NULL;
	List	   *remote_exprs = NULL;
	List	   *params_list = NULL;
	List	   *fdw_scan_tlist = NIL;
	List	   *remote_conds = NIL;

	StringInfoData sql;
	List	   *retrieved_attrs;
	ListCell   *lc;
	List	   *fdw_recheck_quals = NIL;
	int			for_update;
	bool		has_limit = false;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/* Decide to execute function pushdown support in the target list. */
	fpinfo->is_tlist_func_pushdown = influxdb_is_foreign_function_tlist(root, baserel, tlist);

	/*
	 * Get FDW private data created by influxdbGetForeignUpperPaths(), if any.
	 */
	if (best_path->fdw_private)
	{
		has_limit = intVal(list_nth(best_path->fdw_private, FdwPathPrivateHasLimit));
	}

	/*
	 * Build the query string to be sent for execution, and identify
	 * expressions to be sent as parameters.
	 */

	/* Build the query */
	initStringInfo(&sql);

	/*
	 * Separate the scan_clauses into those that can be executed remotely and
	 * those that can't.  baserestrictinfo clauses that were previously
	 * determined to be safe or unsafe by classifyConditions are shown in
	 * fpinfo->remote_conds and fpinfo->local_conds.  Anything else in the
	 * scan_clauses list will be a join clause, which we have to check for
	 * remote-safety.
	 *
	 * Note: the join clauses we see here should be the exact same ones
	 * previously examined by influxdbGetForeignPaths.  Possibly it'd be worth
	 * passing forward the classification work done then, rather than
	 * repeating it here.
	 *
	 * This code must match "extract_actual_clauses(scan_clauses, false)"
	 * except for the additional decision about remote versus local execution.
	 * Note however that we only strip the RestrictInfo nodes from the
	 * local_exprs list, since appendWhereClause expects a list of
	 * RestrictInfos.
	 */
	if ((baserel->reloptkind == RELOPT_BASEREL ||
		 baserel->reloptkind == RELOPT_OTHER_MEMBER_REL) &&
		fpinfo->is_tlist_func_pushdown == false)
	{
		foreach(lc, scan_clauses)
		{
			RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);

			Assert(IsA(rinfo, RestrictInfo));

			/* Ignore any pseudoconstants, they're dealt with elsewhere */
			if (rinfo->pseudoconstant)
				continue;

			if (list_member_ptr(fpinfo->remote_conds, rinfo))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else if (list_member_ptr(fpinfo->local_conds, rinfo))
				local_exprs = lappend(local_exprs, rinfo->clause);
			else if (influxdb_is_foreign_expr(root, baserel, rinfo->clause, false))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else
				local_exprs = lappend(local_exprs, rinfo->clause);

			/*
			 * For a base-relation scan, we have to support EPQ recheck, which
			 * should recheck all the remote quals.
			 */
			fdw_recheck_quals = remote_exprs;
		}
	}
	else
	{
		/*
		 * Join relation or upper relation - set scan_relid to 0.
		 */
		scan_relid = 0;

		/*
		 * For a join rel, baserestrictinfo is NIL and we are not considering
		 * parameterization right now, so there should be no scan_clauses for
		 * a joinrel or an upper rel either.
		 */
		if (fpinfo->is_tlist_func_pushdown == false)
		{
			Assert(!scan_clauses);
		}

		/*
		 * Instead we get the conditions to apply from the fdw_private
		 * structure.
		 */
		remote_exprs = extract_actual_clauses(fpinfo->remote_conds, false);
		local_exprs = extract_actual_clauses(fpinfo->local_conds, false);

		/*
		 * We leave fdw_recheck_quals empty in this case, since we never need
		 * to apply EPQ recheck clauses.  In the case of a joinrel, EPQ
		 * recheck is handled elsewhere --- see influxdbGetForeignJoinPaths().
		 * If we're planning an upperrel (ie, remote grouping or aggregation)
		 * then there's no EPQ to do because SELECT FOR UPDATE wouldn't be
		 * allowed, and indeed we *can't* put the remote clauses into
		 * fdw_recheck_quals because the unaggregated Vars won't be available
		 * locally.
		 */

		/* Build the list of columns to be fetched from the foreign server. */
		if (fpinfo->is_tlist_func_pushdown == true)
		{
			foreach(lc, tlist)
			{
				TargetEntry *tle = lfirst_node(TargetEntry, lc);

				/*
				 * Pull out function from FieldSelect clause and add to
				 * fdw_scan_tlist to push down function portion only
				 */
				if (fpinfo->is_tlist_func_pushdown == true && IsA((Node *) tle->expr, FieldSelect))
				{
					fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
													   influxdb_pull_func_clause((Node *) tle->expr));
				}
				else
				{
					fdw_scan_tlist = lappend(fdw_scan_tlist, tle);
				}
			}

			foreach(lc, fpinfo->local_conds)
			{
				RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

				fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
												   pull_var_clause((Node *) rinfo->clause,
																   PVC_RECURSE_PLACEHOLDERS));
			}
		}
		else
		{
			fdw_scan_tlist = influxdb_build_tlist_to_deparse(baserel);
		}

		/*
		 * Ensure that the outer plan produces a tuple whose descriptor
		 * matches our scan tuple slot. This is safe because all scans and
		 * joins support projection, so we never need to insert a Result node.
		 * Also, remove the local conditions from outer plan's quals, lest
		 * they will be evaluated twice, once by the local plan and once by
		 * the scan.
		 */
		if (outer_plan)
		{
			ListCell   *lc;

			/*
			 * Right now, we only consider grouping and aggregation beyond
			 * joins. Queries involving aggregates or grouping do not require
			 * EPQ mechanism, hence should not have an outer plan here.
			 */
			Assert(baserel->reloptkind != RELOPT_UPPER_REL);
			outer_plan->targetlist = fdw_scan_tlist;

			foreach(lc, local_exprs)
			{
				Join	   *join_plan = (Join *) outer_plan;
				Node	   *qual = lfirst(lc);

				outer_plan->qual = list_delete(outer_plan->qual, qual);

				/*
				 * For an inner join the local conditions of foreign scan plan
				 * can be part of the joinquals as well.
				 */
				if (join_plan->jointype == JOIN_INNER)
					join_plan->joinqual = list_delete(join_plan->joinqual,
													  qual);
			}
		}
	}

	/*
	 * Build the query string to be sent for execution, and identify
	 * expressions to be sent as parameters.
	 */
	initStringInfo(&sql);
	influxdb_deparse_select_stmt_for_rel(&sql, root, baserel, fdw_scan_tlist,
										 remote_exprs, best_path->path.pathkeys,
										 false, &retrieved_attrs, &params_list, has_limit);

	/* Remember remote_exprs for possible use by influxdbPlanDirectModify */
	fpinfo->final_remote_exprs = remote_exprs;

	for_update = false;
	if (baserel->relid == root->parse->resultRelation &&
		(root->parse->commandType == CMD_UPDATE ||
		 root->parse->commandType == CMD_DELETE))
	{
		/* Relation is UPDATE/DELETE target, so use FOR UPDATE */
		for_update = true;
	}

	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwScanPrivateIndex, above.
	 */
	fdw_private = list_make3(makeString(sql.data), retrieved_attrs, makeInteger(for_update));
	fdw_private = lappend(fdw_private, fdw_scan_tlist);
	fdw_private = lappend(fdw_private, makeInteger(fpinfo->is_tlist_func_pushdown));

	/*
	 * Create the ForeignScan node from target list, local filtering
	 * expressions, remote parameter expressions, and FDW private information.
	 *
	 * Note that the remote parameter expressions are stored in the fdw_exprs
	 * field of the finished plan node; we can't keep them in private state
	 * because then they wouldn't be subject to later planner processing.
	 */
	return make_foreignscan(tlist,
							local_exprs,
							scan_relid,
							params_list,
							fdw_private,
							fdw_scan_tlist,
							fdw_recheck_quals,
							outer_plan);
}

/*
 * influxdbBeginForeignScan: Initiate access to the database
 */
static void
influxdbBeginForeignScan(ForeignScanState *node, int eflags)
{
	InfluxDBFdwExecState *festate = NULL;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	int			numParams;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * We'll save private state in node->fdw_state.
	 */
	festate = (InfluxDBFdwExecState *) palloc0(sizeof(InfluxDBFdwExecState));
	node->fdw_state = (void *) festate;
	festate->rowidx = 0;

	/* Stash away the state info we have already */
	festate->query = strVal(list_nth(fsplan->fdw_private, 0));
	festate->retrieved_attrs = list_nth(fsplan->fdw_private, 1);
	festate->for_update = intVal(list_nth(fsplan->fdw_private, 2)) ? true : false;
	festate->tlist = (List *) list_nth(fsplan->fdw_private, 3);
	festate->is_tlist_func_pushdown = intVal(list_nth(fsplan->fdw_private, 4)) ? true : false;

	festate->cursor_exists = false;

	/* Prepare for output conversion of parameters used in remote query. */
	numParams = list_length(fsplan->fdw_exprs);
	festate->numParams = numParams;
	if (numParams > 0)
		prepare_query_params((PlanState *) node,
							 fsplan->fdw_exprs,
							 numParams,
							 &festate->param_flinfo,
							 &festate->param_exprs,
							 &festate->param_values,
							 &festate->param_types,
							 &festate->param_influxdb_types,
							 &festate->param_influxdb_values);
}

static void
make_tuple_from_result_row(InfluxDBRow * result_row,
						   InfluxDBResult * result,
						   TupleDesc tupleDescriptor,
						   Datum *row,
						   bool *is_null,
						   Oid relid,
						   InfluxDBFdwExecState * festate,
						   bool is_agg)
{
	ListCell   *lc = NULL;
	int			attid = 0;
	List	   *retrieved_attrs = festate->retrieved_attrs;
	ListCell   *targetc;
	char	   *opername = NULL;

	memset(row, 0, sizeof(Datum) * tupleDescriptor->natts);
	memset(is_null, true, sizeof(bool) * tupleDescriptor->natts);

	targetc = list_head(festate->tlist);
	foreach(lc, retrieved_attrs)
	{
		int			attnum = lfirst_int(lc) - 1;
		Oid			pgtype = TupleDescAttr(tupleDescriptor, attnum)->atttypid;
		int32		pgtypmod = TupleDescAttr(tupleDescriptor, attnum)->atttypmod;
		int			result_idx = 0;
		char	   *colname = NULL;
		bool		is_agg_star = false;
		bool		is_regex = false;
		int			ntags = 0;
		int			nfields = 0;

		if (is_agg)
		{
			/* Aggregate push down case */

			/*
			 * This column is not explicitly added to InfluxDB query, but
			 * InfluxDB returns implicitly
			 */

			Expr	   *target = ((TargetEntry *) lfirst(targetc))->expr;

			if (festate->is_tlist_func_pushdown && IsA(target, Var))
			{
				char	   *name = influxdb_get_column_name(relid, ((Var *) target)->varattno);

				if (INFLUXDB_IS_TIME_COLUMN(name))
				{
					result_idx = 0;
				}
				else
				{
					attid++;
					result_idx = attid;
				}
			}
			else if (IsA(target, Var))
			{
				/* GROUP BY target variable */
				int			i;
				char	   *name = influxdb_get_column_name(relid, ((Var *) target)->varattno);
				int			nfield = result->ncol - result->ntag;

				/*
				 * If target is tag, we get its value from GROUP BY tag
				 * values, otherwise, get target value from result field.
				 */
				if (influxdb_is_tag_key(name, relid))
				{
					/*
					 * Values of GROUP BY tag are stored in the order of
					 * result->tagkeys at the last of result row. We will find
					 * that index
					 */
					for (i = 0; i < result->ntag; i++)
					{
						if (strcmp(name, result->tagkeys[i]) == 0)
						{
							result_idx = nfield + i;
							break;
						}
					}
				}
				else
				{
					if (INFLUXDB_IS_TIME_COLUMN(name))
					{
						result_idx = 0;
					}
					else
					{
						attid++;
						result_idx = attid;
					}
				}
			}
			else if (IsA(target, FuncExpr) &&
					 strcmp(get_func_name(((FuncExpr *) target)->funcid), "influx_time") == 0)
			{
				/* Time column corresponding to influx_time */
				result_idx = 0;
			}
			else if (IsA(target, OpExpr))
			{
				attid++;
				result_idx = attid;
			}
			else if (IsA(target, FuncExpr) || IsA(target, Aggref))
			{
				Aggref	   *agg = (Aggref *) target;
				FuncExpr   *func = (FuncExpr *) target;
				HeapTuple	tuple;
				bool		is_func = false,
							is_agg = false;
				bool		funcstar = false;
				bool		aggstar = false;
				Oid			objectId = InvalidOid;

				if (IsA(target, FuncExpr))
				{
					is_func = true;
					objectId = func->funcid;
				}
				else
				{
					is_agg = true;
					aggstar = agg->aggstar;
					objectId = agg->aggfnoid;
				}
				/* get function name and schema */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(objectId));

				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", objectId);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);

				attid++;
				result_idx = attid;

				/*
				 * count(*) of postgreSQL return only 1 column, which is
				 * different from InfluxDB. It does not need to go here.
				 */
				if ((is_agg && !(aggstar && strcmp(opername, "count") == 0)) || is_func)
				{
					funcstar = influxdb_is_star_func(objectId, opername);

					if ((aggstar || funcstar) && !influxdb_is_builtin(objectId))
					{
						is_agg_star = true;
						nfields = influxdb_get_number_field_key_match(relid, NULL);
						ntags = influxdb_get_number_tag_key(relid);
						attid = attid + nfields - 1;
					}
					else
					{
						ListCell   *regexlc;
						TargetEntry *tle;
						Node	   *n;

						if (is_agg)
						{
							regexlc = list_head(agg->args);
							tle = (TargetEntry *) lfirst(regexlc);
							n = (Node *) tle->expr;
						}
						else
						{
							regexlc = list_head(func->args);
							n = (Node *) lfirst(regexlc);
						}

						if (IsA(n, Const))
						{
							Const	   *arg = (Const *) n;
							char	   *extval;

							if (arg->consttype == TEXTOID)
							{
								is_regex = influxdb_is_regex_argument(arg, &extval);
								if (is_regex == true)
								{
									/*
									 * Remove '/' at the beginning and at the
									 * end of argument
									 */
									extval++;
									extval[strlen(extval) - 1] = 0;

									nfields = influxdb_get_number_field_key_match(relid, extval);
									ntags = influxdb_get_number_tag_key(relid);
									attid = attid + nfields - 1;
								}
							}
						}
					}
				}
				ReleaseSysCache(tuple);
			}
			else if (IsA(target, Const))
			{
				/* In the case of selecting function pushdown and const value */
#if (PG_VERSION_NUM >= 130000)
				targetc = lnext(festate->tlist, targetc);
#else
				targetc = lnext(targetc);
#endif
				continue;
			}
			else
			{
				/*
				 * Other GROUP BY target is not supported
				 */
				elog(ERROR, "not supported");
			}
#if (PG_VERSION_NUM >= 130000)
			targetc = lnext(festate->tlist, targetc);
#else
			targetc = lnext(targetc);
#endif

		}
		else
		{
			colname = influxdb_get_column_name(relid, attnum + 1);
			if (INFLUXDB_IS_TIME_COLUMN(colname))
			{
				result_idx = 0;
			}
			else
			{
				attid++;
				result_idx = attid;
			}
		}

		if (is_agg_star || is_regex)
		{
			is_null[attnum] = false;
			row[attnum] = influxdb_convert_record_to_datum(pgtype, pgtypmod, result_row->tuple,
														   result_idx, ntags, nfields, result->columns,
														   opername, relid, result->ncol - result->ntag);
		}
		else if (result_row->tuple[result_idx] != NULL)
		{
			is_null[attnum] = false;
			row[attnum] = influxdb_convert_to_pg(pgtype, pgtypmod,
												 result_row->tuple, result_idx);
		}
	}
}

/*
 * influxdbIterateForeignScan: Iterate and get the rows one by one from
 * InfluxDB and placed in tuple slot
 */
static TupleTableSlot *
influxdbIterateForeignScan(ForeignScanState *node)
{
	InfluxDBFdwExecState *festate = (InfluxDBFdwExecState *) node->fdw_state;
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	EState	   *estate = node->ss.ps.state;
	TupleDesc	tupleDescriptor = tupleSlot->tts_tupleDescriptor;
	influxdb_opt *options;
	struct InfluxDBQuery_return volatile ret;
	struct InfluxDBResult volatile *result = NULL;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	RangeTblEntry *rte;
	int			rtindex;
	bool		is_agg;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.  In case of a join or aggregate, use the
	 * lowest-numbered member RTE as a representative; we would get the same
	 * result from any.
	 */
	if (fsplan->scan.scanrelid > 0)
	{
		rtindex = fsplan->scan.scanrelid;
		is_agg = false;
	}
	else
	{
		rtindex = bms_next_member(fsplan->fs_relids, -1);
		is_agg = true;
	}
	rte = rt_fetch(rtindex, estate->es_range_table);

	/* Fetch the options */
	options = influxdb_get_options(rte->relid);

	/*
	 * If this is the first call after Begin or ReScan, we need to create the
	 * cursor on the remote side. Binding parameters is done in this function.
	 */
	if (!festate->cursor_exists)
		create_cursor(node);

	memset(tupleSlot->tts_values, 0, sizeof(Datum) * tupleDescriptor->natts);
	memset(tupleSlot->tts_isnull, true, sizeof(bool) * tupleDescriptor->natts);
	ExecClearTuple(tupleSlot);

	if (festate->rowidx == 0)
	{
		MemoryContext oldcontext = NULL;
		int			i;

		PG_TRY();
		{
			ret = InfluxDBQuery(festate->query, options->svr_address, options->svr_port,
								options->svr_username, options->svr_password,
								options->svr_database,
								festate->param_influxdb_types,
								festate->param_influxdb_values,
								festate->numParams);
			if (ret.r1 != NULL)
			{
				char	   *err = pstrdup(ret.r1);

				free(ret.r1);
				ret.r1 = err;
				elog(ERROR, "influxdb_fdw : %s", err);
			}
			result = &ret.r0;
			elog(DEBUG1, "influxdb_fdw : query: %s", festate->query);
			/* festate->rows need longer context than per tuple */
			oldcontext = MemoryContextSwitchTo(estate->es_query_cxt);

			festate->row_nums = result->nrow;
			festate->rows = palloc(sizeof(Datum *) * result->nrow);
			festate->rows_isnull = palloc(sizeof(bool *) * result->nrow);
			for (i = 0; i < result->nrow; i++)
			{
				festate->rows[i] = palloc(sizeof(Datum) * tupleDescriptor->natts);
				festate->rows_isnull[i] = palloc(sizeof(bool) * tupleDescriptor->natts);
				make_tuple_from_result_row(&(result->rows[i]),
										   (struct InfluxDBResult *) result,
										   tupleDescriptor,
										   festate->rows[i],
										   festate->rows_isnull[i],
										   rte->relid,
										   festate,
										   is_agg);
			}
			MemoryContextSwitchTo(oldcontext);
			InfluxDBFreeResult((InfluxDBResult *) result);
		}
		PG_CATCH();
		{
			if (ret.r1 == NULL)
			{
				InfluxDBFreeResult((InfluxDBResult *) result);
			}

			if (oldcontext)
				MemoryContextSwitchTo(oldcontext);

			PG_RE_THROW();
		}
		PG_END_TRY();
	}

	if (festate->rowidx < festate->row_nums)
	{
		memcpy(tupleSlot->tts_values, festate->rows[festate->rowidx], sizeof(Datum) * tupleDescriptor->natts);
		memcpy(tupleSlot->tts_isnull, festate->rows_isnull[festate->rowidx], sizeof(bool) * tupleDescriptor->natts);

		pfree(festate->rows[festate->rowidx]);
		pfree(festate->rows_isnull[festate->rowidx]);

		ExecStoreVirtualTuple(tupleSlot);
		festate->rowidx++;
	}

	return tupleSlot;
}

/*
 * influxdbEndForeignScan: Finish scanning foreign table and dispose
 * objects used for this scan
 */
static void
influxdbEndForeignScan(ForeignScanState *node)
{
	InfluxDBFdwExecState *festate = (InfluxDBFdwExecState *) node->fdw_state;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	if (festate != NULL)
	{
		festate->cursor_exists = false;
		festate->rowidx = 0;
	}
}

/*
 * influxdbAddForeignUpdateTargets
 *		Add resjunk column(s) needed for update/delete on a foreign table
 */
static void
influxdbAddForeignUpdateTargets(
#if (PG_VERSION_NUM < 140000)
								Query *parsetree,
#else
								PlannerInfo *root,
								Index rtindex,
#endif
								RangeTblEntry *target_rte,
								Relation target_relation)
{
	Oid			relid = RelationGetRelid(target_relation);
	TupleDesc	tupdesc = target_relation->rd_att;
	int			i;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/* loop through all columns of the foreign table */
	for (i = 0; i < tupdesc->natts; i++)
	{
		Form_pg_attribute att = TupleDescAttr(tupdesc, i);
		AttrNumber	attrno = att->attnum;
		char	   *colname = influxdb_get_column_name(relid, attrno);

		if (INFLUXDB_IS_TIME_COLUMN(colname) || influxdb_is_tag_key(colname, relid))
		{
			Var		   *var;
#if (PG_VERSION_NUM < 140000)
			TargetEntry *tle;
			Index		rtindex = parsetree->resultRelation;
#endif

			/* Make a Var representing the desired value */
			var = makeVar(rtindex,
						  attrno,
						  att->atttypid,
						  att->atttypmod,
						  att->attcollation,
						  0);
#if (PG_VERSION_NUM < 140000)
			/* Wrap it in a resjunk TLE with the right name ... */
			tle = makeTargetEntry((Expr *) var,
								  list_length(parsetree->targetList) + 1,
								  pstrdup(NameStr(att->attname)),
								  true);

			/* ... and add it to the query's targetlist */
			parsetree->targetList = lappend(parsetree->targetList, tle);
#else
			/* Register it as a row-identity column needed by this target rel */
			add_row_identity_var(root, var, rtindex, pstrdup(NameStr(att->attname)));
#endif

		}
	}
}

/*
 * influxdbPlanForeignModify
 *		Plan an insert/update/delete operation on a foreign table
 */
static List *
influxdbPlanForeignModify(PlannerInfo *root,
						  ModifyTable *plan,
						  Index resultRelation,
						  int subplan_index)
{
	CmdType		operation = plan->operation;
	RangeTblEntry *rte = planner_rt_fetch(resultRelation, root);
	Relation	rel;
	StringInfoData sql;
	List	   *targetAttrs = NIL;
	TupleDesc	tupdesc;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	initStringInfo(&sql);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
	rel = table_open(rte->relid, NoLock);
	tupdesc = RelationGetDescr(rel);

	if (operation == CMD_INSERT)
	{
		int			attnum;

		for (attnum = 1; attnum <= tupdesc->natts; attnum++)
		{
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);

			if (!attr->attisdropped)
				targetAttrs = lappend_int(targetAttrs, attnum);
		}
	}
	else if (operation == CMD_UPDATE)
		elog(ERROR, "UPDATE is not supported");
	else if (operation == CMD_DELETE)
	{
		/* Append time and all tags column */
		int			i;
		Oid			foreignTableId = RelationGetRelid(rel);

		for (i = 0; i < tupdesc->natts; i++)
		{
			Form_pg_attribute attr = TupleDescAttr(tupdesc, i);
			AttrNumber	attrno = attr->attnum;
			char	   *colname = influxdb_get_column_name(foreignTableId, attrno);

			if (INFLUXDB_IS_TIME_COLUMN(colname) || influxdb_is_tag_key(colname, rte->relid))
				if (!attr->attisdropped)
					targetAttrs = lappend_int(targetAttrs, attrno);
		}
	}
	else
		elog(ERROR, "Not supported");

	if (plan->returningLists)
		elog(ERROR, "RETURNING is not supported");

	if (plan->onConflictAction != ONCONFLICT_NONE)
		elog(ERROR, "ON CONFLICT is not supported");

	/*
	 * Deparse statements
	 */
	switch (operation)
	{
		case CMD_INSERT:
		case CMD_UPDATE:
			break;
		case CMD_DELETE:
			influxdb_deparse_delete(&sql, root, resultRelation, rel, targetAttrs);
			break;
		default:
			elog(ERROR, "unexpected operation: %d", (int) operation);
			break;
	}

	table_close(rel, NoLock);

	return list_make2(makeString(sql.data), targetAttrs);
}

/*
 * influxdbBeginForeignModify
 *		Begin an insert/update/delete operation on a foreign table
 */
static void
influxdbBeginForeignModify(ModifyTableState *mtstate,
						   ResultRelInfo *resultRelInfo,
						   List *fdw_private,
						   int subplan_index,
						   int eflags)
{
	InfluxDBFdwExecState *fmstate = NULL;
	EState	   *estate = mtstate->ps.state;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	AttrNumber	n_params = 0;
	Oid			typefnoid = InvalidOid;
	bool		isvarlena = false;
	ListCell   *lc = NULL;
	Oid			foreignTableId = InvalidOid;
	Plan	   *subplan;
	int			i;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case. resultRelInfo->ri_FdwState
	 * stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	foreignTableId = RelationGetRelid(rel);
#if (PG_VERSION_NUM < 140000)
	subplan = mtstate->mt_plans[subplan_index]->plan;
#else
	subplan = outerPlanState(mtstate)->plan;
#endif

	fmstate = (InfluxDBFdwExecState *) palloc0(sizeof(InfluxDBFdwExecState));
	fmstate->rowidx = 0;

	/* Stash away the state info we have already */
	fmstate->influxdbFdwOptions = influxdb_get_options(foreignTableId);
	fmstate->rel = rel;
	fmstate->query = strVal(list_nth(fdw_private, FdwModifyPrivateUpdateSql));
	fmstate->retrieved_attrs = (List *) list_nth(fdw_private, FdwModifyPrivateTargetAttnums);

	if (mtstate->operation == CMD_INSERT)
	{
		fmstate->column_list = NIL;

		if (fmstate->retrieved_attrs)
		{
			foreach(lc, fmstate->retrieved_attrs)
			{
				int			attnum = lfirst_int(lc);
				struct InfluxDBColumnInfo *col = (InfluxDBColumnInfo *) palloc0(sizeof(InfluxDBColumnInfo));

				/* Get column name and set type of column */
				col->column_name = influxdb_get_column_name(foreignTableId, attnum);
				if (INFLUXDB_IS_TIME_COLUMN(col->column_name))
					col->column_type = INFLUXDB_TIME_KEY;
				else if (influxdb_is_tag_key(col->column_name, foreignTableId))
					col->column_type = INFLUXDB_TAG_KEY;
				else
					col->column_type = INFLUXDB_FIELD_KEY;

				/* Append column information into column list */
				fmstate->column_list = lappend(fmstate->column_list, col);
			}
		}
#if (PG_VERSION_NUM >= 140000)
		fmstate->batch_size = influxdb_get_batch_size_option(rel);
#endif
	}

	n_params = list_length(fmstate->retrieved_attrs) + 1;
	fmstate->p_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * n_params);
	fmstate->p_nums = 0;
	fmstate->param_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * n_params);
	fmstate->param_types = (Oid *) palloc0(sizeof(Oid) * n_params);
	fmstate->param_influxdb_types = (InfluxDBType *) palloc0(sizeof(InfluxDBType) * n_params);
	fmstate->param_influxdb_values = (InfluxDBValue *) palloc0(sizeof(InfluxDBValue) * n_params);
	fmstate->param_column_info = (InfluxDBColumnInfo *) palloc0(sizeof(InfluxDBColumnInfo) * n_params);

	/* Create context for per-tuple temp workspace. */
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "influxdb_fdw temporary data",
											  ALLOCSET_SMALL_SIZES);

	/* Set up for remaining transmittable parameters */
	foreach(lc, fmstate->retrieved_attrs)
	{
		int			attnum = lfirst_int(lc);
		Form_pg_attribute attr = TupleDescAttr(RelationGetDescr(rel), attnum - 1);

		Assert(!attr->attisdropped);

		getTypeOutputInfo(attr->atttypid, &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &fmstate->p_flinfo[fmstate->p_nums]);
		fmstate->p_nums++;
	}
	Assert(fmstate->p_nums <= n_params);

	fmstate->junk_idx = palloc0(RelationGetDescr(rel)->natts * sizeof(AttrNumber));
	/* loop through table columns */
	for (i = 0; i < RelationGetDescr(rel)->natts; i++)
	{
		/*
		 * for primary key columns, get the resjunk attribute number and store
		 * it
		 */
		fmstate->junk_idx[i] =
			ExecFindJunkAttributeInTlist(subplan->targetlist,
										 get_attname(foreignTableId, i + 1
#if (PG_VERSION_NUM >= 110000)
													 ,false
#endif
													 ));
	}
	/* Initialize auxiliary state */
	fmstate->aux_fmstate = NULL;

	resultRelInfo->ri_FdwState = fmstate;
}

/*
 * influxdbExecForeignInsert
 *		Insert one row into a foreign table
 */
static TupleTableSlot *
influxdbExecForeignInsert(EState *estate,
						  ResultRelInfo *resultRelInfo,
						  TupleTableSlot *slot,
						  TupleTableSlot *planSlot)
{
	InfluxDBFdwExecState *fmstate = (InfluxDBFdwExecState *) resultRelInfo->ri_FdwState;
	TupleTableSlot **rslot;
	int			numSlots = 1;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * If the fmstate has aux_fmstate set, use the aux_fmstate
	 */
	if (fmstate->aux_fmstate)
		resultRelInfo->ri_FdwState = fmstate->aux_fmstate;
	rslot = execute_foreign_insert_modify(estate, resultRelInfo, &slot,
										  &planSlot, numSlots);
	/* Revert that change */
	if (fmstate->aux_fmstate)
		resultRelInfo->ri_FdwState = fmstate;

	return rslot ? *rslot : NULL;
}

#if (PG_VERSION_NUM >= 140000)
/*
 * influxdbExecForeignBatchInsert
 *		Insert multiple rows into a foreign table
 */
static TupleTableSlot **
influxdbExecForeignBatchInsert(EState *estate,
							   ResultRelInfo *resultRelInfo,
							   TupleTableSlot **slots,
							   TupleTableSlot **planSlots,
							   int *numSlots)
{
	InfluxDBFdwExecState *fmstate = (InfluxDBFdwExecState *) resultRelInfo->ri_FdwState;
	TupleTableSlot **rslot;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * If the fmstate has aux_fmstate set, use the aux_fmstate
	 */
	if (fmstate->aux_fmstate)
		resultRelInfo->ri_FdwState = fmstate->aux_fmstate;
	rslot = execute_foreign_insert_modify(estate, resultRelInfo, slots,
										  planSlots, *numSlots);
	/* Revert that change */
	if (fmstate->aux_fmstate)
		resultRelInfo->ri_FdwState = fmstate;

	return rslot;
}

/*
 * influxdbGetForeignModifyBatchSize
 *		Determine the maximum number of tuples that can be inserted in bulk
 *
 * Returns the batch size specified for server or table. When batching is not
 * allowed (e.g. for tables with AFTER ROW triggers or with RETURNING clause),
 * returns 1.
 */
static int
influxdbGetForeignModifyBatchSize(ResultRelInfo *resultRelInfo)
{
	int			batch_size;
	InfluxDBFdwExecState *fmstate = resultRelInfo->ri_FdwState ?
	(InfluxDBFdwExecState *) resultRelInfo->ri_FdwState :
	NULL;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/* should be called only once */
	Assert(resultRelInfo->ri_BatchSize == 0);

	/*
	 * Should never get called when the insert is being performed as part of a
	 * row movement operation.
	 */
	Assert(fmstate == NULL || fmstate->aux_fmstate == NULL);

	/*
	 * In EXPLAIN without ANALYZE, ri_FdwState is NULL, so we have to lookup
	 * the option directly in server/table options. Otherwise just use the
	 * value we determined earlier.
	 */
	if (fmstate)
		batch_size = fmstate->batch_size;
	else
		batch_size = influxdb_get_batch_size_option(resultRelInfo->ri_RelationDesc);

	/* Disable batching when we have to use RETURNING. */
	if (resultRelInfo->ri_projectReturning != NULL ||
		(resultRelInfo->ri_TrigDesc &&
		 resultRelInfo->ri_TrigDesc->trig_insert_after_row))
		return 1;

	/*
	 * Otherwise use the batch size specified for server/table. The number of
	 * parameters in a batch is limited to 65535 (uint16), so make sure we
	 * don't exceed this limit by using the maximum batch_size possible.
	 */
	if (fmstate && fmstate->p_nums > 0)
		batch_size = Min(batch_size, 65535 / fmstate->p_nums);

	return batch_size;
}
#endif

static void
bindJunkColumnValue(InfluxDBFdwExecState * fmstate,
					TupleTableSlot *slot,
					TupleTableSlot *planSlot,
					Oid foreignTableId,
					int bindnum)
{
	int			i;
	Datum		value;

	/* Bind where condition using junk column */
	for (i = 0; i < slot->tts_tupleDescriptor->natts; i++)
	{
		Oid			type = TupleDescAttr(slot->tts_tupleDescriptor, i)->atttypid;
		bool		is_null = false;

		/* look for the "key" option on this column */
		if (fmstate->junk_idx[i] == InvalidAttrNumber)
			continue;

		/* Get the id that was passed up as a resjunk column */
		value = ExecGetJunkAttribute(planSlot, fmstate->junk_idx[i], &is_null);

		/* Check value is null */
		if (is_null)
		{
			fmstate->param_influxdb_types[bindnum] = INFLUXDB_NULL;
			fmstate->param_influxdb_values[bindnum].i = 0;
		}
		else
			influxdb_bind_sql_var(type, bindnum, value, &is_null,
								  fmstate->param_influxdb_types, fmstate->param_influxdb_values);
		bindnum++;
	}
}

/*
 * influxdbExecForeignDelete
 *		Delete one row from a foreign table
 */
static TupleTableSlot *
influxdbExecForeignDelete(EState *estate,
						  ResultRelInfo *resultRelInfo,
						  TupleTableSlot *slot,
						  TupleTableSlot *planSlot)
{
	InfluxDBFdwExecState *fmstate = (InfluxDBFdwExecState *) resultRelInfo->ri_FdwState;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	Oid			foreignTableId = RelationGetRelid(rel);
	struct InfluxDBQuery_return volatile ret;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	bindJunkColumnValue(fmstate, slot, planSlot, foreignTableId, 0);
	/* Execute the query */
	ret = InfluxDBQuery(fmstate->query, fmstate->influxdbFdwOptions->svr_address,
						fmstate->influxdbFdwOptions->svr_port, fmstate->influxdbFdwOptions->svr_username,
						fmstate->influxdbFdwOptions->svr_password, fmstate->influxdbFdwOptions->svr_database,
						fmstate->param_influxdb_types, fmstate->param_influxdb_values, fmstate->p_nums);
	if (ret.r1 != NULL)
	{
		char	   *err = pstrdup(ret.r1);

		free(ret.r1);
		ret.r1 = err;
		elog(ERROR, "influxdb_fdw : %s", err);
	}

	InfluxDBFreeResult((InfluxDBResult *) & ret.r0);
	/* Return NULL if nothing was updated on the remote end */
	return slot;
}

/*
 * influxdbEndForeignModify
 *		Finish an insert/update/delete operation on a foreign table
 */
static void
influxdbEndForeignModify(EState *estate,
						 ResultRelInfo *resultRelInfo)
{
	InfluxDBFdwExecState *fmstate = (InfluxDBFdwExecState *) resultRelInfo->ri_FdwState;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	if (fmstate != NULL)
	{
		fmstate->cursor_exists = false;
		fmstate->rowidx = 0;
	}
}

#if (PG_VERSION_NUM >= 110000)
static void
influxdbBeginForeignInsert(ModifyTableState *mtstate,
						   ResultRelInfo *resultRelInfo)
{
	elog(ERROR, "Not support partition insert");
}
static void
influxdbEndForeignInsert(EState *estate,
						 ResultRelInfo *resultRelInfo)
{
	elog(ERROR, "Not support partition insert");
}
#endif

#if (PG_VERSION_NUM >= 140000)
/*
 * find_modifytable_subplan
 *		Helper routine for influxdbPlanDirectModify to find the
 *		ModifyTable subplan node that scans the specified RTI.
 *
 * Returns NULL if the subplan couldn't be identified.  That's not a fatal
 * error condition, we just abandon trying to do the update directly.
 */
static ForeignScan *
find_modifytable_subplan(PlannerInfo *root,
						 ModifyTable *plan,
						 Index rtindex,
						 int subplan_index)
{
	Plan	   *subplan = outerPlan(plan);

	/*
	 * The cases we support are (1) the desired ForeignScan is the immediate
	 * child of ModifyTable, or (2) it is the subplan_index'th child of an
	 * Append node that is the immediate child of ModifyTable.  There is no
	 * point in looking further down, as that would mean that local joins are
	 * involved, so we can't do the update directly.
	 *
	 * There could be a Result atop the Append too, acting to compute the
	 * UPDATE targetlist values.  We ignore that here; the tlist will be
	 * checked by our caller.
	 *
	 * In principle we could examine all the children of the Append, but it's
	 * currently unlikely that the core planner would generate such a plan
	 * with the children out-of-order.  Moreover, such a search risks costing
	 * O(N^2) time when there are a lot of children.
	 */
	if (IsA(subplan, Append))
	{
		Append	   *appendplan = (Append *) subplan;

		if (subplan_index < list_length(appendplan->appendplans))
			subplan = (Plan *) list_nth(appendplan->appendplans, subplan_index);
	}
	else if (IsA(subplan, Result) &&
			 outerPlan(subplan) != NULL &&
			 IsA(outerPlan(subplan), Append))
	{
		Append	   *appendplan = (Append *) outerPlan(subplan);

		if (subplan_index < list_length(appendplan->appendplans))
			subplan = (Plan *) list_nth(appendplan->appendplans, subplan_index);
	}

	/* Now, have we got a ForeignScan on the desired rel? */
	if (IsA(subplan, ForeignScan))
	{
		ForeignScan *fscan = (ForeignScan *) subplan;

		if (bms_is_member(rtindex, fscan->fs_relids))
			return fscan;
	}

	return NULL;
}
#endif

/*
 * influxdbPlanDirectModify Consider a direct foreign table modification
 *
 * Decide whether it is safe to modify a foreign table directly, and if so,
 * rewrite subplan accordingly.
 */
static bool
influxdbPlanDirectModify(PlannerInfo *root,
						 ModifyTable *plan,
						 Index resultRelation,
						 int subplan_index)
{
	CmdType		operation = plan->operation;
	RelOptInfo *foreignrel;
	RangeTblEntry *rte;
	InfluxDBFdwRelationInfo *fpinfo;
	Relation	rel;
	StringInfoData sql;
	ForeignScan *fscan;
	List	   *remote_exprs;
	List	   *params_list = NIL;
	List	   *retrieved_attrs = NIL;
#if (PG_VERSION_NUM < 140000)
	Plan	   *subplan;
#endif

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * Decide whether it is safe to modify a foreign table directly.
	 */

	/*
	 * The table modification must be an DELETE.
	 */
	if (operation != CMD_DELETE)
		return false;

#if (PG_VERSION_NUM < 140000)

	/*
	 * It's unsafe to modify a foreign table directly if there are any local
	 * joins needed.
	 */
	subplan = (Plan *) list_nth(plan->plans, subplan_index);
	if (!IsA(subplan, ForeignScan))
		return false;
	fscan = (ForeignScan *) subplan;
#else

	/*
	 * Try to locate the ForeignScan subplan that's scanning resultRelation.
	 */
	fscan = find_modifytable_subplan(root, plan, resultRelation, subplan_index);
	if (!fscan)
		return false;
#endif

	/*
	 * It's unsafe to modify a foreign table directly if there are any quals
	 * that should be evaluated locally.
	 */
	if (fscan->scan.plan.qual != NIL)
		return false;

	/*
	 * not supported RETURNING clause by this FDW
	 */
	if (plan->returningLists)
		return false;

	/* Safe to fetch data about the target foreign rel */
	if (fscan->scan.scanrelid == 0)
	{
		foreignrel = find_join_rel(root, fscan->fs_relids);
		/* We should have a rel for this foreign join. */
		Assert(foreignrel);
	}
	else
		foreignrel = root->simple_rel_array[resultRelation];

	/* Direct modification does not support JOIN clause */
	if (IS_JOIN_REL(foreignrel))
		return false;

	rte = root->simple_rte_array[resultRelation];
	fpinfo = (InfluxDBFdwRelationInfo *) foreignrel->fdw_private;

	/*
	 * Ok, rewrite subplan so as to modify the foreign table directly.
	 */
	initStringInfo(&sql);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
	rel = table_open(rte->relid, NoLock);

	/*
	 * Recall the qual clauses that must be evaluated remotely.  (These are
	 * bare clauses not RestrictInfos, but deparse.c's
	 * influxdb_append_conditions() doesn't care.)
	 */
	remote_exprs = fpinfo->final_remote_exprs;

	/*
	 * Construct the SQL command string. DELETE does not support fields in the
	 * WHERE clause.
	 */
	if (!influxdb_deparse_direct_delete_sql(&sql, root, resultRelation, rel,
											foreignrel,
											remote_exprs, &params_list,
											&retrieved_attrs))
	{
		table_close(rel, NoLock);
		return false;
	}

	/*
	 * Update the operation and target relation info.
	 */
	fscan->operation = operation;
#if (PG_VERSION_NUM >= 140000)
	fscan->resultRelation = resultRelation;
#endif

	/*
	 * Update the fdw_exprs list that will be available to the executor.
	 */
	fscan->fdw_exprs = params_list;

	/*
	 * Update the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwDirectModifyPrivateIndex, above.
	 */
	fscan->fdw_private = list_make4(makeString(sql.data),
									makeInteger(0),
									retrieved_attrs,
									makeInteger(plan->canSetTag));

	/*
	 * Update the foreign-join-related fields.
	 */
	if (fscan->scan.scanrelid == 0)
	{
		/* No need for the outer subplan. */
		fscan->scan.plan.lefttree = NULL;
	}

	table_close(rel, NoLock);
	return true;
}

/*
 * influxdbBeginDirectModify Prepare a direct foreign table modification
 */
static void
influxdbBeginDirectModify(ForeignScanState *node, int eflags)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	EState	   *estate = node->ss.ps.state;
	InfluxDBFdwDirectModifyState *dmstate;
	Index		rtindex;
	RangeTblEntry *rte;
	int			numParams;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case.  node->fdw_state stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/*
	 * We'll save private state in node->fdw_state.
	 */
	dmstate = (InfluxDBFdwDirectModifyState *) palloc0(sizeof(InfluxDBFdwDirectModifyState));
	node->fdw_state = (void *) dmstate;

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.
	 */
#if (PG_VERSION_NUM < 140000)
	rtindex = estate->es_result_relation_info->ri_RangeTableIndex;
#else
	rtindex = node->resultRelInfo->ri_RangeTableIndex;
#endif

	rte = exec_rt_fetch(rtindex, estate);

	/* Get info about foreign table. */
	if (fsplan->scan.scanrelid == 0)
		dmstate->rel = ExecOpenScanRelation(estate, rtindex, eflags);
	else
		dmstate->rel = node->ss.ss_currentRelation;

	/* Fetch options */
	dmstate->influxdbFdwOptions = influxdb_get_options(rte->relid);

	/* Update the foreign-join-related fields. */
	if (fsplan->scan.scanrelid == 0)
	{
		/* Save info about foreign table. */
		dmstate->resultRel = dmstate->rel;

		/*
		 * Set dmstate->rel to NULL to teach get_returning_data() and
		 * make_tuple_from_result_row() that columns fetched from the remote
		 * server are described by fdw_scan_tlist of the foreign-scan plan
		 * node, not the tuple descriptor for the target relation.
		 */
		dmstate->rel = NULL;
	}

	/* Initialize state variable */
	dmstate->num_tuples = -1;	/* -1 means not set yet */

	/* Get private info created by planner functions. */
	dmstate->query = strVal(list_nth(fsplan->fdw_private,
									 FdwDirectModifyPrivateUpdateSql));
	dmstate->has_returning = intVal(list_nth(fsplan->fdw_private,
											 FdwDirectModifyPrivateHasReturning));
	dmstate->retrieved_attrs = (List *) list_nth(fsplan->fdw_private,
												 FdwDirectModifyPrivateRetrievedAttrs);
	dmstate->set_processed = intVal(list_nth(fsplan->fdw_private,
											 FdwDirectModifyPrivateSetProcessed));

	/*
	 * Prepare for processing of parameters used in remote query, if any.
	 */
	numParams = list_length(fsplan->fdw_exprs);
	dmstate->numParams = numParams;
	if (numParams > 0)
		prepare_query_params((PlanState *) node,
							 fsplan->fdw_exprs,
							 numParams,
							 &dmstate->param_flinfo,
							 &dmstate->param_exprs,
							 &dmstate->param_values,
							 &dmstate->param_types,
							 &dmstate->param_influxdb_types,
							 &dmstate->param_influxdb_values);
}

/*
 * influxdbIterateDirectModify
 *		Execute a direct foreign table modification
 */
static TupleTableSlot *
influxdbIterateDirectModify(ForeignScanState *node)
{
	InfluxDBFdwDirectModifyState *dmstate = (InfluxDBFdwDirectModifyState *) node->fdw_state;
	EState	   *estate = node->ss.ps.state;
	TupleTableSlot *slot = node->ss.ss_ScanTupleSlot;
	Instrumentation *instr = node->ss.ps.instrument;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * If this is the first call after Begin, execute the statement.
	 */
	if (dmstate->num_tuples == -1)
		execute_dml_stmt(node);

	Assert(!dmstate->has_returning);

	/* Increment the command es_processed count if necessary. */
	if (dmstate->set_processed)
		estate->es_processed += dmstate->num_tuples;

	/* Increment the tuple count for EXPLAIN ANALYZE if necessary. */
	if (instr)
		instr->tuplecount += dmstate->num_tuples;

	return ExecClearTuple(slot);
}

/*
 * influxdbEndDirectModify
 *		Finish a direct foreign table modification
 */
static void
influxdbEndDirectModify(ForeignScanState *node)
{
	elog(DEBUG1, "influxdb_fdw : %s", __func__);
}

/*
 * Restart the scan from the beginning. Note that any parameters the scan
 * depends on may have changed value, so the new scan does not necessarily
 * return exactly the same rows.
 */
static void
influxdbReScanForeignScan(ForeignScanState *node)
{

	InfluxDBFdwExecState *festate = (InfluxDBFdwExecState *) node->fdw_state;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	festate->cursor_exists = false;
	festate->rowidx = 0;
}

static void
influxdbExplainForeignScan(ForeignScanState *node,
						   struct ExplainState *es)
{

	InfluxDBFdwExecState *festate = (InfluxDBFdwExecState *) node->fdw_state;
	StringInfoData buf;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	if (es->verbose)
	{
		ExplainPropertyText("InfluxDB query", festate->query, es);
	}

	initStringInfo(&buf);
	appendStringInfo(&buf, "EXPLAIN QUERY PLAN %s", festate->query);
}

static void
influxdbExplainForeignModify(ModifyTableState *mtstate,
							 ResultRelInfo *rinfo,
							 List *fdw_private,
							 int subplan_index,
							 struct ExplainState *es)
{
	elog(DEBUG1, "influxdb_fdw : %s", __func__);

#if (PG_VERSION_NUM >= 140000)
	if (es->verbose)
	{
		/*
		 * For INSERT we should always have batch size >= 1, but UPDATE and
		 * DELETE don't support batching so don't show the property.
		 */
		if (rinfo->ri_BatchSize > 0)
			ExplainPropertyInteger("Batch Size", NULL, rinfo->ri_BatchSize, es);
	}
#endif
}

/*
 * influxdbExplainDirectModify
 *		Produce extra output for EXPLAIN of a ForeignScan that modifies a
 *		foreign table directly
 */
static void
influxdbExplainDirectModify(ForeignScanState *node, ExplainState *es)
{
	List	   *fdw_private;
	char	   *sql;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	if (es->verbose)
	{
		fdw_private = ((ForeignScan *) node->ss.ps.plan)->fdw_private;
		sql = strVal(list_nth(fdw_private, FdwDirectModifyPrivateUpdateSql));
		ExplainPropertyText("InfluxDB query", sql, es);
	}
}

static bool
influxdbAnalyzeForeignTable(Relation relation,
							AcquireSampleRowsFunc *func,
							BlockNumber *totalpages)
{
	elog(DEBUG1, "influxdb_fdw : %s", __func__);
	return false;
}

/*
 * Import a foreign schema
 */
static List *
influxdbImportForeignSchema(ImportForeignSchemaStmt *stmt,
							Oid serverOid)
{

	influxdb_opt *options = NULL;
	ListCell   *lc;
	StringInfoData buf;
	List	   *commands = NIL;
	struct TableInfo volatile *info;
	int volatile info_len;
	bool		import_time_text = false;
	struct InfluxDBSchemaInfo_return ret;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);
	/* Parse statement options */
	foreach(lc, stmt->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "import_time_text") == 0)
			import_time_text = defGetBoolean(def);
		else
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname)));
	}

	options = influxdb_get_options(serverOid);
	ret = InfluxDBSchemaInfo(options->svr_address, options->svr_port,
							 options->svr_username, options->svr_password,
							 options->svr_database);
	if (ret.r2 != NULL)
	{
		char	   *err = pstrdup(ret.r2);

		free(ret.r2);
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("influxdb_fdw : %s", err)));
	}
	info = ret.r0;
	info_len = ret.r1;
	if (info_len == 0)
	{
		return commands;
	}

	PG_TRY();
	{
		int			table_idx;
		int			col_idx;

		/* Scan all tables */
		for (table_idx = 0; table_idx < info_len; table_idx++)
		{
			/* Apply restrictions for LIMIT TO and EXCEPT */
			if (stmt->list_type == FDW_IMPORT_SCHEMA_LIMIT_TO ||
				stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT)
			{
				bool		found = false;

				foreach(lc, stmt->table_list)
				{
					RangeVar   *rv = (RangeVar *) lfirst(lc);

					if (strcmp(rv->relname, info[table_idx].measurement) == 0)
					{
						found = true;
						break;
					}
				}

				if ((found && stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT) ||
					(!found && stmt->list_type == FDW_IMPORT_SCHEMA_LIMIT_TO))
				{
					continue;
				}
			}
			initStringInfo(&buf);

			appendStringInfo(&buf, "CREATE FOREIGN TABLE %s.%s (\n",
							 quote_identifier(stmt->local_schema), quote_identifier(info[table_idx].measurement));

			appendStringInfo(&buf, "%s timestamp with time zone", INFLUXDB_TIME_COLUMN);
			if (import_time_text)
				appendStringInfo(&buf, ",\n%s text", INFLUXDB_TIME_TEXT_COLUMN);

			for (col_idx = 0; col_idx < info[table_idx].tag_len; col_idx++)
			{
				appendStringInfo(&buf, ",\n%s ", quote_identifier(info[table_idx].tag[col_idx]));
				/* tag is always string type */
				influxdb_to_pg_type(&buf, "string");
			}

			for (col_idx = 0; col_idx < info[table_idx].field_len; col_idx++)
			{
				appendStringInfo(&buf, ",\n%s ", quote_identifier(info[table_idx].field[col_idx]));
				influxdb_to_pg_type(&buf, info[table_idx].field_type[col_idx]);
			}

			appendStringInfo(&buf, "\n) SERVER %s\nOPTIONS (table ",
							 quote_identifier(stmt->server_name));
			influxdb_deparse_string_literal(&buf, info[table_idx].measurement);
			if (info[table_idx].tag_len > 0)
			{
				bool		is_first = true;
				StringInfoData tags_list;

				initStringInfo(&tags_list);

				appendStringInfoString(&buf, ", tags ");
				for (col_idx = 0; col_idx < info[table_idx].tag_len; col_idx++)
				{
					if (!is_first)
						appendStringInfoChar(&tags_list, ',');
					appendStringInfo(&tags_list, "%s", info[table_idx].tag[col_idx]);
					is_first = false;
				}
				influxdb_deparse_string_literal(&buf, tags_list.data);
			}

			appendStringInfoString(&buf, ");");
			commands = lappend(commands, pstrdup(buf.data));

			elog(DEBUG1, "influxdb_fdw : %s %s", __func__, pstrdup(buf.data));
		}
	}
	PG_CATCH();
	{
		InfluxDBFreeSchemaInfo((struct TableInfo *) info, (int) info_len);
		PG_RE_THROW();
	}
	PG_END_TRY();

	InfluxDBFreeSchemaInfo((struct TableInfo *) info, (int) info_len);

	return commands;
}

static bool
influxdb_contain_regex_star_functions(Node *clause)
{
	return influxdb_contain_regex_star_functions_walker(clause, NULL);
}

static bool
influxdb_contain_regex_star_functions_walker(Node *node, void *context)
{
	if (node == NULL)
		return false;

	if (nodeTag(node) == T_FuncExpr || nodeTag(node) == T_Aggref)
	{
		Aggref	   *agg = (Aggref *) node;
		FuncExpr   *fe = (FuncExpr *) node;
		char	   *opername = NULL;
		HeapTuple	tuple;
		Oid			funcoid;
		bool		isAgg;
		int			arglength = 0;

		if (nodeTag(node) == T_FuncExpr)
		{
			funcoid = fe->funcid;
			isAgg = false;
			arglength = list_length(fe->args);
		}
		else
		{
			funcoid = agg->aggfnoid;
			isAgg = true;
			arglength = list_length(agg->args);
		}
		/* get function name and schema */
		tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcoid));
		if (!HeapTupleIsValid(tuple))
		{
			elog(ERROR, "cache lookup failed for function %u", funcoid);
		}
		opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
		ReleaseSysCache(tuple);

		/* Star function */
		if (influxdb_is_star_func(funcoid, opername))
			return true;

		/* Regex function */
		if (arglength > 0)
		{
			ListCell   *funclc;
			Node	   *firstArg;

			if (isAgg)
			{
				funclc = list_head(agg->args);
				firstArg = (Node *) ((TargetEntry *) lfirst(funclc))->expr;
			}
			else
			{
				funclc = list_head(fe->args);
				firstArg = (Node *) lfirst(funclc);
			}

			if (IsA(firstArg, Const))
			{
				Const	   *arg = (Const *) firstArg;
				char	   *extval;

				if (arg->consttype == TEXTOID && influxdb_is_regex_argument(arg, &extval))
					return true;
			}
		}
	}

	return expression_tree_walker(node, influxdb_contain_regex_star_functions_walker,
								  context);
}

/*
 * Assess whether the aggregation, grouping and having operations can be pushed
 * down to the foreign server.  As a side effect, save information we obtain in
 * this function to InfluxDBFdwRelationInfo of the input relation.
 */
static bool
foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel)
{
	Query	   *query = root->parse;
	PathTarget *grouping_target;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) grouped_rel->fdw_private;
	InfluxDBFdwRelationInfo *ofpinfo;
	ListCell   *lc;
	int			i;
	List	   *tlist = NIL;
	bool		is_regex_star = false;
	int			nSelect = 0;

	/* Grouping Sets are not pushable */
	if (query->groupingSets)
		return false;

	/*
	 * Does not pushdown HAVING clause if there is any qualifications applied
	 * to groups.
	 */
	if (root->hasHavingQual && query->havingQual)
		return false;

	/* Get the fpinfo of the underlying scan relation. */
	ofpinfo = (InfluxDBFdwRelationInfo *) fpinfo->outerrel->fdw_private;

	/*
	 * If underneath input relation has any local conditions, those conditions
	 * are required to be applied before performing aggregation.  Hence the
	 * aggregate cannot be pushed down.
	 */
	if (ofpinfo->local_conds)
		return false;

	/*
	 * The targetlist expected from this node and the targetlist pushed down
	 * to the foreign server may be different. The latter requires
	 * sortgrouprefs to be set to push down GROUP BY clause, but should not
	 * have those arising from ORDER BY clause. These sortgrouprefs may be
	 * different from those in the plan's targetlist. Use a copy of path
	 * target to record the new sortgrouprefs.
	 */
	grouping_target = copy_pathtarget(root->upper_targets[UPPERREL_GROUP_AGG]);

	/*
	 * Evaluate grouping targets and check whether they are safe to push down
	 * to the foreign side.  All GROUP BY expressions will be part of the
	 * grouping target and thus there is no need to evaluate it separately.
	 * While doing so, add required expressions into target list which can
	 * then be used to pass to foreign server.
	 */
	i = 0;
	foreach(lc, grouping_target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		Index		sgref = get_pathtarget_sortgroupref(grouping_target, i);
		ListCell   *l;

		/* Check whether this expression is part of GROUP BY clause */
		if (sgref && get_sortgroupref_clause_noerr(sgref, query->groupClause))
		{
			TargetEntry *tle;
			ListCell   *tmplc;

			/*
			 * If any of the GROUP BY expression is not shippable we can not
			 * push down aggregation to the foreign server.
			 */
			if (!influxdb_is_foreign_expr(root, grouped_rel, expr, true))
				return false;

			/*
			 * If any of grouping target expression is not tag key, we can not
			 * push down it to the foreign server.
			 */
			if (IsA(expr, Var))
			{
				char	   *colname = influxdb_get_column_name(ofpinfo->table->relid, ((Var *) expr)->varattno);

				if (!influxdb_is_tag_key(colname, ofpinfo->table->relid))
					return false;
			}

			/*
			 * InfluxDB only support GROUP BY tags and GROUP BY time
			 * intervals, we can not push down any expression that other than
			 * Var and FuncExpr nodes.
			 */
			if (!(IsA(expr, Var) || IsA(expr, FuncExpr)))
				return false;

			/* Pushable, add to tlist */
			tlist = add_to_flat_tlist(tlist, list_make1(expr));

			/* Set ressortgroupref to be easier to detect GROUP BY target */
			tmplc = list_tail(tlist);
			tle = (TargetEntry *) lfirst(tmplc);
			tle->ressortgroupref = sgref;
		}
		else
		{
			/* Check entire expression whether it is pushable or not */
			if (influxdb_is_foreign_expr(root, grouped_rel, expr, true))
			{
				/* Pushable, add to tlist */
				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
			else
			{
				List	   *aggvars;

				/*
				 * If we have sortgroupref set, then it means that we have an
				 * ORDER BY entry pointing to this expression.  Since we are
				 * not pushing ORDER BY with GROUP BY, clear it.
				 */
				if (sgref)
					grouping_target->sortgrouprefs[i] = 0;

				/* Not matched exactly, pull the var with aggregates then */
				aggvars = pull_var_clause((Node *) expr,
										  PVC_INCLUDE_AGGREGATES);

				if (!influxdb_is_foreign_expr(root, grouped_rel, (Expr *) aggvars, true))
					return false;

				/*
				 * Add aggregates, if any, into the targetlist.  Plain var
				 * nodes should be either same as some GROUP BY expression or
				 * part of some GROUP BY expression. In later case, the query
				 * cannot refer plain var nodes without the surrounding
				 * expression.  In both the cases, they are already part of
				 * the targetlist and thus no need to add them again.  In fact
				 * adding pulled plain var nodes in SELECT clause will cause
				 * an error on the foreign server if they are not same as some
				 * GROUP BY expression.
				 */
				foreach(l, aggvars)
				{
					Expr	   *expr = (Expr *) lfirst(l);

					if (IsA(expr, Aggref))
						tlist = add_to_flat_tlist(tlist, list_make1(expr));
				}
			}
		}

		i++;
	}

	/*
	 * Do not push down when selecting multiple targets which contains regex
	 * or star function. Raise a warning in this case.
	 */
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);
		bool		is_col_grouping_target = false;

		if (IsA((Expr *) tle->expr, Var) || IsA((Expr *) tle->expr, FuncExpr))
		{
			is_col_grouping_target = influxdb_is_grouping_target(tle, query);
		}
		if (influxdb_contain_regex_star_functions((Node *) tle->expr))
			is_regex_star = true;

		if (IsA((Expr *) tle->expr, Aggref)
			|| IsA((Expr *) tle->expr, OpExpr)
			|| (IsA((Expr *) tle->expr, FuncExpr) && !is_col_grouping_target)
			|| (IsA((Expr *) tle->expr, Var) && !is_col_grouping_target))
			nSelect++;
	}
	if (is_regex_star && nSelect > 1)
	{
		elog(WARNING, "Selecting multiple functions with regular expression or star is not supported.");
		return false;
	}

	/*
	 * If there are any local conditions, pull Vars and aggregates from it and
	 * check whether they are safe to pushdown or not.
	 */
	if (fpinfo->local_conds)
	{
		List	   *aggvars = NIL;
		ListCell   *lc;

		foreach(lc, fpinfo->local_conds)
		{
			RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

			aggvars = list_concat(aggvars,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_INCLUDE_AGGREGATES));
		}

		foreach(lc, aggvars)
		{
			Expr	   *expr = (Expr *) lfirst(lc);

			/*
			 * If aggregates within local conditions are not safe to push
			 * down, then we cannot push down the query.  Vars are already
			 * part of GROUP BY clause which are checked above, so no need to
			 * access them again here.
			 */
			if (IsA(expr, Aggref))
			{
				if (!influxdb_is_foreign_expr(root, grouped_rel, expr, true))
					return false;

				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
		}
	}

	/* Transfer any sortgroupref data to the replacement tlist */
	apply_pathtarget_labeling_to_tlist(tlist, grouping_target);

	/* Store generated targetlist */
	fpinfo->grouped_tlist = tlist;

	/* Safe to pushdown */
	fpinfo->pushdown_safe = true;

	/*
	 * If user is willing to estimate cost for a scan using EXPLAIN, he
	 * intends to estimate scans on that relation more accurately. Then, it
	 * makes sense to estimate the cost of the grouping on that relation more
	 * accurately using EXPLAIN.
	 */
	fpinfo->use_remote_estimate = ofpinfo->use_remote_estimate;

	/* Copy startup and tuple cost as is from underneath input rel's fpinfo */
	fpinfo->fdw_startup_cost = ofpinfo->fdw_startup_cost;
	fpinfo->fdw_tuple_cost = ofpinfo->fdw_tuple_cost;

	/*
	 * Set cached relation costs to some negative value, so that we can detect
	 * when they are set to some sensible costs, during one (usually the
	 * first) of the calls to estimate_path_cost_size().
	 */
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	/*
	 * Set the string describing this grouped relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.
	 */
	fpinfo->relation_name = psprintf("Aggregate on (%s)",
									 ofpinfo->relation_name);

	return true;
}

/*
 * add_foreign_final_paths
 *		Add foreign paths for performing the final processing remotely.
 *
 * Given input_rel contains the source-data Paths.  The paths are added to the
 * given final_rel.
 */
static void
add_foreign_final_paths(PlannerInfo *root, RelOptInfo *input_rel,
						RelOptInfo *final_rel
#if (PG_VERSION_NUM >= 120000)
						,FinalPathExtraData *extra
#endif
)
{
	Query	   *parse = root->parse;
	InfluxDBFdwRelationInfo *ifpinfo = (InfluxDBFdwRelationInfo *) input_rel->fdw_private;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) final_rel->fdw_private;
	bool		has_final_sort = false;
	List	   *pathkeys = NIL;
	double		rows = 0;
	Cost		startup_cost = 0;
	Cost		total_cost = 0;
	List	   *fdw_private;
	ForeignPath *final_path;

	/*
	 * Currently, we only support this for SELECT commands
	 */
	if (parse->commandType != CMD_SELECT)
		return;

	/*
	 * Currently, we do not support FOR UPDATE/SHARE
	 */
	if (parse->rowMarks)
		return;

	/*
	 * No work if there is no FOR UPDATE/SHARE clause and if there is no need
	 * to add a LIMIT node
	 */
	if (!parse->rowMarks
#if (PG_VERSION_NUM >= 120000)
		&& !extra->limit_needed
#endif
		)
		return;

	/* We don't support cases where there are any SRFs in the targetlist */
	if (parse->hasTargetSRFs)
		return;

	/* Save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;

	/*
	 * If there is no need to add a LIMIT node, there might be a ForeignPath
	 * in the input_rel's pathlist that implements all behavior of the query.
	 * Note: we would already have accounted for the query's FOR UPDATE/SHARE
	 * (if any) before we get here.
	 */
#if (PG_VERSION_NUM >= 120000)
	if (!extra->limit_needed)
	{
		ListCell   *lc;

		Assert(parse->rowMarks);

		/*
		 * Grouping and aggregation are not supported with FOR UPDATE/SHARE,
		 * so the input_rel should be a base, join, or ordered relation; and
		 * if it's an ordered relation, its input relation should be a base or
		 * join relation.
		 */
		Assert(input_rel->reloptkind == RELOPT_BASEREL ||
			   input_rel->reloptkind == RELOPT_JOINREL ||
			   (input_rel->reloptkind == RELOPT_UPPER_REL &&
				ifpinfo->stage == UPPERREL_ORDERED &&
				(ifpinfo->outerrel->reloptkind == RELOPT_BASEREL ||
				 ifpinfo->outerrel->reloptkind == RELOPT_JOINREL)));

		foreach(lc, input_rel->pathlist)
		{
			Path	   *path = (Path *) lfirst(lc);

			/*
			 * apply_scanjoin_target_to_paths() uses create_projection_path()
			 * to adjust each of its input paths if needed, whereas
			 * create_ordered_paths() uses apply_projection_to_path() to do
			 * that.  So the former might have put a ProjectionPath on top of
			 * the ForeignPath; look through ProjectionPath and see if the
			 * path underneath it is ForeignPath.
			 */
			if (IsA(path, ForeignPath) ||
				(IsA(path, ProjectionPath) &&
				 IsA(((ProjectionPath *) path)->subpath, ForeignPath)))
			{
				/*
				 * Create foreign final path; this gets rid of a
				 * no-longer-needed outer plan (if any), which makes the
				 * EXPLAIN output look cleaner
				 */
#if (PG_VERSION_NUM >= 120000)
				final_path = create_foreign_upper_path(root,
													   path->parent,
													   path->pathtarget,
													   path->rows,
													   path->startup_cost,
													   path->total_cost,
													   path->pathkeys,
													   NULL,	/* no extra plan */
													   NULL);	/* no fdw_private */
#else
				final_path = create_foreignscan_path(root,
													 input_rel,
													 root->upper_targets[UPPERREL_FINAL],
													 rows,
													 startup_cost,
													 total_cost,
													 pathkeys,
													 NULL,	/* no required_outer */
													 NULL,	/* no extra plan */
													 fdw_private);
#endif
				/* and add it to the final_rel */
				add_path(final_rel, (Path *) final_path);

				/* Safe to push down */
				fpinfo->pushdown_safe = true;

				return;
			}
		}

		/*
		 * If we get here it means no ForeignPaths; since we would already
		 * have considered pushing down all operations for the query to the
		 * remote server, give up on it.
		 */
		return;
	}
	Assert(extra->limit_needed);
#endif

	/*
	 * If the input_rel is an ordered relation, replace the input_rel with its
	 * input relation
	 */
	if (input_rel->reloptkind == RELOPT_UPPER_REL &&
		ifpinfo->stage == UPPERREL_ORDERED)
	{
		input_rel = ifpinfo->outerrel;
		ifpinfo = (InfluxDBFdwRelationInfo *) input_rel->fdw_private;
		has_final_sort = true;
		pathkeys = root->sort_pathkeys;
	}

	/* The input_rel should be a base, join, or grouping relation */
	Assert(input_rel->reloptkind == RELOPT_BASEREL ||
		   input_rel->reloptkind == RELOPT_JOINREL ||
		   (input_rel->reloptkind == RELOPT_UPPER_REL &&
			ifpinfo->stage == UPPERREL_GROUP_AGG));

	/*
	 * We try to create a path below by extending a simple foreign path for
	 * the underlying base, join, or grouping relation to perform the final
	 * sort (if has_final_sort) and the LIMIT restriction remotely, which is
	 * stored into the fdw_private list of the resulting path.  (We
	 * re-estimate the costs of sorting the underlying relation, if
	 * has_final_sort.)
	 */

	/*
	 * Assess if it is safe to push down the LIMIT and OFFSET to the remote
	 * server
	 */

	/*
	 * If the underlying relation has any local conditions, the LIMIT/OFFSET
	 * cannot be pushed down.
	 */
	if (ifpinfo->local_conds)
		return;

	/*
	 * When query contains OFFSET but no LIMIT, do not push down because
	 * InfluxDB can return inconsistent query result
	 */
	if (!parse->limitCount && parse->limitOffset)
		return;

	/*
	 * Also, the LIMIT/OFFSET cannot be pushed down, if their expressions are
	 * not safe to remote.
	 */
	if (!influxdb_is_foreign_expr(root, input_rel, (Expr *) parse->limitOffset, false) ||
		!influxdb_is_foreign_expr(root, input_rel, (Expr *) parse->limitCount, false))
		return;

	/* Safe to push down */
	fpinfo->pushdown_safe = true;

	/*
	 * Build the fdw_private list that will be used by influxdbGetForeignPlan.
	 * Items in the list must match order in enum FdwPathPrivateIndex.
	 */
	fdw_private = list_make2(makeInteger(has_final_sort)
#if (PG_VERSION_NUM >= 120000)
							 ,makeInteger(extra->limit_needed));
#else
							 ,makeInteger(false));
#endif

	/*
	 * Create foreign final path; this gets rid of a no-longer-needed outer
	 * plan (if any), which makes the EXPLAIN output look cleaner
	 */
#if (PG_VERSION_NUM >= 120000)
	final_path = create_foreign_upper_path(root,
										   input_rel,
										   root->upper_targets[UPPERREL_FINAL],
										   rows,
										   startup_cost,
										   total_cost,
										   pathkeys,
										   NULL,	/* no extra plan */
										   fdw_private);
#else
	final_path = create_foreignscan_path(root,
										 input_rel,
										 root->upper_targets[UPPERREL_FINAL],
										 rows,
										 startup_cost,
										 total_cost,
										 pathkeys,
										 NULL,	/* no required_outer */
										 NULL,	/* no extra plan */
										 fdw_private);
#endif
	/* and add it to the final_rel */
	add_path(final_rel, (Path *) final_path);
}

/*
 * influxdbGetForeignUpperPaths
 *		Add paths for post-join operations like aggregation, grouping etc. if
 *		corresponding operations are safe to push down.
 *
 * Right now, we only support aggregate, grouping and having clause pushdown.
 */
static void
influxdbGetForeignUpperPaths(PlannerInfo *root, UpperRelationKind stage,
							 RelOptInfo *input_rel, RelOptInfo *output_rel
#if (PG_VERSION_NUM >= 110000)
							 ,
							 void *extra
#endif
)
{
	InfluxDBFdwRelationInfo *fpinfo;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * If input rel is not safe to pushdown, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	if (!input_rel->fdw_private ||
		!((InfluxDBFdwRelationInfo *) input_rel->fdw_private)->pushdown_safe)
		return;

	/* Ignore stages we don't support; and skip any duplicate calls. */
#if (PG_VERSION_NUM >= 120000)
	if ((stage != UPPERREL_GROUP_AGG && stage != UPPERREL_FINAL) || output_rel->fdw_private)
#else
	if (stage != UPPERREL_GROUP_AGG || output_rel->fdw_private)
#endif
		return;

	fpinfo = (InfluxDBFdwRelationInfo *) palloc0(sizeof(InfluxDBFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	output_rel->fdw_private = fpinfo;

	switch (stage)
	{
		case UPPERREL_GROUP_AGG:
			add_foreign_grouping_paths(root, input_rel, output_rel);
			break;

		case UPPERREL_FINAL:
			add_foreign_final_paths(root, input_rel, output_rel
#if (PG_VERSION_NUM >= 120000)
									,(FinalPathExtraData *) extra
#endif
				);
			break;
		default:
			elog(ERROR, "unexpected upper relation: %d", (int) stage);
			break;
	}
}

/*
 * add_foreign_grouping_paths
 *		Add foreign path for grouping and/or aggregation.
 *
 * Given input_rel represents the underlying scan.  The paths are added to the
 * given grouped_rel.
 */
static void
add_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
						   RelOptInfo *grouped_rel)
{
	Query	   *parse = root->parse;
	InfluxDBFdwRelationInfo *ifpinfo = input_rel->fdw_private;
	InfluxDBFdwRelationInfo *fpinfo = grouped_rel->fdw_private;
	ForeignPath *grouppath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/* Nothing to be done, if there is no grouping or aggregation required. */
	if (!parse->groupClause && !parse->groupingSets && !parse->hasAggs &&
		!root->hasHavingQual)
		return;

	/* save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, shippable extensions
	 * etc. details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;

	fpinfo->shippable_extensions = ifpinfo->shippable_extensions;

	/* Assess if it is safe to push down aggregation and grouping. */
	if (!foreign_grouping_ok(root, grouped_rel))
		return;

	/* Use small cost to push down aggregate always */
	rows = width = startup_cost = total_cost = 1;
	/* Now update this information in the fpinfo */
	fpinfo->rows = rows;
	fpinfo->width = width;
	fpinfo->startup_cost = startup_cost;
	fpinfo->total_cost = total_cost;

	/* Create and add foreign path to the grouping relation. */
#if (PG_VERSION_NUM >= 120000)
	grouppath = create_foreign_upper_path(root,
										  grouped_rel,
										  grouped_rel->reltarget,
										  rows,
										  startup_cost,
										  total_cost,
										  NIL,	/* no pathkeys */
										  NULL,
										  NIL); /* no fdw_private */
#else

	grouppath = create_foreignscan_path(root,
										grouped_rel,
										root->upper_targets[UPPERREL_GROUP_AGG],
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										NULL,	/* no required_outer */
										NULL,
										NIL);	/* no fdw_private */
#endif
	/* Add generated path into grouped_rel by add_path(). */
	add_path(grouped_rel, (Path *) grouppath);
}

static void
influxdb_to_pg_type(StringInfo str, char *type)
{
	int			i;

	static const char *conversion[][2] = {
		{"string", "text"},
		{"float", "double precision"},
		{"integer", "bigint"},
		{"boolean", "boolean"},
	{NULL, NULL}};

	for (i = 0; conversion[i][0] != NULL; i++)
	{
		if (strcmp(type, conversion[i][0]) == 0)
		{
			appendStringInfoString(str, conversion[i][1]);
			return;
		}
	}
	elog(ERROR, "cannot convert type %s", type);
}

/*
 * Force assorted GUC parameters to settings that ensure that we'll output
 * data values in a form that is unambiguous to the remote server.
 *
 * This is rather expensive and annoying to do once per row, but there's
 * little choice if we want to be sure values are transmitted accurately;
 * we can't leave the settings in place between rows for fear of affecting
 * user-visible computations.
 *
 * We use the equivalent of a function SET option to allow the settings to
 * persist only until the caller calls reset_transmission_modes().  If an
 * error is thrown in between, guc.c will take care of undoing the settings.
 *
 * The return value is the nestlevel that must be passed to
 * reset_transmission_modes() to undo things.
 */
int
influxdb_set_transmission_modes(void)
{
	int			nestlevel = NewGUCNestLevel();

	/*
	 * The values set here should match what pg_dump does.  See also
	 * configure_remote_session in connection.c.
	 */
	if (DateStyle != USE_ISO_DATES)
		(void) set_config_option("datestyle", "ISO",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);

	if (IntervalStyle != INTSTYLE_POSTGRES)
		(void) set_config_option("intervalstyle", "postgres",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (extra_float_digits < 3)
		(void) set_config_option("extra_float_digits", "3",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);

	return nestlevel;
}

/*
 * Undo the effects of set_transmission_modes().
 */
void
influxdb_reset_transmission_modes(int nestlevel)
{
	AtEOXact_GUC(true, nestlevel);
}

/*
 * Prepare for processing of parameters used in remote query.
 */
static void
prepare_query_params(PlanState *node,
					 List *fdw_exprs,
					 int numParams,
					 FmgrInfo **param_flinfo,
					 List **param_exprs,
					 const char ***param_values,
					 Oid **param_types,
					 InfluxDBType * *param_influxdb_types,
					 InfluxDBValue * *param_influxdb_values)
{
	int			i;
	ListCell   *lc;

	Assert(numParams > 0);

	/* Prepare for output conversion of parameters used in remote query. */
	*param_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * numParams);
	*param_types = (Oid *) palloc0(sizeof(Oid) * numParams);
	*param_influxdb_types = (InfluxDBType *) palloc0(sizeof(InfluxDBType) * numParams);
	*param_influxdb_values = (InfluxDBValue *) palloc0(sizeof(InfluxDBValue) * numParams);

	i = 0;
	foreach(lc, fdw_exprs)
	{
		Node	   *param_expr = (Node *) lfirst(lc);
		Oid			typefnoid;
		bool		isvarlena;

		(*param_types)[i] = exprType(param_expr);
		getTypeOutputInfo(exprType(param_expr), &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &(*param_flinfo)[i]);
		i++;
	}

	/*
	 * Prepare remote-parameter expressions for evaluation.  (Note: in
	 * practice, we expect that all these expressions will be just Params, so
	 * we could possibly do something more efficient than using the full
	 * expression-eval machinery for this.  But probably there would be little
	 * benefit, and it'd require influxdb_fdw to know more than is desirable
	 * about Param evaluation.)
	 */
	*param_exprs = (List *) ExecInitExprList(fdw_exprs, node);
	/* Allocate buffer for text form of query parameters. */
	*param_values = (const char **) palloc0(numParams * sizeof(char *));
}

/*
 * Construct array of query parameter values and bind parameters
 *
 */

static void
process_query_params(ExprContext *econtext,
					 FmgrInfo *param_flinfo,
					 List *param_exprs,
					 const char **param_values,
					 Oid *param_types,
					 InfluxDBType * param_influxdb_types,
					 InfluxDBValue * param_influxdb_values)
{
	int			nestlevel;
	int			i;
	ListCell   *lc;

	nestlevel = influxdb_set_transmission_modes();

	i = 0;
	foreach(lc, param_exprs)
	{
		ExprState  *expr_state = (ExprState *) lfirst(lc);
		Datum		expr_value;
		bool		isNull;

		/* Evaluate the parameter expression */
		expr_value = ExecEvalExpr(expr_state, econtext, &isNull);
		/* Bind parameters */
		influxdb_bind_sql_var(param_types[i], i, expr_value, &isNull,
							  param_influxdb_types, param_influxdb_values);

		/*
		 * Get string sentation of each parameter value by invoking
		 * type-specific output function, unless the value is null.
		 */
		if (isNull)
			param_values[i] = NULL;
		else
			param_values[i] = OutputFunctionCall(&param_flinfo[i], expr_value);
		i++;
	}
	influxdb_reset_transmission_modes(nestlevel);
}

/*
 * Create cursor for node's query with current parameter values.
 */
static void
create_cursor(ForeignScanState *node)
{
	InfluxDBFdwExecState *festate = (InfluxDBFdwExecState *) node->fdw_state;
	ExprContext *econtext = node->ss.ps.ps_ExprContext;
	int			numParams = festate->numParams;
	const char **values = festate->param_values;

	/*
	 * Construct array of query parameter values in text format.  We do the
	 * conversions in the short-lived per-tuple context, so as not to cause a
	 * memory leak over repeated scans.
	 */
	if (numParams > 0)
	{
		MemoryContext oldcontext;

		oldcontext = MemoryContextSwitchTo(econtext->ecxt_per_tuple_memory);
		festate->params = palloc(numParams);
		process_query_params(econtext,
							 festate->param_flinfo,
							 festate->param_exprs,
							 values,
							 festate->param_types,
							 festate->param_influxdb_types,
							 festate->param_influxdb_values);

		MemoryContextSwitchTo(oldcontext);
	}

	/* Mark the cursor as created, and show no tuples have been retrieved */
	festate->cursor_exists = true;
}

/*
 * Execute a direct UPDATE/DELETE statement.
 */
static void
execute_dml_stmt(ForeignScanState *node)
{
	InfluxDBFdwDirectModifyState *dmstate = (InfluxDBFdwDirectModifyState *) node->fdw_state;
	ExprContext *econtext = node->ss.ps.ps_ExprContext;
	int			numParams = dmstate->numParams;
	const char **values = dmstate->param_values;
	struct InfluxDBQuery_return volatile ret;

	/*
	 * Construct array of query parameter values in text format.
	 */
	if (numParams > 0)
	{
		MemoryContext oldcontext;

		oldcontext = MemoryContextSwitchTo(econtext->ecxt_per_tuple_memory);
		dmstate->params = palloc(numParams);
		process_query_params(econtext,
							 dmstate->param_flinfo,
							 dmstate->param_exprs,
							 values,
							 dmstate->param_types,
							 dmstate->param_influxdb_types,
							 dmstate->param_influxdb_values);

		MemoryContextSwitchTo(oldcontext);
	}

	/*
	 * Notice that we pass NULL for paramTypes, thus forcing the remote server
	 * to infer types for all parameters.  Since we explicitly cast every
	 * parameter (see deparse.c), the "inference" is trivial and will produce
	 * the desired result.  This allows us to avoid assuming that the remote
	 * server has the same OIDs we do for the parameters' types.
	 */
	ret = InfluxDBQuery(dmstate->query, dmstate->influxdbFdwOptions->svr_address,
						dmstate->influxdbFdwOptions->svr_port, dmstate->influxdbFdwOptions->svr_username,
						dmstate->influxdbFdwOptions->svr_password, dmstate->influxdbFdwOptions->svr_database,
						dmstate->param_influxdb_types, dmstate->param_influxdb_values, dmstate->numParams);
	if (ret.r1 != NULL)
	{
		char	   *err = pstrdup(ret.r1);

		free(ret.r1);
		ret.r1 = err;
		elog(ERROR, "influxdb_fdw : %s", err);
	}

	InfluxDBFreeResult((InfluxDBResult *) & ret.r0);

	/*
	 * InfluxDB does not return any rows after DELETE. So we set default is 0.
	 */
	dmstate->num_tuples = 0;
}


/*
 * execute_foreign_insert_modify
 *		Perform foreign-table insert modification as required.  (This is the
 *		shared guts of influxdbExecForeignInsert, influxdbExecForeignBatchInsert.)
 */
static TupleTableSlot **
execute_foreign_insert_modify(EState *estate,
							  ResultRelInfo *resultRelInfo,
							  TupleTableSlot **slots,
							  TupleTableSlot **planSlots,
							  int numSlots)
{
	InfluxDBFdwExecState *fmstate = (InfluxDBFdwExecState *) resultRelInfo->ri_FdwState;
	uint32_t	bindnum = 0;
	char	   *ret;
	int			i;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	TupleDesc	tupdesc = RelationGetDescr(rel);
	char	   *tablename = influxdb_get_table_name(rel);
	bool		time_had_value = false; /* true if time column had value */
	int			bind_num_time_column = 0;
	MemoryContext oldcontext;

	oldcontext = MemoryContextSwitchTo(fmstate->temp_cxt);

	fmstate->param_influxdb_types = (InfluxDBType *) repalloc(fmstate->param_influxdb_types, sizeof(InfluxDBType) * fmstate->p_nums * numSlots);
	fmstate->param_influxdb_values = (InfluxDBValue *) repalloc(fmstate->param_influxdb_values, sizeof(InfluxDBValue) * fmstate->p_nums * numSlots);
	fmstate->param_column_info = (InfluxDBColumnInfo *) repalloc(fmstate->param_column_info, sizeof(InfluxDBColumnInfo) * fmstate->p_nums * numSlots);

	/* get following parameters from slots */
	if (slots != NULL && fmstate->retrieved_attrs != NIL)
	{
		int			nestlevel;
		ListCell   *lc;

		nestlevel = influxdb_set_transmission_modes();

		for (i = 0; i < numSlots; i++)
		{
			/* Bind values */
			foreach(lc, fmstate->retrieved_attrs)
			{
				int			attnum = lfirst_int(lc) - 1;
				Oid			type = TupleDescAttr(slots[i]->tts_tupleDescriptor, attnum)->atttypid;
				Datum		value;
				bool		is_null;
				struct InfluxDBColumnInfo *col = list_nth(fmstate->column_list, (int) bindnum % fmstate->p_nums);

				fmstate->param_column_info[bindnum].column_name = col->column_name;
				fmstate->param_column_info[bindnum].column_type = col->column_type;
				value = slot_getattr(slots[i], attnum + 1, &is_null);

				/* Check value is null */
				if (is_null)
				{
					/* If column is not null, we can not insert NULL record */
					if (TupleDescAttr(tupdesc, attnum)->attnotnull)
						elog(ERROR, "influxdb_fdw : null value in column \"%s\" of relation \"%s\" violates not-null constraint",
							 col->column_name, tablename);
					fmstate->param_influxdb_types[bindnum] = INFLUXDB_NULL;
					fmstate->param_influxdb_values[bindnum].i = 0;
				}
				else
				{
					if (INFLUXDB_IS_TIME_COLUMN(col->column_name))
					{
						/* time column has no value */
						if (!time_had_value)
						{
							influxdb_bind_sql_var(type, bindnum, value, &is_null,
												  fmstate->param_influxdb_types, fmstate->param_influxdb_values);
							bind_num_time_column = bindnum;
							time_had_value = true;
						}
						else
						{
							/*
							 * Both values of time and time_text column are
							 * specified
							 */
							/* Values of time column will be ignored */
							elog(WARNING, "Inserting value has both \'time_text\' and \'time\' columns specified. The \'time\' will be ignored.");
							if (strcmp(col->column_name, INFLUXDB_TIME_TEXT_COLUMN) == 0)
							{
								influxdb_bind_sql_var(type, bind_num_time_column, value, &is_null,
													  fmstate->param_influxdb_types, fmstate->param_influxdb_values);
							}
							fmstate->param_influxdb_types[bindnum] = INFLUXDB_NULL;
							fmstate->param_influxdb_values[bindnum].i = 0;
						}
					}
					else
						influxdb_bind_sql_var(type, bindnum, value, &is_null,
											  fmstate->param_influxdb_types, fmstate->param_influxdb_values);
				}
				bindnum++;
			}
		}
		influxdb_reset_transmission_modes(nestlevel);
	}

	Assert(bindnum == fmstate->p_nums * numSlots);
	/* Insert the record */
	ret = InfluxDBInsert(fmstate->influxdbFdwOptions->svr_address, fmstate->influxdbFdwOptions->svr_port,
						 fmstate->influxdbFdwOptions->svr_username, fmstate->influxdbFdwOptions->svr_password,
						 fmstate->influxdbFdwOptions->svr_database, tablename, fmstate->param_column_info,
						 fmstate->param_influxdb_types, fmstate->param_influxdb_values, fmstate->p_nums, numSlots);
	if (ret != NULL)
		elog(ERROR, "influxdb_fdw : %s", ret);

	MemoryContextSwitchTo(oldcontext);
	MemoryContextReset(fmstate->temp_cxt);

	return slots;
}

#if (PG_VERSION_NUM >= 140000)
/*
 * Determine batch size for a given foreign table. The option specified for
 * a table has precedence.
 */
static int
influxdb_get_batch_size_option(Relation rel)
{
	Oid			foreigntableid = RelationGetRelid(rel);
	List	   *options = NIL;
	ListCell   *lc;
	ForeignTable *table;
	ForeignServer *server;

	/* we use 1 by default, which means "no batching" */
	int			batch_size = 1;

	/*
	 * Load options for table and server. We append server options after table
	 * options, because table options take precedence.
	 */
	table = GetForeignTable(foreigntableid);
	server = GetForeignServer(table->serverid);

	options = list_concat(options, table->options);
	options = list_concat(options, server->options);

	/* See if either table or server specifies batch_size. */
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "batch_size") == 0)
		{
			(void) parse_int(defGetString(def), &batch_size, 0, NULL);
			break;
		}
	}

	return batch_size;
}
#endif
