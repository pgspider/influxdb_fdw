/*-------------------------------------------------------------------------
 *
 * InfluxDB Foreign Data Wrapper for PostgreSQL
 *
 * Portions Copyright (c) 2020, TOSHIBA CORPORATION
 *
 * IDENTIFICATION
 *        influxdb_fdw--1.0.sql
 *
 *-------------------------------------------------------------------------
 */

CREATE FUNCTION influxdb_fdw_handler()
RETURNS fdw_handler
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION influxdb_fdw_validator(text[], oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FOREIGN DATA WRAPPER influxdb_fdw
  HANDLER influxdb_fdw_handler
  VALIDATOR influxdb_fdw_validator;

CREATE FUNCTION last_value_sfunc(anyelement, timestamp with time zone, anyelement)
RETURNS anyelement
IMMUTABLE

LANGUAGE PLPGSQL
AS $$
BEGIN
  RAISE 'Cannot execute this function in PostgreSQL';
END;
$$;

CREATE FUNCTION last_value_finalfunc_bigint(anyelement)
RETURNS anyelement
IMMUTABLE

LANGUAGE PLPGSQL
AS $$
BEGIN
  RAISE 'Cannot execute this function in PostgreSQL';
END;
$$;


CREATE AGGREGATE last (timestamp with time zone, anyelement)
(
    sfunc = last_value_sfunc,
    stype = anyelement
);

CREATE FUNCTION influx_time(timestamp with time zone, interval, interval) RETURNS timestamp with time zone AS $$
BEGIN
RAISE 'Cannot execute this function in PostgreSQL';
END
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION influx_time(timestamp with time zone, interval) RETURNS timestamp with time zone AS $$
BEGIN
RAISE 'Cannot execute this function in PostgreSQL';
END
$$ LANGUAGE plpgsql IMMUTABLE;