
--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
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
--Testcase 19:
DROP FOREIGN TABLE cpu;
--Testcase 20:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 21:
DROP SERVER server1;
--Testcase 22:
DROP EXTENSION influxdb_fdw;
