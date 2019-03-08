
--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='UTC';

CREATE EXTENSION influxdb_fdw;
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086') ;
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS(user 'user', password 'pass');


-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');




--ALTER EXTENSION influxdb_fdw ADD FUNCTION postgres_fdw_abs(int);
--ALTER SERVER server1 OPTIONS (ADD extensions 'influxdb_fdw');

SELECT * FROM t4;

EXPLAIN (verbose)  
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;
SELECT sum("value1"),influx_time(time,interval '1s', interval '0.00001s'),tag1 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
GROUP BY influx_time(time,interval '1s', interval '0.00001s'), tag1;


EXPLAIN (verbose) 
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
 GROUP BY tag2, tag1;
SELECT tag1,sum("value1"),tag2 FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
 GROUP BY tag2, tag1;



SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;
EXPLAIN (verbose)  SELECT tag1,sum("value1"), count(value1), tag2 FROM "t4" group by tag1, tag2;




SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
 GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

EXPLAIN (VERBOSE)
SELECT influx_time(time,interval '5s',interval '0s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
GROUP BY influx_time(time,interval '5s', interval '0s'), tag1;

-- no offset 
SELECT influx_time(time,interval '5s'),tag1,last(time, value1) FROM "t4" WHERE time >= '1970-01-01 00:00:00+00' and time <= '1970-01-01 0:00:05+00' 
GROUP BY influx_time(time,interval '5s'), tag1;

EXPLAIN (verbose) 
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;
SELECT last(time, value1),last(time, value2) FROM t4 GROUP BY tag1;

-- InfluxDB does not return error for the following query
--SELECT sum(value1) FROM t4 GROUP BY value1;

-- not allowed
SELECT sum(value1) FROM t4 GROUP BY time;

--last returns NULL for tag
--SELECT last(time, value1),last(time, value2),last(time, tag1) FROM t4 GROUP BY tag1;

DROP FOREIGN TABLE t3;
DROP FOREIGN TABLE t4;
DROP FOREIGN TABLE cpu;
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
DROP SERVER server1;
DROP EXTENSION influxdb_fdw ;