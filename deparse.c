/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2018-2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        deparse.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "influxdb_fdw.h"

#include "pgtime.h"
#include "access/heapam.h"
#include "access/htup_details.h"
#include "access/sysattr.h"
#include "catalog/pg_aggregate.h"
#include "catalog/pg_collation.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "nodes/nodeFuncs.h"
#include "nodes/plannodes.h"
#include "optimizer/clauses.h"
#include "optimizer/tlist.h"
#include "parser/parsetree.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"
#include "utils/timestamp.h"
#include "utils/typcache.h"
#include "sys/types.h"
#include "regex.h"
#define QUOTE '"'

/* List of stable function with star argument of InfluxDB */
static const char *InfluxDBStableStarFunction[] = {
	"influx_count_all",
	"influx_mode_all",
	"influx_max_all",
	"influx_min_all",
	"influx_sum_all",
	"integral_all",
	"mean_all",
	"median_all",
	"spread_all",
	"stddev_all",
	"first_all",
	"last_all",
	"percentile_all",
	"sample_all",
	"abs_all",
	"acos_all",
	"asin_all",
	"atan_all",
	"atan2_all",
	"ceil_all",
	"cos_all",
	"cumulative_sum_all",
	"derivative_all",
	"difference_all",
	"elapsed_all",
	"exp_all",
	"floor_all",
	"ln_all",
	"log_all",
	"log2_all",
	"log10_all",
	"moving_average_all",
	"non_negative_derivative_all",
	"non_negative_difference_all",
	"pow_all",
	"round_all",
	"sin_all",
	"sqrt_all",
	"tan_all",
	"chande_momentum_oscillator_all",
	"exponential_moving_average_all",
	"double_exponential_moving_average_all",
	"kaufmans_efficiency_ratio_all",
	"kaufmans_adaptive_moving_average_all",
	"triple_exponential_moving_average_all",
	"triple_exponential_derivative_all",
	"relative_strength_index_all",
NULL};

/* List of unique function without star argument of InfluxDB */
static const char *InfluxDBUniqueFunction[] = {
	"bottom",
	"percentile",
	"top",
	"cumulative_sum",
	"derivative",
	"difference",
	"elapsed",
	"log2",
	"log10",					/* Use for PostgreSQL old version */
	"moving_average",
	"non_negative_derivative",
	"non_negative_difference",
	"holt_winters",
	"holt_winters_with_fit",
	"chande_momentum_oscillator",
	"exponential_moving_average",
	"double_exponential_moving_average",
	"kaufmans_efficiency_ratio",
	"kaufmans_adaptive_moving_average",
	"triple_exponential_moving_average",
	"triple_exponential_derivative",
	"relative_strength_index",
	"influx_count",
	"integral",
	"spread",
	"first",
	"last",
	"sample",
	"influx_time",
	"influx_fill_numeric",
	"influx_fill_option",
NULL};

/* List of supported builtin function of InfluxDB */
static const char *InfluxDBSupportedBuiltinFunction[] = {
	"now",
	"sqrt",
	"abs",
	"acos",
	"asin",
	"atan",
	"atan2",
	"ceil",
	"cos",
	"exp",
	"floor",
	"ln",
	"log",
	"log10",
	"pow",
	"round",
	"sin",
	"tan",
NULL};

/*
 * Global context for influxdb_foreign_expr_walker's search of an expression tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	Relids		relids;			/* relids of base relations in the underlying
								 * scan */
	Oid			relid;			/* relation oid */
	unsigned int mixing_aggref_status;	/* mixing_aggref_status contains
										 * information about whether
										 * expression includes both of
										 * aggregate and non-aggregate. */
	bool		for_tlist;		/* whether evaluation for the expression of
								 * tlist */
	bool		is_inner_func;	/* exist or not in inner exprs */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for influxdb_foreign_expr_walker's search.
 * This is concerned with identifying collations used in the expression.
 */
typedef enum
{
	FDW_COLLATE_NONE,			/* expression is of a noncollatable type */
	FDW_COLLATE_SAFE,			/* collation derives from a foreign Var */
	FDW_COLLATE_UNSAFE			/* collation derives from something else */
} FDWCollateState;

typedef struct foreign_loc_cxt
{
	Oid			collation;		/* OID of current collation, if any */
	FDWCollateState state;		/* state of current collation choice */
	bool		can_skip_cast;	/* outer function can skip float8/numeric cast */
	bool		can_pushdown_stable;	/* true if query contains stable
										 * function with star or regex */
	bool		can_pushdown_volatile;	/* true if query contains volatile
										 * function */
	bool		influx_fill_enable; /* true if deparse subexpression inside
									 * influx_time() */
} foreign_loc_cxt;

/*
 * Context for influxdb_deparse_expr
 */
typedef struct deparse_expr_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	RelOptInfo *scanrel;		/* the underlying scan relation. Same as
								 * foreignrel, when that represents a join or
								 * a base relation. */
	StringInfo	buf;			/* output buffer to append to */
	List	  **params_list;	/* exprs that will become remote Params */
	bool		require_regex;	/* require regex for LIKE operator */
	bool		is_tlist;		/* deparse during target list exprs */
	bool		can_skip_cast;	/* outer function can skip float8/numeric cast */
	bool		can_delete_directly;	/* DELETE statement can pushdown
										 * directly */
	FuncExpr   *influx_fill_expr;	/* Store the fill() function */
} deparse_expr_cxt;

typedef struct pull_func_clause_context
{
	List	   *funclist;
}			pull_func_clause_context;

/*
 * Functions to determine whether an expression can be evaluated safely on
 * remote server.
 */
static bool influxdb_foreign_expr_walker(Node *node,
										 foreign_glob_cxt *glob_cxt,
										 foreign_loc_cxt *outer_cxt);

/*
 * Functions to construct string representation of a node tree.
 */
static void influxdb_deparse_expr(Expr *expr, deparse_expr_cxt *context);
static void influxdb_deparse_var(Var *node, deparse_expr_cxt *context);
static void influxdb_deparse_const(Const *node, deparse_expr_cxt *context, int showtype);
static void influxdb_deparse_param(Param *node, deparse_expr_cxt *context);
static void influxdb_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context);
static void influxdb_deparse_fill_option(StringInfo buf, const char *val);
static void influxdb_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context);
static void influxdb_deparse_operator_name(StringInfo buf, Form_pg_operator opform, bool *regex);

static void influxdb_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node,
												  deparse_expr_cxt *context);
static void influxdb_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context);
static void influxdb_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context);
static void influxdb_deparse_null_test(NullTest *node, deparse_expr_cxt *context);
static void influxdb_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context);
static void influxdb_print_remote_param(int paramindex, Oid paramtype, int32 paramtypmod,
										deparse_expr_cxt *context);
static void influxdb_print_remote_placeholder(Oid paramtype, int32 paramtypmod,
											  deparse_expr_cxt *context);
static void influxdb_deparse_relation(StringInfo buf, Relation rel);
static void influxdb_deparse_target_list(StringInfo buf, PlannerInfo *root, Index rtindex, Relation rel,
										 Bitmapset *attrs_used, List **retrieved_attrs);
static void influxdb_deparse_column_ref(StringInfo buf, int varno, int varattno, Oid vartype, PlannerInfo *root, bool convert, bool *can_delete_directly);
static void influxdb_deparse_select(List *tlist, List **retrieved_attrs, deparse_expr_cxt *context);
static void influxdb_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root,
											   RelOptInfo *foreignrel,
											   bool use_alias, List **params_list);
static void influxdb_deparse_from_expr(List *quals, deparse_expr_cxt *context);
static void influxdb_deparse_aggref(Aggref *node, deparse_expr_cxt *context);
static void influxdb_append_conditions(List *exprs, deparse_expr_cxt *context);
static void influxdb_append_group_by_clause(List *tlist, deparse_expr_cxt *context);

static void influxdb_append_order_by_clause(List *pathkeys, deparse_expr_cxt *context);
static Node *influxdb_deparse_sort_group_clause(Index ref, List *tlist,
												deparse_expr_cxt *context);
static void influxdb_deparse_explicit_target_list(List *tlist, List **retrieved_attrs,
												  deparse_expr_cxt *context);
static Expr *influxdb_find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel);
static bool influxdb_is_contain_time_column(List *tlist);
static void influxdb_append_field_key(TupleDesc tupdesc, StringInfo buf, Index rtindex, PlannerInfo *root, bool first);
static void influxdb_append_limit_clause(deparse_expr_cxt *context);
static bool influxdb_is_string_type(Node *node);
static char *influxdb_quote_identifier(const char *s, char q);
static bool influxdb_contain_functions_walker(Node *node, void *context);

bool		influxdb_is_grouping_target(TargetEntry *tle, Query *query);
bool		influxdb_is_builtin(Oid objectId);
bool		influxdb_is_regex_argument(Const *node, char **extval);
char	   *influxdb_replace_function(char *in);
bool		influxdb_is_star_func(Oid funcid, char *in);
static bool influxdb_is_unique_func(Oid funcid, char *in);
static bool influxdb_is_supported_builtin_func(Oid funcid, char *in);
static bool exist_in_function_list(char *funcname, const char **funclist);

/*
 * Local variables.
 */
static char *cur_opname = NULL;

/*
 * Append remote name of specified foreign table to buf.
 * Use value of table_name FDW option (if any) instead of relation's name.
 * Similarly, schema_name FDW option overrides schema name.
 */
static void
influxdb_deparse_relation(StringInfo buf, Relation rel)
{
	char	   *relname = influxdb_get_table_name(rel);

	appendStringInfo(buf, "%s", influxdb_quote_identifier(relname, QUOTE));
}

static char *
influxdb_quote_identifier(const char *s, char q)
{
	char	   *result = palloc(strlen(s) * 2 + 3);
	char	   *r = result;

	*r++ = q;
	while (*s)
	{
		if (*s == q)
			*r++ = *s;
		*r++ = *s;
		s++;
	}
	*r++ = q;
	*r++ = '\0';
	return result;
}

/*
 * pull_func_clause_walker
 *
 * Recursively search for functions within a clause.
 */
static bool
influxdb_pull_func_clause_walker(Node *node, pull_func_clause_context * context)
{
	if (node == NULL)
		return false;
	if (IsA(node, FuncExpr))
	{
		context->funclist = lappend(context->funclist, node);
		return false;
	}

	return expression_tree_walker(node, influxdb_pull_func_clause_walker,
								  (void *) context);
}

/*
 * pull_func_clause
 *
 * Pull out function from a clause and then add to target list
 */
List *
influxdb_pull_func_clause(Node *node)
{
	pull_func_clause_context context;

	context.funclist = NIL;

	influxdb_pull_func_clause_walker(node, &context);

	return context.funclist;
}

/*
 * Returns true if given expr is safe to evaluate on the foreign server.
 */
bool
influxdb_is_foreign_expr(PlannerInfo *root,
						 RelOptInfo *baserel,
						 Expr *expr,
						 bool for_tlist)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) (baserel->fdw_private);

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	glob_cxt.root = root;
	glob_cxt.foreignrel = baserel;
	glob_cxt.relid = fpinfo->table->relid;
	glob_cxt.mixing_aggref_status = INFLUXDB_TARGETS_MIXING_AGGREF_SAFE;
	glob_cxt.for_tlist = for_tlist;
	glob_cxt.is_inner_func = false;

	/*
	 * For an upper relation, use relids from its underneath scan relation,
	 * because the upperrel's own relids currently aren't set to anything
	 * meaningful by the core code.  For other relation, use their own relids.
	 */
	if (baserel->reloptkind == RELOPT_UPPER_REL)
		glob_cxt.relids = fpinfo->outerrel->relids;
	else
		glob_cxt.relids = baserel->relids;
	loc_cxt.collation = InvalidOid;
	loc_cxt.state = FDW_COLLATE_NONE;
	loc_cxt.can_skip_cast = false;
	loc_cxt.influx_fill_enable = false;
	if (!influxdb_foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	/*
	 * If the expression has a valid collation that does not arise from a
	 * foreign var, the expression can not be sent over.
	 */
	if (loc_cxt.state == FDW_COLLATE_UNSAFE)
		return false;

	/* OK to evaluate on the remote server */
	return true;
}

static bool
is_valid_type(Oid type)
{
	switch (type)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
		case VARCHAROID:
		case TEXTOID:
		case TIMEOID:
		case TIMESTAMPOID:
		case TIMESTAMPTZOID:
			return true;
	}
	return false;
}

/*
 * Check if expression is safe to execute remotely, and return true if so.
 *
 * In addition, *outer_cxt is updated with collation information.
 *
 * We must check that the expression contains only node types we can deparse,
 * that all types/functions/operators are safe to send (which we approximate
 * as being built-in), and that all collations used in the expression derive
 * from Vars of the foreign table.  Because of the latter, the logic is
 * pretty close to assign_collations_walker() in parse_collate.c, though we
 * can assume here that the given expression is valid.
 */
static bool
influxdb_foreign_expr_walker(Node *node,
							 foreign_glob_cxt *glob_cxt,
							 foreign_loc_cxt *outer_cxt)
{
	bool		check_type = true;
	foreign_loc_cxt inner_cxt;
	Oid			collation;
	FDWCollateState state;
	HeapTuple	tuple;
	Form_pg_operator form;
	char	   *cur_opname;
	static bool is_time_column = false; /* Use static variable for save value
										 * from child node to parent node.
										 * Check column T_Var is time column? */

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;
	inner_cxt.can_skip_cast = false;
	inner_cxt.can_pushdown_stable = false;
	inner_cxt.can_pushdown_volatile = false;
	inner_cxt.influx_fill_enable = false;
	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;

				/*
				 * If the Var is from the foreign table, we consider its
				 * collation (if any) safe to use.  If it is from another
				 * table, we treat its collation the same way as we would a
				 * Param's collation, ie it's not safe for it to have a
				 * non-default collation.
				 */
				if (bms_is_member(var->varno, glob_cxt->relids) &&
					var->varlevelsup == 0)
				{
					/* Var belongs to foreign table */

					if (var->varattno < 0)
						return false;

					/* check column is time column? */
					if (var->vartype == TIMESTAMPTZOID ||
						var->vartype == TIMEOID ||
						var->vartype == TIMESTAMPOID)
					{
						is_time_column = true;
					}

					/* Mark this target is field/tag */
					glob_cxt->mixing_aggref_status |= INFLUXDB_TARGETS_MARK_COLUMN;

					/* Else check the collation */
					collation = var->varcollid;
					state = OidIsValid(collation) ? FDW_COLLATE_SAFE : FDW_COLLATE_NONE;
				}
				else
				{
					/* Var belongs to some other table */
					collation = var->varcollid;
					if (collation == InvalidOid ||
						collation == DEFAULT_COLLATION_OID)
					{
						/*
						 * It's noncollatable, or it's safe to combine with a
						 * collatable foreign Var, so set state to NONE.
						 */
						state = FDW_COLLATE_NONE;
					}
					else
					{
						/*
						 * Do not fail right away, since the Var might appear
						 * in a collation-insensitive context.
						 */
						state = FDW_COLLATE_UNSAFE;
					}
				}
			}
			break;
		case T_Const:
			{
				char	   *type_name;
				Const	   *c = (Const *) node;

				if (c->consttype == INTERVALOID)
				{
					Interval   *interval = DatumGetIntervalP(c->constvalue);
					struct pg_tm tm;
					fsec_t		fsec;

					interval2tm(*interval, &tm, &fsec);

					/*
					 * Not pushdown interval with month or year because
					 * InfluxDB does not support month and year duration
					 */
					if (tm.tm_mon != 0 || tm.tm_year != 0)
					{
						return false;
					}
				}

				/*
				 * Get type name based on the const value. If the type name is
				 * "influx_fill_enum", allow it to push down to remote by
				 * disable build in type check
				 */
				type_name = influxdb_get_data_type_name(c->consttype);
				if (strcmp(type_name, "influx_fill_enum") == 0)
					check_type = false;

				/*
				 * If the constant has nondefault collation, either it's of a
				 * non-builtin type, or it reflects folding of a CollateExpr;
				 * either way, it's unsafe to send to the remote.
				 */
				if (c->constcollid != InvalidOid &&
					c->constcollid != DEFAULT_COLLATION_OID)
					return false;

				/* Otherwise, we can consider that it doesn't set collation */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_Param:
			{
				Param	   *p = (Param *) node;

				if (!is_valid_type(p->paramtype))
					return false;

				/*
				 * Collation rule is same as for Consts and non-foreign Vars.
				 */
				collation = p->paramcollid;
				if (collation == InvalidOid ||
					collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_FieldSelect:		/* Allow pushdown FieldSelect to support
								 * accessing value of record of star and regex
								 * functions */
			{
				if (!(glob_cxt->foreignrel->reloptkind == RELOPT_BASEREL ||
					  glob_cxt->foreignrel->reloptkind == RELOPT_OTHER_MEMBER_REL))
					return false;

				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
				check_type = false;
			}
			break;
		case T_FuncExpr:
			{

				FuncExpr   *fe = (FuncExpr *) node;
				char	   *opername = NULL;
				bool		is_cast_func = false;
				bool		is_star_func = false;
				bool		can_pushdown_func = false;
				bool		is_regex = false;

				/* get function name and schema */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fe->funcid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", fe->funcid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				ReleaseSysCache(tuple);

				if (strcmp(opername, "float8") == 0 || strcmp(opername, "numeric") == 0)
				{
					is_cast_func = true;
				}

				/* pushed down to InfluxDB */
				if (influxdb_is_star_func(fe->funcid, opername))
				{
					is_star_func = true;
					outer_cxt->can_pushdown_stable = true;
				}

				if (influxdb_is_unique_func(fe->funcid, opername) ||
					influxdb_is_supported_builtin_func(fe->funcid, opername))
				{
					can_pushdown_func = true;
					inner_cxt.can_skip_cast = true;
					outer_cxt->can_pushdown_volatile = true;
				}

				if (!(is_star_func || can_pushdown_func || is_cast_func))
					return false;

				/* fill() must be inside influx_time() */
				if (strcmp(opername, "influx_fill_numeric") == 0 ||
					strcmp(opername, "influx_fill_option") == 0)
				{
					if (outer_cxt->influx_fill_enable == false)
						elog(ERROR, "influxdb_fdw: syntax error influx_fill_numeric() or influx_fill_option() must be embedded inside influx_time() function\n");
				}

				/* Accept type cast functions if outer is specific functions */
				if (is_cast_func)
				{
					if (outer_cxt->can_skip_cast == false)
						return false;
				}
				else
				{
					/*
					 * Nested function cannot be executed in non tlist
					 */
					if (!glob_cxt->for_tlist && glob_cxt->is_inner_func)
						return false;

					glob_cxt->is_inner_func = true;
				}

				/*
				 * Allow influx_fill_numeric/influx_fill_option() inside
				 * influx_time() function
				 */
				if (strcmp(opername, "influx_time") == 0)
					inner_cxt.influx_fill_enable = true;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!influxdb_foreign_expr_walker((Node *) fe->args,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * Force to restore the state after deparse subexpression if
				 * it has been change above
				 */
				inner_cxt.influx_fill_enable = false;

				if (!is_cast_func)
					glob_cxt->is_inner_func = false;

				if (list_length(fe->args) > 0)
				{
					ListCell   *funclc;
					Node	   *firstArg;

					funclc = list_head(fe->args);
					firstArg = (Node *) lfirst(funclc);

					if (IsA(firstArg, Const))
					{
						Const	   *arg = (Const *) firstArg;
						char	   *extval;

						if (arg->consttype == TEXTOID)
							is_regex = influxdb_is_regex_argument(arg, &extval);
					}
				}

				if (is_regex)
				{
					collation = InvalidOid;
					state = FDW_COLLATE_NONE;
					check_type = false;
					outer_cxt->can_pushdown_stable = true;
				}
				else
				{
					/*
					 * If function's input collation is not derived from a
					 * foreign Var, it can't be sent to remote.
					 */
					if (fe->inputcollid == InvalidOid)
						 /* OK, inputs are all noncollatable */ ;
					else if (inner_cxt.state != FDW_COLLATE_SAFE ||
							 fe->inputcollid != inner_cxt.collation)
						return false;

					/*
					 * Detect whether node is introducing a collation not
					 * derived from a foreign Var.  (If so, we just mark it
					 * unsafe for now rather than immediately returning false,
					 * since the parent node might not care.)
					 */
					collation = fe->funccollid;
					if (collation == InvalidOid)
						state = FDW_COLLATE_NONE;
					else if (inner_cxt.state == FDW_COLLATE_SAFE &&
							 collation == inner_cxt.collation)
						state = FDW_COLLATE_SAFE;
					else if (collation == DEFAULT_COLLATION_OID)
						state = FDW_COLLATE_NONE;
					else
						state = FDW_COLLATE_UNSAFE;
				}
			}
			break;
		case T_OpExpr:
			{
				OpExpr	   *oe = (OpExpr *) node;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!influxdb_is_builtin(oe->opno))
					return false;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				/* opname is not a SQL identifier, so we should not quote it. */
				cur_opname = pstrdup(NameStr(form->oprname));
				ReleaseSysCache(tuple);

				/* ILIKE cannot be pushed down to InfluxDB */
				if (strcmp(cur_opname, "~~*") == 0 || strcmp(cur_opname, "!~~*") == 0)
				{
					return false;
				}

				/*
				 * Cannot pushdown to InfluxDB if there is string comparison
				 * with: "<, >, <=, >=" operators
				 */
				if (influxdb_is_string_type((Node *) linitial(oe->args)))
				{
					if (strcmp(cur_opname, "<") == 0 ||
						strcmp(cur_opname, ">") == 0 ||
						strcmp(cur_opname, "<=") == 0 ||
						strcmp(cur_opname, ">=") == 0)
					{
						return false;
					}
				}

				/*
				 * Cannot pushdown to InfluxDB if compare time column with
				 * "!=, <>" operators
				 */
				if (strcmp(cur_opname, "!=") == 0 || strcmp(cur_opname, "<>") == 0)
				{
					if (influxdb_is_contain_time_column(oe->args))
					{
						return false;
					}
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!influxdb_foreign_expr_walker((Node *) oe->args,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * Mixing aggregate and non-aggregate error occurs when SELECT
				 * statement includes both of aggregate function and
				 * standalone field key or tag key. It is unsafe to pushdown
				 * if target operation expression has mixing aggregate and
				 * non-aggregate, such as: (1+col1+sum(col2)),
				 * (sum(col1)*col2)
				 */
				if ((glob_cxt->mixing_aggref_status & INFLUXDB_TARGETS_MIXING_AGGREF_UNSAFE) ==
					INFLUXDB_TARGETS_MIXING_AGGREF_UNSAFE)
				{
					return false;
				}

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Result-collation handling is same as for functions */
				collation = oe->opcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_ScalarArrayOpExpr:
			{
				ScalarArrayOpExpr *oe = (ScalarArrayOpExpr *) node;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				cur_opname = pstrdup(NameStr(form->oprname));
				ReleaseSysCache(tuple);

				/*
				 * Cannot pushdown to InfluxDB if there is string comparison
				 * with: "<, >, <=, >=" operators
				 */
				if (influxdb_is_string_type((Node *) linitial(oe->args)))
				{
					if (strcmp(cur_opname, "<") == 0 ||
						strcmp(cur_opname, ">") == 0 ||
						strcmp(cur_opname, "<=") == 0 ||
						strcmp(cur_opname, ">=") == 0)
					{
						return false;
					}
				}

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!influxdb_is_builtin(oe->opno))
					return false;

				/*
				 * InfluxDB do not support OR with multi time column or time
				 * column with !=, <> --> Not pushdown time column
				 */
				if (influxdb_is_contain_time_column(oe->args))
				{
					return false;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!influxdb_foreign_expr_walker((Node *) oe->args,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_RelabelType:
			{
				RelabelType *r = (RelabelType *) node;

				/*
				 * Recurse to input subexpression.
				 */
				if (!influxdb_foreign_expr_walker((Node *) r->arg,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * RelabelType must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = r->resultcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_BoolExpr:
			{
				BoolExpr   *b = (BoolExpr *) node;

				is_time_column = false;

				if (b->boolop == NOT_EXPR)
				{
					/* InfluxDB does not support not operator */
					return false;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!influxdb_foreign_expr_walker((Node *) b->args,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * InfluxDB does not support OR with condition contain time
				 * column
				 */
				if (b->boolop == OR_EXPR && is_time_column)
				{
					is_time_column = false;
					return false;
				}

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_List:
			{
				List	   *l = (List *) node;
				ListCell   *lc;

				/* inherit can_skip_cast flag */
				inner_cxt.can_skip_cast = outer_cxt->can_skip_cast;
				inner_cxt.influx_fill_enable = outer_cxt->influx_fill_enable;

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!influxdb_foreign_expr_walker((Node *) lfirst(lc),
													  glob_cxt, &inner_cxt))
						return false;
				}

				/*
				 * When processing a list, collation state just bubbles up
				 * from the list elements.
				 */
				collation = inner_cxt.collation;
				state = inner_cxt.state;

				/* Don't apply exprType() to the list. */
				check_type = false;
			}
			break;
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;
				ListCell   *lc;
				FuncExpr   *func = (FuncExpr *) node;
				char	   *opername = NULL;
				bool		old_val;
				int			index_const = -1;
				int			index;
				bool		is_regex = false;
				bool		is_star_func = false;
				bool		is_not_star_func = false;

				/* get function name and schema */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(agg->aggfnoid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", func->funcid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				ReleaseSysCache(tuple);

				/* these function can be passed to InfluxDB */
				if ((strcmp(opername, "sum") == 0 ||
					 strcmp(opername, "max") == 0 ||
					 strcmp(opername, "min") == 0 ||
					 strcmp(opername, "count") == 0 ||
					 strcmp(opername, "influx_distinct") == 0 ||
					 strcmp(opername, "spread") == 0 ||
					 strcmp(opername, "sample") == 0 ||
					 strcmp(opername, "first") == 0 ||
					 strcmp(opername, "last") == 0 ||
					 strcmp(opername, "integral") == 0 ||
					 strcmp(opername, "mean") == 0 ||
					 strcmp(opername, "median") == 0 ||
					 strcmp(opername, "influx_count") == 0 ||
					 strcmp(opername, "influx_mode") == 0 ||
					 strcmp(opername, "stddev") == 0 ||
					 strcmp(opername, "influx_sum") == 0 ||
					 strcmp(opername, "influx_max") == 0 ||
					 strcmp(opername, "influx_min") == 0))
				{
					is_not_star_func = true;
				}

				is_star_func = influxdb_is_star_func(agg->aggfnoid, opername);

				if (!(is_star_func || is_not_star_func))
					return false;

				/* Some aggregate influxdb functions have a const argument. */
				if (strcmp(opername, "sample") == 0 ||
					strcmp(opername, "integral") == 0)
					index_const = 1;

				/*
				 * Only sum(), count() and spread() are aggregate functions,
				 * max(), min() and last() are selector functions
				 */
				if (strcmp(opername, "sum") == 0 ||
					strcmp(opername, "spread") == 0 ||
					strcmp(opername, "count") == 0)
				{
					/* Mark target as aggregate function */
					glob_cxt->mixing_aggref_status |= INFLUXDB_TARGETS_MARK_AGGREF;
				}

				/* Not safe to pushdown when not in grouping context */
				if (glob_cxt->foreignrel->reloptkind != RELOPT_UPPER_REL)
					return false;

				/* Only non-split aggregates are pushable. */
				if (agg->aggsplit != AGGSPLIT_SIMPLE)
					return false;

				/*
				 * Save value of is_time_column before we check time argument
				 * aggregate.
				 */
				old_val = is_time_column;
				is_time_column = false;

				/*
				 * Recurse to input args. aggdirectargs, aggorder and
				 * aggdistinct are all present in args, so no need to check
				 * their shippability explicitly.
				 */
				index = -1;
				foreach(lc, agg->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					index++;

					/* If TargetEntry, extract the expression from it */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;

						if (IsA(n, Var) ||
							((index == index_const) && IsA(n, Const)))
							 /* arguments checking is OK */ ;
						else if (IsA(n, Const))
						{
							Const	   *arg = (Const *) n;
							char	   *extval;

							if (arg->consttype == TEXTOID)
							{
								is_regex = influxdb_is_regex_argument(arg, &extval);
								if (is_regex)
									 /* arguments checking is OK */ ;
								else
									return false;
							}
							else
								return false;
						}
						else if (is_star_func)
							 /* arguments checking is OK */ ;
						else
							return false;
					}

					/* Check if arg is Var */
					if (IsA(n, Var))
					{
						Var		   *var = (Var *) n;
						char	   *colname = influxdb_get_column_name(glob_cxt->relid, var->varattno);

						/* Not push down if arg is tag key */
						if (influxdb_is_tag_key(colname, glob_cxt->relid))
							return false;

						/*
						 * Not push down max(), min() if arg type is text
						 * column
						 */
						if ((strcmp(opername, "max") == 0 || strcmp(opername, "min") == 0)
							&& var->vartype == TEXTOID)
							return false;
					}

					if (!influxdb_foreign_expr_walker(n, glob_cxt, &inner_cxt))
						return false;

					/*
					 * Does not pushdown time column argument within aggregate
					 * function except time related functions, because these
					 * functions are converted from func(time, value) to
					 * func(value) when deparsing.
					 */
					if (is_time_column && !(strcmp(opername, "last") == 0 || strcmp(opername, "first") == 0))
					{
						is_time_column = false;
						return false;
					}
				}

				/*
				 * If there is no time column argument within aggregate
				 * function, restore value of is_time_column.
				 */
				is_time_column = old_val;

				if (agg->aggorder || agg->aggfilter)
				{
					return false;
				}

				/*
				 * influxdb_fdw only supports push-down DISTINCT within
				 * aggregate for count()
				 */
				if (agg->aggdistinct && (strcmp(opername, "count") != 0))
					return false;

				if (is_regex)
					check_type = false;
				else
				{
					/*
					 * If aggregate's input collation is not derived from a
					 * foreign Var, it can't be sent to remote.
					 */
					if (agg->inputcollid == InvalidOid)
						 /* OK, inputs are all noncollatable */ ;
					else if (inner_cxt.state != FDW_COLLATE_SAFE ||
							 agg->inputcollid != inner_cxt.collation)
						return false;
				}

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
				 */
				collation = agg->aggcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_ArrayExpr:
			{
				ArrayExpr  *a = (ArrayExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!influxdb_foreign_expr_walker((Node *) a->elements,
												  glob_cxt, &inner_cxt))
					return false;

				/*
				 * ArrayExpr must not introduce a collation not derived from
				 * an input foreign Var (same logic as for a function).
				 */
				collation = a->array_collid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_DistinctExpr:
			/* IS DISTINCT FROM */
		case T_NullTest:
			return false;
		default:

			/*
			 * If it's anything else, assume it's unsafe.  This list can be
			 * expanded later, but don't forget to add deparse support below.
			 */
			return false;
	}

	/*
	 * If result type of given expression is not built-in, it can't be sent to
	 * remote because it might have incompatible semantics on remote side.
	 */
	if (check_type && !influxdb_is_builtin(exprType(node)))
		return false;

	/*
	 * Now, merge my collation information into my parent's state.
	 */
	if (state > outer_cxt->state)
	{
		/* Override previous parent state */
		outer_cxt->collation = collation;
		outer_cxt->state = state;
	}
	else if (state == outer_cxt->state)
	{
		/* Merge, or detect error if there's a collation conflict */
		switch (state)
		{
			case FDW_COLLATE_NONE:
				/* Nothing + nothing is still nothing */
				break;
			case FDW_COLLATE_SAFE:
				if (collation != outer_cxt->collation)
				{
					/*
					 * Non-default collation always beats default.
					 */
					if (outer_cxt->collation == DEFAULT_COLLATION_OID)
					{
						/* Override previous parent state */
						outer_cxt->collation = collation;
					}
					else if (collation != DEFAULT_COLLATION_OID)
					{
						/*
						 * Conflict; show state as indeterminate.  We don't
						 * want to "return false" right away, since parent
						 * node might not care about collation.
						 */
						outer_cxt->state = FDW_COLLATE_UNSAFE;
					}
				}
				break;
			case FDW_COLLATE_UNSAFE:
				/* We're still conflicted ... */
				break;
		}
	}

	/* It looks OK */
	return true;
}

/*
 * Build the targetlist for given relation to be deparsed as SELECT clause.
 *
 * The output targetlist contains the columns that need to be fetched from the
 * foreign server for the given relation.  If foreignrel is an upper relation,
 * then the output targetlist can also contains expressions to be evaluated on
 * foreign server.
 */
List *
influxdb_build_tlist_to_deparse(RelOptInfo *foreignrel)
{
	List	   *tlist = NIL;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) foreignrel->fdw_private;
	ListCell   *lc;

	/*
	 * For an upper relation, we have already built the target list while
	 * checking shippability, so just return that.
	 */
	if (foreignrel->reloptkind == RELOPT_UPPER_REL)
		return fpinfo->grouped_tlist;

	/*
	 * We require columns specified in foreignrel->reltarget->exprs and those
	 * required for evaluating the local conditions.
	 */
	tlist = add_to_flat_tlist(tlist,
							  pull_var_clause((Node *) foreignrel->reltarget->exprs,
											  PVC_RECURSE_PLACEHOLDERS));
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		tlist = add_to_flat_tlist(tlist,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_RECURSE_PLACEHOLDERS));
	}

	return tlist;
}

/*
 * deparse remote DELETE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned
 * to *retrieved_attrs.
 */
void
influxdb_deparse_delete(StringInfo buf, PlannerInfo *root,
						Index rtindex, Relation rel,
						List *attname)
{
	int			i = 0;
	ListCell   *lc;

	appendStringInfoString(buf, "DELETE FROM ");
	influxdb_deparse_relation(buf, rel);
	foreach(lc, attname)
	{
		int			attnum = lfirst_int(lc);

		appendStringInfo(buf, i == 0 ? " WHERE " : " AND ");
		influxdb_deparse_column_ref(buf, rtindex, attnum, -1, root, false, false);
		appendStringInfo(buf, "=$%d", i + 1);
		i++;
	}
	elog(DEBUG1, "delete:%s", buf->data);
}

/*
 * deparse remote DELETE statement
 *
 * 'buf' is the output buffer to append the statement to 'rtindex' is the RT
 * index of the associated target relation 'rel' is the relation descriptor
 * for the target relation 'foreignrel' is the RelOptInfo for the target
 * relation or the join relation containing all base relations in the query
 * 'remote_conds' is the qual clauses that must be evaluated remotely
 * '*params_list' is an output list of exprs that will become remote Params
 * '*retrieved_attrs' is an output list of integers of columns being
 * retrieved by RETURNING (if any)
 */
bool
influxdb_deparse_direct_delete_sql(StringInfo buf, PlannerInfo *root,
								   Index rtindex, Relation rel,
								   RelOptInfo *foreignrel,
								   List *remote_conds,
								   List **params_list,
								   List **retrieved_attrs)
{
	deparse_expr_cxt context;

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = foreignrel;
	context.scanrel = foreignrel;
	context.buf = buf;
	context.params_list = params_list;
	context.can_delete_directly = true;

	appendStringInfoString(buf, "DELETE FROM ");
	influxdb_deparse_relation(buf, rel);

	if (remote_conds)
	{
		appendStringInfoString(buf, " WHERE ");
		influxdb_append_conditions(remote_conds, &context);
	}
	return context.can_delete_directly;
}

/*
 * Deparse SELECT statement for given relation into buf.
 *
 * tlist contains the list of desired columns to be fetched from foreign server.
 * For a base relation fpinfo->attrs_used is used to construct SELECT clause,
 * hence the tlist is ignored for a base relation.
 *
 * remote_conds is the list of conditions to be deparsed into the WHERE clause
 * (or, in the case of upper relations, into the HAVING clause).
 *
 * If params_list is not NULL, it receives a list of Params and other-relation
 * Vars used in the clauses; these values must be transmitted to the remote
 * server as parameter values.
 *
 * If params_list is NULL, we're generating the query for EXPLAIN purposes,
 * so Params and other-relation Vars should be replaced by dummy values.
 *
 * pathkeys is the list of pathkeys to order the result by.
 *
 * List of columns selected is returned in retrieved_attrs.
 */
void
influxdb_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
									 List *tlist, List *remote_conds, List *pathkeys,
									 bool is_subquery, List **retrieved_attrs,
									 List **params_list,
									 bool has_limit)
{
	deparse_expr_cxt context;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) rel->fdw_private;
	List	   *quals;

	/*
	 * We handle relations for foreign tables, joins between those and upper
	 * relations.
	 */
	Assert(rel->reloptkind == RELOPT_JOINREL ||
		   rel->reloptkind == RELOPT_BASEREL ||
		   rel->reloptkind == RELOPT_OTHER_MEMBER_REL ||
		   rel->reloptkind == RELOPT_UPPER_REL);
	/* Fill portions of context common to upper, join and base relation */
	context.buf = buf;
	context.root = root;
	context.foreignrel = rel;
	context.scanrel = (rel->reloptkind == RELOPT_UPPER_REL) ? fpinfo->outerrel : rel;
	context.params_list = params_list;
	context.require_regex = false;
	context.is_tlist = false;
	context.can_skip_cast = false;
	/* Construct SELECT clause */
	influxdb_deparse_select(tlist, retrieved_attrs, &context);

	/*
	 * For upper relations, the WHERE clause is built from the remote
	 * conditions of the underlying scan relation; otherwise, we can use the
	 * supplied list of remote conditions directly.
	 */
	if (rel->reloptkind == RELOPT_UPPER_REL)
	{
		InfluxDBFdwRelationInfo *ofpinfo;

		ofpinfo = (InfluxDBFdwRelationInfo *) fpinfo->outerrel->fdw_private;
		quals = ofpinfo->remote_conds;
	}
	else
		quals = remote_conds;

	/* Construct FROM and WHERE clauses */
	influxdb_deparse_from_expr(quals, &context);

	if (rel->reloptkind == RELOPT_UPPER_REL)
	{
		/* Append GROUP BY clause */
		influxdb_append_group_by_clause(tlist, &context);

		/* Append HAVING clause */
		if (remote_conds)
		{
			appendStringInfo(buf, " HAVING ");
			influxdb_append_conditions(remote_conds, &context);
		}
	}

	/* Add ORDER BY clause if we found any useful pathkeys */
	if (pathkeys)
		influxdb_append_order_by_clause(pathkeys, &context);

	/* Add LIMIT clause if necessary */
	if (has_limit)
		influxdb_append_limit_clause(&context);

}

/**
 * get_proname
 *
 * Add a aggregate function name of 'oid' to 'proname'
 * by fetching from pg_proc system catalog.
 *
 * @param[in] oid
 * @param[out] procname
 */
static void
get_proname(Oid oid, StringInfo proname)
{
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *name;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(oid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", oid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Always print the function name */
	name = NameStr(procform->proname);
	appendStringInfoString(proname, name);

	ReleaseSysCache(proctup);
}

/*
 * Deparse SELECT statment
 */
static void
influxdb_deparse_select(List *tlist, List **retrieved_attrs, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	PlannerInfo *root = context->root;
	RelOptInfo *foreignrel = context->foreignrel;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) foreignrel->fdw_private;

	/*
	 * Construct SELECT list
	 */
	appendStringInfoString(buf, "SELECT ");

	if (foreignrel->reloptkind == RELOPT_JOINREL ||
		fpinfo->is_tlist_func_pushdown == true ||
		foreignrel->reloptkind == RELOPT_UPPER_REL)
	{
		/*
		 * For a join or upper relation the input tlist gives the list of
		 * columns required to be fetched from the foreign server.
		 */
		influxdb_deparse_explicit_target_list(tlist, retrieved_attrs, context);
	}
	else
	{
		/*
		 * For a base relation fpinfo->attrs_used gives the list of columns
		 * required to be fetched from the foreign server.
		 */
		RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel = table_open(rte->relid, NoLock);

		influxdb_deparse_target_list(buf, root, foreignrel->relid, rel, fpinfo->attrs_used, retrieved_attrs);

		table_close(rel, NoLock);
	}
}

/*
 * Construct a FROM clause and, if needed, a WHERE clause, and append those to
 * "buf".
 *
 * quals is the list of clauses to be included in the WHERE clause.
 */
static void
influxdb_deparse_from_expr(List *quals, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *scanrel = context->scanrel;

	/* For upper relations, scanrel must be either a joinrel or a baserel */
	Assert(context->foreignrel->reloptkind != RELOPT_UPPER_REL ||
		   scanrel->reloptkind == RELOPT_JOINREL ||
		   scanrel->reloptkind == RELOPT_BASEREL);

	/* Construct FROM clause */
	appendStringInfoString(buf, " FROM ");
	influxdb_deparse_from_expr_for_rel(buf, context->root, scanrel,
									   (bms_num_members(scanrel->relids) > 1),
									   context->params_list);

	/* Construct WHERE clause */
	if (quals != NIL)
	{
		appendStringInfo(buf, " WHERE ");
		influxdb_append_conditions(quals, context);
	}
}

/*
 * Deparse conditions from the provided list and append them to buf.
 *
 * The conditions in the list are assumed to be ANDed. This function is used to
 * deparse WHERE clauses, JOIN .. ON clauses and HAVING clauses.
 */
static void
influxdb_append_conditions(List *exprs, deparse_expr_cxt *context)
{
	int			nestlevel;
	ListCell   *lc;
	bool		is_first = true;
	StringInfo	buf = context->buf;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = influxdb_set_transmission_modes();

	foreach(lc, exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);

		/* Extract clause from RestrictInfo, if required */
		if (IsA(expr, RestrictInfo))
			expr = ((RestrictInfo *) expr)->clause;

		/* Connect expressions with "AND" and parenthesize each condition. */
		if (!is_first)
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		influxdb_deparse_expr(expr, context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}

	influxdb_reset_transmission_modes(nestlevel);
}

/*
 * Deparse given targetlist and append it to context->buf.
 *
 * tlist is list of TargetEntry's which in turn contain Var nodes.
 *
 * retrieved_attrs is the list of continuously increasing integers starting
 * from 1. It has same number of entries as tlist.
 */
static void
influxdb_deparse_explicit_target_list(List *tlist, List **retrieved_attrs,
									  deparse_expr_cxt *context)
{
	ListCell   *lc;
	StringInfo	buf = context->buf;
	int			i = 0;
	bool		first = true;
	bool		is_col_grouping_target = false;
	bool		need_field_key;
	bool		is_need_comma = false;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) context->foreignrel->fdw_private;

	*retrieved_attrs = NIL;

	/*
	 * We do not construct grouping target column in SELECT InfluxDB SQL. We
	 * just check for need to add field key more e.g. SELECT col1, col2, col3
	 * FROM table GROUP BY col1, col2; (col1 and col2 are tag keys) --> SELECT
	 * col3 FROM table GROUP BY col1, col2; So, firstly we need to check
	 * whether all target are columns or not.
	 */
	need_field_key = true;

	context->is_tlist = true;

	/* Contruct targets for remote SELECT statement */
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		/* Check whether column is a grouping target or not */
		if (!fpinfo->is_tlist_func_pushdown && IsA((Expr *) tle->expr, Var))
		{
			is_col_grouping_target = influxdb_is_grouping_target(tle, context->root->parse);
		}

		if (IsA((Expr *) tle->expr, Aggref) ||
			IsA((Expr *) tle->expr, OpExpr) ||
			IsA((Expr *) tle->expr, FuncExpr) ||
			(IsA((Expr *) tle->expr, Var) && !is_col_grouping_target))
		{
			bool		is_skip_expr = false;

			if (IsA((Expr *) tle->expr, FuncExpr))
			{
				FuncExpr   *fe = (FuncExpr *) tle->expr;
				StringInfo	func_name = makeStringInfo();

				get_proname(fe->funcid, func_name);
				if (strcmp(func_name->data, "influx_time") == 0 ||
					strcmp(func_name->data, "influx_fill_numeric") == 0 ||
					strcmp(func_name->data, "influx_fill_option") == 0)
					is_skip_expr = true;
			}

			if (is_need_comma && !is_skip_expr)
				appendStringInfoString(buf, ", ");
			need_field_key = false;

			if (!is_skip_expr)
			{
				first = false;
				influxdb_deparse_expr((Expr *) tle->expr, context);
				is_need_comma = true;
			}
		}

		/*
		 * Check all target columns are tag keys or not. If all target columns
		 * are tag keys, need to append a field key more.
		 */
		if (IsA((Expr *) tle->expr, Var) && need_field_key)
		{
			RangeTblEntry *rte = planner_rt_fetch(context->scanrel->relid, context->root);
			char	   *colname = influxdb_get_column_name(rte->relid, ((Var *) tle->expr)->varattno);

			if (!influxdb_is_tag_key(colname, rte->relid))
				need_field_key = false;
		}

		*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
		i++;
	}
	context->is_tlist = false;

	if (i == 0)
	{
		appendStringInfoString(buf, "*");
		return;
	}

	if (need_field_key)
	{
		/*
		 * For a base relation fpinfo->attrs_used gives the list of columns
		 * required to be fetched from the foreign server.
		 */
		RangeTblEntry *rte = planner_rt_fetch(context->scanrel->relid, context->root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel = table_open(rte->relid, NoLock);
		TupleDesc	tupdesc = RelationGetDescr(rel);

		influxdb_append_field_key(tupdesc, context->buf, context->scanrel->relid, context->root, first);

		table_close(rel, NoLock);
		return;
	}
}

/*
 * Construct FROM clause for given relation
 *
 * The function constructs ... JOIN ... ON ... for join relation. For a base
 * relation it just returns schema-qualified tablename, with the appropriate
 * alias if so requested.
 */
static void
influxdb_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *foreignrel,
								   bool use_alias, List **params_list)
{
	Assert(!use_alias);
	if (foreignrel->reloptkind == RELOPT_JOINREL)
	{
		/* Join pushdown not supported */
		Assert(false);
	}
	else
	{
		RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel = table_open(rte->relid, NoLock);

		influxdb_deparse_relation(buf, rel);

		table_close(rel, NoLock);
	}
}

void
influxdb_deparse_analyze(StringInfo sql, char *dbname, char *relname)
{
	appendStringInfo(sql, "SELECT");
	appendStringInfo(sql, " round(((data_length + index_length)), 2)");
	appendStringInfo(sql, " FROM information_schema.TABLES");
	appendStringInfo(sql, " WHERE table_schema = '%s' AND table_name = '%s'", dbname, relname);
}

/*
 * Emit a target list that retrieves the columns specified in attrs_used.
 * This is used for both SELECT and RETURNING targetlists.
 */
static void
influxdb_deparse_target_list(StringInfo buf,
							 PlannerInfo *root,
							 Index rtindex,
							 Relation rel,
							 Bitmapset *attrs_used,
							 List **retrieved_attrs)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	bool		have_wholerow;
	bool		first;
	int			i;
	bool		need_field_key; /* Check for need to add field key more */

	/* If there's a whole-row reference, we'll need all the columns. */
	have_wholerow = bms_is_member(0 - FirstLowInvalidHeapAttributeNumber,
								  attrs_used);

	first = true;
	need_field_key = true;

	*retrieved_attrs = NIL;
	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		if (have_wholerow ||
			bms_is_member(i - FirstLowInvalidHeapAttributeNumber,
						  attrs_used))
		{
			RangeTblEntry *rte = planner_rt_fetch(rtindex, root);
			char	   *name = influxdb_get_column_name(rte->relid, i);

			/* Skip if column is time */
			if (!INFLUXDB_IS_TIME_COLUMN(name))
			{
				if (!influxdb_is_tag_key(name, rte->relid))
					need_field_key = false;

				if (!first)
					appendStringInfoString(buf, ", ");
				first = false;
				influxdb_deparse_column_ref(buf, rtindex, i, -1, root, false, false);
			}

			*retrieved_attrs = lappend_int(*retrieved_attrs, i);
		}
	}

	/* Use '*' instead of NULL because InfluxDB does not support NULL */
	if (first)
	{
		appendStringInfoString(buf, "*");
		return;
	}

	/* If all of target list are tag keys, need to append a field key more */
	if (need_field_key)
	{
		influxdb_append_field_key(tupdesc, buf, rtindex, root, first);
	}
}

/*
 * Deparse WHERE clauses in given list of RestrictInfos and append them to buf.
 *
 * baserel is the foreign table we're planning for.
 *
 * If no WHERE clause already exists in the buffer, is_first should be true.
 *
 * If params is not NULL, it receives a list of Params and other-relation Vars
 * used in the clauses; these values must be transmitted to the remote server
 * as parameter values.
 *
 * If params is NULL, we're generating the query for EXPLAIN purposes,
 * so Params and other-relation Vars should be replaced by dummy values.
 */
void
influxdb_append_where_clause(StringInfo buf,
							 PlannerInfo *root,
							 RelOptInfo *baserel,
							 List *exprs,
							 bool is_first,
							 List **params)
{
	deparse_expr_cxt context;
	ListCell   *lc;

	if (params)
		*params = NIL;			/* initialize result list to empty */

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = baserel;
	context.buf = buf;
	context.params_list = params;
	context.is_tlist = false;
	context.can_skip_cast = false;

	foreach(lc, exprs)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		/* Connect expressions with "AND" and parenthesize each condition. */
		if (is_first)
			appendStringInfoString(buf, " WHERE ");
		else
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		influxdb_deparse_expr(ri->clause, &context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}
}

/*
 * Construct name to use for given column, and emit it into buf.
 * If it has a column_name FDW option, use that instead of attribute name.
 */
static void
influxdb_deparse_column_ref(StringInfo buf, int varno, int varattno, Oid vartype,
							PlannerInfo *root, bool convert, bool *can_delete_directly)
{
	RangeTblEntry *rte;
	char	   *colname = NULL;

	/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
	Assert(!IS_SPECIAL_VARNO(varno));

	/* Get RangeTblEntry from array in PlannerInfo. */
	rte = planner_rt_fetch(varno, root);

	colname = influxdb_get_column_name(rte->relid, varattno);

	/*
	 * If WHERE clause contains fields key, DELETE statement can not push down
	 * directly.
	 */
	if (can_delete_directly)
		if (!INFLUXDB_IS_TIME_COLUMN(colname) && !influxdb_is_tag_key(colname, rte->relid))
			*can_delete_directly = false;

	if (convert && vartype == BOOLOID)
	{
		appendStringInfo(buf, "(%s=true)", influxdb_quote_identifier(colname, QUOTE));
	}
	else
	{
		if (INFLUXDB_IS_TIME_COLUMN(colname))
			appendStringInfoString(buf, "time");
		else
			appendStringInfoString(buf, influxdb_quote_identifier(colname, QUOTE));
	}
}

/*
 * Append a SQL string regex representing "val" to buf.
 *
 * We convert LIKE's pattern on PostgreSQL to regex pattern on
 * InfluxDB.
 *
 * Surround regex pattern by '/' characters.
 *
 * PostgreSQL's percent sign is used to matches any sequence of
 * zero or more characters. We convert '%' sign to "(.*)" regex string.
 *
 * PostgreSQL's underscore is used to matches any single character.
 * We convert '_' character to "(.{1})" regex string.
 *
 * Escape regex special characters: "\\^$.|?*+()[{"
 */
void
influxdb_deparse_string_regex(StringInfo buf, const char *val)
{
	const char *regex_special = "\\^$.|?*+()[{";
	const char *ptr = val;

	appendStringInfoChar(buf, '/');
	while (*ptr != '\0')
	{
		switch (*ptr)
		{
			case '%':
				/* Change to regex string */
				appendStringInfoString(buf, "(.*)");
				break;
			case '_':
				/* Change to regex string */
				appendStringInfoString(buf, "(.{1})");
				break;
			case '\\':

				/*
				 * Backslash character is the escape character of PostgreSQL.
				 * We skip backslash, and move to the next character which is
				 * escaped by backslash and will be escapsed if it is a regex
				 * special character.
				 */
				ptr++;

				/* Check terminate character */
				if (*ptr == '\0')
				{
					elog(ERROR, "invalid pattern matching");
				}
				else
			default:
				{
					char		ch = *ptr;

					/* Check regex special character */
					if (strchr(regex_special, ch) != NULL)
					{
						/* Escape this char */
						appendStringInfoChar(buf, '\\');
						appendStringInfoChar(buf, ch);
					}
					else
					{
						appendStringInfoChar(buf, ch);
					}
				}
				break;
		}

		ptr++;
	}
	appendStringInfoChar(buf, '/');

	return;
}

/*
 * Append a fill option value as a string literal
 */
static void
influxdb_deparse_fill_option(StringInfo buf, const char *val)
{
	appendStringInfo(buf, "%s", val);
}

/*
 * Append a SQL string literal representing "val" to buf.
 */
void
influxdb_deparse_string_literal(StringInfo buf, const char *val)
{
	const char *valptr;

	appendStringInfoChar(buf, '\'');
	for (valptr = val; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}
	appendStringInfoChar(buf, '\'');
}

/*
 * Deparse given expression into context->buf.
 *
 * This function must support all the same node types that influxdb_foreign_expr_walker
 * accepts.
 *
 * Note: unlike ruleutils.c, we just use a simple hard-wired parenthesization
 * scheme: anything more complex than a Var, Const, function call or cast
 * should be self-parenthesized.
 */
static void
influxdb_deparse_expr(Expr *node, deparse_expr_cxt *context)
{
	bool		outer_can_skip_cast = context->can_skip_cast;

	if (node == NULL)
		return;

	context->can_skip_cast = false;

	switch (nodeTag(node))
	{
		case T_Var:
			influxdb_deparse_var((Var *) node, context);
			break;
		case T_Const:
			influxdb_deparse_const((Const *) node, context, 0);
			break;
		case T_Param:
			influxdb_deparse_param((Param *) node, context);
			break;
		case T_FuncExpr:
			context->can_skip_cast = outer_can_skip_cast;
			influxdb_deparse_func_expr((FuncExpr *) node, context);
			break;
		case T_OpExpr:
			influxdb_deparse_op_expr((OpExpr *) node, context);
			break;
		case T_ScalarArrayOpExpr:
			influxdb_deparse_scalar_array_op_expr((ScalarArrayOpExpr *) node, context);
			break;
		case T_RelabelType:
			influxdb_deparse_relabel_type((RelabelType *) node, context);
			break;
		case T_BoolExpr:
			influxdb_deparse_bool_expr((BoolExpr *) node, context);
			break;
		case T_NullTest:
			influxdb_deparse_null_test((NullTest *) node, context);
			break;
		case T_ArrayExpr:
			influxdb_deparse_array_expr((ArrayExpr *) node, context);
			break;
		case T_Aggref:
			influxdb_deparse_aggref((Aggref *) node, context);
			break;
		default:
			elog(ERROR, "unsupported expression type for deparse: %d",
				 (int) nodeTag(node));
			break;
	}
}

/*
 * Deparse given Var node into context->buf.
 *
 * If the Var belongs to the foreign relation, just print its remote name.
 * Otherwise, it's effectively a Param (and will in fact be a Param at
 * run time).  Handle it the same way we handle plain Params --- see
 * deparseParam for comments.
 */
static void
influxdb_deparse_var(Var *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Relids		relids = context->scanrel->relids;

	/* Qualify columns when multiple relations are involved. */
	/* bool		qualify_col = (bms_num_members(relids) > 1); */

	if (bms_is_member(node->varno, relids) && node->varlevelsup == 0)
		/* if (node->varno == context->foreignrel->relid && */
		/* node->varlevelsup == 0) */
	{
		InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) context->foreignrel->fdw_private;
		bool		convert = true;

		/*
		 * Var with BOOLOID type should be deparsed without conversion in
		 * target list.
		 */
		if (context->is_tlist && fpinfo->is_tlist_func_pushdown)
			convert = false;

		/* Var belongs to foreign table */
		influxdb_deparse_column_ref(buf, node->varno, node->varattno, node->vartype, context->root, convert, &context->can_delete_directly);
	}
	else
	{
		/* Treat like a Param */
		if (context->params_list)
		{
			int			pindex = 0;
			ListCell   *lc;

			/* find its index in params_list */
			foreach(lc, *context->params_list)
			{
				pindex++;
				if (equal(node, (Node *) lfirst(lc)))
					break;
			}
			if (lc == NULL)
			{
				/* not in list, so add it */
				pindex++;
				*context->params_list = lappend(*context->params_list, node);
			}
			influxdb_print_remote_param(pindex, node->vartype, node->vartypmod, context);
		}
		else
		{
			influxdb_print_remote_placeholder(node->vartype, node->vartypmod, context);
		}
	}
}

/*
 * Deparse given constant value into context->buf.
 *
 * This function has to be kept in sync with ruleutils.c's get_const_expr.
 * As for that function, showtype can be -1 to never show "::typename" decoration,
 * or +1 to always show it, or 0 to show it only if the constant wouldn't be assumed
 * to be the right type by default.
 */
static void
influxdb_deparse_const(Const *node, deparse_expr_cxt *context, int showtype)
{
	StringInfo	buf = context->buf;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;
	char	   *type_name;

	if (node->constisnull)
	{
		appendStringInfoString(buf, "NULL");
		return;
	}

	getTypeOutputInfo(node->consttype,
					  &typoutput, &typIsVarlena);

	switch (node->consttype)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			{
				extval = OidOutputFunctionCall(typoutput, node->constvalue);

				/*
				 * No need to quote unless it's a special value such as 'NaN'.
				 * See comments in get_const_expr().
				 */
				if (strspn(extval, "0123456789+-eE.") == strlen(extval))
				{
					if (extval[0] == '+' || extval[0] == '-')
						appendStringInfo(buf, "(%s)", extval);
					else
						appendStringInfoString(buf, extval);
				}
				else
					appendStringInfo(buf, "'%s'", extval);
			}
			break;
		case BITOID:
		case VARBITOID:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			appendStringInfo(buf, "B'%s'", extval);
			break;
		case BOOLOID:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			if (strcmp(extval, "t") == 0)
				appendStringInfoString(buf, "true");
			else
				appendStringInfoString(buf, "false");
			break;

		case BYTEAOID:

			/*
			 * the string for BYTEA always seems to be in the format "\\x##"
			 * where # is a hex digit, Even if the value passed in is
			 * 'hi'::bytea we will receive "\x6869". Making this assumption
			 * allows us to quickly convert postgres escaped strings to
			 * InfluxDB ones for comparison
			 */
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			appendStringInfo(buf, "X\'%s\'", extval + 2);
			break;
		case TIMESTAMPTZOID:
			{
				Datum		datum;

				/*
				 * Convert from TIMESTAMPTZOID to TIMESTAMP ex: '2015-08-18
				 * 09:00:00+09' -> '2015-08-18 00:00:00'
				 */
				datum = DirectFunctionCall2(timestamptz_zone, CStringGetTextDatum("UTC"), node->constvalue);

				/* Convert to string */
				getTypeOutputInfo(TIMESTAMPOID, &typoutput, &typIsVarlena);
				extval = OidOutputFunctionCall(typoutput, datum);
				appendStringInfo(buf, "'%s'", extval);
				break;
			}
		case INTERVALOID:
			{
				Interval   *interval = DatumGetIntervalP(node->constvalue);
				struct pg_tm tm;
				fsec_t		fsec;

				interval2tm(*interval, &tm, &fsec);

				appendStringInfo(buf, "%dd%dh%dm%ds%du", tm.tm_mday, tm.tm_hour,
								 tm.tm_min, tm.tm_sec, fsec
					);


				break;
			}
		default:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);

			/*
			 * Get type name based on the const value. If the type name is
			 * "influx_fill_option", allow it to push down to remote without
			 * casting.
			 */
			type_name = influxdb_get_data_type_name(node->consttype);

			if (strcmp(type_name, "influx_fill_enum") == 0)
			{
				influxdb_deparse_fill_option(buf, extval);
			}
			else if (context->require_regex)
			{
				/*
				 * Convert LIKE's pattern on PostgreSQL to regex pattern on
				 * InfluxDB.
				 */
				influxdb_deparse_string_regex(buf, extval);
			}
			else
			{
				influxdb_deparse_string_literal(buf, extval);
			}
			break;
	}
}

/*
 * Deparse given Param node.
 *
 * If we're generating the query "for real", add the Param to
 * context->params_list if it's not already present, and then use its index
 * in that list as the remote parameter number.  During EXPLAIN, there's
 * no need to identify a parameter number.
 */
static void
influxdb_deparse_param(Param *node, deparse_expr_cxt *context)
{
	if (context->params_list)
	{
		int			pindex = 0;
		ListCell   *lc;

		/* find its index in params_list */
		foreach(lc, *context->params_list)
		{
			pindex++;
			if (equal(node, (Node *) lfirst(lc)))
				break;
		}
		if (lc == NULL)
		{
			/* not in list, so add it */
			pindex++;
			*context->params_list = lappend(*context->params_list, node);
		}

		influxdb_print_remote_param(pindex, node->paramtype, node->paramtypmod, context);
	}
	else
	{
		influxdb_print_remote_placeholder(node->paramtype, node->paramtypmod, context);
	}
}

/*
 * This possible that name of function in PostgreSQL and
 * InfluxDB differ, so return the InfluxDB equelent function name
 */
char *
influxdb_replace_function(char *in)
{
	if (strcmp(in, "btrim") == 0)
		return "trim";
	else if (strcmp(in, "influx_count") == 0 || strcmp(in, "influx_count_all") == 0)
		return "count";
	else if (strcmp(in, "influx_distinct") == 0)
		return "distinct";
	else if (strcmp(in, "integral_all") == 0)
		return "integral";
	else if (strcmp(in, "mean_all") == 0)
		return "mean";
	else if (strcmp(in, "median_all") == 0)
		return "median";
	else if (strcmp(in, "influx_mode") == 0 || strcmp(in, "influx_mode_all") == 0)
		return "mode";
	else if (strcmp(in, "spread_all") == 0)
		return "spread";
	else if (strcmp(in, "stddev_all") == 0)
		return "stddev";
	else if (strcmp(in, "influx_sum") == 0 || strcmp(in, "influx_sum_all") == 0)
		return "sum";
	else if (strcmp(in, "first_all") == 0)
		return "first";
	else if (strcmp(in, "last_all") == 0)
		return "last";
	else if (strcmp(in, "influx_max") == 0 || strcmp(in, "influx_max_all") == 0)
		return "max";
	else if (strcmp(in, "influx_min") == 0 || strcmp(in, "influx_min_all") == 0)
		return "min";
	else if (strcmp(in, "percentile_all") == 0)
		return "percentile";
	else if (strcmp(in, "sample_all") == 0)
		return "sample";
	else if (strcmp(in, "abs_all") == 0)
		return "abs";
	else if (strcmp(in, "acos_all") == 0)
		return "acos";
	else if (strcmp(in, "asin_all") == 0)
		return "asin";
	else if (strcmp(in, "atan_all") == 0)
		return "atan";
	else if (strcmp(in, "atan2_all") == 0)
		return "atan2";
	else if (strcmp(in, "ceil_all") == 0)
		return "ceil";
	else if (strcmp(in, "cos_all") == 0)
		return "cos";
	else if (strcmp(in, "cumulative_sum_all") == 0)
		return "cumulative_sum";
	else if (strcmp(in, "derivative_all") == 0)
		return "derivative";
	else if (strcmp(in, "difference_all") == 0)
		return "difference";
	else if (strcmp(in, "elapsed_all") == 0)
		return "elapsed";
	else if (strcmp(in, "exp_all") == 0)
		return "exp";
	else if (strcmp(in, "floor_all") == 0)
		return "floor";
	else if (strcmp(in, "ln_all") == 0)
		return "ln";
	else if (strcmp(in, "log_all") == 0)
		return "log";
	else if (strcmp(in, "log2_all") == 0)
		return "log2";
	else if (strcmp(in, "log10_all") == 0)
		return "log10";
	else if (strcmp(in, "moving_average_all") == 0)
		return "moving_average";
	else if (strcmp(in, "non_negative_derivative_all") == 0)
		return "non_negative_derivative";
	else if (strcmp(in, "non_negative_difference_all") == 0)
		return "non_negative_difference";
	else if (strcmp(in, "pow_all") == 0)
		return "pow";
	else if (strcmp(in, "round_all") == 0)
		return "round";
	else if (strcmp(in, "sin_all") == 0)
		return "sin";
	else if (strcmp(in, "sqrt_all") == 0)
		return "sqrt";
	else if (strcmp(in, "tan_all") == 0)
		return "tan";
	else if (strcmp(in, "chande_momentum_oscillator_all") == 0)
		return "chande_momentum_oscillator";
	else if (strcmp(in, "exponential_moving_average_all") == 0)
		return "exponential_moving_average";
	else if (strcmp(in, "double_exponential_moving_average_all") == 0)
		return "double_exponential_moving_average";
	else if (strcmp(in, "kaufmans_efficiency_ratio_all") == 0)
		return "kaufmans_efficiency_ratio";
	else if (strcmp(in, "kaufmans_adaptive_moving_average_all") == 0)
		return "kaufmans_adaptive_moving_average";
	else if (strcmp(in, "triple_exponential_moving_average_all") == 0)
		return "triple_exponential_moving_average";
	else if (strcmp(in, "triple_exponential_derivative_all") == 0)
		return "triple_exponential_derivative";
	else if (strcmp(in, "relative_strength_index_all") == 0)
		return "relative_strength_index";
	else
		return in;
}

/*
 * Deparse a function call.
 */
static void
influxdb_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	char	   *proname;
	bool		first;
	ListCell   *arg;
	bool		arg_swap = false;
	bool		can_skip_cast = false;
	bool		is_star_func = false;
	List	   *args = node->args;

	/*
	 * Normal function: display as proname(args).
	 */
	proname = get_func_name(node->funcid);

	/*
	 * fill() must go at the end of the GROUP BY clause if you are GROUP(ing)
	 * BY several things. At this stage saved the fill expression and not
	 * deparse
	 */
	if (strcmp(proname, "influx_fill_numeric") == 0 ||
		strcmp(proname, "influx_fill_option") == 0)
	{
		Assert(list_length(args) == 1);
		/* Does not deparse this function in SELECT statement */
		if (context->is_tlist)
			return;

		/*
		 * "time(0d0h0m2s0u, " => "time(0d0h0m2s0u" fill() is consider as a
		 * parameter of time() and at this stage it has been deparsed ", " to
		 * prepare to not deparse fill() inside time function, reverse this
		 * action. Fill() will be saved and deparsed at the latter part GROUP
		 * BY expression.
		 */
		buf->len = buf->len - 2;

		/* Store the fill() node to deparse later */
		context->influx_fill_expr = node;
		return;
	}

	/* -----
	 * Convert time() function for influx
	 * "influx_time(time, interval '2h')" => "time(2h)"
	 * "influx_time(time, interval '2h', interval '1h')" => to "time(2h, 1h)"
	 * "influx_time(time, interval '2h', influx_fill_numeric(100))" => "time(2h) fill(100)"
	 * "influx_time(time, interval '2h', influx_fill_option('linear'))" => "time(2h) fill(linear)"
	 * "influx_time(time, interval '2h', interval '1h', influx_fill_numeric(100))" => "time(2h, 1h) fill(100)"
	 * "influx_time(time, interval '2h', interval '1h', influx_fill_option('linear'))" => "time(2h,1h) fill(linear)"
	 * ------
	 */
	if (strcmp(proname, "influx_time") == 0)
	{
		int			idx = 0;

		Assert(list_length(args) == 2 ||
			   list_length(args) == 3 ||
			   list_length(args) == 4);

		if (context->is_tlist)
			return;

		appendStringInfo(buf, "time(");
		first = true;
		foreach(arg, args)
		{
			if (idx == 0)
			{
				/* Skip first parameter */
				idx++;
				continue;
			}
			if (idx >= 2)
				appendStringInfoString(buf, ", ");

			influxdb_deparse_expr((Expr *) lfirst(arg), context);
			idx++;
		}
		appendStringInfoChar(buf, ')');
		return;
	}

	/* remove cast function if parent function is can handle without cast */
	if (context->can_skip_cast == true &&
		(strcmp(proname, "float8") == 0 || strcmp(proname, "numeric") == 0))
	{
		arg = list_head(args);
		context->can_skip_cast = false;
		influxdb_deparse_expr((Expr *) lfirst(arg), context);
		return;
	}

	if (strcmp(proname, "log") == 0)
	{
		arg_swap = true;
	}

	/* inner function can skip cast if any */
	if (influxdb_is_unique_func(node->funcid, proname) ||
		influxdb_is_supported_builtin_func(node->funcid, proname))
		can_skip_cast = true;

	is_star_func = influxdb_is_star_func(node->funcid, proname);
	/* Translate PostgreSQL function into InfluxDB function */
	proname = influxdb_replace_function(proname);

	/* Deparse the function name ... */
	appendStringInfo(buf, "%s(", proname);

	/* swap arguments */
	if (arg_swap && list_length(args) == 2)
	{
		args = list_make2(lfirst(list_tail(args)), lfirst(list_head(args)));
	}

	/* ... and all the arguments */
	first = true;

	if (is_star_func)
	{
		appendStringInfoChar(buf, '*');
		first = false;
	}
	foreach(arg, args)
	{
		Expr	   *exp = (Expr *) lfirst(arg);

		if (!first)
			appendStringInfoString(buf, ", ");

		if (IsA((Node *) exp, Const))
		{
			Const	   *arg = (Const *) exp;
			char	   *extval;

			if (arg->consttype == TEXTOID)
			{
				bool		is_regex = influxdb_is_regex_argument(arg, &extval);

				/* Append regex */
				if (is_regex == true)
				{
					appendStringInfo(buf, "%s", extval);
					first = false;
					continue;
				}
			}
		}

		if (can_skip_cast)
			context->can_skip_cast = true;
		influxdb_deparse_expr((Expr *) exp, context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse given operator expression.  To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
influxdb_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Form_pg_operator form;
	char		oprkind;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
	Assert((oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/* Deparse left operand, if any. */
	if (oprkind == 'b')
	{
		influxdb_deparse_expr(linitial(node->args), context);
		appendStringInfoChar(buf, ' ');
	}

	/* Deparse operator name. */
	influxdb_deparse_operator_name(buf, form, &context->require_regex);

	/* Deparse right operand. */
	appendStringInfoChar(buf, ' ');
	influxdb_deparse_expr(llast(node->args), context);

	/* Reset regex require for next operation */
	if (context->require_regex)
		context->require_regex = false;

	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
}

/*
 * Print the name of an operator.
 */
static void
influxdb_deparse_operator_name(StringInfo buf, Form_pg_operator opform, bool *regex)
{
	/* opname is not a SQL identifier, so we should not quote it. */
	cur_opname = NameStr(opform->oprname);
	*regex = false;

	/* Print schema name only if it's not pg_catalog */
	if (opform->oprnamespace != PG_CATALOG_NAMESPACE)
	{
		const char *opnspname;

		opnspname = get_namespace_name(opform->oprnamespace);
		/* Print fully qualified operator name. */
		appendStringInfo(buf, "OPERATOR(%s.%s)",
						 influxdb_quote_identifier(opnspname, QUOTE), cur_opname);
	}
	else
	{
		if (strcmp(cur_opname, "~~") == 0)
		{
			appendStringInfoString(buf, "=~");
			*regex = true;
		}
		else if (strcmp(cur_opname, "!~~") == 0)
		{
			appendStringInfoString(buf, "!~");
			*regex = true;
		}
		else if (strcmp(cur_opname, "~~*") == 0 ||
				 strcmp(cur_opname, "!~~*") == 0 ||
				 strcmp(cur_opname, "~") == 0 ||
				 strcmp(cur_opname, "!~") == 0 ||
				 strcmp(cur_opname, "~*") == 0 ||
				 strcmp(cur_opname, "!~*") == 0)
		{
			elog(ERROR, "OPERATOR is not supported");
		}
		else
		{
			appendStringInfoString(buf, cur_opname);
		}
	}
}

/*
 * Deparse given ScalarArrayOpExpr expression.  To avoid problems
 * around priority of operations, we always parenthesize the arguments.
 * InfluxDB does not support IN,
 * so conditions concatenated by OR will be created.
 * expr IN (c1, c2, c3) => expr == c1 OR expr == c2 OR expr == c3
 * expr NOT IN (c1, c2, c3) => expr <> c1 AND expr <> c2 AND expr <> c3
 */
static void
influxdb_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Expr	   *arg1;
	Expr	   *arg2;
	Form_pg_operator form;
	char	   *opname = NULL;
	Oid			typoutput;
	bool		typIsVarlena;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	opname = pstrdup(NameStr(form->oprname));
	ReleaseSysCache(tuple);

	/* Get left and right argument for deparsing */
	arg1 = linitial(node->args);
	arg2 = lsecond(node->args);
	switch (nodeTag((Node *) arg2))
	{
		case T_Const:
			{
				char	   *extval;
				Const	   *c;
				bool		isstr;
				const char *valptr;
				int			i = -1;
				bool		deparseLeft = true;
				bool		inString = false;
				bool		isEscape = false;

				c = (Const *) arg2;
				if (!c->constisnull)
				{
					getTypeOutputInfo(c->consttype,
									  &typoutput, &typIsVarlena);
					extval = OidOutputFunctionCall(typoutput, c->constvalue);
					switch (c->consttype)
					{
						case BOOLARRAYOID:
						case INT8ARRAYOID:
						case INT2ARRAYOID:
						case INT4ARRAYOID:
						case OIDARRAYOID:
						case FLOAT4ARRAYOID:
						case FLOAT8ARRAYOID:
							isstr = false;
							break;
						default:
							isstr = true;
							break;
					}

					/* Deparse right operand. */
					for (valptr = extval; *valptr; valptr++)
					{
						char		ch = *valptr;

						i++;

						/* Deparse left operand. */
						if (deparseLeft)
						{
							if (c->consttype == BOOLARRAYOID)
							{
								if (arg1 != NULL && IsA(arg1, Var))
								{
									Var		   *var = (Var *) arg1;

									/*
									 * Deparse bool column with convert
									 * argument is false
									 */
									influxdb_deparse_column_ref(buf, var->varno, var->varattno, var->vartype, context->root, false, false);
								}
							}
							else
							{
								influxdb_deparse_expr(arg1, context);
							}

							/* Append operator */
							appendStringInfo(buf, " %s ", opname);

							if (isstr)
								appendStringInfoChar(buf, '\'');
							deparseLeft = false;
						}

						if ((ch == '{' && i == 0) || (ch == '}' && (i == (strlen(extval) - 1))))
							continue;

						/* Remove '\"' and process the next character. */
						if (ch == '\"' && !isEscape)
						{
							inString = ~inString;
							continue;
						}
						/* Add escape character '\'' for '\'' */
						if (ch == '\'')
							appendStringInfoChar(buf, '\'');

						/*
						 * Remove character '\\' and process the next
						 * character.
						 */
						if (ch == '\\' && !isEscape)
						{
							isEscape = true;
							continue;
						}
						isEscape = false;

						if (ch == ',' && !inString)
						{
							if (isstr)
								appendStringInfoChar(buf, '\'');

							if (node->useOr)
								appendStringInfo(buf, " OR ");
							else
								appendStringInfo(buf, " AND ");

							deparseLeft = true;
							continue;
						}

						/*
						 * InfluxDB only supports "= true" or "= false" (not
						 * "= 't'"" or "= 'f'")
						 */
						if (c->consttype == BOOLARRAYOID)
						{
							if (ch == 't')
								appendStringInfo(buf, "true");
							else
								appendStringInfo(buf, "false");
							continue;
						}
						appendStringInfoChar(buf, ch);
					}
					if (isstr)
						appendStringInfoChar(buf, '\'');
				}
				break;
			}
		case T_ArrayExpr:
			{
				bool		first = true;
				ListCell   *lc;

				foreach(lc, ((ArrayExpr *) arg2)->elements)
				{
					if (!first)
					{
						if (node->useOr)
							appendStringInfoString(buf, " OR ");
						else
							appendStringInfoString(buf, " AND ");
					}

					/* deparse left argument */
					appendStringInfoChar(buf, '(');
					influxdb_deparse_expr(arg1, context);

					appendStringInfo(buf, " %s ", opname);

					/* deparse each element in right argument sequentially */
					influxdb_deparse_expr(lfirst(lc), context);
					appendStringInfoChar(buf, ')');

					first = false;
				}
				break;
			}
		default:
			elog(ERROR, "unsupported expression type for deparse: %d", (int) nodeTag(node));
			break;
	}
}

/*
 * Deparse a RelabelType (binary-compatible cast) node.
 */
static void
influxdb_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context)
{
	influxdb_deparse_expr(node->arg, context);
}

/*
 * Deparse a BoolExpr node.
 *
 * Note: by the time we get here, AND and OR expressions have been flattened
 * into N-argument form, so we'd better be prepared to deal with that.
 */
static void
influxdb_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	const char *op = NULL;		/* keep compiler quiet */
	bool		first;
	ListCell   *lc;

	switch (node->boolop)
	{
		case AND_EXPR:
			op = "AND";
			break;
		case OR_EXPR:
			op = "OR";
			break;
		case NOT_EXPR:
			appendStringInfoString(buf, "(NOT ");
			influxdb_deparse_expr(linitial(node->args), context);
			appendStringInfoChar(buf, ')');
			return;
	}

	appendStringInfoChar(buf, '(');
	first = true;
	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfo(buf, " %s ", op);
		influxdb_deparse_expr((Expr *) lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse IS [NOT] NULL expression.
 */
static void
influxdb_deparse_null_test(NullTest *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfoChar(buf, '(');
	influxdb_deparse_expr(node->arg, context);
	if (node->nulltesttype == IS_NULL)
		appendStringInfoString(buf, " IS NULL)");
	else
		appendStringInfoString(buf, " IS NOT NULL)");
}

/*
 * Deparse ARRAY[...] construct.
 */
static void
influxdb_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first = true;
	ListCell   *lc;

	appendStringInfoString(buf, "ARRAY[");
	foreach(lc, node->elements)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		influxdb_deparse_expr(lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ']');
}

/*
 * Print the representation of a parameter to be sent to the remote side.
 *
 * Note: we always label the Param's type explicitly rather than relying on
 * transmitting a numeric type OID in PQexecParams().  This allows us to
 * avoid assuming that types have the same OIDs on the remote side as they
 * do locally --- they need only have the same names.
 */
static void
influxdb_print_remote_param(int paramindex, Oid paramtype, int32 paramtypmod,
							deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfo(buf, "$%d", paramindex);
}

/*
 * Print the representation of a placeholder for a parameter that will be
 * sent to the remote side at execution time.
 *
 * This is used when we're just trying to EXPLAIN the remote query.
 * We don't have the actual value of the runtime parameter yet, and we don't
 * want the remote planner to generate a plan that depends on such a value
 * anyway.  Thus, we can't do something simple like "$1::paramtype".
 */
static void
influxdb_print_remote_placeholder(Oid paramtype, int32 paramtypmod,
								  deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfo(buf, "(SELECT null)");
}

/*
 * Return true if given object is one of PostgreSQL's built-in objects.
 *
 * We use FirstBootstrapObjectId as the cutoff, so that we only consider
 * objects with hand-assigned OIDs to be "built in", not for instance any
 * function or type defined in the information_schema.
 *
 * Our constraints for dealing with types are tighter than they are for
 * functions or operators: we want to accept only types that are in pg_catalog,
 * else format_type might incorrectly fail to schema-qualify their names.
 * (This could be fixed with some changes to format_type, but for now there's
 * no need.)  Thus we must exclude information_schema types.
 *
 * XXX there is a problem with this, which is that the set of built-in
 * objects expands over time.  Something that is built-in to us might not
 * be known to the remote server, if it's of an older version.  But keeping
 * track of that would be a huge exercise.
 */
bool
influxdb_is_builtin(Oid oid)
{
	return (oid < FirstBootstrapObjectId);
}

bool
influxdb_is_regex_argument(Const *node, char **extval)
{
	Oid			typoutput;
	bool		typIsVarlena;
	const char *first;
	const char *last;

	getTypeOutputInfo(node->consttype,
					  &typoutput, &typIsVarlena);

	(*extval) = OidOutputFunctionCall(typoutput, node->constvalue);
	first = *extval;
	last = *extval + strlen(*extval) - 1;
	/* Append regex */
	if (*first == '/' && *last == '/')
		return true;
	else
		return false;
}

/*
 * Check if it is necessary to add a star(*) as the 1st argument
 */
bool
influxdb_is_star_func(Oid funcid, char *in)
{
	char	   *eof = "_all";	/* End of function should be "_all" */
	size_t		func_len = strlen(in);
	size_t		eof_len = strlen(eof);

	if (influxdb_is_builtin(funcid))
		return false;

	if (func_len > eof_len && strcmp(in + func_len - eof_len, eof) == 0 &&
		exist_in_function_list(in, InfluxDBStableStarFunction))
		return true;

	return false;
}

static bool
influxdb_is_unique_func(Oid funcid, char *in)
{
	if (influxdb_is_builtin(funcid))
		return false;

	if (exist_in_function_list(in, InfluxDBUniqueFunction))
		return true;

	return false;
}

static bool
influxdb_is_supported_builtin_func(Oid funcid, char *in)
{
	if (!influxdb_is_builtin(funcid))
		return false;

	if (exist_in_function_list(in, InfluxDBSupportedBuiltinFunction))
		return true;

	return false;
}

/*
 * Deparse an Aggref node.
 */
static void
influxdb_deparse_aggref(Aggref *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		use_variadic;
	char	   *func_name;
	bool		is_star_func;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->aggvariadic;

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	func_name = get_func_name(node->aggfnoid);

	if (!node->aggstar)
	{
		if ((strcmp(func_name, "last") == 0 || strcmp(func_name, "first") == 0) && list_length(node->args) == 2)
		{
			/* Convert func(time, value) to func(value) */
			Assert(list_length(node->args) == 2);
			appendStringInfo(buf, "%s(", func_name);
			influxdb_deparse_expr((Expr *) (((TargetEntry *) list_nth(node->args, 1))->expr), context);
			appendStringInfoChar(buf, ')');
			return;
		}
	}

	is_star_func = influxdb_is_star_func(node->aggfnoid, func_name);
	func_name = influxdb_replace_function(func_name);
	appendStringInfo(buf, "%s", func_name);

	appendStringInfoChar(buf, '(');

	/* Add DISTINCT */
	appendStringInfo(buf, "%s", (node->aggdistinct != NIL) ? "DISTINCT " : "");

	/* aggstar can be set only in zero-argument aggregates */
	if (node->aggstar)
		appendStringInfoChar(buf, '*');
	else
	{
		ListCell   *arg;
		bool		first = true;

		if (is_star_func)
		{
			appendStringInfoChar(buf, '*');
			first = false;
		}

		/* Add all the arguments */
		foreach(arg, node->args)
		{
			TargetEntry *tle = (TargetEntry *) lfirst(arg);
			Node	   *n = (Node *) tle->expr;

			if (IsA(n, Const))
			{
				Const	   *arg = (Const *) n;
				char	   *extval;

				if (arg->consttype == TEXTOID)
				{
					bool		is_regex = influxdb_is_regex_argument(arg, &extval);

					/* Append regex */
					if (is_regex == true)
					{
						appendStringInfo(buf, "%s", extval);
						first = false;
						continue;
					}

				}
			}

			if (tle->resjunk)
				continue;

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			/* Add VARIADIC */
#if (PG_VERSION_NUM >= 130000)
			if (use_variadic && lnext(node->args, arg) == NULL)
#else
			if (use_variadic && lnext(arg) == NULL)
#endif
				appendStringInfoString(buf, "VARIADIC ");

			influxdb_deparse_expr((Expr *) n, context);
		}
	}

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse GROUP BY clause.
 */
static void
influxdb_append_group_by_clause(List *tlist, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Query	   *query = context->root->parse;
	ListCell   *lc;
	bool		first = true;

	/* Nothing to be done, if there's no GROUP BY clause in the query. */
	if (!query->groupClause)
		return;

	appendStringInfo(buf, " GROUP BY ");

	/*
	 * Queries with grouping sets are not pushed down, so we don't expect
	 * grouping sets here.
	 */
	Assert(!query->groupingSets);

	context->influx_fill_expr = NULL;
	foreach(lc, query->groupClause)
	{
		SortGroupClause *grp = (SortGroupClause *) lfirst(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		influxdb_deparse_sort_group_clause(grp->tleSortGroupRef, tlist, context);
	}

	/* Append fill() function in the last position of GROUP BY clause if have */
	if (context->influx_fill_expr)
	{
		ListCell   *arg;

		appendStringInfo(buf, " fill(");

		foreach(arg, context->influx_fill_expr->args)
		{
			influxdb_deparse_expr((Expr *) lfirst(arg), context);
		}

		appendStringInfoChar(buf, ')');
	}
}

/*
 * Deparse LIMIT/OFFSET clause.
 */
static void
influxdb_append_limit_clause(deparse_expr_cxt *context)
{
	PlannerInfo *root = context->root;
	StringInfo	buf = context->buf;
	int			nestlevel;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = influxdb_set_transmission_modes();

	if (root->parse->limitCount)
	{
		appendStringInfoString(buf, " LIMIT ");
		influxdb_deparse_expr((Expr *) root->parse->limitCount, context);
	}
	if (root->parse->limitOffset)
	{
		appendStringInfoString(buf, " OFFSET ");
		influxdb_deparse_expr((Expr *) root->parse->limitOffset, context);
	}

	influxdb_reset_transmission_modes(nestlevel);
}

/*
 * Find an equivalence class member expression, all of whose Vars, come from
 * the indicated relation.
 */
static Expr *
influxdb_find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel)
{
	ListCell   *lc_em;

	foreach(lc_em, ec->ec_members)
	{
		EquivalenceMember *em = lfirst(lc_em);

		if (bms_is_subset(em->em_relids, rel->relids))
		{
			/*
			 * If there is more than one equivalence member whose Vars are
			 * taken entirely from this relation, we'll be content to choose
			 * any one of those.
			 */
			return em->em_expr;
		}
	}

	/* We didn't find any suitable equivalence class expression */
	return NULL;
}

/*
 * Deparse ORDER BY clause according to the given pathkeys for given base
 * relation. From given pathkeys expressions belonging entirely to the given
 * base relation are obtained and deparsed.
 */
static void
influxdb_append_order_by_clause(List *pathkeys, deparse_expr_cxt *context)
{
	ListCell   *lcell;
	int			nestlevel;
	char	   *delim = " ";
	RelOptInfo *baserel = context->scanrel;
	StringInfo	buf = context->buf;

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = influxdb_set_transmission_modes();

	appendStringInfo(buf, " ORDER BY");
	foreach(lcell, pathkeys)
	{
		PathKey    *pathkey = lfirst(lcell);
		Expr	   *em_expr;

		em_expr = influxdb_find_em_expr_for_rel(pathkey->pk_eclass, baserel);
		Assert(em_expr != NULL);

		appendStringInfoString(buf, delim);
		influxdb_deparse_expr(em_expr, context);
		if (pathkey->pk_strategy == BTLessStrategyNumber)
			appendStringInfoString(buf, " ASC");
		else
			appendStringInfoString(buf, " DESC");

		if (pathkey->pk_nulls_first)
			elog(ERROR, "NULLS FIRST not supported");
		delim = ", ";
	}
	influxdb_reset_transmission_modes(nestlevel);
}

/*
 * influxdb_get_data_type_name
 *		Deparses data type name from given data type oid.
 */
char *
influxdb_get_data_type_name(Oid data_type_id)
{
	HeapTuple	tuple;
	Form_pg_type type;
	char	   *type_name;

	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(data_type_id));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for data type id %u", data_type_id);
	type = (Form_pg_type) GETSTRUCT(tuple);
	/* Always print the data type name */
	type_name = pstrdup(type->typname.data);
	ReleaseSysCache(tuple);
	return type_name;
}

/*
 * Appends a sort or group clause.
 *
 * Like get_rule_sortgroupclause(), returns the expression tree, so caller
 * need not find it again.
 */
static Node *
influxdb_deparse_sort_group_clause(Index ref, List *tlist, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	TargetEntry *tle;
	Expr	   *expr;

	tle = get_sortgroupref_tle(ref, tlist);
	expr = tle->expr;

	if (expr && IsA(expr, Const))
	{
		/*
		 * Force a typecast here so that we don't emit something like "GROUP
		 * BY 2", which will be misconstrued as a column position rather than
		 * a constant.
		 */
		influxdb_deparse_const((Const *) expr, context, 1);
	}
	else if (!expr || IsA(expr, Var))
		influxdb_deparse_expr(expr, context);
	else
	{
		/* Always parenthesize the expression. */
		appendStringInfoString(buf, "(");
		influxdb_deparse_expr(expr, context);
		appendStringInfoString(buf, ")");
	}

	return (Node *) expr;
}

/*
 * At least one element in the list is time column
 * influxdb_is_contain_time_column function returns true.
 */
static bool
influxdb_is_contain_time_column(List *tlist)
{
	Expr	   *expr;
	Var		   *var;
	ListCell   *lc;

	/* Check Timestamp type for the operand which is Var */
	foreach(lc, tlist)
	{
		expr = (Expr *) lfirst(lc);
		if (!IsA(expr, Var))
			continue;

		var = (Var *) expr;
		if (var->vartype == TIMESTAMPTZOID ||
			var->vartype == TIMEOID ||
			var->vartype == TIMESTAMPOID)
		{
			return true;
		}
	}

	return false;
}

/*
 * influxdb_is_grouping_target
 * This function check whether given target entry is grouping target,
 * if so, return true, otherwise return false.
 */
bool
influxdb_is_grouping_target(TargetEntry *tle, Query *query)
{
	ListCell   *lc;

	/* Nothing to be done, if there's no GROUP BY clause in the query. */
	if (!query->groupClause)
		return false;

	foreach(lc, query->groupClause)
	{
		SortGroupClause *grp = (SortGroupClause *) lfirst(lc);

		/* Check whether target entry is a grouping target or not */
		if (grp->tleSortGroupRef == tle->ressortgroupref)
		{
			return true;
		}
	}

	return false;
}

/*
 * influxdb_append_field_key
 * This function finds field key and the first found field key will be added into buf.
 */
void
influxdb_append_field_key(TupleDesc tupdesc, StringInfo buf, Index rtindex, PlannerInfo *root, bool first)
{
	int			i;

	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);
		RangeTblEntry *rte = planner_rt_fetch(rtindex, root);
		char	   *name = influxdb_get_column_name(rte->relid, i);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		/* Skip if column is time and tag key */
		if (!INFLUXDB_IS_TIME_COLUMN(name) && !influxdb_is_tag_key(name, rte->relid))
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			influxdb_deparse_column_ref(buf, rtindex, i, -1, root, false, false);
			return;
		}
	}
}

/*
 * influxdb_get_table_name
 * This function return name of table.
 */
char *
influxdb_get_table_name(Relation rel)
{
	ForeignTable *table;
	char	   *relname = NULL;
	ListCell   *lc = NULL;

	/* obtain additional catalog information. */
	table = GetForeignTable(RelationGetRelid(rel));

	/*
	 * Use value of FDW options if any, instead of the name of object itself.
	 */
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "table") == 0)
			relname = defGetString(def);
	}

	if (relname == NULL)
		relname = RelationGetRelationName(rel);

	return relname;
}

/*
 * influxdb_get_column_name
 * This function return name of column.
 */
char *
influxdb_get_column_name(Oid relid, int attnum)
{
	List	   *options = NULL;
	ListCell   *lc_opt;
	char	   *colname = NULL;

	options = GetForeignColumnOptions(relid, attnum);

	foreach(lc_opt, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc_opt);

		if (strcmp(def->defname, "column_name") == 0)
		{
			colname = defGetString(def);
			break;
		}
	}

	if (colname == NULL)
		colname = get_attname(relid, attnum
#if (PG_VERSION_NUM >= 110000)
							  ,
							  false
#endif
			);
	return colname;
}

/*
 * influxdb_is_tag_key
 * This function check whether column is tag key or not.
 * Return true if it is tag, otherwise return false.
 */
bool
influxdb_is_tag_key(const char *colname, Oid reloid)
{
	influxdb_opt *options;
	ListCell   *lc;

	/* Get FDW options */
	options = influxdb_get_options(reloid);

	/* If there is no tag in "tags" option, it means column is field */
	if (!options->tags_list)
		return false;

	/* Check whether column is tag or not */
	foreach(lc, options->tags_list)
	{
		char	   *name = (char *) lfirst(lc);

		if (strcmp(colname, name) == 0)
			return true;
	}

	return false;
}

/*****************************************************************************
 *		Check clauses for functions
 *****************************************************************************/

/*
 * influxdb_contain_functions
 *	  Recursively search for functions within a clause.
 *
 * Returns true if any function (or operator implemented by function) is found.
 *
 * We will recursively look into TargetEntry exprs.
 */
static bool
influxdb_contain_functions(Node *clause)
{
	return influxdb_contain_functions_walker(clause, NULL);
}

static bool
influxdb_contain_functions_walker(Node *node, void *context)
{
	if (node == NULL)
		return false;
	/* Check for functions in node itself */
	if (nodeTag(node) == T_FuncExpr)
	{
		return true;
	}

	/* Recurse to check arguments */
	if (IsA(node, Query))
	{
		/* Recurse into subselects */
		return query_tree_walker((Query *) node,
								 influxdb_contain_functions,
								 context, 0);
	}
	return expression_tree_walker(node, influxdb_contain_functions,
								  context);
}

/*
 * Returns true if given tlist is safe to evaluate on the foreign server.
 */
bool
influxdb_is_foreign_function_tlist(PlannerInfo *root,
								   RelOptInfo *baserel,
								   List *tlist)
{
	ListCell   *lc;
	bool		is_contain_function;
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;

	if (!(baserel->reloptkind == RELOPT_BASEREL ||
		  baserel->reloptkind == RELOPT_OTHER_MEMBER_REL))
		return false;

	/*
	 * Check that the expression consists of any immutable function.
	 */
	is_contain_function = false;
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (influxdb_contain_functions((Node *) tle->expr))
		{
			is_contain_function = true;
			break;
		}
	}

	if (!is_contain_function)
		return false;

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);
		InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) (baserel->fdw_private);

		/*
		 * Check that the expression consists of nodes that are safe to
		 * execute remotely.
		 */
		glob_cxt.root = root;
		glob_cxt.foreignrel = baserel;
		glob_cxt.relid = fpinfo->table->relid;
		glob_cxt.mixing_aggref_status = INFLUXDB_TARGETS_MIXING_AGGREF_SAFE;
		glob_cxt.for_tlist = true;
		glob_cxt.is_inner_func = false;

		/*
		 * For an upper relation, use relids from its underneath scan
		 * relation, because the upperrel's own relids currently aren't set to
		 * anything meaningful by the core code.  For other relation, use
		 * their own relids.
		 */
		if (baserel->reloptkind == RELOPT_UPPER_REL)
			glob_cxt.relids = fpinfo->outerrel->relids;
		else
			glob_cxt.relids = baserel->relids;
		loc_cxt.collation = InvalidOid;
		loc_cxt.state = FDW_COLLATE_NONE;
		loc_cxt.can_skip_cast = false;
		loc_cxt.can_pushdown_stable = false;
		loc_cxt.can_pushdown_volatile = false;
		loc_cxt.influx_fill_enable = false;
		if (!influxdb_foreign_expr_walker((Node *) tle->expr, &glob_cxt, &loc_cxt))
			return false;

		/*
		 * Do not push down when selecting multiple targets which contains
		 * star or regex functions
		 */
		if (list_length(tlist) > 1 && loc_cxt.can_pushdown_stable)
		{
			elog(WARNING, "Selecting multiple functions with regular expression or star. The query are not pushed down.");
			return false;
		}

		/*
		 * If the expression has a valid collation that does not arise from a
		 * foreign var, the expression can not be sent over.
		 */
		if (loc_cxt.state == FDW_COLLATE_UNSAFE)
			return false;

		/*
		 * An expression which includes any mutable functions can't be sent
		 * over because its result is not stable.  For example, sending now()
		 * remote side could cause confusion from clock offsets.  Future
		 * versions might be able to make this choice with more granularity.
		 * (We check this last because it requires a lot of expensive catalog
		 * lookups.)
		 */
		if (!IsA(tle->expr, FieldSelect))
		{
			if (!loc_cxt.can_pushdown_volatile)
			{
				if (loc_cxt.can_pushdown_stable)
				{
					if (contain_volatile_functions((Node *) tle->expr))
						return false;
				}
				else
				{
					if (contain_mutable_functions((Node *) tle->expr))
						return false;
				}
			}
		}
	}

	/* OK for the target list with functions to evaluate on the remote server */
	return true;
}

/* Check type of node whether it is string or not */
static bool
influxdb_is_string_type(Node *node)
{
	Oid			oidtype = 0;

	if (node == NULL)
		return false;

	if (IsA(node, Var))
	{
		Var		   *var = (Var *) node;

		oidtype = var->vartype;

	}
	else if (IsA(node, Const))
	{
		Const	   *c = (Const *) node;

		oidtype = c->consttype;
	}
	else
	{
		return expression_tree_walker(node, influxdb_is_string_type, NULL);
	}

	switch (oidtype)
	{
		case CHAROID:
		case VARCHAROID:
		case TEXTOID:
		case BPCHAROID:
		case NAMEOID:
			return true;
		default:
			return false;
	}
}

int
influxdb_get_number_field_key_match(Oid relid, char *regex)
{
	int			i = 0;
	int			nfields = 0;
	char	   *colname = NULL;
	regex_t		regex_cmp;

	/* Compile a regular expression */
	if (regex != NULL)
		if (regcomp(&regex_cmp, regex, 0) != 0)
			elog(ERROR, "Cannot initial regex");

	do
	{
		colname = get_attname(relid, ++i
#if (PG_VERSION_NUM >= 110000)
							  ,
							  true
#endif
			);

		if (colname != NULL &&
			!INFLUXDB_IS_TIME_COLUMN(colname) &&
			!influxdb_is_tag_key(colname, relid))
		{
			if (regex != NULL)
			{
				/* Check whether column name match regex or not */
				if (regexec(&regex_cmp, colname, 0, NULL, 0) == 0)
					nfields++;
			}
			else
			{
				nfields++;
			}
		}
	} while (colname != NULL);

	if (regex != NULL)
		regfree(&regex_cmp);

	return nfields;
}

int
influxdb_get_number_tag_key(Oid relid)
{
	int			i = 0;
	int			ntags = 0;
	char	   *colname = NULL;

	do
	{
		colname = get_attname(relid, ++i
#if (PG_VERSION_NUM >= 110000)
							  ,
							  true
#endif
			);

		if (colname != NULL &&
			!INFLUXDB_IS_TIME_COLUMN(colname) &&
			influxdb_is_tag_key(colname, relid))
		{
			ntags++;
		}
	} while (colname != NULL);

	return ntags;
}

/*
 * Return true if function name existed in list of function
 */
static bool
exist_in_function_list(char *funcname, const char **funclist)
{
	int			i;

	for (i = 0; funclist[i]; i++)
	{
		if (strcmp(funcname, funclist[i]) == 0)
			return true;
	}
	return false;
}
