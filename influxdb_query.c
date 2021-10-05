/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2021, TOSHIBA CORPORATION
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
influxdb_convert_to_pg(Oid pgtyp, int pgtypmod, char **row, int attnum)
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
	valueDatum = CStringGetDatum(row[attnum]);

	/* convert string value to appropriate type value */
	value_datum = OidFunctionCall3(typeinput, valueDatum, ObjectIdGetDatum(InvalidOid), Int32GetDatum(typemod));

	return value_datum;
}

/*
 * influxdb_convert_record_to_datum: Convert influxdb string data into PostgreSQL's compatible data types
 */
Datum
influxdb_convert_record_to_datum(Oid pgtyp, int pgtypmod, char **row, int attnum, int ntags, int nfield, char **column, char *opername, Oid relid, int ncol)
{
	Datum		value_datum = 0;
	Datum		valueDatum = 0;
	regproc		typeinput;
	HeapTuple	tuple;
	int			typemod;
	int			i;
	StringInfo	record = makeStringInfo();
	bool		first = true;
	char	   *foreignColName = NULL;
	int			nmatch = 0;

	/* get the type's output function */
	tuple = SearchSysCache1(TYPEOID, ObjectIdGetDatum(pgtyp));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for type%u", pgtyp);

	typeinput = ((Form_pg_type) GETSTRUCT(tuple))->typinput;
	typemod = ((Form_pg_type) GETSTRUCT(tuple))->typtypmod;
	ReleaseSysCache(tuple);

	/* Append time column */
	appendStringInfo(record, "(%s,", row[0]);

	/* Append tags column as NULL */
	for (i = 0; i < ntags; i++)
		appendStringInfo(record, ",");

	/* Append fields column */
	i = 0;
	do
	{
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
				char	   *influxdbFuncName = influxdb_replace_function(opername);
				char	   *tmpName = psprintf("%s_%s", influxdbFuncName, foreignColName);

				if (strcmp(tmpName, influxdbColName) == 0)
				{
					match = true;
					nmatch++;
					if (first)
					{
						appendStringInfo(record, "%s", row[j] != NULL ? row[j] : "");
						first = false;
					}
					else
						appendStringInfo(record, ",%s", row[j] != NULL ? row[j] : "");
					break;
				}
			}
			if (nmatch == nfield)
				break;

			/* Column of temp table does not match regex, fill as NULL */
			if (match == false)
				appendStringInfo(record, ",");
		}
	} while (foreignColName != NULL);

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
				/* Bind as string, but types is time */
				char	   *outputString = NULL;
				Oid			outputFunctionId = InvalidOid;
				bool		typeVarLength = false;

				getTypeOutputInfo(type, &outputFunctionId, &typeVarLength);
				outputString = OidOutputFunctionCall(outputFunctionId, value);
				param_influxdb_values[idx].s = outputString;
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
