--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='Japan';

CREATE EXTENSION influxdb_fdw;
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086') ;
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS(user 'user', password 'pass');
CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, value1 integer) SERVER server1  OPTIONS (table 'cpu');
SELECT * FROM t1;
SELECT * FROM t1 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
SELECT * FROM cpu;
SELECT tag1,value1 FROM cpu;
SELECT value1,time,value2 FROM cpu;
SELECT value1,time_text,value2 FROM cpu;
DROP FOREIGN TABLE cpu;

-- test EXECPT
IMPORT FOREIGN SCHEMA public EXCEPT (cpu) FROM SERVER server1 INTO public;
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

select
	at.attname,
	format_type(at.atttypid, at.atttypmod)
from
	pg_attribute as at
		left join pg_type as tp on (at.atttypid = tp.oid)
where
	at.attnum > 0 and
	at.attrelid = (select relfilenode from pg_class where relname = 'cpu')
order by
	at.attnum
;

SELECT * FROM cpu WHERE value1=100;
SELECT * FROM cpu WHERE value2=0.5;
SELECT * FROM cpu WHERE value3='str';
SELECT * FROM cpu WHERE value4=true;
SELECT * FROM cpu WHERE NOT (value4 AND value1=100);


DROP FOREIGN TABLE cpu;



DROP USER MAPPING FOR CURRENT_USER SERVER server1;
DROP SERVER server1;
DROP EXTENSION influxdb_fdw CASCADE;
