--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 57:
CREATE EXTENSION influxdb_fdw;
--Testcase 58:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 59:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
--Testcase 1:
SELECT * FROM cpu;
--Testcase 2:
SELECT tag1,value1 FROM cpu;
--Testcase 3:
SELECT value1,time,value2 FROM cpu;
--Testcase 4:
SELECT value1,time_text,value2 FROM cpu;
--Testcase 60:
DROP FOREIGN TABLE cpu;
--Testcase 61:
DROP FOREIGN TABLE t3;
--Testcase 62:
DROP FOREIGN TABLE t4;

-- test EXECPT
IMPORT FOREIGN SCHEMA public EXCEPT (cpu,t3, t4) FROM SERVER server1 INTO public;
--Testcase 5:
SELECT ftoptions FROM pg_foreign_table;

-- test LIMIT TO
IMPORT FOREIGN SCHEMA public LIMIT TO (cpu) FROM SERVER server1 INTO public;
--Testcase 6:
SELECT ftoptions FROM pg_foreign_table;
--Testcase 63:
DROP FOREIGN TABLE cpu;

IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');

--Testcase 7:
SELECT * FROM cpu;
--Testcase 8:
SELECT tag1,value1 FROM cpu;
--Testcase 9:
SELECT value1,time,value2 FROM cpu;
--Testcase 10:
SELECT tag1 FROM cpu;

--Testcase 11:
\d cpu;

--Testcase 12:
SELECT * FROM cpu WHERE value1=100;
--Testcase 13:
SELECT * FROM cpu WHERE value2=0.5;
--Testcase 14:
SELECT * FROM cpu WHERE value3='str';
--Testcase 15:
SELECT * FROM cpu WHERE value4=true;
--Testcase 16:
SELECT * FROM cpu WHERE NOT (value4 AND value1=100);
--Testcase 17:
SELECT * FROM cpu WHERE tag1='tag1_A';

--Testcase 64:
EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 19:
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 20:
SELECT * FROM cpu WHERE tag2 IS NULL;
--Testcase 21:
SELECT * FROM cpu WHERE value3 IS NOT NULL;
--Testcase 22:
SELECT * FROM cpu WHERE tag2 IS NOT NULL;

-- InfluxDB not support compare timestamp with OR condition
--Testcase 23:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- InfluxDB not support compare timestamp with != or <>
--Testcase 24:
SELECT * FROM cpu WHERE time != '2015-08-18 09:48:08+09';
--Testcase 25:
SELECT * FROM cpu WHERE time <> '2015-08-18 09:48:08+09';

--Testcase 65:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- There is inconsitency for search of missing values between tag and field
--Testcase 66:
EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE value3 = '';
--Testcase 27:
SELECT * FROM cpu WHERE value3 = '';

--Testcase 67:
EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE tag2 = '';
--Testcase 29:
SELECT * FROM cpu WHERE tag2 = '';

--Testcase 30:
SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');
--Testcase 31:
EXPLAIN (verbose)  SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');

-- Rows which have no tag are considered to have empty string
--Testcase 32:
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');
--Testcase 33:
EXPLAIN (verbose)  SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');

-- test IN/NOT IN
--Testcase 34:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 35:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 36:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 37:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 38:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 39:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 40:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 41:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 68:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 69:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 70:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 71:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 72:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 73:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 74:
SELECT * FROM cpu WHERE value4 IN ('f', 't');

--Testcase 75:
DROP FOREIGN TABLE cpu;

--Testcase 76:
CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, value1 integer) SERVER server1  OPTIONS (table 'cpu');
--Testcase 77:
CREATE FOREIGN TABLE t2(time timestamp , tag1 text, value1 integer) SERVER server1  OPTIONS (table 'cpu');

--Testcase 42:
SELECT * FROM t1;
--Testcase 43:
SELECT * FROM t2;
-- In following four queries, timestamp condition is added to InfluxQL as "time = '2015-08-18 00:00:00'"
--Testcase 44:
SELECT * FROM t1 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 45:
SELECT * FROM t1 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

--Testcase 46:
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 47:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

-- pushdown now()
--Testcase 48:
SELECT * FROM t2 WHERE now() > time;
--Testcase 78:
EXPLAIN (verbose) SELECT * FROM t2 WHERE now() > time;

--Testcase 49:
SELECT * FROM t2 WHERE time = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';
--Testcase 50:
EXPLAIN (verbose)  SELECT * FROM t2 WHERE time = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';

-- InfluxDB does not seem to support time column + interval, so below query returns empty result
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00';
-- EXPLAIN (verbose, costs off) 
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00';

-- InfluxDB does not support month or year interval, so not push down
--Testcase 51:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';
--Testcase 52:
EXPLAIN (verbose)  SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';

--Testcase 53:
SELECT * FROM t2 WHERE value1 = ANY (ARRAY(SELECT value1 FROM t1 WHERE value1 < 1000));

ALTER SERVER server1 OPTIONS (SET dbname 'no such database');
--Testcase 54:
SELECT * FROM t1;
ALTER SERVER server1 OPTIONS (SET dbname 'mydb');
--Testcase 55:
SELECT * FROM t1;

-- map time column to both timestamp and text
--Testcase 79:
CREATE FOREIGN TABLE t5(t timestamp OPTIONS (column_name 'time') , tag1 text OPTIONS (column_name 'time'), v1  integer OPTIONS (column_name 'value1')) SERVER server1  OPTIONS (table 'cpu');
--Testcase 56:
SELECT * FROM t5;

--Testcase 80:
DROP FOREIGN TABLE t1;
--Testcase 81:
DROP FOREIGN TABLE t2;
--Testcase 82:
DROP FOREIGN TABLE t3;
--Testcase 83:
DROP FOREIGN TABLE t4;
--Testcase 84:
DROP FOREIGN TABLE t5;

--Testcase 85:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 86:
DROP SERVER server1;
--Testcase 87:
DROP EXTENSION influxdb_fdw CASCADE;
