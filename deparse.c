/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2020, TOSHIBA CORPORATION
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
#define QUOTE '"'

static char *influxdb_quote_identifier(const char *s, char q);
static bool influxdb_contain_immutable_functions_walker(Node *node, void *context);

/*
 * Global context for foreign_expr_walker's search of an expression tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	Relids		relids;			/* relids of base relations in the underlying
								 * scan */
	Oid			relid;			/* relation oid */
	unsigned int mixing_aggref_status; /* mixing_aggref_status contains information about whether expression
										* includes both of aggregate and non-aggregate.
										*/
	bool		for_tlist;		/* whether evaluation for the expression of tlist */
	bool		is_inner_func;  /* exist or not in inner exprs */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for foreign_expr_walker's search.
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
	bool        can_skip_cast;  /* outer function can skip float8/numeric cast */
} foreign_loc_cxt;

/*
 * Context for deparseExpr
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
	bool        is_tlist;       /* deparse during target list exprs */
	bool        can_skip_cast;  /* outer function can skip float8/numeric cast */
} deparse_expr_cxt;

/*
 * Functions to determine whether an expression can be evaluated safely on
 * remote server.
 */
static bool foreign_expr_walker(Node *node,
								foreign_glob_cxt *glob_cxt,
								foreign_loc_cxt *outer_cxt);

/*
 * Functions to construct string representation of a node tree.
 */
static void deparseExpr(Expr *expr, deparse_expr_cxt *context);
static bool influxdb_deparse_var(Var *node, deparse_expr_cxt *context);
static void influxdb_deparse_const(Const *node, deparse_expr_cxt *context, int showtype);
static void influxdb_deparse_param(Param *node, deparse_expr_cxt *context);
static void influxdb_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context);
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
static void influxdb_deparse_column_ref(StringInfo buf, int varno, int varattno, Oid vartype, PlannerInfo *root, bool convert);
static char *influxdb_get_column_ref(StringInfo buf, int varno, int varattno, Oid vartype,
									 PlannerInfo *root);
static void influxdb_deparse_select(List *tlist, List **retrieved_attrs, deparse_expr_cxt *context);
static void deparseFromExprForRel(StringInfo buf, PlannerInfo *root,
								  RelOptInfo *foreignrel,
								  bool use_alias, List **params_list);
static void deparseFromExpr(List *quals, deparse_expr_cxt *context);
static void deparseAggref(Aggref *node, deparse_expr_cxt *context);
static void appendConditions(List *exprs, deparse_expr_cxt *context);
static void appendGroupByClause(List *tlist, deparse_expr_cxt *context);

static void appendOrderByClause(List *pathkeys, deparse_expr_cxt *context);
static Node *deparseSortGroupClause(Index ref, List *tlist,
									deparse_expr_cxt *context);
static void deparseExplicitTargetList(List *tlist, List **retrieved_attrs,
									  deparse_expr_cxt *context);
static Expr *find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel);
static bool is_builtin(Oid objectId);
static bool is_contain_time_column(List *tlist);
static bool is_grouping_target(TargetEntry *tle, deparse_expr_cxt *context);
static void influxdb_append_field_key(TupleDesc tupdesc, StringInfo buf, Index rtindex, PlannerInfo *root, bool first);

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
	ForeignTable *table;
	const char *relname = NULL;
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
	if (!foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
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
foreign_expr_walker(Node *node,
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
	static bool is_time_column = false;     /* Use static variable for save value 
	                                         * from child node to parent node.
	                                         * Check column T_Var is time column? */

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;
	inner_cxt.can_skip_cast = false;

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

		case T_FuncExpr:
			{

				FuncExpr	*fe = (FuncExpr *) node;
				char		*opername = NULL;
				bool		is_cast_func = false;

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
				if (strcmp(opername, "now") != 0 &&
					strcmp(opername, "sqrt") != 0 &&
					strcmp(opername, "log") != 0 &&
					strcmp(opername, "log2") != 0 &&
					strcmp(opername, "abs") != 0 &&
					strcmp(opername, "cumulative_sum") != 0 &&
					strcmp(opername, "derivative") != 0 &&
					strcmp(opername, "non_negative_derivative") != 0 &&
					strcmp(opername, "difference") != 0 &&
					strcmp(opername, "non_negative_difference") != 0 &&
					strcmp(opername, "elapsed") != 0 &&
					strcmp(opername, "moving_average") != 0 &&
					strcmp(opername, "exponential_moving_average") != 0 &&
					strcmp(opername, "influx_time") != 0 &&
					is_cast_func != true)
				{
					return false;
				}

#if PG_VERSION_NUM < 100000
				if (strcmp(opername, "influx_time") == 0)
				{
					return false;
				}
#endif

				/* inner function can skip float/numeric cast if any */
				if (strcmp(opername, "sqrt") == 0 || strcmp(opername, "log") == 0)
					inner_cxt.can_skip_cast = true;

				/* Accept type cast functions if outer is specific functions */
				if (is_cast_func)
				{
					if (outer_cxt->can_skip_cast == false)
						return false;
				}

				if (!is_cast_func)
				{
					/*
					 * Nested function cannot be executed in non tlist
					 */
					if (!glob_cxt->for_tlist && glob_cxt->is_inner_func)
						return false;

					glob_cxt->is_inner_func = true;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) fe->args,
										 glob_cxt, &inner_cxt))
					return false;

				if (!is_cast_func)
					glob_cxt->is_inner_func = false;

				/*
				 * If function's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (fe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 fe->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
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
			break;
		case T_OpExpr:

			{
				OpExpr	   *oe = (OpExpr *) node;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!is_builtin(oe->opno))
					return false;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				/* opname is not a SQL identifier, so we should not quote it. */
				cur_opname = NameStr(form->oprname);

				/* ILIKE cannot be pushed down to InfluxDB */
				if (strcmp(cur_opname, "~~*") == 0 || strcmp(cur_opname, "!~~*") == 0)
				{
					ReleaseSysCache(tuple);
					return false;
				}

				/*
				 * Cannot pushdown to InfluxDB if there is string comparison with:
				 * "<, >, <=, >=" operators
				 */
				if (strcmp(cur_opname, "<") == 0
					|| strcmp(cur_opname, ">") == 0
					|| strcmp(cur_opname, "<=") == 0
					|| strcmp(cur_opname, ">=") == 0)
				{
					Expr *expr;
					ListCell *lc;
					Const *c;

					/*
					 * Check String type for the operand which is Const
					 * We do not specific any target OID for string type of constant.
					 * The implementation is based on implementation of influxdb_deparse_const()
					 * where default phrase deparses string value of constant.
					 */
					foreach(lc, oe->args)
					{
						expr = lfirst(lc);
						if (!IsA(expr, Const))
							continue;

						c = (Const *)expr;
						switch (c->consttype)
						{
							case INT2OID:
							case INT4OID:
							case INT8OID:
							case OIDOID:
							case FLOAT4OID:
							case FLOAT8OID:
							case NUMERICOID:
							case BITOID:
							case VARBITOID:
							case BOOLOID:
							case BYTEAOID:
							case TIMESTAMPTZOID:
							case INTERVALOID:
								break;
							default:
								{
									/* A Const expression has string type here */
									ReleaseSysCache(tuple);
									return false;
								}
						}
						break;
					}
				}

				/*
				 * Cannot pushdown to InfluxDB if compare time column with "!=, <>" operators
				 */
				if (strcmp(cur_opname, "!=") == 0 || strcmp(cur_opname, "<>") == 0)
				{
					if (is_contain_time_column(oe->args))
					{
						ReleaseSysCache(tuple);
						return false;
					}
				}

				ReleaseSysCache(tuple);

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * Mixing aggregate and non-aggregate error occurs when SELECT statement
				 * includes both of aggregate function and standalone field key or tag key.
				 * It is unsafe to pushdown if target operation expression has mixing aggregate
				 * and non-aggregate, such as: (1+col1+sum(col2)), (sum(col1)*col2)
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

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!is_builtin(oe->opno))
					return false;

				/*
				 * InfluxDB do not support OR with multi time column or time column with !=, <>
				 * --> Not pushdown time column
				 */
				if (is_contain_time_column(oe->args))
				{
					return false;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
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
				if (!foreign_expr_walker((Node *) r->arg,
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
					/* InfluxDB do not support not operator */
					return false;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) b->args,
										 glob_cxt, &inner_cxt))
					return false;

				/* Influx do not support OR with condition contain time column */
				if (b->boolop == OR_EXPR && is_time_column){
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

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!foreign_expr_walker((Node *) lfirst(lc),
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
				Aggref		*agg = (Aggref *) node;
				ListCell	*lc;
				FuncExpr	*func = (FuncExpr *) node;
				char		*opername = NULL;
				bool		old_val;
				int			index_const = -1;
				int			index;

				/* get function name and schema */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(agg->aggfnoid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", func->funcid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				ReleaseSysCache(tuple);

				/* these function can be passed to InfluxDB */
				if (!(strcmp(opername, "sum") == 0
					  || strcmp(opername, "max") == 0
					  || strcmp(opername, "min") == 0
					  || strcmp(opername, "count") == 0
					  || strcmp(opername, "spread") == 0
					  || strcmp(opername, "sample") == 0
					  || strcmp(opername, "first") == 0
					  || strcmp(opername, "last") == 0))
				{
					return false;
				}

				/* Some aggregate influxdb functions have a const argument. */
				if (strcmp(opername, "sample") == 0)
					index_const = 1;

				/*
				 * Only sum(), count() and spread() are aggregate functions,
				 * max(), min() and last() are selector functions
				 */
				if (strcmp(opername, "sum") == 0
					|| strcmp(opername, "spread") == 0
					|| strcmp(opername, "count") == 0)
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
				 * Save value of is_time_column before we check time argument aggregate.
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
							/* arguments checking is OK*/ ;
						else
							return false;
					}

					/* Check if arg is Var */
					if (IsA(n, Var))
					{
						Var		*var = (Var *) n;
						char	*colname = influxdb_get_column_name(glob_cxt->relid, var->varattno);

						/* Not push down if arg is tag key */
						if (influxdb_is_tag_key(colname, glob_cxt->relid))
							return false;

						/* Not push down max(), min() if arg type is text column */
						if ((strcmp(opername, "max") == 0 || strcmp(opername, "min") == 0)
							 && var->vartype == TEXTOID)
							return false;
					}

					if (!foreign_expr_walker(n, glob_cxt, &inner_cxt))
						return false;

					/*
					 * Does not pushdown time column argument within aggregate function
					 * except time related functions, because these functions are converted from
					 * func(time, value) to func(value) when deparsing.
					 */
					if (is_time_column && !(strcmp(opername, "last") == 0 || strcmp(opername, "first") == 0))
					{
						is_time_column = false;
						return false;
					}
				}

				/*
				 * If there is no time column argument within aggregate function,
				 * restore value of is_time_column.
				 */
				is_time_column = old_val;

				if (agg->aggorder || agg->aggfilter)
				{
					return false;
				}

				/* influxdb_fdw only supports push-down DISTINCT within aggregate for count() */
				if (agg->aggdistinct && (strcmp(opername, "count") != 0))
					return false;

				/*
				 * If aggregate's input collation is not derived from a
				 * foreign Var, it can't be sent to remote.
				 */
				if (agg->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 agg->inputcollid != inner_cxt.collation)
					return false;

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
	if (check_type && !is_builtin(exprType(node)))
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
influxdbDeparseSelectStmtForRel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
								List *tlist, List *remote_conds, List *pathkeys,
								bool is_subquery, List **retrieved_attrs,
								List **params_list)
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
	deparseFromExpr(quals, &context);

	if (rel->reloptkind == RELOPT_UPPER_REL)
	{
		/* Append GROUP BY clause */
		appendGroupByClause(tlist, &context);

		/* Append HAVING clause */
		if (remote_conds)
		{
			appendStringInfo(buf, " HAVING ");
			appendConditions(remote_conds, &context);
		}
	}

	/* Add ORDER BY clause if we found any useful pathkeys */
	if (pathkeys)
		appendOrderByClause(pathkeys, &context);
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
 * Deparese SELECT statment
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
		deparseExplicitTargetList(tlist, retrieved_attrs, context);
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
deparseFromExpr(List *quals, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *scanrel = context->scanrel;

	/* For upper relations, scanrel must be either a joinrel or a baserel */
	Assert(context->foreignrel->reloptkind != RELOPT_UPPER_REL ||
		   scanrel->reloptkind == RELOPT_JOINREL ||
		   scanrel->reloptkind == RELOPT_BASEREL);

	/* Construct FROM clause */
	appendStringInfoString(buf, " FROM ");
	deparseFromExprForRel(buf, context->root, scanrel,
						  (bms_num_members(scanrel->relids) > 1),
						  context->params_list);

	/* Construct WHERE clause */
	if (quals != NIL)
	{
		appendStringInfo(buf, " WHERE ");
		appendConditions(quals, context);
	}
}

/*
 * Deparse conditions from the provided list and append them to buf.
 *
 * The conditions in the list are assumed to be ANDed. This function is used to
 * deparse WHERE clauses, JOIN .. ON clauses and HAVING clauses.
 */
static void
appendConditions(List *exprs, deparse_expr_cxt *context)
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
		deparseExpr(expr, context);
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
deparseExplicitTargetList(List *tlist, List **retrieved_attrs,
						  deparse_expr_cxt *context)
{
	ListCell   *lc;
	StringInfo	buf = context->buf;
	int			i = 0;
	bool        first = true;
	bool		is_col_grouping_target = false;
	bool		need_field_key;
	bool		is_need_comma = false;
	InfluxDBFdwRelationInfo *fpinfo = (InfluxDBFdwRelationInfo *) context->foreignrel->fdw_private;

	*retrieved_attrs = NIL;
	/*
	 * We do not construct grouping target column in SELECT influxdb SQL.
	 * We just check for need to add field key more
	 * e.g. SELECT col1, col2, col3 FROM table GROUP BY col1, col2; (col1 and col2 are tag keys)
	 * --> SELECT col3 FROM table GROUP BY col1, col2;
	 * So, firstly we need to check whether all target are columns or not.
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
			is_col_grouping_target = is_grouping_target(tle, context);
		}

		if (IsA((Expr *) tle->expr, Aggref)
			|| IsA((Expr *) tle->expr, OpExpr)
			|| IsA((Expr *) tle->expr, FuncExpr)
			|| (IsA((Expr *) tle->expr, Var) && !is_col_grouping_target))
		{
			bool is_skip_expr = false;

			if (IsA((Expr *) tle->expr, FuncExpr))
			{
				FuncExpr *fe = (FuncExpr *) tle->expr;
				StringInfo func_name = makeStringInfo();
				get_proname(fe->funcid, func_name);
				if (strcmp(func_name->data, "influx_time") == 0)
					is_skip_expr = true;
			}

			if (is_need_comma && !is_skip_expr)
				appendStringInfoString(buf, ", ");
			need_field_key = false;

			if (!is_skip_expr)
			{
				first = false;
				deparseExpr((Expr *) tle->expr, context);
				is_need_comma = true;
			}
		}

		/*
		 * Check all target columns are tag keys or not.
		 * If all target columns are tag keys, need to append a field key more.
		 */
		if (IsA((Expr *) tle->expr, Var) && need_field_key)
		{
			RangeTblEntry	*rte = planner_rt_fetch(context->scanrel->relid, context->root);
			char			*colname = influxdb_get_column_name(rte->relid, ((Var *) tle->expr)->varattno);

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
deparseFromExprForRel(StringInfo buf, PlannerInfo *root, RelOptInfo *foreignrel,
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
	bool		need_field_key;	/* Check for need to add field key more */

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
			char			*name = influxdb_get_column_ref(buf, rtindex, i, -1, root);
			RangeTblEntry	*rte = planner_rt_fetch(rtindex, root);

			/* Skip if column is time */
			if (!INFLUXDB_IS_TIME_COLUMN(name))
			{
				if (!influxdb_is_tag_key(name, rte->relid))
					need_field_key = false;

				if (!first)
					appendStringInfoString(buf, ", ");
				first = false;
				influxdb_deparse_column_ref(buf, rtindex, i, -1, root, false);
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
		deparseExpr(ri->clause, &context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}
}

static char *
influxdb_get_column_ref(StringInfo buf, int varno, int varattno, Oid vartype,
						PlannerInfo *root)
{
	RangeTblEntry *rte;
	char	   *colname = NULL;
	List	   *options;
	ListCell   *lc;

	/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
	Assert(!IS_SPECIAL_VARNO(varno));

	/* Get RangeTblEntry from array in PlannerInfo. */
	rte = planner_rt_fetch(varno, root);

	/*
	 * If it's a column of a foreign table, and it has the column_name FDW
	 * option, use that value.
	 */
	options = GetForeignColumnOptions(rte->relid, varattno);
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "column_name") == 0)
		{
			colname = defGetString(def);
			break;
		}
	}

	/*
	 * If it's a column of a regular table or it doesn't have column_name FDW
	 * option, use attribute name.
	 */
	if (colname == NULL)
		colname = get_attname(rte->relid, varattno
#if (PG_VERSION_NUM >= 110000)
							  ,
							  false
#endif
			);
	return colname;
}

/*
 * Construct name to use for given column, and emit it into buf.
 * If it has a column_name FDW option, use that instead of attribute name.
 */
static void
influxdb_deparse_column_ref(StringInfo buf, int varno, int varattno, Oid vartype,
							PlannerInfo *root, bool convert)
{
	RangeTblEntry *rte;
	char	   *colname = NULL;
	List	   *options;
	ListCell   *lc;

	/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
	Assert(!IS_SPECIAL_VARNO(varno));

	/* Get RangeTblEntry from array in PlannerInfo. */
	rte = planner_rt_fetch(varno, root);

	/*
	 * If it's a column of a foreign table, and it has the column_name FDW
	 * option, use that value.
	 */
	options = GetForeignColumnOptions(rte->relid, varattno);
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "column_name") == 0)
		{
			colname = defGetString(def);
			break;
		}
	}

	/*
	 * If it's a column of a regular table or it doesn't have column_name FDW
	 * option, use attribute name.
	 */
	if (colname == NULL)
		colname = get_attname(rte->relid, varattno
#if (PG_VERSION_NUM >= 110000)
							  ,
							  false
#endif
			);
	if (convert && vartype == BOOLOID)
	{
		appendStringInfo(buf, "(%s=true)", influxdb_quote_identifier(colname, QUOTE));
	}
	else
	{
		if (strcmp(colname, "time") == 0)
			appendStringInfoString(buf, colname);
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
	const char	*regex_special = "\\^$.|?*+()[{";
	const char	*ptr = val;

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
				 * escaped by backslash and will be escapsed if it is a regex special character.
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
					char	ch = *ptr;

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
 * This function must support all the same node types that foreign_expr_walker
 * accepts.
 *
 * Note: unlike ruleutils.c, we just use a simple hard-wired parenthesization
 * scheme: anything more complex than a Var, Const, function call or cast
 * should be self-parenthesized.
 */
static void
deparseExpr(Expr *node, deparse_expr_cxt *context)
{
	bool outer_can_skip_cast = context->can_skip_cast;

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
			deparseAggref((Aggref *) node, context);
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
static bool
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
		bool convert = true;

		/* Var with BOOLOID type should be deparsed without conversion in target list. */
		if (context->is_tlist && fpinfo->is_tlist_func_pushdown)
			convert = false;

		/* Var belongs to foreign table */
		influxdb_deparse_column_ref(buf, node->varno, node->varattno, node->vartype, context->root, convert);
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
	return true;
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
			if (context->require_regex)
			{
				/*
				 * Convert LIKE's pattern on PostgreSQL to regex pattern on InfluxDB.
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
 * influxdb differ, so return the influxdb equelent function name
 */
static char *
influxdb_replace_function(char *in)
{
	if (strcmp(in, "btrim") == 0)
	{
		return "trim";
	}
	return in;
}

/*
 * Deparse a function call.
 */
static void
influxdb_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;
	bool		first;
	ListCell   *arg;
	bool        arg_swap = false;
	bool        can_skip_cast = false;
	List       *args;

	/*
	 * Normal function: display as proname(args).
	 */
	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(node->funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", node->funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/*
	 * convert influx_time(time, interval '2h') to time(2h) and
	 * influx_time(time, interval '2h', interval '1h') to time(2h, 1h)
	 */
	if (strcmp(NameStr(procform->proname), "influx_time") == 0)
	{
		int			idx = 0;

		Assert(list_length(node->args) == 2 || list_length(node->args) == 3);

		if (context->is_tlist)
		{
			ReleaseSysCache(proctup);
			return;
		}

		appendStringInfo(buf, "time(");
		first = true;
		foreach(arg, node->args)
		{
			if (idx == 0)
			{
				/* Skip first parameter */
				idx++;
				continue;
			}
			if (idx >= 2)
				appendStringInfoString(buf, ", ");

			deparseExpr((Expr *) lfirst(arg), context);
			idx++;
		}
		appendStringInfoChar(buf, ')');
		ReleaseSysCache(proctup);
		return;
	}

	/* remove cast function if parent function is can handle without cast */
	if (context->can_skip_cast == true &&
		(strcmp(NameStr(procform->proname), "float8") == 0 || strcmp(NameStr(procform->proname), "numeric") == 0))
	{
		ReleaseSysCache(proctup);
		arg = list_head(node->args);
		context->can_skip_cast = false;
		deparseExpr((Expr *) lfirst(arg), context);
		return;
	}
	
	if (strcmp(NameStr(procform->proname), "log") == 0)
	{
		arg_swap = true;
	}

	/* inner function can skip cast if any */
	if (strcmp(NameStr(procform->proname), "sqrt") == 0 || strcmp(NameStr(procform->proname), "log") == 0)
		can_skip_cast = true;

	/* Translate PostgreSQL function into influxdb function */
	proname = influxdb_replace_function(NameStr(procform->proname));

	/* Deparse the function name ... */
	appendStringInfo(buf, "%s(", proname);

	ReleaseSysCache(proctup);

	/* swap arguments */
	args = node->args;
	if (arg_swap && list_length(args) == 2)
	{
		args = list_make2(lfirst(list_tail(args)), lfirst(list_head(args)));
	}

	/* ... and all the arguments */
	first = true;
	foreach(arg, args)
	{
		if (!first)
			appendStringInfoString(buf, ", ");

		if (can_skip_cast)
			context->can_skip_cast = true;
		deparseExpr((Expr *) lfirst(arg), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse given operator expression.   To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
influxdb_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Form_pg_operator form;
	char		oprkind;
	ListCell   *arg;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
	Assert((oprkind == 'r' && list_length(node->args) == 1) ||
		   (oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/* Deparse left operand. */
	if (oprkind == 'r' || oprkind == 'b')
	{
		arg = list_head(node->args);
		deparseExpr(lfirst(arg), context);
		appendStringInfoChar(buf, ' ');
	}

	/* Deparse operator name. */
	influxdb_deparse_operator_name(buf, form, &context->require_regex);

	/* Deparse right operand. */
	if (oprkind == 'l' || oprkind == 'b')
	{
		arg = list_tail(node->args);
		appendStringInfoChar(buf, ' ');
		deparseExpr(lfirst(arg), context);
	}

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
	char	   *opname;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;
	bool		notIn;
	Const	   *c;
	bool		isstr;
	const char *valptr;
	int			i = -1;
	bool		deparseLeft;
	bool		inString;
	bool		isEscape;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	opname = NameStr(form->oprname);

	notIn = false;
	if (strcmp(opname, "<>") == 0)
		notIn = true;

	arg2 = lsecond(node->args);
	c = (Const *) arg2;
	Assert(nodeTag((Node *) arg2) == T_Const || c->constisnull);

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
	deparseLeft = true;
	inString = false;
	isEscape = false;

	for (valptr = extval; *valptr; valptr++)
	{
		char		ch = *valptr;

		i++;

		/* Deparse left operand. */
		if (deparseLeft)
		{
			arg1 = linitial(node->args);
			if (c->consttype == BOOLARRAYOID)
			{
				if (arg1 != NULL && IsA(arg1, Var))
				{
					Var *var = (Var*) arg1;
					/* Deparse bool column with convert argument is false */
					influxdb_deparse_column_ref(buf, var->varno, var->varattno, var->vartype, context->root, false);
				}
			}
			else{
				deparseExpr(arg1, context);
			}
			if (notIn)
				appendStringInfo(buf, " <> ");
			else
				appendStringInfo(buf, " = ");
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

		/* Remove character '\\' and process the next character. */
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
			if (notIn)
				appendStringInfo(buf, "  AND ");
			else
				appendStringInfo(buf, "  OR ");
			deparseLeft = true;
			continue;
		}

		/* Influx only support "= true" or "= false" (not "= 't'"" or "= 'f'") */
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
	ReleaseSysCache(tuple);
}

/*
 * Deparse a RelabelType (binary-compatible cast) node.
 */
static void
influxdb_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context)
{
	deparseExpr(node->arg, context);
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
			deparseExpr(linitial(node->args), context);
			appendStringInfoChar(buf, ')');
			return;
	}

	appendStringInfoChar(buf, '(');
	first = true;
	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfo(buf, " %s ", op);
		deparseExpr((Expr *) lfirst(lc), context);
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
	deparseExpr(node->arg, context);
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
		deparseExpr(lfirst(lc), context);
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
static bool
is_builtin(Oid oid)
{
	return (oid < FirstBootstrapObjectId);
}

/*
 * Deparse an Aggref node.
 */
static void
deparseAggref(Aggref *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		use_variadic;
	char	   *func_name;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->aggvariadic;

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	func_name = influxdb_get_function_name(node->aggfnoid);

	if (strcmp(func_name, "last") == 0 || strcmp(func_name, "first") == 0)
	{
		/* Convert func(time, value) to func(value) */
		Assert(list_length(node->args) == 2);
		appendStringInfo(buf, "%s(", func_name);
		deparseExpr((Expr *) (((TargetEntry *) list_nth(node->args, 1))->expr), context);
		appendStringInfoChar(buf, ')');
		return;
	}

	appendStringInfo(buf, "%s", quote_identifier(func_name));
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

		/* Add all the arguments */
		foreach(arg, node->args)
		{
			TargetEntry *tle = (TargetEntry *) lfirst(arg);
			Node	   *n = (Node *) tle->expr;

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

			deparseExpr((Expr *) n, context);
		}
	}

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse GROUP BY clause.
 */
static void
appendGroupByClause(List *tlist, deparse_expr_cxt *context)
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

	foreach(lc, query->groupClause)
	{
		SortGroupClause *grp = (SortGroupClause *) lfirst(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		deparseSortGroupClause(grp->tleSortGroupRef, tlist, context);
	}
}

/*
 * Find an equivalence class member expression, all of whose Vars, come from
 * the indicated relation.
 */
static Expr *
find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel)
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
appendOrderByClause(List *pathkeys, deparse_expr_cxt *context)
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

		em_expr = find_em_expr_for_rel(pathkey->pk_eclass, baserel);
		Assert(em_expr != NULL);

		appendStringInfoString(buf, delim);
		deparseExpr(em_expr, context);
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
 * appendFunctionName
 *		Deparses function name from given function oid.
 */
char *
influxdb_get_function_name(Oid funcid)
{

	HeapTuple	proctup;
	Form_pg_proc procform;
	char	   *proname;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);
	/* Always print the function name */
	proname = pstrdup(NameStr(procform->proname));
	ReleaseSysCache(proctup);
	return proname;
}

/*
 * Appends a sort or group clause.
 *
 * Like get_rule_sortgroupclause(), returns the expression tree, so caller
 * need not find it again.
 */
static Node *
deparseSortGroupClause(Index ref, List *tlist, deparse_expr_cxt *context)
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
		deparseExpr(expr, context);
	else
	{
		/* Always parenthesize the expression. */
		appendStringInfoString(buf, "(");
		deparseExpr(expr, context);
		appendStringInfoString(buf, ")");
	}

	return (Node *) expr;
}

/*
 * At least one element in the list is time column
 * is_contain_time_column function returns true.
 */
static bool
is_contain_time_column(List *tlist)
{
	Expr *expr;
	Var *var;
	ListCell *lc;

	/* Check Timestamp type for the operand which is Var */
	foreach(lc, tlist)
	{
		expr = (Expr *) lfirst(lc);
		if (!IsA(expr, Var))
			continue;

		var = (Var *)expr;
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
 * is_grouping_target
 * This function check whether given target entry is grouping target,
 * if so, return true, otherwise return false.
 */
bool is_grouping_target(TargetEntry *tle, deparse_expr_cxt *context)
{
	Query	   *query = context->root->parse;
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
void influxdb_append_field_key(TupleDesc tupdesc, StringInfo buf, Index rtindex, PlannerInfo *root, bool first)
{
	int		i;

	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute	attr = TupleDescAttr(tupdesc, i - 1);
		char				*name = influxdb_get_column_ref(buf, rtindex, i, -1, root);
		RangeTblEntry		*rte = planner_rt_fetch(rtindex, root);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		/* Skip if column is time and tag key */
		if (!INFLUXDB_IS_TIME_COLUMN(name) && !influxdb_is_tag_key(name, rte->relid))
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			influxdb_deparse_column_ref(buf, rtindex, i, -1, root, false);
			return;
		}
	}
}


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
bool influxdb_is_tag_key(const char *colname, Oid reloid)
{
	influxdb_opt	*options;
	ListCell		*lc;

	/* Get FDW options */
	options = influxdb_get_options(reloid);

	/* If there is no tag in "tags" option, it means column is field */
	if (!options->tags_list)
		return false;

	/* Check whether column is tag or not */
	foreach(lc, options->tags_list)
	{
		char *name = (char*)lfirst(lc);

		if (strcmp(colname, name) == 0)
			return true;
	}

	return false;
}

/*****************************************************************************
 *		Check clauses for immutable functions
 *****************************************************************************/

/*
 * contain_immutable_functions
 *	  Recursively search for immutable functions within a clause.
 *
 * Returns true if any immutable function (or operator implemented by a
 * immutable function) is found.
 *
 * We will recursively look into TargetEntry exprs.
 */
static bool
influxdb_contain_immutable_functions(Node *clause)
{
	return influxdb_contain_immutable_functions_walker(clause, NULL);
}

static bool
influxdb_contain_immutable_functions_walker(Node *node, void *context)
{
	if (node == NULL)
		return false;
	/* Check for mutable functions in node itself */
	if (nodeTag(node) == T_FuncExpr)
	{
		FuncExpr *expr = (FuncExpr *) node;
		if (func_volatile(expr->funcid) == PROVOLATILE_IMMUTABLE)
			return true;
	}

	/*
	 * It should be safe to treat MinMaxExpr as immutable, because it will
	 * depend on a non-cross-type btree comparison function, and those should
	 * always be immutable.  Treating XmlExpr as immutable is more dubious,
	 * and treating CoerceToDomain as immutable is outright dangerous.  But we
	 * have done so historically, and changing this would probably cause more
	 * problems than it would fix.  In practice, if you have a non-immutable
	 * domain constraint you are in for pain anyhow.
	 */

	/* Recurse to check arguments */
	if (IsA(node, Query))
	{
		/* Recurse into subselects */
		return query_tree_walker((Query *) node,
								 influxdb_contain_immutable_functions_walker,
								 context, 0);
	}
	return expression_tree_walker(node, influxdb_contain_immutable_functions_walker,
								  context);
}

/*
 * Returns true if given tlist is safe to evaluate on the foreign server.
 */
bool influxdb_is_foreign_function_tlist(PlannerInfo *root,
										RelOptInfo *baserel,
										List *tlist)
{
	ListCell        *lc;
	bool             is_contain_function;

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

		if (influxdb_contain_immutable_functions((Node *) tle->expr))
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

		if (!influxdb_is_foreign_expr(root, baserel, tle->expr, true))
			return false;

		/*
		 * An expression which includes any mutable functions can't be sent over
		 * because its result is not stable.  For example, sending now() remote
		 * side could cause confusion from clock offsets.  Future versions might
		 * be able to make this choice with more granularity.  (We check this last
		 * because it requires a lot of expensive catalog lookups.)
		 */
		if (contain_mutable_functions((Node *) tle->expr))
			return false;
	}

	/* OK for the target list with functions to evaluate on the remote server */
	return true;
}
