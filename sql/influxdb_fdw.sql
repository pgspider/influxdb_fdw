--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='Japan';

CREATE EXTENSION influxdb_fdw;
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086') ;
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS(user 'user', password 'pass');

-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
SELECT * FROM cpu;
SELECT tag1,value1 FROM cpu;
SELECT value1,time,value2 FROM cpu;
SELECT value1,time_text,value2 FROM cpu;
DROP FOREIGN TABLE cpu;
DROP FOREIGN TABLE t3;

-- test EXECPT
IMPORT FOREIGN SCHEMA public EXCEPT (cpu,t3) FROM SERVER server1 INTO public;
SELECT ftoptions FROM pg_foreign_table;

-- test LIMIT TO
IMPORT FOREIGN SCHEMA public LIMIT TO (cpu) FROM SERVER server1 INTO public;
SELECT ftoptions FROM pg_foreign_table;
DROP FOREIGN TABLE cpu;


IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');

SELECT * FROM cpu;
SELECT tag1,value1 FROM cpu;
SELECT value1,time,value2 FROM cpu;
-- Get only tags returns no row. This behavior is based on InfluxDB 
SELECT tag1 FROM cpu;

\d cpu;

SELECT * FROM cpu WHERE value1=100;
SELECT * FROM cpu WHERE value2=0.5;
SELECT * FROM cpu WHERE value3='str';
SELECT * FROM cpu WHERE value4=true;
SELECT * FROM cpu WHERE NOT (value4 AND value1=100);
SELECT * FROM cpu WHERE tag1='tag1_A';

EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE value3 IS NULL;
SELECT * FROM cpu WHERE value3 IS NULL;
SELECT * FROM cpu WHERE tag2 IS NULL;
SELECT * FROM cpu WHERE value3 IS NOT NULL;
SELECT * FROM cpu WHERE tag2 IS NOT NULL;
-- There is inconsitency for search of missing values between tag and field
EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE value3 = '';
SELECT * FROM cpu WHERE value3 = '';

EXPLAIN (verbose,costs off)
SELECT * FROM cpu WHERE tag2 = '';
SELECT * FROM cpu WHERE tag2 = '';

SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');
EXPLAIN (verbose)  SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');

-- Rows which have no tag are considered to have empty string tag, so much below conditions
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');
EXPLAIN (verbose)  SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');

DROP FOREIGN TABLE cpu;

CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, value1 integer) SERVER server1  OPTIONS (table 'cpu');
CREATE FOREIGN TABLE t2(time timestamp , tag1 text, value1 integer) SERVER server1  OPTIONS (table 'cpu');

SELECT * FROM t1;
SELECT * FROM t1 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
SELECT * FROM t1 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

SELECT * FROM t2;
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

-- pushdown now()
SELECT * FROM t2 WHERE now() > time;
EXPLAIN (verbose) SELECT * FROM t2 WHERE now() > time;

SELECT * FROM t2 WHERE time = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';
EXPLAIN (verbose)  SELECT * FROM t2 WHERE time = TIMESTAMP  WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';

-- InfluxDB does not seem to support time + interval, so below query does not work
-- SELECT * FROM t2 WHERE time + interval '1 seconds' = TIMESTAMP '2015-08-18 00:00:01+09';

-- InfluxDB does not support month or year interval, so not push down
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';
EXPLAIN (verbose)  SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';


SELECT * FROM t3;

EXPLAIN (verbose, costs off) SELECT
sum(value1), max(value1),count(*) FROM t3;
SELECT sum(value1), max(value1),count(*) FROM t3;

EXPLAIN (verbose, costs off) 
SELECT avg(value1) FROM t3;
SELECT avg(value1) FROM t3;


-- Not pushdown aggregates with GROUP BY because "SELECT sum(value1),tag1" cause error "mixing aggregate and non-aggregate queries is not supported"
EXPLAIN (verbose, costs off) 
SELECT sum(value1) FROM t3 GROUP BY "tag1";
SELECT sum(value1) FROM t3 GROUP BY "tag1";

-- Currently using column_name 'time' does not work 
-- CREATE FOREIGN TABLE t(tm timestamp OPTIONS (column_name 'time'),tm_with_zone timestamp with time zone OPTIONS (column_name 'time'), tag1 text,value1 integer) SERVER server1  OPTIONS (table 'cpu');

DROP FOREIGN TABLE t1;
DROP FOREIGN TABLE t2;
DROP FOREIGN TABLE t3;

DROP USER MAPPING FOR CURRENT_USER SERVER server1;
DROP SERVER server1;
DROP EXTENSION influxdb_fdw CASCADE;
