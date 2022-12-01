/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        query_cxx.h
 *          C interface for query.cpp
 * 			This file content is unified with obj/_cgo_export.h
 *
 *-------------------------------------------------------------------------
 */

#ifndef QUERY_CXX_H
#define QUERY_CXX_H

/* Represents information of data type */
typedef enum InfluxDBType{
	INFLUXDB_INT64,
	INFLUXDB_DOUBLE,
	INFLUXDB_BOOLEAN,
	INFLUXDB_STRING,
	INFLUXDB_TIME,
	INFLUXDB_NULL
} InfluxDBType;

/* Represents information of values in influxdb */
typedef union InfluxDBValue{
	long long int i;
	double d;
	int b;
	char *s;
} InfluxDBValue;

/* Represents schema of one measurement(table) */
typedef struct TableInfo {
	char *measurement;	/* name */
	char **tag; 		/* array of tag name */
	char **field;		/* array of field name */
	char **field_type;	/* array of field type */
	int tag_len;		/* the number of tags */
	int field_len;		/* the number of fields */
} TableInfo;

/* Represents information of a row */
typedef struct InfluxDBRow {
	char **tuple;
} InfluxDBRow;

/* Represents information of influxdb's result set */
typedef struct InfluxDBResult {
	InfluxDBRow *rows;
	int ncol;
	int nrow;
	char **columns;
	char **tagkeys;
	int ntag;
} InfluxDBResult;

/* Represents information of a table's column type */
typedef enum InfluxDBColumnType{
	INFLUXDB_TIME_KEY,
	INFLUXDB_TAG_KEY,
	INFLUXDB_FIELD_KEY
} InfluxDBColumnType;

/* Represents information of a table's column */
typedef struct InfluxDBColumnInfo {
	char *column_name;				/* name of column */
	InfluxDBColumnType column_type;	/* type of column */
} InfluxDBColumnInfo;


/* Return type for InfluxDBSchemaInfo */
struct InfluxDBSchemaInfo_return {
	struct TableInfo* r0; /* retinfo */
	long long r1; /* length */
	char* r2; /* errret */
};

#define INFLUXDB_VERSION_1    1
#define INFLUXDB_VERSION_2    2

/* InfluxDBSchemaInfo returns information of table if success */
extern struct InfluxDBSchemaInfo_return InfluxDBSchemaInfo(char* addr, int port, char* user, char* pass, char* db, int version, char* auth_token, char* retention_policy);

/* InfluxDBFreeSchemaInfo returns nothing */
extern void InfluxDBFreeSchemaInfo(struct TableInfo* tableInfo, long long length);

/* Return type for InfluxDBQuery */
struct InfluxDBQuery_return {
	InfluxDBResult r0;
	char* r1;
};

/* InfluxDBQuery returns result set */
extern struct InfluxDBQuery_return InfluxDBQuery(char* cquery, char* addr, int port, char* username, char* password, char* db, int version, char* auth_token, char* retention_policy, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum);

/* InfluxDBFreeResult returns nothing */
extern void InfluxDBFreeResult(InfluxDBResult* result);

/* InfluxDBInsert returns nil if success */
extern char* InfluxDBInsert(char* addr, int port, char* user, char* pass, char* db, char* tablename, int version, char* auth_token, char* retention_policy, struct InfluxDBColumnInfo* ccolumns, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum, int cnumSlots);

/* If version not set, check to which version can be connected  */
extern int check_connected_influxdb_version(char* addr, int port, char* user, char* pass, char* db, char* auth_token, char* retention_policy);

#endif  /* QUERY_CXX_H */
