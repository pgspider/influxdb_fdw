/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        slvars.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "nodes/nodeFuncs.h"
#include "parser/parse_oper.h"
#include "parser/parse_type.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"
#include "influxdb_fdw.h"


/*
 * Context for schemaless vars walker
 */
typedef struct pull_slvars_context
{
	Index				varno;
	schemaless_info		*pslinfo;
	List				*columns;
	bool                extract_raw;
	List                *remote_exprs;
} pull_slvars_context;

static bool influxdb_slvars_walker(Node *node, pull_slvars_context *context);
static bool influxdb_is_att_dropped(Oid relid, AttrNumber attnum);
static void influxdb_validate_foreign_table_sc(Oid reloid);

/*
 * influxdb_is_slvar: Check whether the node is schemaless type variable
 */
bool
influxdb_is_slvar(Oid oid, int attnum, schemaless_info *pslinfo, bool *is_tags, bool *is_fields)
{
	List	   *options;
	ListCell   *lc;
	bool	   tags_opt = false;
	bool	   fields_opt = false;

	if (!pslinfo->schemaless)
		return false;

	/*
	 * If it's a column of a foreign table, and it has the column_name FDW
	 * option, use that value.
	 */
	options = GetForeignColumnOptions(pslinfo->relid, attnum);
	foreach(lc, options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "tags") == 0)
		{
			tags_opt = defGetBoolean(def);
			break;
		}
		else if (strcmp(def->defname, "fields") == 0)
		{
			fields_opt = defGetBoolean(def);
			break;
		}
	}

	if (is_tags)
		*is_tags = tags_opt;
	if (is_fields)
		*is_fields = fields_opt;

	if ((oid == pslinfo->slcol_type_oid) &&
		(tags_opt || fields_opt))
		return true;

	return false;
}

/*
 * influxdb_is_slvar_fetch: Check whether the node is fetch of schemaless type variable
 */
bool
influxdb_is_slvar_fetch(Node *node, schemaless_info *pslinfo)
{
	OpExpr *oe = (OpExpr *)node;
	Node *arg1;
	Node *arg2;

	if (!pslinfo->schemaless)
		return false;

	if (IsA(node, CoerceViaIO))
	{
		node = (Node *) (((CoerceViaIO *)node)->arg);
		oe = (OpExpr *)node;
	}

	if (!IsA(node, OpExpr))
		return false;
	if (oe->opno != pslinfo->jsonb_op_oid)
		return false;
	if (list_length(oe->args) != 2)
		return false;

	arg1 = (Node *)linitial(oe->args);
	arg2 = (Node *)lsecond(oe->args);
	if (!IsA(arg1, Var) || !IsA(arg2, Const))
		return false;
	if (!influxdb_is_slvar(((Var *)arg1)->vartype, ((Var *)arg1)->varattno, pslinfo, NULL, NULL))
		return false;
	return true;
}

/*
 * influxdb_is_param_fetch: Check whether the node is fetch of schemaless type param
 */
bool
influxdb_is_param_fetch(Node *node, schemaless_info *pslinfo)
{
	OpExpr *oe = (OpExpr *)node;
	Node *arg1;
	Node *arg2;

	if (!pslinfo->schemaless)
		return false;

	if (!IsA(node, OpExpr))
		return false;
	if (oe->opno != pslinfo->jsonb_op_oid)
		return false;
	if (list_length(oe->args) != 2)
		return false;

	arg1 = (Node *)linitial(oe->args);
	arg2 = (Node *)lsecond(oe->args);
	if (!IsA(arg1, Param) || !IsA(arg2, Const))
		return false;
	return true;
}

/*
 * influxdb_get_slvar: Extract remote column name
 */
char *
influxdb_get_slvar(Expr *node, schemaless_info *pslinfo)
{
	if (!pslinfo->schemaless)
		return NULL;

	if (influxdb_is_slvar_fetch((Node *)node, pslinfo))
	{
		OpExpr *oe;
		Const *cnst;

		if (IsA(node, CoerceViaIO))
			node = (Expr *) (((CoerceViaIO *)node)->arg);

		oe = (OpExpr *)node;
		cnst = lsecond_node(Const, oe->args);

		return TextDatumGetCString(cnst->constvalue);
	}

	return NULL;
}

/*
 * influxdb_get_schemaless_info: Get information required for schemaless processing
 */
void influxdb_get_schemaless_info(schemaless_info *pslinfo, bool schemaless, Oid reloid)
{
	pslinfo->schemaless = schemaless;
	if (schemaless)
	{
		/* cache influxdb_tags and influxdb_fields oids */
		if (pslinfo->slcol_type_oid == InvalidOid)
			pslinfo->slcol_type_oid = JSONBOID;
		if (pslinfo->jsonb_op_oid == InvalidOid)
			pslinfo->jsonb_op_oid = LookupOperName(NULL, list_make1(makeString("->>")),
													pslinfo->slcol_type_oid, TEXTOID, true, -1);

		/* validate format of the foreign table */
		influxdb_validate_foreign_table_sc(reloid);

		pslinfo->relid = reloid;
	}
}

/*
 * influxdb_slvars_walker: Recursive function for extracting remote columns name
 */
static bool
influxdb_slvars_walker(Node *node, pull_slvars_context *context)
{
	if (node == NULL)
		return false;

	if (influxdb_is_slvar_fetch(node, context->pslinfo))
	{
		if (IsA(node, CoerceViaIO))
			node = (Node *)(((CoerceViaIO *)node)->arg);

		if (context->extract_raw)
		{
			ListCell *temp;
			foreach (temp, context->columns)
			{
				if (equal(lfirst(temp), node))
				{
					OpExpr *oe1 = (OpExpr *)lfirst(temp);
					OpExpr *oe2 = (OpExpr *)node;
					if (oe1->location == oe2->location)
						return false;
				}
			}
			foreach (temp, context->remote_exprs)
			{
				if (equal(lfirst(temp), node))
				{
					OpExpr *oe1 = (OpExpr *)lfirst(temp);
					OpExpr *oe2 = (OpExpr *)node;
					if (oe1->location == oe2->location)
						return false;
				}
			}
			context->columns = lappend(context->columns, node);
		}
		else
		{
			OpExpr *oe = (OpExpr *)node;
			Var *var = linitial_node(Var, oe->args);
			Const *cnst = lsecond_node(Const, oe->args);

			if (var->varno == context->varno && var->varlevelsup == 0)
			{
				ListCell *temp;
				char *const_str = TextDatumGetCString(cnst->constvalue);

				foreach (temp, context->columns)
				{
					char *colname = strVal(lfirst(temp));
					Assert(colname != NULL);

					if (strcmp(colname, const_str) == 0)
					{
						return false;
					}
				}
				context->columns = lappend(context->columns, makeString(const_str));
			}
		}
	}

	/* Should not find an unplanned subquery */
	Assert(!IsA(node, Query));

	return expression_tree_walker(node, influxdb_slvars_walker,
								  (void *) context);
}

/*
 * influxdb_pull_slvars: Pull remote columns name
 */
List *
influxdb_pull_slvars(Expr *expr, Index varno, List *columns, bool extract_raw, List *remote_exprs, schemaless_info *pslinfo)
{
	pull_slvars_context context;

	memset(&context, 0, sizeof(pull_slvars_context));

	context.varno = varno;
	context.columns = columns;
	context.pslinfo = pslinfo;
	context.extract_raw = extract_raw;
	context.remote_exprs = remote_exprs;

	(void) influxdb_slvars_walker((Node *)expr, &context);

	return context.columns;
}


/*
 * influxdb_is_att_dropped: Check if an attribute is dropped or not
 *
 * Return true if the attribute is dropped. Otherwise, return false.
 */
static bool
influxdb_is_att_dropped(Oid relid, AttrNumber attnum)
{
	HeapTuple	tp;

	tp = SearchSysCache2(ATTNUM,
						 ObjectIdGetDatum(relid), Int16GetDatum(attnum));
	if (HeapTupleIsValid(tp))
	{
		Form_pg_attribute att_tup = (Form_pg_attribute) GETSTRUCT(tp);

		bool result = att_tup->attisdropped;

		ReleaseSysCache(tp);
		return result;
	}

	return false;
}

/*
 * influxdb_validate_foreign_table_sc: Validate format of the foreign table in schemaless mode
 *
 * The foreign table may has 04 columns:
 *    (time timestamp with time zone, time_text text, tags jsonb OPTIONS (tags 'true'), fields jsonb OPTIONS (fields 'true'))
 *
 * In which:
 *    The foreign table may have dropped columns.
 *    time column: data type can be either timestamp or timestamp with timze zone
 *    time_text column: data type is text, value of time column is presented as text
 *    tags and fields: data type is jsonb, they must have option to specify they are tags or fields.
 */
static void
influxdb_validate_foreign_table_sc(Oid reloid)
{
	int	    attnum = 1;		/* column index start from 1 */

	/* Validate until all columns are counted */
	while (true)
	{
		char *attname = get_attname(reloid, attnum, true);
		Oid atttype = get_atttype(reloid, attnum);
		bool att_is_dropped = influxdb_is_att_dropped(reloid, attnum);

		/* Skip if the attribute is dropped */
		if (att_is_dropped)
		{
			attnum++;
			continue;
		}

		/* there is no more columns to check */
		if (attname == NULL || atttype == InvalidOid)
			break;

		/* time column */
		if (strcmp(attname, "time") == 0)
		{
			/* check data type */
			if (atttype != TIMESTAMPOID &&
				atttype != TIMESTAMPTZOID)
			{
				elog(ERROR, "influxdb fdw: invalid data type for time column");
			}
		}
		else if (strcmp(attname, "time_text") == 0) /* time_text column */
		{
			/* check data type */
			if (atttype != TEXTOID)
			{
				elog(ERROR, "influxdb fdw: invalid data type for time_text column");
			}
		}
		else if (strcmp(attname, "tags") == 0 || strcmp(attname, "fields") == 0) /* tags/fields column */
		{
			List *options = NIL;

			/* check data type */
			if (atttype != JSONBOID)
				elog(ERROR, "influxdb fdw: invalid data type for tags/fields column");

			/* check option name */
			options = GetForeignColumnOptions(reloid, attnum);
			if (options != NIL)
			{
				DefElem *def = (DefElem *)linitial(options);

				/* Validate option value only because influxdb_fdw_validator() already validated column option */
				if (defGetBoolean(def) != true)
					elog(ERROR, "influxdb fdw: invalid option value for tags/fields column");

			}
		}
		else /* Other columns */
		{
			/* In case using different names for time and time_text, they must have column_name option and the option value is 'time' */
			if (atttype == TIMESTAMPOID ||
				atttype == TIMESTAMPTZOID ||
				atttype == TEXTOID)
			{
				List *options = GetForeignColumnOptions(reloid, attnum);

				if (options != NIL)
				{
					DefElem *def = (DefElem *)linitial(options);

					if (strcmp(defGetString(def), "time") != 0)
						elog(ERROR, "influxdb fdw: invalid option value for time/time_text column");
				}
				else
					elog(ERROR, "influxdb fdw: invalid column name of time/time_text in schemaless mode");
			}
			else if (atttype == JSONBOID)
			{
				List *options = GetForeignColumnOptions(reloid, attnum);

				if (options != NIL)
				{
					DefElem *def = (DefElem *)linitial(options);

					if (defGetBoolean(def) != true)
						elog(ERROR, "influxdb fdw: invalid option value for tags/fields column");
				}
				else
					elog(ERROR, "influxdb fdw: invalid column name of tags/fields in schemaless mode");

			}
			else /*Other cases*/
				elog(ERROR, "influxdb fdw: invalid column in schemaless mode. Only time, time_text, tags and fields columns are accepted.");
		}

		attnum++;
	}
}
