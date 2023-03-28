/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        connection.hpp
 *
 *-------------------------------------------------------------------------
 */

#ifndef CONNECTION_HPP
#define CONNECTION_HPP

extern "C"
{
#include "influxdb_fdw.h"
}

#include <InfluxDB.h>
#include <InfluxDBFactory.h>

extern influxdb::InfluxDB *influxdb_get_connection(UserMapping *user, influxdb_opt *options);
extern std::unique_ptr<influxdb::InfluxDB> create_influxDB_client(char* addr, int port, char* user, char* pass, char* db, int version, char* auth_token, char* retention_policy);
extern void influx_cleanup_connection(void);
#endif /* CONNECTION_HPP */