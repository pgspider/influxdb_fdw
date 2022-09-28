/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2018, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 * 		influxdb_query.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "influxdb_fdw.h"

#include <stdio.h>

#include "foreign/fdwapi.h"
#include "foreign/foreign.h"
#include "nodes/makefuncs.h"
#include "storage/ipc.h"
#include "utils/array.h"
#include "utils/builtins.h"
#include "utils/numeric.h"
#include "utils/date.h"
#include "utils/datetime.h"
#include "utils/hsearch.h"
#include "utils/syscache.h"
#include "utils/lsyscache.h"
#include "utils/rel.h"
#include "utils/timestamp.h"
#include "utils/formatting.h"
#include "utils/memutils.h"
#include "utils/guc.h"
#include "access/htup_details.h"
#include "access/sysattr.h"
#include "access/reloptions.h"
#include "commands/defrem.h"
#include "commands/explain.h"
#include "commands/vacuum.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "optimizer/cost.h"
#include "optimizer/paths.h"
#include "optimizer/prep.h"
#include "optimizer/restrictinfo.h"
#include "optimizer/cost.h"
#include "optimizer/pathnode.h"
#include "optimizer/plancat.h"
#include "optimizer/planmain.h"
#include "parser/parsetree.h"
#include "catalog/pg_type.h"
#include "funcapi.h"
#include "miscadmin.h"
#include "postmaster/syslogger.h"
#include "storage/fd.h"
#include "catalog/pg_type.h"

extern char *influxdb_replace_function(char *in);

/*
 * influxdb_convert_to_pg: Convert influxdb string data into PostgreSQL's compatible data types
 */
Datum
influxdb_convert_to_pg(Oid pgtyp, int pgtypmod, char *value)
{
	Datum		value_datum = 0;
	Datum		valueDatum = 0;
	regproc		typeinput;
	HeapTuple	tuple;
	int			typemod;

	/* get the type's output function */
	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(pgtyp));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for type%u", pgtyp);

	typeinput = ((Form_pg_type) GETSTRUCT(tuple))->typinput;
	typemod = ((Form_pg_type) GETSTRUCT(tuple))->typtypmod;
	ReleaseSysCache(tuple);
	valueDatum = CStringGetDatum(value);

	/* convert string value to appropriate type value */
	value_datum = OidFunctionCall3(typeinput, valueDatum, ObjectIdGetDatum(InvalidOid), Int32GetDatum(typemod));

	return value_datum;
}

/*
 * influxdb_convert_record_to_datum: Convert influxdb string data into PostgreSQL's compatible data types
 */
Datum
influxdb_convert_record_to_datum(Oid pgtyp, int pgtypmod, char **row, int attnum, int ntags, int nfield,
								 char **column, char *opername, Oid relid, int ncol, bool is_schemaless)
{
	Datum		value_datum = 0;
	Datum		valueDatum = 0;
	regproc		typeinput;
	HeapTuple	tuple;
	int			typemod;
	int			i;
	StringInfoData fields_jsstr;
	StringInfo	record = makeStringInfo();
	bool		first = true;
	bool		is_sc_agg_starregex = false;
	bool		need_enclose_brace = false;
	char	   *foreignColName = NULL;
	char	   *influxdbFuncName = influxdb_replace_function(opername);
	int			nmatch = 0;

	/* get the type's output function */
	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(pgtyp));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for type%u", pgtyp);

	typeinput = ((Form_pg_type) GETSTRUCT(tuple))->typinput;
	typemod = ((Form_pg_type) GETSTRUCT(tuple))->typtypmod;
	ReleaseSysCache(tuple);

	/* Build the fields json string value */
	if (is_schemaless)
		initStringInfo(&fields_jsstr);

	/* Append time column */
	appendStringInfo(record, "(%s,", row[0]);

	if (is_schemaless)
	{
		/*
		 * Dummy value for tags jsonb schemaless column,
		 * it is not number of actual tag keys.
		 */
		ntags = 1;
	}

	/* Append tags column as NULL */
	for (i = 0; i < ntags; i++)
		appendStringInfo(record, ",");

	/* Append fields column */
	i = 0;
	do
	{
		if (is_schemaless)
		{
			if (i < ncol)
				foreignColName = column[i];
			else
				foreignColName = NULL;
			i++;

			is_sc_agg_starregex = true;
		}
		else
		foreignColName = get_attname(relid, ++i
#if (PG_VERSION_NUM >= 110000)
									 ,
									 true
#endif
			);

		if (foreignColName != NULL &&
			!INFLUXDB_IS_TIME_COLUMN(foreignColName) &&
			!influxdb_is_tag_key(foreignColName, relid))
		{
			bool		match = false;
			int			j;

			for (j = attnum; j < ncol; j++)
			{
				/*
				 * InfluxDB returns column name of result in format:
				 * functionname_columnname (Example: last_value1). We need to
				 * concatenate string to compare with the column returned from
				 * InfluxDB.
				 */
				char	   *influxdbColName = column[j];
				char	   *tmpName;

				if (is_sc_agg_starregex)
					tmpName = foreignColName;
				else
					tmpName = psprintf("%s_%s", influxdbFuncName, foreignColName);

				if (strcmp(tmpName, influxdbColName) == 0)
				{
					match = true;
					nmatch++;

					if (is_schemaless)
					{
						char *colname = NULL;
						char *escaped_key = NULL;
						char *escaped_value = NULL;

						/* Escape comma charater in PostgreSQL composite type */
						if (!first)
							appendStringInfoChar(&fields_jsstr, ',');

						/* Get actual column name */
						colname = pstrdup(tmpName + strlen(influxdbFuncName) + 1); /* Skip "functionname_" */

						escaped_key = influxdb_escape_json_string(colname);
						pfree(colname);

						if (escaped_key == NULL)
							elog(ERROR, "Cannot escape json column key");

						escaped_value = influxdb_escape_json_string(row[j]);

						if (need_enclose_brace == false)
						{
							appendStringInfoChar(&fields_jsstr, '{');
							need_enclose_brace = true;
						}

						/* Build json string value for fields column */
						appendStringInfo(&fields_jsstr, "\"%s\" : ", escaped_key); /* \"key\" : */
						if (escaped_value)
							appendStringInfo(&fields_jsstr, "\"%s\"", escaped_value); /* \"value\" */
						else
							appendStringInfoString(&fields_jsstr, "null"); /* null */
					}
					else
					{
						if (!first)
							appendStringInfoChar(record, ',');

						appendStringInfo(record, "%s", row[j] != NULL ? row[j] : "");
					}
					first = false;
					break;
				}
			}
			if (!is_sc_agg_starregex && nmatch == nfield)
				break;

			/* Column of temp table does not match regex, fill as NULL */
			if (!is_schemaless && match == false)
				appendStringInfo(record, ",");
		}

		is_sc_agg_starregex = false;
	} while (foreignColName != NULL);

	if (is_schemaless)
	{
		char *escaped_fields_jsstr = NULL;

		if (need_enclose_brace)
			appendStringInfoString(&fields_jsstr, " }");

		/* Escape json string value in PostgreSQL composite type */
		escaped_fields_jsstr = influxdb_escape_record_string(fields_jsstr.data);

		/* Nested the escaped json string value in record */
		appendStringInfo(record, "%s", (escaped_fields_jsstr != NULL) ? escaped_fields_jsstr : "");
	}

	appendStringInfo(record, ")");
	valueDatum = CStringGetDatum(record->data);

	/* convert string value to appropriate type value */
	value_datum = OidFunctionCall3(typeinput, valueDatum, ObjectIdGetDatum(InvalidOid), Int32GetDatum(typemod));

	return value_datum;
}

/*
 * influxdb_bind_sql_var
 * Bind the values provided as DatumBind the values and nulls to modify the target table
 */
void
influxdb_bind_sql_var(Oid type, int idx, Datum value, bool *isnull,
					  InfluxDBType * param_influxdb_types, InfluxDBValue * param_influxdb_values)
{

	Oid			outputFunctionId = InvalidOid;
	bool		typeVarLength = false;

	if (*isnull)
	{
		elog(ERROR, "influxdb_fdw : cannot bind NULL");
		return;
	}

	getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);

	switch (type)
	{
		case INT2OID:
			{
				int16		dat = DatumGetInt16(value);

				param_influxdb_values[idx].i = dat;
				param_influxdb_types[idx] = INFLUXDB_INT64;
				break;
			}
		case INT4OID:
			{
				int32		dat = DatumGetInt32(value);

				param_influxdb_values[idx].i = dat;
				param_influxdb_types[idx] = INFLUXDB_INT64;
				break;
			}
		case INT8OID:
			{
				int64		dat = DatumGetInt64(value);

				param_influxdb_values[idx].i = dat;
				param_influxdb_types[idx] = INFLUXDB_INT64;
				break;
			}

		case FLOAT4OID:

			{
				float4		dat = DatumGetFloat4(value);

				param_influxdb_values[idx].d = (double) dat;
				param_influxdb_types[idx] = INFLUXDB_DOUBLE;
				break;
			}
		case FLOAT8OID:
			{
				float8		dat = DatumGetFloat8(value);

				param_influxdb_values[idx].d = dat;
				param_influxdb_types[idx] = INFLUXDB_DOUBLE;
				break;
			}

		case NUMERICOID:
			{
				Datum		valueDatum = DirectFunctionCall1(numeric_float8, value);
				float8		dat = DatumGetFloat8(valueDatum);

				param_influxdb_values[idx].d = dat;
				param_influxdb_types[idx] = INFLUXDB_DOUBLE;
				break;
			}
		case BOOLOID:
			{
				bool		dat = DatumGetBool(value);

				param_influxdb_values[idx].b = dat;
				param_influxdb_types[idx] = INFLUXDB_BOOLEAN;

				break;
			}
		case TEXTOID:
		case BPCHAROID:
		case VARCHAROID:
			{
				/* Bind as string */
				char	   *outputString = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				param_influxdb_values[idx].s = outputString;
				param_influxdb_types[idx] = INFLUXDB_STRING;
				break;
			}
		case TIMEOID:
		case TIMESTAMPOID:
		case TIMESTAMPTZOID:
			{
#ifdef GO_CLIENT
				/* Bind as string, but types is time */
				char	   *outputString = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				param_influxdb_values[idx].s = outputString;
#endif
#ifdef CXX_CLIENT
				const int64 postgres_to_unux_epoch_usecs = (POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * USECS_PER_DAY;
				Timestamp	valueTimestamp = DatumGetTimestamp(value);
				int64		valueNanoSecs = (valueTimestamp + postgres_to_unux_epoch_usecs) * 1000;

				param_influxdb_values[idx].i = valueNanoSecs;
#endif
				param_influxdb_types[idx] = INFLUXDB_TIME;
				break;
			}
		default:
			{
				ereport(ERROR, (errcode(ERRCODE_FDW_INVALID_DATA_TYPE),
								errmsg("cannot convert constant value to InfluxDB value %u", type),
								errhint("Constant value data type: %u", type)));
				break;
			}
	}

}
