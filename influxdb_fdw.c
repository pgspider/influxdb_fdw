/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2020, TOSHIBA CORPORATION
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
#include "commands/defrem.h"
#include "commands/explain.h"
#include "commands/vacuum.h"
#include "storage/ipc.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "parser/parsetree.h"
#include "utils/typcache.h"
#include "utils/selfuncs.h"

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

static void influxdbExplainForeignScan(ForeignScanState *node,
									   struct ExplainState *es);

static void influxdbExplainForeignModify(ModifyTableState *mtstate,
										 ResultRelInfo *rinfo,
										 List *fdw_private,
										 int subplan_index,
										 struct ExplainState *es);

static bool influxdbAnalyzeForeignTable(Relation relation,
										AcquireSampleRowsFunc *func,
										BlockNumber *totalpages);

static List *influxdbImportForeignSchema(ImportForeignSchemaStmt *stmt,
										 Oid serverOid);

static void
			influxdbGetForeignUpperPaths(PlannerInfo *root,
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
static bool foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel);
static void add_foreign_grouping_paths(PlannerInfo *root,
									   RelOptInfo *input_rel,
									   RelOptInfo *grouped_rel);

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

	/* support for EXPLAIN */
	fdwroutine->ExplainForeignScan = influxdbExplainForeignScan;
	fdwroutine->ExplainForeignModify = influxdbExplainForeignModify;

	/* support for ANALYSE */
	fdwroutine->AnalyzeForeignTable = influxdbAnalyzeForeignTable;

	/* support for IMPORT FOREIGN SCHEMA */
	fdwroutine->ImportForeignSchema = influxdbImportForeignSchema;

#if (PG_VERSION_NUM >= 100000)
	/* Support functions for upper relation push-down */
	fdwroutine->GetForeignUpperPaths = influxdbGetForeignUpperPaths;
#endif
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
	InfluxDBFdwRelationInfo *fpinfo =
	(InfluxDBFdwRelationInfo *) foreignrel->fdw_private;
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
	RangeTblEntry *rte = planner_rt_fetch(baserel->relid, root);
	const char *namespace;
	const char *relname;
	const char *refname;

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
#if PG_VERSION_NUM >= 90600
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid, &fpinfo->attrs_used);
#else
	pull_varattnos((Node *) baserel->reltargetlist, baserel->relid, &fpinfo->attrs_used);
#endif

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
		 * If the foreign table has never been ANALYZEd, it will have relpages
		 * and reltuples equal to zero, which most likely has nothing to do
		 * with reality.  We can't do a whole lot about that if we're not
		 * allowed to consult the remote server, but we can use a hack similar
		 * to plancat.c's treatment of empty relations: use a minimum size
		 * estimate of 10 pages, and divide by the column-datatype-based width
		 * estimate to get the corresponding number of tuples.
		 */
		if (baserel->pages == 0 && baserel->tuples == 0)
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
	fpinfo->relation_name = makeStringInfo();
	namespace = get_namespace_name(get_rel_namespace(foreigntableid));
	relname = get_rel_name(foreigntableid);
	refname = rte->eref->aliasname;
	appendStringInfo(fpinfo->relation_name, "%s.%s",
					 quote_identifier(namespace),
					 quote_identifier(relname));
	if (*refname && strcmp(refname, relname) != 0)
		appendStringInfo(fpinfo->relation_name, " %s",
						 quote_identifier(rte->eref->aliasname));
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
#if PG_VERSION_NUM >= 90600
									 NULL,	/* default pathtarget */
#endif
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
influxdbGetForeignPlan(
					   PlannerInfo *root, RelOptInfo *baserel, Oid foreigntableid, ForeignPath *best_path, List *tlist, List *scan_clauses, Plan *outer_plan)
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


	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/* Decide to execute function pushdown support in the target list. */
	fpinfo->is_tlist_func_pushdown = influxdb_is_foreign_function_tlist(root, baserel, tlist);

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
			fdw_scan_tlist = copyObject(tlist);
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
	influxdbDeparseSelectStmtForRel(&sql, root, baserel, fdw_scan_tlist,
									remote_exprs, best_path->path.pathkeys,
									false, &retrieved_attrs, &params_list);

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
	fdw_private = lappend(fdw_private, makeString(sql.data));
	fdw_private = lappend(fdw_private, retrieved_attrs);
	fdw_private = lappend(fdw_private, makeInteger(for_update));
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
	return make_foreignscan(tlist, local_exprs, scan_relid, params_list, fdw_private,
							fdw_scan_tlist, fdw_recheck_quals, outer_plan

		);
}

/*
 * influxdbBeginForeignScan: Initiate access to the database
 */
static void
influxdbBeginForeignScan(ForeignScanState *node, int eflags)
{
	InfluxDBFdwExecState *festate = NULL;
	EState	   *estate = node->ss.ps.state;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	int			numParams;

	elog(DEBUG1, "influxdb_fdw : %s", __func__);

	/*
	 * We'll save private state in node->fdw_state.
	 */
	festate = (InfluxDBFdwExecState *) palloc(sizeof(InfluxDBFdwExecState));
	node->fdw_state = (void *) festate;
	festate->rowidx = 0;

	/* Stash away the state info we have already */
	festate->query = strVal(list_nth(fsplan->fdw_private, 0));
	festate->retrieved_attrs = list_nth(fsplan->fdw_private, 1);
	festate->for_update = intVal(list_nth(fsplan->fdw_private, 2)) ? true : false;
	festate->tlist = (List *) list_nth(fsplan->fdw_private, 3);
	festate->is_tlist_func_pushdown = intVal(list_nth(fsplan->fdw_private, 4)) ? true : false;

	festate->cursor_exists = false;

	festate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "influxdb_fdw temporary data",
											  ALLOCSET_SMALL_SIZES);


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
				 * If target is tag, we get its value from GROUP BY tag values,
				 * otherwise, get target value from result field.
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
					 strcmp(influxdb_get_function_name(((FuncExpr *) target)->funcid), "influx_time") == 0)
			{
				/* Time column corresponding to influx_time */
				result_idx = 0;
			}
			else if (IsA(target, Aggref) || IsA(target, OpExpr) || IsA(target, FuncExpr))
			{
				attid++;
				result_idx = attid;
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

		if (result_row->tuple[result_idx] != NULL)
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

	/* table = GetForeignTable(rte->relid); */
	/* Fetch the options */
	options = influxdb_get_options(rte->relid);

	/*
	 * If this is the first call after Begin or ReScan, we need to create the
	 * cursor on the remote side. Binding parameters is done in this function.
	 */
	if (!festate->cursor_exists)
		create_cursor(node);

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
			elog(DEBUG1, "influxdb_fdw : query: %s %d", festate->query, festate->numParams);
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

	festate->cursor_exists = false;
	festate->rowidx = 0;
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
				bool			is_first = true;
				StringInfoData	tags_list;

				initStringInfo(&tags_list);

				appendStringInfoString(&buf, ", tags ");
				for (col_idx = 0; col_idx < info[table_idx].tag_len; col_idx++)
				{
					if (!is_first)
						appendStringInfoChar(&tags_list, ',');
					appendStringInfo(&tags_list, "%s",info[table_idx].tag[col_idx]);
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
	List	   *aggvars;
	ListCell   *lc;
	int			i;
	List	   *tlist = NIL;

	/* Grouping Sets are not pushable */
	if (query->groupingSets)
		return false;

	/*
	 * Does not pushdown HAVING clause if there is any
	 * qualifications applied to groups.
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
				char *colname = influxdb_get_column_name(ofpinfo->table->relid, ((Var *) expr)->varattno);

				if (!influxdb_is_tag_key(colname, ofpinfo->table->relid))
					return false;
			}

			/*
			 * InfluxDB only support GROUP BY tags and GROUP BY time intervals,
			 * we can not push down any expression that other than Var and FuncExpr nodes.
			 */
			if (!(IsA(expr, Var) || IsA(expr, FuncExpr)))
				return false;

			/* Pushable, add to tlist */
			tlist = add_to_flat_tlist(tlist, list_make1(expr));
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
	fpinfo->relation_name = makeStringInfo();

	return true;
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

	/*
	 * If input rel is not safe to pushdown, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	if (!input_rel->fdw_private ||
		!((InfluxDBFdwRelationInfo *) input_rel->fdw_private)->pushdown_safe)
		return;

	/* Ignore stages we don't support; and skip any duplicate calls. */
	if (stage != UPPERREL_GROUP_AGG || output_rel->fdw_private)
		return;

	fpinfo = (InfluxDBFdwRelationInfo *) palloc0(sizeof(InfluxDBFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	output_rel->fdw_private = fpinfo;

	add_foreign_grouping_paths(root, input_rel, output_rel);
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
					 InfluxDBValue * *influxdb_values)
{
	int			i;
	ListCell   *lc;

	Assert(numParams > 0);

	/* Prepare for output conversion of parameters used in remote query. */
	*param_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * numParams);
	*param_types = (Oid *) palloc0(sizeof(Oid) * numParams);
	*param_influxdb_types = (InfluxDBType *) palloc0(sizeof(InfluxDBType) * numParams);
	*influxdb_values = (InfluxDBValue *) palloc0(sizeof(InfluxDBValue) * numParams);

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
#if PG_VERSION_NUM >= 100000
	*param_exprs = (List *) ExecInitExprList(fdw_exprs, node);
#else
	*param_exprs = (List *) ExecInitExpr((Expr *) fdw_exprs, node);
#endif
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
	int			i;
	ListCell   *lc;
	int			nestlevel;

	nestlevel = influxdb_set_transmission_modes();
	i = 0;
	foreach(lc, param_exprs)
	{
		ExprState  *expr_state = (ExprState *) lfirst(lc);
		Datum		expr_value;
		bool		isNull;

		/* Evaluate the parameter expression */
#if PG_VERSION_NUM >= 100000
		expr_value = ExecEvalExpr(expr_state, econtext, &isNull);
#else
		expr_value = ExecEvalExpr(expr_state, econtext, &isNull, NULL);
#endif
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
