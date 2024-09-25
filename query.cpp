/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2022, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        query.cpp
 *
 *-------------------------------------------------------------------------
 */

#include <InfluxDB.h>
#include <InfluxDBFactory.h>
#include <Point.h>
#include <InfluxDBTable.h>
#include <InfluxDBParams.h>
#include <string>
#include <sstream>
#include <vector>
#include <memory>
#include "date/date.h"
#include "date/tz.h"
#include "connection.hpp"

extern "C"
{
#include "query_cxx.h"
}

std::vector<std::string> timestampFormats =
{
    "%FT%TZ",           /* RFC3399: 1997-12-17T07:37:16Z */
    "%F %T",          /* ISO: 1997-12-17 07:37:16 */
    "%m/%d/%Y %T %Z",   /* SQL: 12/17/1997 07:37:16.00 PST8PDT */
    "%m/%d/%Y %T",   /* SQL: 12/17/1997 07:37:16.00 */
    "%a %b %d %T %Y %Z", /* Postgres: Wed Dec 17 07:37:16 1997 PST8PDT */
    "%a %b %d %T %Y", /* Postgres: Wed Dec 17 07:37:16 1997 */
    "%m.%d.%Y %T %Z",    /* German: 17.12.1997 07:37:16.00 PST8PDT */
    "%m.%d.%Y %T"    /* German: 17.12.1997 07:37:16.00 */
};

static size_t InfluxDBSeries_get_total_row(std::vector<influxdb::InfluxDBSeries> &series);

std::chrono::system_clock::time_point parseTimeStamp(const std::string& value);

/*
 * InfluxDBSchemaInfo
 *      Returns information of table if success
 */
extern "C" struct InfluxDBSchemaInfo_return
InfluxDBSchemaInfo(UserMapping *user, influxdb_opt *opts)
{
    struct InfluxDBSchemaInfo_return res;
    std::string     query;
    TableInfo      *tables_info;
    int             table_idx;
    size_t          table_count;
    char           *db = opts->svr_database;

    try
    {
        auto influx = influxdb_get_connection(user, opts);

        query = "SHOW MEASUREMENTS ON " + std::string(db);

        auto measurements = influx->query(query).at(0);

        if (measurements.error.length() > 0)
            elog(ERROR, "influxdb_fdw: %s",measurements.error.c_str());

        table_count = InfluxDBSeries_get_total_row(measurements.series);

        if (table_count == 0)
            elog(ERROR, "influxdb_fdw: No table in remote server");

        tables_info = (TableInfo *) palloc0(sizeof(TableInfo) * table_count);

        table_idx = 0;
        for (auto &measurements_series_iter: measurements.series)
        {
            for (auto &mesurements_row: measurements_series_iter.rows)
            {
                size_t tags_idx, field_idx;

                tables_info[table_idx].measurement = pstrdup(mesurements_row.tuple.at(0).c_str());

                /*
                 * Get tagkeys for each foreign table
                 */
                query = "SHOW TAG KEYS ON " + std::string(db) + " FROM " + tables_info[table_idx].measurement;
                auto tagkeys = influx->query(query).at(0);
                if (tagkeys.error.length() > 0)
                    elog(ERROR, "influxdb_fdw: %s",tagkeys.error.c_str());

                tables_info[table_idx].tag_len = InfluxDBSeries_get_total_row(tagkeys.series);
                if (tables_info[table_idx].tag_len > 0)
                {
                    tables_info[table_idx].tag = (char **) palloc0(sizeof(char *) * tables_info[table_idx].tag_len);
                    tags_idx = 0;
                    for (auto &tagkeys_series_iter: tagkeys.series)
                    {
                        for (auto &tagkeys_row: tagkeys_series_iter.rows)
                        {
                            tables_info[table_idx].tag[tags_idx] = pstrdup(tagkeys_row.tuple.at(0).c_str());
                            tags_idx++;
                        }
                    }
                }

                /*
                 * Get fieldkeys for each foreign table
                 */
                query = "SHOW FIELD KEYS ON " + std::string(db) + " FROM " + tables_info[table_idx].measurement;
                auto fieldkeys = influx->query(query).at(0);
                if (fieldkeys.error.length() > 0)
                    elog(ERROR, "influxdb_fdw: %s",fieldkeys.error.c_str());

                tables_info[table_idx].field_len = InfluxDBSeries_get_total_row(fieldkeys.series);
                tables_info[table_idx].field = (char **) palloc0(sizeof(char *) * tables_info[table_idx].field_len);
                tables_info[table_idx].field_type = (char **) palloc0(sizeof(char *) * tables_info[table_idx].field_len);
                field_idx = 0;
                for (auto &fieldkeys_series_iter: fieldkeys.series)
                {
                    for (auto &fieldkeys_row: fieldkeys_series_iter.rows)
                    {
                        tables_info[table_idx].field[field_idx] = pstrdup(fieldkeys_row.tuple.at(0).c_str());
                        tables_info[table_idx].field_type[field_idx] = pstrdup(fieldkeys_row.tuple.at(1).c_str());
                        field_idx++;
                    }
                }

                table_idx++;
            }
        }
    }
    catch (const std::exception& e)
    {
        res.r2 = pstrdup(e.what());
        return res;
    }

    /* return interface of go-client */
    res.r0 = tables_info;
    res.r1 = table_count;
    res.r2 = NULL;

    return res;
}

/*
 * InfluxDBFreeSchemaInfo
 *      Not implement but keep this interface for consistency with go client
 */
extern "C" void
InfluxDBFreeSchemaInfo(struct TableInfo* tableInfo, long long length)
{
    /* Not implement but keep this interface for consistency with go client */
}

/*
 * bindParameter
 *      bind parameter to prepare for query exection
 */
static influxdb::InfluxDBParams
bindParameter(InfluxDBType *param_type, InfluxDBValue *param_val, int param_num)
{
    influxdb::InfluxDBParams params;

    if (param_num > 0)
    {
        for (int i = 0; i < param_num; i++)
        {
            /* Each placeholder is "$1", "$2",...,so set "1","2",... to map key */
            switch (param_type[i])
            {
                case INFLUXDB_STRING:
                    params.addParam(std::to_string(i + 1), std::string(param_val[i].s));
                    break;
                case INFLUXDB_INT64:
                case INFLUXDB_TIME:
                    params.addParam(std::to_string(i + 1), param_val[i].i);
                    break;
                case INFLUXDB_BOOLEAN:
                    params.addParam(std::to_string(i + 1), (bool) param_val[i].b);
                    break;
                case INFLUXDB_DOUBLE:
                    params.addParam(std::to_string(i + 1), param_val[i].d);
                    break;
                case INFLUXDB_NULL:
                    params.addParam(std::to_string(i + 1), "\"\"");
                    break;
                default:
                    elog(ERROR, "Unexpected type: %d", param_type[i]);
            }
        }
    }

    return params;
}

/*
 * InfluxDBSeries_get_total_row
 *      Get total number of row in a series
 */
static size_t
InfluxDBSeries_get_total_row(std::vector<influxdb::InfluxDBSeries> &series)
{
    size_t res = 0;

    for (auto &serie: series)
    {
        res += serie.rows.size();
    }

    return res;
}

/*
 * InfluxDBSeries_to_InfluxDBResult
 *      Convert result from series to table format
 */
static struct InfluxDBResult *
InfluxDBSeries_to_InfluxDBResult(std::vector<influxdb::InfluxDBSeries> &series)
{
    size_t total_row = InfluxDBSeries_get_total_row(series);
    size_t current_row_idx = 0;
    struct InfluxDBResult *res = (struct InfluxDBResult *)palloc0(sizeof(struct InfluxDBResult));

    if (series.size() < 1)
        return res;

    /* get tags key from first serie only */
    res->ntag = series.at(0).tagKeys.size();
    if (res->ntag != 0)
    {
        res->tagkeys = (char **)palloc0(sizeof(char*) * res->ntag);
        for (int i = 0; i < res->ntag; i++)
            res->tagkeys[i] = pstrdup(series.at(0).tagKeys.at(i).c_str());
    }

    /* get column name from first serie only */
    res->ncol = series.at(0).columnNames.size() + res->ntag;

    res->columns = (char **)palloc0(sizeof(char *) * series.at(0).columnNames.size());
    for (size_t i = 0; i < series.at(0).columnNames.size(); i++)
        res->columns[i] = pstrdup(series.at(0).columnNames.at(i).c_str());

    res->nrow = total_row;
    res->rows = (InfluxDBRow *)palloc0(sizeof(InfluxDBRow) * res->nrow);

    for (auto &serie: series)
    {
        for (auto &influx_row: serie.rows)
        {
            InfluxDBRow row;
            size_t    tuple_len = res->ncol;

            row.tuple = (char **)palloc0(sizeof(char *) * tuple_len);
            for (size_t col_idx = 0; col_idx < serie.columnNames.size(); col_idx++)
            {
                if (influx_row.tuple.at(col_idx).length() > 0)
                    row.tuple[col_idx] = pstrdup(influx_row.tuple.at(col_idx).c_str());
                else
                    row.tuple[col_idx] = NULL;
            }

            /* add tag value to tuple */
            for (size_t tag_idx = serie.columnNames.size(); tag_idx < tuple_len; tag_idx++)
            {
                std::string tag_value = serie.tagValues.at(tag_idx - serie.columnNames.size());

                if (tag_value.length() > 0)
                    row.tuple[tag_idx] = pstrdup(tag_value.c_str());
                else
                    row.tuple[tag_idx] = NULL;
            }
            res->rows[current_row_idx++] = row;
        }
    }

    return res;
}

/*
 * InfluxDBQuery
 *      execute single InfluxQL query
 */
extern "C" struct InfluxDBQuery_return
InfluxDBQuery(char* cquery, UserMapping *user, influxdb_opt *opts, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum)
{
    InfluxDBQuery_return *res = (InfluxDBQuery_return *) palloc0(sizeof(InfluxDBQuery_return));
    auto influx = influxdb_get_connection(user, opts);
    auto params = bindParameter(ctypes, cvalues, cparamNum);

    try
    {
        auto result_set = influx->query(std::string(cquery), params);

        /* Use first statement result */
        if (result_set.size() > 0)
        {
            auto query_result = result_set.at(0);
            if (query_result.error.length() > 0)
            {
                res->r1 = (char *) palloc0(sizeof(char) * (query_result.error.length()) + 1);
                strcpy(res->r1, query_result.error.c_str());
            }
            else
                res->r0 = InfluxDBSeries_to_InfluxDBResult(query_result.series);
        }
    }
    catch (const std::exception& e)
    {
        res->r1 = (char *) palloc0(sizeof(char) * (strlen(e.what()) + 1));
        strcpy(res->r1, e.what());
    }

    return *res;
}

/*
 * InfluxDBFreeResult
 *      InfluxDBFreeResult does not implement yet
 */
extern "C" void
InfluxDBFreeResult(InfluxDBResult* result)
{
    /* Not implement but keep this interface for consistency with go client */
}

/*
 * getCurrentMicroSecond
 *      Get current timestamp with micro second precision
 */
static long long
getCurrentMicroSecond()
{
    auto now = std::chrono::high_resolution_clock::now();
    auto tp = std::chrono::time_point_cast<std::chrono::microseconds>(now);
    auto epoch = tp.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::microseconds>(epoch).count();
}

/*
 * makeRecord
 *      Prepare record to insert
 */
static void
makeRecord(influxdb::Point& record, struct InfluxDBColumnInfo* pColInfo, InfluxDBType dataType, InfluxDBValue value)
{
    switch (dataType)
    {
        case INFLUXDB_INT64:
            record.addField(pColInfo->column_name, value.i);
            break;
        case INFLUXDB_DOUBLE:
            record.addField(pColInfo->column_name, value.d);
            break;
        case INFLUXDB_BOOLEAN:
            record.addField(pColInfo->column_name, value.b == 0 ? false : true);
            break;
        case INFLUXDB_STRING:
        {
            switch (pColInfo->column_type)
            {
                case INFLUXDB_TIME_KEY:
                {
                    /* time_text column */
                    record.setTimestamp(parseTimeStamp(std::string{value.s}));
                    break;
                }
                case INFLUXDB_TAG_KEY:
                    record.addTag(pColInfo->column_name, value.s);
                    break;
                case INFLUXDB_FIELD_KEY:
                    record.addField(pColInfo->column_name, std::string{value.s});
                    break;
                default:
                    elog(ERROR, "Unexpected column type: %d", pColInfo->column_type);
            }
        }
        case INFLUXDB_NULL:
            /* Do not need to append null value when execute INSERT */
            break;
        case INFLUXDB_TIME:
            record.setTimestamp(value.i);
            break;
        default:
            elog(ERROR, "Unexpected type: %d", dataType);
    }
}

/*
 * InfluxDBInsert
 *      Insert record to influxdb
 */
extern "C" char *
InfluxDBInsert(char *tablename, UserMapping *user, influxdb_opt *opts, struct InfluxDBColumnInfo* ccolumns, InfluxDBType* ctypes, InfluxDBValue* cvalues, int cparamNum, int cnumSlots)
{
    char* retMsg = NULL;

    /* Create a new HTTPClient */
    auto influxdb = influxdb_get_connection(user, opts);
    try
    {
        long long prev_time = 0;
        long long cur_time;

        influxdb->batchOf(cnumSlots);

        /* wait a microsecond to ensure different timestamps with previous batch */
        pg_usleep(1);

        /* Write batches of cnumSlots points */
        for (size_t idx = 0; idx < (size_t)cnumSlots; idx++)
        {
            influxdb::Point record(tablename);

            /* Busy wait to different timestamp */
            do
            {
                cur_time = getCurrentMicroSecond();
            }
            while (cur_time <= prev_time);
            prev_time = cur_time;

            /* set current time in micro second as default */
            record.setTimestamp(cur_time * 1000);
            for (size_t pos = 0; pos < (size_t)cparamNum; pos++)
                makeRecord(record, ccolumns + pos, ctypes[idx * cparamNum + pos], cvalues[idx * cparamNum + pos]);
            influxdb->write(std::move(record));
        }
    }
    catch (const std::exception& e)
    {
        /* clean error batch */
        influxdb->clearBatch();
        retMsg = (char *) palloc0(sizeof(char) * (strlen(e.what()) + 1));
        strcpy(retMsg, e.what());
        return retMsg;
    }
    influxdb->flushBatch();
    return retMsg;
}

/*
 * parseTimeStamp
 *      Parse timestamp string to nanosecond time_point
 */
std::chrono::system_clock::time_point parseTimeStamp(const std::string& value)
{
    std::string tzname;
    date::local_time<std::chrono::nanoseconds> local_tp;
    std::chrono::system_clock::time_point tp;

    for (auto &format: timestampFormats)
    {
        std::istringstream timeString{value};
        timeString >> date::parse(format, local_tp, tzname);
        if (!timeString.fail() && timeString.peek() == EOF)
        {
            if (tzname.size() > 0)
                tp = date::locate_zone(tzname)->to_sys(local_tp);
            else
                tp = std::chrono::system_clock::time_point(local_tp.time_since_epoch());
            return tp;
        }
    }

    {
        /* parse ISO timestamp format: "%F %T%z", ISO: 1997-12-17 07:37:16-08 */
        std::istringstream timeString{value};
        timeString >> date::parse("%F %T%z", tp);
        if (!timeString.fail() && timeString.peek() == EOF)
        {
            return tp;
        }
    }

    throw std::runtime_error("Unsupported timestamp format: " + value);
}

/* If version not set, check to which version can be connected  */
extern "C" int
check_connected_influxdb_version(char* addr, int port, char* user, char* pass, char* db, char* auth_token, char* retention_policy)
{
    std::unique_ptr<influxdb::InfluxDB> influx;
    std::string                         query;

    query = "SHOW MEASUREMENTS ON " + std::string(db);

    try
    {
        influx = influxdb::InfluxDBFactory::GetV2(std::string(addr), port, std::string(db), std::string(auth_token), std::string(retention_policy));
        auto measurements = influx->query(query);
        return INFLUXDB_VERSION_2;
    }
    catch (const std::exception &e)
    {
        /* do nothing */
    }

    try
    {
        influx = influxdb::InfluxDBFactory::GetV1(std::string(addr), port, std::string(db), std::string(user), std::string(pass));
        auto measurements = influx->query(query);
        return INFLUXDB_VERSION_1;
    }
    catch(const std::exception& e)
    {
        elog(ERROR, "Could not connect to InfluxDB: %s", e.what());
    }

    elog(ERROR, "Could not connect to InfluxDB.");
}

/*
 * Clean up all open cxx client connection.
 * C interface wrapper function for influx_cleanup_connection in connection.cpp
 */
extern "C" void
cleanup_cxx_client_connection(void)
{
    influx_cleanup_connection();
}

/*
 * InfluxDBExecDDLCommand
 *      drop a measurement
 * Return NULL if success, otherwise return error message
 */
extern "C" char *
InfluxDBExecDDLCommand(char* addr, int port, char* user, char* pass, char* db, char* cquery, int version, char* auth_token, char* retention_policy)
{
    std::unique_ptr<influxdb::InfluxDB> influx;
    char* retMsg = NULL;
    bool retry_connect = false;

    if (version != INFLUXDB_VERSION_1 && version != INFLUXDB_VERSION_2)
    {
        try
        {
            /* Automatically detect InfluxDB version 1.x and 2.x: trying to connect InfluxDB v2.x first */
            influx = influxdb::InfluxDBFactory::GetV2(std::string(addr), port, std::string(db), std::string(auth_token), std::string(retention_policy));
            auto err = influx->query(cquery);
        }
        catch(const std::exception& e)
        {
            /* Trying to connect InfluxDB v1.x */
            retry_connect = true;
        }

        if (!retry_connect)
            return NULL; /* Query successfully */

        try
        {
            influx = influxdb::InfluxDBFactory::GetV1(std::string(addr), port, std::string(db), std::string(user), std::string(pass));
            auto err = influx->query(cquery);
        }
        catch(const std::exception& e)
        {
            elog(ERROR, "influxdb_fdw: could not execute query: %s", cquery);
        }
    }

    try
    {
        /* InfluxDB version is specified */
        if (version == INFLUXDB_VERSION_1)
            influx = influxdb::InfluxDBFactory::GetV1(std::string(addr), port, std::string(db), std::string(user), std::string(pass));
        else if (version == INFLUXDB_VERSION_2)
            influx = influxdb::InfluxDBFactory::GetV2(std::string(addr), port, std::string(db), std::string(auth_token), std::string(retention_policy));

        if (!influx)
            elog(ERROR, "Fail to create influxDB client");

        auto err = influx->query(cquery);
    }
    catch (const std::exception& e)
    {
        retMsg = (char *) pstrdup(e.what());
    }

    return retMsg;
}
