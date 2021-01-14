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

CREATE FUNCTION influxdb_create_or_replace_stub(func_type text, name_arg text, return_type regtype) RETURNS BOOL AS $$
DECLARE
  proname_raw text := split_part(name_arg, '(', 1);
  proname text := ltrim(rtrim(proname_raw));
BEGIN
  IF lower(func_type) = 'aggregation' OR lower(func_type) = 'aggregate' OR lower(func_type) = 'agg' OR lower(func_type) = 'a' THEN
    DECLARE
      proargs_raw text := right(name_arg, length(name_arg) - length(proname_raw));
      proargs text := ltrim(rtrim(proargs_raw));
      proargs_types text := right(left(proargs, length(proargs) - 1), length(proargs) - 2);
      aggproargs text := format('(%s, %s)', return_type, proargs_types);
    BEGIN
      BEGIN
        EXECUTE format('
          CREATE FUNCTION %s_sfunc%s RETURNS %s IMMUTABLE AS $inner$
          BEGIN
            RAISE EXCEPTION ''stub %s_sfunc%s is called'';
            RETURN NULL;
          END $inner$ LANGUAGE plpgsql;',
	  proname, aggproargs, return_type, proname, aggproargs);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub function for aggregation already exists (ignored)';
      END;
      BEGIN
        EXECUTE format('
          CREATE AGGREGATE %s
          (
            sfunc = %s_sfunc,
            stype = %s
          );', name_arg, proname, return_type);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub aggregation already exists (ignored)';
        WHEN others THEN
          RAISE EXCEPTION 'stub aggregation exception';
      END;
    END;
  ELSIF lower(func_type) = 'function' OR lower(func_type) = 'func' OR lower(func_type) = 'f' THEN
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s RETURNS %s IMMUTABLE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSE
    RAISE EXCEPTION 'not supported function type %', func_type;
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s_sfunc RETURNS %s AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  END IF;
  RETURN TRUE;
END
$$ LANGUAGE plpgsql;

SELECT influxdb_create_or_replace_stub('a', 'last(timestamp with time zone, anyelement)', 'anyelement');
SELECT influxdb_create_or_replace_stub('a', 'first(timestamp with time zone, anyelement)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval, interval)', 'timestamp with time zone');
SELECT influxdb_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval)', 'timestamp with time zone');
SELECT influxdb_create_or_replace_stub('f', 'log(bigint, bigint)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'log(float8, float8)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'log2(bigint)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'log2(float8)', 'float8');
SELECT influxdb_create_or_replace_stub('a', 'spread(bigint)', 'bigint');
SELECT influxdb_create_or_replace_stub('a', 'spread(float8)', 'float8');
SELECT influxdb_create_or_replace_stub('a', 'sample(anyelement, int)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'cumulative_sum(bigint)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'cumulative_sum(float8)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'derivative(anyelement)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'derivative(anyelement, interval)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'non_negative_derivative(anyelement)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'non_negative_derivative(anyelement, interval)', 'anyelement');
SELECT influxdb_create_or_replace_stub('f', 'difference(bigint)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'difference(float8)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'non_negative_difference(bigint)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'non_negative_difference(float8)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'elapsed(anyelement)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'elapsed(anyelement, interval)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'elapsed(anyelement)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'elapsed(anyelement, interval)', 'bigint');
SELECT influxdb_create_or_replace_stub('f', 'moving_average(bigint, int)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'moving_average(float8, int)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'exponential_moving_average(bigint, int)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'exponential_moving_average(float8, int)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'exponential_moving_average(bigint, int, int)', 'float8');
SELECT influxdb_create_or_replace_stub('f', 'exponential_moving_average(float8, int, int)', 'float8');
