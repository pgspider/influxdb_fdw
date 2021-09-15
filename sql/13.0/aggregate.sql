
--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
--Testcase 23:
SET datestyle=ISO;
-- timestamp with time zone differs based on this
--Testcase 24:
SET timezone='UTC';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 14:
CREATE EXTENSION influxdb_fdw;
--Testcase 15:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 16:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');

--ALTER EXTENSION influxdb_fdw ADD FUNCTION postgres_fdw_abs(int);
--ALTER SERVER server1 OPTIONS (ADD extensions 'influxdb_fdw');

--Testcase 1:
SELECT * FROM t4;

--Testcase 2:
EXPLAIN (verbose)
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;
--Testcase 3:
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;

--Testcase 4:
EXPLAIN (verbose)
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY tag2, tag1;
--Testcase 5:
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY tag2, tag1;

--Testcase 6:
SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;
--Testcase 7:
EXPLAIN (verbose)  SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;

--Testcase 8:
SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
 GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

--Testcase 9:
EXPLAIN (VERBOSE)
SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

-- no offset
--Testcase 10:
SELECT influx_time(time,interval '5s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00'
GROUP BY influx_time(time,interval '5s'), tag1;

--Testcase 11:
EXPLAIN (verbose)
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;
--Testcase 12:
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;

-- GROUP BY time intervals and fill()
--Testcase 25:
SELECT * FROM tx;

--Testcase 26:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100));

--Testcase 27:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100));

--Testcase 28:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001));

--Testcase 29:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001));

--Testcase 30:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('none')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none'));

--Testcase 31:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('none')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none'));

--Testcase 32:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('null')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null'));

--Testcase 33:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('null')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null'));

--Testcase 34:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('previous')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous'));

--Testcase 35:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('previous')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous'));

--Testcase 36:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('linear')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear'));

--Testcase 37:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_option('linear')) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear'));

-- with offset interval '0.00001s'
--Testcase 38:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100));

--Testcase 39:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)) FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100));

--Testcase 40:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1;

--Testcase 41:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1;

--Testcase 42:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 43:
SELECT sum("value1"), influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', interval '0.00001s', influx_fill_numeric(100)), tag1, tag2;

--with tag1
--Testcase 44:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1;

--Testcase 45:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1;

--Testcase 46:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1;

--Testcase 47:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1;

--Testcase 48:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('null')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null')), tag1;

--Testcase 49:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('null')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('null')), tag1;

--Testcase 50:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('none')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none')), tag1;

--Testcase 51:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('none')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('none')), tag1;

--Testcase 52:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('previous')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous')), tag1;

--Testcase 53:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('previous')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('previous')), tag1;

--Testcase 54:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('linear')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear')), tag1;

--Testcase 55:
SELECT sum("value1"), influx_time(time,interval '2s',influx_fill_option('linear')), tag1 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_option('linear')), tag1;

--with tag1,tag2

--Testcase 56:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 57:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100)), tag1, tag2;

--Testcase 58:
EXPLAIN (verbose)
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2;

--Testcase 59:
SELECT sum("value1"), influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2 FROM "tx"
WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:15+00'
GROUP BY influx_time(time,interval '2s', influx_fill_numeric(100.001)), tag1, tag2;

-- unsupport syntax
--Testcase 60:
EXPLAIN (verbose)
SELECT influx_fill_numeric(100) FROM "tx";
--Testcase 61:
SELECT influx_fill_numeric(100) FROM "tx";

--Testcase 62:
SELECT * FROM "tx" WHERE influx_fill_numeric(100) > 0;

--Testcase 63:
EXPLAIN (verbose)
SELECT influx_fill_option('linear') FROM "tx";
--Testcase 64:
SELECT influx_fill_option('linear') FROM "tx";

--Testcase 65:
SELECT * FROM "tx" WHERE influx_fill_option('linear') > 0;


-- InfluxDB does not return error for the following query
--SELECT sum(value1) FROM t4 GROUP BY value1;

-- not allowed
--Testcase 13:
SELECT sum(value1) FROM t4 GROUP BY time;

--last returns NULL for tag
--SELECT last(time, value1),last(time, value2),last(time, tag1) FROM t4 GROUP BY tag1;

--Testcase 17:
DROP FOREIGN TABLE t3;
--Testcase 18:
DROP FOREIGN TABLE t4;

--Testcase 66:
DROP FOREIGN TABLE tx;
--Testcase 19:
DROP FOREIGN TABLE cpu;
--Testcase 20:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 21:
DROP SERVER server1 CASCADE;
--Testcase 22:
DROP EXTENSION influxdb_fdw CASCADE;
