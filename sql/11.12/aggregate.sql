
--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
--Testcase 1:
SET datestyle=ISO;
-- timestamp with time zone differs based on this
--Testcase 2:
SET timezone='UTC';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 3:
CREATE EXTENSION influxdb_fdw;
--Testcase 4:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');

--ALTER EXTENSION influxdb_fdw ADD FUNCTION postgres_fdw_abs(int);
--ALTER SERVER server1 OPTIONS (ADD extensions 'influxdb_fdw');

--Testcase 6:
SELECT * FROM t4;

--Testcase 7:
EXPLAIN (verbose)
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;
--Testcase 8:
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;

--Testcase 9:
EXPLAIN (verbose)
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY tag2, tag1;
--Testcase 10:
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY tag2, tag1;

--Testcase 11:
SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;
--Testcase 12:
EXPLAIN (verbose)  SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;

--Testcase 13:
SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

--Testcase 14:
EXPLAIN (VERBOSE)
SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

-- no offset
--Testcase 15:
SELECT influx_time(time,interval '5s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '5s'), tag1;

--Testcase 16:
EXPLAIN (verbose)
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;
--Testcase 17:
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;

-- GROUP BY time intervals and fill()
--Testcase 18:
SELECT * FROM tx;

--Testcase 19:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100));

--Testcase 20:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100));

--Testcase 21:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001));

--Testcase 22:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001));

--Testcase 23:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('none')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none'));

--Testcase 24:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('none')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none'));

--Testcase 25:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('null')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null'));

--Testcase 26:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('null')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null'));

--Testcase 27:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('previous')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous'));

--Testcase 28:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('previous')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous'));

--Testcase 29:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('linear')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear'));

--Testcase 30:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('linear')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear'));

-- with offset interval '0.00001s'
--Testcase 31:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100));

--Testcase 32:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100));

--Testcase 33:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1;

--Testcase 34:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1;

--Testcase 35:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 36:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2;

--with tag1
--Testcase 37:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1;

--Testcase 38:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1;

--Testcase 39:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1;

--Testcase 40:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1;

--Testcase 41:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('null')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null')), tag1;

--Testcase 42:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('null')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null')), tag1;

--Testcase 43:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('none')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none')), tag1;

--Testcase 44:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('none')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none')), tag1;

--Testcase 45:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('previous')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous')), tag1;

--Testcase 46:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('previous')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous')), tag1;

--Testcase 47:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('linear')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear')), tag1;

--Testcase 48:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('linear')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear')), tag1;

--with tag1,tag2

--Testcase 49:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 50:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 51:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2;

--Testcase 52:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2;

-- unsupport syntax
--Testcase 53:
EXPLAIN (verbose)
SELECT influx_fill_numeric(100) FROM "tx";
--Testcase 54:
SELECT influx_fill_numeric(100) FROM "tx";

--Testcase 55:
SELECT * FROM "tx" WHERE influx_fill_numeric(100) > 0;

--Testcase 56:
EXPLAIN (verbose)
SELECT influx_fill_option('linear') FROM "tx";
--Testcase 57:
SELECT influx_fill_option('linear') FROM "tx";

--Testcase 58:
SELECT * FROM "tx" WHERE influx_fill_option('linear') > 0;


-- InfluxDB does not return error for the following query
--SELECT sum(value1) FROM t4 GROUP BY value1;

-- not allowed
--Testcase 59:
SELECT sum(value1) FROM t4 GROUP BY time;

--last returns NULL for tag
--SELECT last(time, value1),last(time, value2),last(time, tag1) FROM t4 GROUP BY tag1;

--Testcase 60:
DROP FOREIGN TABLE t3;
--Testcase 61:
DROP FOREIGN TABLE t4;
--Testcase 62:
DROP FOREIGN TABLE cpu;
--Testcase 63:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 64:
DROP SERVER server1 CASCADE;
--Testcase 65:
DROP EXTENSION influxdb_fdw CASCADE;
