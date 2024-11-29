--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
--Testcase 1:
SET datestyle=ISO;
-- timestamp with time zone differs based on this
--Testcase 2:
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 3:
CREATE EXTENSION influxdb_fdw;
--Testcase 4:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', :SERVER);
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (:AUTHENTICATION);
-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true', schemaless 'true');
--Testcase 6:
SELECT * FROM cpu;
--Testcase 7:
SELECT tags->>'tag1' tag1, (fields->>'value1')::bigint value1 FROM cpu;
--Testcase 8:
SELECT (fields->>'value1')::bigint value1, time, (fields->>'value2')::double precision value2 FROM cpu;
--Testcase 9:
SELECT (fields->>'value1')::bigint value1, time_text, (fields->>'value2')::double precision value2 FROM cpu;

--Testcase 10:
DROP FOREIGN TABLE cpu;
--Testcase 11:
DROP FOREIGN TABLE t3;
--Testcase 12:
DROP FOREIGN TABLE t4;
--Testcase 13:
DROP FOREIGN TABLE tx;
--Testcase 14:
DROP FOREIGN TABLE numbers;

-- test EXECPT
IMPORT FOREIGN SCHEMA public EXCEPT (cpu, t3, t4, tx, numbers) FROM SERVER server1 INTO public OPTIONS(schemaless 'true');
--Testcase 15:
SELECT ftoptions FROM pg_foreign_table;

-- test LIMIT TO
IMPORT FOREIGN SCHEMA public LIMIT TO (cpu) FROM SERVER server1 INTO public OPTIONS(schemaless 'true');
--Testcase 16:
SELECT ftoptions FROM pg_foreign_table;
--Testcase 17:
DROP FOREIGN TABLE cpu;

IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false', schemaless 'true');

--Testcase 18:
SELECT * FROM cpu;
--Testcase 19:
SELECT tags->>'tag1' tag1, (fields->>'value1')::int value1 FROM cpu;
--Testcase 20:
SELECT (fields->>'value1')::int value1, time, (fields->>'value2')::double precision value2 FROM cpu;
--Testcase 21:
SELECT tags->>'tag1' tag1 FROM cpu;
--Testcase 22:
SELECT * FROM numbers;

--Testcase 23:
\d cpu;

--Testcase 24:
SELECT * FROM cpu WHERE (fields->>'value1')::int=100;
--Testcase 25:
SELECT * FROM cpu WHERE (fields->>'value2')::double precision=0.5;
--Testcase 26:
SELECT * FROM cpu WHERE fields->>'value3'='str';
--Testcase 27:
SELECT * FROM cpu WHERE (fields->>'value4')::boolean=true;
--Testcase 28:
SELECT * FROM cpu WHERE NOT ((fields->>'value4')::boolean AND (fields->>'value1')::int=100);
--Testcase 29:
SELECT * FROM cpu WHERE tags->>'tag1'='tag1_A';

--Testcase 30:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE fields->>'value3' IS NULL;
--Testcase 31:
SELECT * FROM cpu WHERE fields->>'value3' IS NULL;
--Testcase 32:
SELECT * FROM cpu WHERE tags->>'tag2' IS NULL;
--Testcase 33:
SELECT * FROM cpu WHERE fields->>'value3' IS NOT NULL;
--Testcase 34:
SELECT * FROM cpu WHERE tags->>'tag2' IS NOT NULL;

-- InfluxDB not support compare timestamp with OR condition
--Testcase 35:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR (fields->>'value2')::double precision = 0.5;

-- InfluxDB not support compare timestamp with != or <>
--Testcase 36:
SELECT * FROM cpu WHERE time != '2015-08-18 09:48:08+09';
--Testcase 37:
SELECT * FROM cpu WHERE time <> '2015-08-18 09:48:08+09';

--Testcase 38:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR (fields->>'value2')::double precision = 0.5;

-- There is inconsitency for search of missing values between tag and field
--Testcase 39:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE fields->>'value3' = '';
--Testcase 40:
SELECT * FROM cpu WHERE fields->>'value3' = '';

--Testcase 41:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE tags->>'tag2' = '';
--Testcase 42:
SELECT * FROM cpu WHERE tags->>'tag2' = '';

--Testcase 43:
SELECT * FROM cpu WHERE tags->>'tag1' IN ('tag1_A', 'tag1_B');
--Testcase 44:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tags->>'tag1' IN ('tag1_A', 'tag1_B');

-- Rows which have no tag are considered to have empty string
--Testcase 45:
SELECT * FROM cpu WHERE tags->>'tag1' NOT IN ('tag1_A', 'tag1_B');
--Testcase 46:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tags->>'tag1' NOT IN ('tag1_A', 'tag1_B');

-- test IN/NOT IN
--Testcase 47:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 48:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 49:
SELECT * FROM cpu WHERE (fields->>'value1')::int NOT IN (100, 97);
--Testcase 50:
SELECT * FROM cpu WHERE (fields->>'value1')::int IN (100, 97);
--Testcase 51:
SELECT * FROM cpu WHERE (fields->>'value2')::double precision IN (0.5, 10.9);
--Testcase 52:
SELECT * FROM cpu WHERE (fields->>'value2')::double precision NOT IN (2, 9.7);
--Testcase 53:
SELECT * FROM cpu WHERE (fields->>'value4')::boolean NOT IN ('true', 'true');
--Testcase 54:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 55:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 56:
SELECT * FROM cpu WHERE (fields->>'value1')::int NOT IN (100, 97);
--Testcase 57:
SELECT * FROM cpu WHERE (fields->>'value1')::int IN (100, 97);
--Testcase 58:
SELECT * FROM cpu WHERE (fields->>'value2')::double precision IN (0.5, 10.9);
--Testcase 59:
SELECT * FROM cpu WHERE (fields->>'value2')::double precision NOT IN (2, 9.7);
--Testcase 60:
SELECT * FROM cpu WHERE (fields->>'value4')::boolean NOT IN ('true', 'true');
--Testcase 61:
SELECT * FROM cpu WHERE (fields->>'value4')::boolean IN ('f', 't');

--Testcase 62:
CREATE FOREIGN TABLE t1(time timestamp with time zone ,tags jsonb OPTIONS(tags 'true'),  fields jsonb OPTIONS (fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true', tags 'tag1');
--Testcase 63:
CREATE FOREIGN TABLE t2(time timestamp ,tags jsonb OPTIONS(tags 'true'),  fields jsonb OPTIONS (fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true', tags 'tag1');

--Testcase 64:
SELECT * FROM t1;
--Testcase 65:
SELECT * FROM t2;
-- In following four queries, timestamp condition is added to InfluxQL as "time = '2015-08-18 00:00:00'"
--Testcase 66:
SELECT * FROM t1 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 67:
SELECT * FROM t1 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

--Testcase 68:
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 69:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

-- pushdown now()
--Testcase 70:
SELECT * FROM t2 WHERE now() > time;
--Testcase 71:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE now() > time;

--Testcase 401:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time < now() + interval '1d';
--Testcase 402:
SELECT * FROM t2 WHERE time < now() + interval '1d';

--Testcase 403:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time < now() - interval '1d';
--Testcase 404:
SELECT * FROM t2 WHERE time < now() - interval '1d';

--Testcase 72:
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';
--Testcase 73:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';

-- InfluxDB does not seem to support time column + interval, so below query returns empty result
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00';
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00';

-- InfluxDB does not support month or year interval, so not push down
--Testcase 74:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';
--Testcase 75:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';

--Testcase 76:
SELECT * FROM t2 WHERE (fields->>'value1')::int = ANY (ARRAY(SELECT (fields->>'value1')::int FROM t1 WHERE (fields->>'value1')::int < 1000));

-- ANY with ARRAY expression
--Testcase 77:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 78:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 79:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 80:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 81:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 82:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ANY(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 83:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 84:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ANY(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 85:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 86:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ANY(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 87:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ANY(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 88:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ANY(ARRAY[1, (fields->>'a')::int + 1]);

-- ANY with ARRAY const
--Testcase 89:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY(ARRAY[1, 2]);
--Testcase 90:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY(ARRAY[1, 2]);

--Testcase 91:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY(ARRAY[1, 2]);
--Testcase 92:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY(ARRAY[1, 2]);

--Testcase 93:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ANY(ARRAY[1, 2]);
--Testcase 94:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ANY(ARRAY[1, 2]);

--Testcase 95:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ANY(ARRAY[1, 2]);
--Testcase 96:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ANY(ARRAY[1, 2]);

--Testcase 97:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ANY(ARRAY[1, 2]);
--Testcase 98:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ANY(ARRAY[1, 2]);

--Testcase 99:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ANY(ARRAY[1, 2]);
--Testcase 100:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ANY(ARRAY[1, 2]);

--Testcase 101:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY('{1, 2, 3}');
--Testcase 102:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ANY('{1, 2, 3}');
--Testcase 103:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY('{1, 2, 3}');
--Testcase 104:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ANY('{1, 2, 3}');

-- ALL with ARRAY expression
--Testcase 105:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ALL(ARRAY[1, (fields->>'a')::int * 1]);
--Testcase 106:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ALL(ARRAY[1, (fields->>'a')::int * 1]);

--Testcase 107:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ALL(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 108:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ALL(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 109:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ALL(ARRAY[1, (fields->>'a')::int / 1]);
--Testcase 110:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ALL(ARRAY[1, (fields->>'a')::int / 1]);

--Testcase 111:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ALL(ARRAY[1, (fields->>'a')::int + 1]);
--Testcase 112:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ALL(ARRAY[1, (fields->>'a')::int + 1]);

--Testcase 113:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ALL(ARRAY[1, (fields->>'a')::int - 1]);
--Testcase 114:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ALL(ARRAY[1, (fields->>'a')::int - 1]);

--Testcase 115:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ALL(ARRAY[2, (fields->>'a')::int + 1]);
--Testcase 116:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ALL(ARRAY[2, (fields->>'a')::int + 1]);

-- ALL with ARRAY const
--Testcase 117:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ALL(ARRAY[1, 1]);
--Testcase 118:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int = ALL(ARRAY[1, 1]);

--Testcase 119:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ALL(ARRAY[1, 3]);
--Testcase 120:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <> ALL(ARRAY[1, 3]);

--Testcase 121:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ALL(ARRAY[1, 2]);
--Testcase 122:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int >= ALL(ARRAY[1, 2]);

--Testcase 123:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ALL(ARRAY[1, 2]);
--Testcase 124:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int <= ALL(ARRAY[1, 2]);

--Testcase 125:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ALL(ARRAY[0, 1]);
--Testcase 126:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int > ALL(ARRAY[0, 1]);

--Testcase 127:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ALL(ARRAY[2, 3]);
--Testcase 128:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE (fields->>'a')::int < ALL(ARRAY[2, 3]);

-- ANY/ALL with TEXT ARRAY const
--Testcase 129:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' = ANY(ARRAY['One', 'Two']);
--Testcase 130:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' = ANY(ARRAY['One', 'Two']);

--Testcase 131:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' <> ALL(ARRAY['One', 'Four']);
--Testcase 132:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' <> ALL(ARRAY['One', 'Four']);

--Testcase 133:
EXPLAIN VERBOSE
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' > ANY(ARRAY['One', 'Two']);
--Testcase 134:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' > ANY(ARRAY['One', 'Two']);

--Testcase 135:
EXPLAIN VERBOSE
SELECT * FROM numbers WHERE fields->>'b' > ALL(ARRAY['Four', 'Five']);
--Testcase 136:
SELECT (fields->>'a')::int a, fields->>'b' b FROM numbers WHERE fields->>'b' > ALL(ARRAY['Four', 'Five']);

--Testcase 137:
DROP FOREIGN TABLE numbers;

--Testcase 138:
ALTER SERVER server1 OPTIONS (SET dbname 'no such database');
--Testcase 139:
SELECT * FROM t1;
--Testcase 140:
ALTER SERVER server1 OPTIONS (SET dbname 'mydb');
--Testcase 141:
SELECT * FROM t1;

-- map time column to both timestamp and text
--Testcase 142:
CREATE FOREIGN TABLE t5(t timestamp OPTIONS (column_name 'time'), tag1 text OPTIONS (column_name 'time'), fields jsonb OPTIONS (fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 143:
SELECT * FROM t5;

--get version
--Testcase 144:
\df influxdb_fdw*
--Testcase 145:
SELECT * FROM public.influxdb_fdw_version();
--Testcase 146:
SELECT influxdb_fdw_version();
--Test pushdown LIMIT...OFFSET
--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 148:
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 149:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 1;

--Testcase 150:
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 1;

--Testcase 151:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 152:
SELECT ctid, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 153:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM t2 LIMIT 10 OFFSET 20;

--Testcase 154:
SELECT ctid, * FROM t2 LIMIT 10 OFFSET 20;

--Testcase 155:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM
  t1
  LEFT JOIN t2
  ON (t2.fields->>'value1')::int = 123,
  LATERAL (SELECT (t2.fields->>'value1')::int value1, t1.tags->>'tag1' tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss
WHERE (t1.fields->>'value1')::int = ss.value1;

--Testcase 156:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM
  t1
  LEFT JOIN t2
  ON (t2.fields->>'value1')::int = 123,
  LATERAL (SELECT (t2.fields->>'value1')::int value1, t1.tags->>'tag1' tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss1,
  LATERAL (SELECT ss1.* from t3 LIMIT 1 OFFSET 20) AS ss2
WHERE (t1.fields->>'value1')::int = ss2.value1;

--Testcase 157:
DROP FOREIGN TABLE cpu;
--Testcase 158:
DROP FOREIGN TABLE t1;
--Testcase 159:
DROP FOREIGN TABLE t2;
--Testcase 160:
DROP FOREIGN TABLE t3;
--Testcase 161:
DROP FOREIGN TABLE t4;
--Testcase 162:
DROP FOREIGN TABLE t5;
--Testcase 163:
DROP FOREIGN TABLE tx;

-- test INSERT, DELETE
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true', schemaless 'true');
--Testcase 204:
CREATE FOREIGN TABLE cpu_nsc (time timestamp with time zone, time_text text, tag1 text, tag2 text, value1 int, value2 float, value3 text, value4 boolean) SERVER server1 OPTIONS (table 'cpu', tags 'tag1, tag2');
--Testcase 164:
SELECT * FROM cpu;
--Testcase 165:
EXPLAIN VERBOSE
INSERT INTO cpu_nsc(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test1', true);
--Testcase 166:
INSERT INTO cpu_nsc(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test', true);
--Testcase 167:
SELECT * FROM cpu;

--Testcase 168:
EXPLAIN VERBOSE
INSERT INTO cpu_nsc(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 169:
INSERT INTO cpu_nsc(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 170:
SELECT * FROM cpu;

--Testcase 171:
INSERT INTO cpu_nsc(tag2, value1) VALUES('tag2_KH', 400);
--Testcase 172:
SELECT tags->>'tag1' tag1, tags->>'tag2' tag2, (fields->>'value1')::bigint value1, (fields->>'value2')::double precision value2, fields->>'value3' value3, (fields->>'value4')::boolean value4 FROM cpu;

--Testcase 173:
EXPLAIN VERBOSE
DELETE FROM cpu_nsc WHERE tag2 = 'tag2_KH';
--Testcase 174:
DELETE FROM cpu_nsc WHERE tag2 = 'tag2_KH';
--Testcase 175:
SELECT tags->>'tag1' tag1, tags->>'tag2' tag2, (fields->>'value1')::bigint value1, (fields->>'value2')::double precision value2, fields->>'value3' value3, (fields->>'value4')::boolean value4 FROM cpu;

--Testcase 176:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 177:
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 178:
SELECT * FROM cpu;

--Testcase 179:
EXPLAIN VERBOSE
DELETE FROM cpu_nsc WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 180:
DELETE FROM cpu_nsc WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 181:
SELECT * FROM cpu;

-- Test INSERT, DELETE with time_text column
--Testcase 182:
INSERT INTO cpu_nsc(time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02T00:00:00Z', 'tag1_D', 'tag2_E', 600, 20.2, 'test3', true);
--Testcase 183:
SELECT * FROM cpu;

--Testcase 184:
INSERT INTO cpu_nsc(time_text, tag1, value2) VALUES('2021-02-02T00:00:00.123456789Z', 'tag1_P', 25.8);
--Testcase 185:
SELECT * FROM cpu;

--Testcase 186:
INSERT INTO cpu_nsc(time_text, tag1, value2) VALUES('2021-02-02 00:00:01', 'tag1_J', 37.1);
--Testcase 187:
SELECT * FROM cpu;

--Testcase 188:
INSERT INTO cpu_nsc(time, time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02 00:00:01+05', '2021-02-02T00:00:02.123456789Z', 'tag1_A', 'tag2_B', 200, 5.5, 'test', true);
--Testcase 189:
SELECT * FROM cpu;

--Testcase 190:
INSERT INTO cpu_nsc(time_text, time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-03T00:00:03.123456789Z', '2021-03-03 00:00:01+07', 'tag1_C', 'tag2_D', 200, 5.5, 'test', true);
--Testcase 191:
SELECT * FROM cpu;

--Testcase 192:
EXPLAIN VERBOSE
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 193:
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 194:
SELECT * FROM cpu;

--Testcase 195:
EXPLAIN VERBOSE
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 196:
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 197:
SELECT * FROM cpu;

--Testcase 198:
EXPLAIN VERBOSE
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 199:
DELETE FROM cpu_nsc WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 200:
SELECT * FROM cpu;

-- InfluxDB_FDW will store time data for Field values as a strings
--Testcase 209:
CREATE FOREIGN TABLE tmp_time (
time timestamp,
tags jsonb OPTIONS (tags 'true'),
fields jsonb OPTIONS (fields 'true')
) SERVER server1 OPTIONS (table 'tmp_time', schemaless 'true', tags 'c1');
-- Use this foreign table to insert data to the table tmp_time in non-schemaless mode.
--Testcase 210:
CREATE FOREIGN TABLE tmp_time_nsc (
time timestamp,
c1 time,
c2 timestamp,
c3 timestamp with time zone,
c4 timestamp,
c5 timestamp with time zone,
agvState character varying NULL COLLATE pg_catalog."default",
value numeric NULL
) SERVER server1 OPTIONS (table 'tmp_time');

--Testcase 211:
SELECT * FROM tmp_time_nsc;
--Testcase 212:
INSERT INTO tmp_time_nsc (time, c1, agvState, value) VALUES ('1900-01-01 01:01:01', '01:02:03', 'state 1', 0.1);
--Testcase 213:
INSERT INTO tmp_time_nsc (time, c1, agvState, value) VALUES ('2100-01-01 01:01:01', '04:05:06', 'state 2', 0.2);
--Testcase 214:
INSERT INTO tmp_time_nsc (time, c1, agvState, value) VALUES ('1990-01-01 01:01:01', '07:08:09', 'state 3', 0.3);
--Testcase 215:
INSERT INTO tmp_time_nsc (time, c2) VALUES ('2020-12-27 03:02:56.634467', '1950-02-02 02:02:02');
--Testcase 216:
INSERT INTO tmp_time_nsc (time, c3, agvState, value) VALUES ('2021-12-27 03:02:56.668301', '1800-02-02 02:02:02+9', 'state 5', 0.5);
--Testcase 217:
INSERT INTO tmp_time_nsc (time, c1, c2, c3, agvState, value) VALUES ('2022-05-06 07:08:09', '07:08:09', '2022-05-06 07:08:09', '2022-05-06 07:08:09+9', 'state 6', 0.6);
--Testcase 261:
INSERT INTO tmp_time_nsc (time, c1, c2, c3, agvState, value) VALUES ('2023-05-06 07:08:09', '07:08:10', '2023-05-06 07:08:09', '2023-05-06 07:08:09+9', 'state 7', 0.7);
--Testcase 482:
INSERT INTO tmp_time_nsc (time, c1, c2, c3, c4, c5, agvState, value) VALUES ('2023-05-06 07:08:09', '07:08:10', '2023-05-06 07:08:09', '2023-05-06 07:08:09+9', '2023-05-06 08:08:09', '2023-05-06 08:08:09+9', 'state 8', 0.8);
--Testcase 483:
INSERT INTO tmp_time_nsc (time, c1, c2, c3, c4, c5, agvState, value) VALUES ('2025-05-06 07:08:09', '07:08:10', '2025-05-06 07:08:09', '2025-05-06 07:08:09+9', '2025-05-06 08:08:09', '2025-05-06 08:08:09+9', 'state 9', 0.9);
--Testcase 218:
-- 1800-02-02 02:02:02+9 is Daylight Saving Time (DST) changes in Japan.
-- Timezone setting Japan so it will plus 18s:59
-- https://www.timeanddate.com/time/zone/japan/tokyo?syear=1850
--Testcase 362:
SELECT * FROM tmp_time;

/* For time key column, InfluxDB does not support the operators !=, <> */
--Testcase 363:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != '2022-05-06 07:08:09';
--Testcase 364:
SELECT * FROM tmp_time WHERE time != '2022-05-06 07:08:09';

--Testcase 365:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <> '2022-05-06 07:08:09';
--Testcase 366:
SELECT * FROM tmp_time WHERE time <> '2022-05-06 07:08:09';

--Testcase 416:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != (fields->>'c2')::timestamp;
--Testcase 417:
SELECT * FROM tmp_time WHERE time != (fields->>'c2')::timestamp;

--Testcase 418:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != (fields->>'c2')::timestamp + interval '1d';
--Testcase 419:
SELECT * FROM tmp_time WHERE time != (fields->>'c2')::timestamp + interval '1d'; 

--Testcase 420:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 421:
SELECT * FROM tmp_time WHERE time != (select max(fields->>'c2')::timestamp from tmp_time);

--Testcase 422:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != now();
--Testcase 423:
SELECT * FROM tmp_time WHERE time != now();

--Testcase 424:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != now() + interval '1d';
--Testcase 425:
SELECT * FROM tmp_time WHERE time != now() + interval '1d';

-- For comparison between tags/fields and time constant, tags/fields column, param , InfluxDB support the operator !=, <>
--Testcase 367:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' != '2022-05-06 07:08:09+9';
--Testcase 368:
SELECT * FROM tmp_time WHERE fields->>'c3' != '2022-05-06 07:08:09+9';

--Testcase 369:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' <> '2022-05-06 07:08:09+9';
--Testcase 370:
SELECT * FROM tmp_time WHERE fields->>'c3' <> '2022-05-06 07:08:09+9';

--Testcase 370:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' != '2022-05-06 07:08:09';
--Testcase 371:
SELECT * FROM tmp_time WHERE fields->>'c2' != '2022-05-06 07:08:09';

--Testcase 372:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <> '2022-05-06 07:08:09';
--Testcase 373:
SELECT * FROM tmp_time WHERE fields->>'c2' <> '2022-05-06 07:08:09';

--Testcase 374:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' != '07:08:09';
--Testcase 375:
SELECT * FROM tmp_time WHERE tags->>'c1' != '07:08:09';

--Testcase 376:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' <> '07:08:09';
--Testcase 377:
SELECT * FROM tmp_time WHERE tags->>'c1' <> '07:08:09';

--Testcase 426:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <> fields->>'c4';
--Testcase 427:
SELECT * FROM tmp_time WHERE fields->>'c2' <> fields->>'c4';

--Testcase 428:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' != (select max(fields->>'c2') from tmp_time) ;
--Testcase 429:
SELECT * FROM tmp_time WHERE fields->>'c2' != (select max(fields->>'c2') from tmp_time) ;

--Testcase 430:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != time;
--Testcase 431:
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != time;

--Testcase 432:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != now();
--Testcase 433:
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != now();

--Testcase 434:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != now() + interval '1d';
--Testcase 435:
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp != now() + interval '1d';

/* InfluxDB does not pushdown comparison between interval and interval */
--Testcase 263:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone <= interval '1d';
--Testcase 264:
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone <= interval '1d';

--Testcase 265:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone >= interval '1d';
--Testcase 266:
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone >= interval '1d';

--Testcase 267:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone = interval '25896 days 01:00:54.634467';
--Testcase 268:
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone = interval '25896 days 01:00:54.634467';

--Testcase 269:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone > interval '1d';
--Testcase 270:
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone > interval '1d';

--Testcase 271:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone < interval '1d';
--Testcase 272:
SELECT * FROM tmp_time WHERE time - (fields->>'c2')::timestamp without time zone < interval '1d';

--Testcase 273:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time - (fields->>'c2')::timestamp without time zone) - ((tags->>'c1')::time - (tags->>'c1')::time) > interval '-1d';
--Testcase 274:
SELECT * FROM tmp_time WHERE (time - (fields->>'c2')::timestamp without time zone) - ((tags->>'c1')::time - (tags->>'c1')::time) > interval '-1d';

--Testcase 275:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time - (fields->>'c2')::timestamp without time zone) > ((tags->>'c1')::time - (tags->>'c1')::time) + interval '-1d';
--Testcase 276:
SELECT * FROM tmp_time WHERE (time - (fields->>'c2')::timestamp without time zone) > ((tags->>'c1')::time - (tags->>'c1')::time) + interval '-1d';

--Testcase 383:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time + interval '1d') - (((fields->>'c2')::timestamp without time zone) + interval '1d') > interval '-1d';
--Testcase 384:
SELECT * FROM tmp_time WHERE (time + interval '1d') - (((fields->>'c2')::timestamp without time zone) + interval '1d') > interval '-1d';

/* InfluxDB does not pushdown comparison time expression with time except now() with time key */
--Testcase 385:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time + interval '1d') > now() + interval '-1d';
--Testcase 386:
SELECT * FROM tmp_time WHERE (time + interval '1d') > now() + interval '-1d';

--Testcase 387:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time - interval '1d') > now() - interval '-1d';
--Testcase 388:
SELECT * FROM tmp_time WHERE (time - interval '1d') > now() - interval '-1d';

--Testcase 389:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (((fields->>'c2')::timestamp without time zone) + interval '1d') < now() + interval '-1d';
--Testcase 390:
SELECT * FROM tmp_time WHERE (((fields->>'c2')::timestamp without time zone) + interval '1d') < now() + interval '-1d';

--Testcase 391:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (((fields->>'c2')::timestamp without time zone) - interval '1d') < now() - interval '-1d';
--Testcase 392:
SELECT * FROM tmp_time WHERE (((fields->>'c2')::timestamp without time zone) - interval '1d') < now() - interval '-1d';

/* Result is empty, the purpose is to check pushdown or not */
--Testcase 397:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp = now() + interval '-1d';
--Testcase 398:
SELECT * FROM tmp_time WHERE (fields->>'c2')::timestamp = now() + interval '-1d';  -- empty

--Testcase 399:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = (fields->>'c2')::timestamp + interval '25896 days 01:00:54.634467';
--Testcase 400:
SELECT * FROM tmp_time WHERE time = (fields->>'c2')::timestamp + interval '25896 days 01:00:54.634467';

--Testcase 277:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (select max(fields->>'c3') from tmp_time)::timestamp without time zone  < interval '109541 days 00:58:59';
--Testcase 278:
SELECT * FROM tmp_time WHERE time - (select max(fields->>'c3') from tmp_time)::timestamp without time zone  < interval '109541 days 00:58:59';

-- InfluxDB support pushdown now() +/- interval in comparison with time key column
--Testcase 393:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < now() - interval '-1d';
--Testcase 394:
SELECT * FROM tmp_time WHERE time < now() - interval '-1d';

--Testcase 395:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < now() - interval '-1d' AND  time > '1990-01-01 01:01:01';
--Testcase 396:
SELECT * FROM tmp_time WHERE time < now() - interval '-1d' AND  time > '1990-01-01 01:01:01';

-- InfluxDB FDW does not support pushdown function (not now()) in condition
--Testcase 410:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamp with time zone;

--Testcase 411:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' < time;
--Testcase 412:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' < time;

--Testcase 413:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > '2022-05-06 07:08:09+9';
--Testcase 414:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > '2022-05-06 07:08:09+9';

--Testcase 436:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') < (fields->>'c3')::timestamptz;
--Testcase 437:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') < (fields->>'c3')::timestamptz;

--Testcase 438:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') = (fields->>'c3')::timestamptz;
--Testcase 439:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') = (fields->>'c3')::timestamptz;

--Testcase 440:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') != (fields->>'c3')::timestamptz;
--Testcase 441:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') != (fields->>'c3')::timestamptz;

--Testcase 442:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > (fields->>'c3')::timestamptz;
--Testcase 443:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > (fields->>'c3')::timestamptz;

--Testcase 415:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamp;

/* InfluxDB does not pushdown pseudocontant expression (there is no Var node) */
--Testcase 378:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (select min(fields->>'c3') from tmp_time) <= '2024-05-06 07:08:09+09';
--Testcase 379:
SELECT * FROM tmp_time WHERE (select min(fields->>'c3') from tmp_time) <= '2024-05-06 07:08:09+09';

--Testcase 380:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (select min(fields->>'c3') from tmp_time) <= (select max(fields->>'c2') from tmp_time);
--Testcase 381:
SELECT * FROM tmp_time WHERE (select min(fields->>'c3') from tmp_time) <= (select max(fields->>'c2') from tmp_time);

/* InfluxDB does not support pushdown =, <, >, >=, <= operators in comparison between time key and time colum */
--Testcase 446:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = (fields->>'c2')::timestamp;
--Testcase 447:
SELECT * FROM tmp_time WHERE time = (fields->>'c2')::timestamp;

--Testcase 448:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time >= (fields->>'c2')::timestamp;
--Testcase 449:
SELECT * FROM tmp_time WHERE time >= (fields->>'c2')::timestamp;

--Testcase 450:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > (fields->>'c2')::timestamp;
--Testcase 451:
SELECT * FROM tmp_time WHERE time > (fields->>'c2')::timestamp;

--Testcase 452:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < (fields->>'c2')::timestamp;
--Testcase 453:
SELECT * FROM tmp_time WHERE time < (fields->>'c2')::timestamp;

--Testcase 454:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <= (fields->>'c2')::timestamp;
--Testcase 455:
SELECT * FROM tmp_time WHERE time <= (fields->>'c2')::timestamp;

-- InfluxDB supports pushdown =, <, >, >=, <= operators in comparison between time key with time const, time param
--Testcase 279:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '2022-05-06 07:08:09';
--Testcase 280:
SELECT * FROM tmp_time WHERE time > '2022-05-06 07:08:09';

--Testcase 281:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < '2022-05-06 07:08:09';
--Testcase 282:
SELECT * FROM tmp_time WHERE time < '2022-05-06 07:08:09';

--Testcase 283:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time >= '2022-05-06 07:08:09';
--Testcase 284:
SELECT * FROM tmp_time WHERE time >= '2022-05-06 07:08:09';

--Testcase 285:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <= '2022-05-06 07:08:09';
--Testcase 286:
SELECT * FROM tmp_time WHERE time <= '2022-05-06 07:08:09';

--Testcase 287:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = '2022-05-06 07:08:09';
--Testcase 288:
SELECT * FROM tmp_time WHERE time = '2022-05-06 07:08:09';

--Testcase 405:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND time < '2023-05-06 07:08:09';
--Testcase 406:
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND time < '2023-05-06 07:08:09';

--Testcase 456:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 457:
SELECT * FROM tmp_time WHERE time = (select max(fields->>'c2')::timestamp from tmp_time);

--Testcase 458:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 459:
SELECT * FROM tmp_time WHERE time > (select max(fields->>'c2')::timestamp from tmp_time);

--Testcase 460:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 461:
SELECT * FROM tmp_time WHERE time < (select max(fields->>'c2')::timestamp from tmp_time);

--Testcase 462:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time >= (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 463:
SELECT * FROM tmp_time WHERE time >= (select max(fields->>'c2')::timestamp from tmp_time);

--Testcase 464:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <= (select max(fields->>'c2')::timestamp from tmp_time);
--Testcase 465:
SELECT * FROM tmp_time WHERE time <= (select max(fields->>'c2')::timestamp from tmp_time);

-- SELECT with sub-query returning timestamp with timezone value
--Testcase 233:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' = (SELECT fields->>'c3' FROM tmp_time WHERE fields->>'c3' = '2022-05-06 07:08:09+09');
--Testcase 234:
SELECT * FROM tmp_time WHERE fields->>'c3' = (SELECT fields->>'c3' FROM tmp_time WHERE fields->>'c3' = '2022-05-06 07:08:09+09');

--Testcase 299:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' > (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');
--Testcase 300:
SELECT * FROM tmp_time WHERE fields->>'c3' > (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');

--Testcase 301:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' < (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');
--Testcase 302:
SELECT * FROM tmp_time WHERE fields->>'c3' < (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');

--Testcase 303:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' >= (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');
--Testcase 304:
SELECT * FROM tmp_time WHERE fields->>'c3' >= (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');

--Testcase 305:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c3' <= (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');
--Testcase 306:
SELECT * FROM tmp_time WHERE fields->>'c3' <= (SELECT fields->>'c3' FROM tmp_time WHERE  fields->>'c3' = '2022-05-06 07:08:09+09');

-- SELECT with sub-query returning timestamp value
--Testcase 235:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 236:
SELECT * FROM tmp_time WHERE fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

--Testcase 307:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' > (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 308:
SELECT * FROM tmp_time WHERE fields->>'c2' > (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

--Testcase 309:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' < (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 310:
SELECT * FROM tmp_time WHERE fields->>'c2' < (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

--Testcase 311:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' >= (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 312:
SELECT * FROM tmp_time WHERE fields->>'c2' >= (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

--Testcase 313:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <= (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 314:
SELECT * FROM tmp_time WHERE fields->>'c2' <= (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

-- SELECT with sub-query returning time value
--Testcase 237:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');
--Testcase 238:
SELECT * FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');

--Testcase 315:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');
--Testcase 316:
SELECT * FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');

--Testcase 317:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');
--Testcase 318:
SELECT * FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');

--Testcase 319:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');
--Testcase 320:
SELECT * FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');

--Testcase 321:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');
--Testcase 322:
SELECT * FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09');

-- Mixing pushdown condition and not pushdown condition
--Testcase 407:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND (fields->>'c2')::timestamp > '1950-02-02 02:02:02' AND (select min(fields->>'c2') from tmp_time)::timestamp <= time;
--Testcase 408:
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND (fields->>'c2')::timestamp > '1950-02-02 02:02:02' AND (select min(fields->>'c2') from tmp_time)::timestamp <= time;

--Testcase 408:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' OR (fields->>'c2')::timestamp > '1950-02-02 02:02:02' OR (select min(fields->>'c2') from tmp_time)::timestamp <= time;
--Testcase 409:
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' OR (fields->>'c2')::timestamp > '1950-02-02 02:02:02' OR (select min(fields->>'c2') from tmp_time)::timestamp <= time;

-- Sub-query in the expression
--Testcase 248:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time = INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 249:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time = INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 323:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time < INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 324:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time < INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 325:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time > INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 326:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time > INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 327:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time <= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 328:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time <= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 329:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time >= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 330:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time >= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 250:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' = INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 251:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' = INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 331:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' > INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 332:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' > INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 333:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' < INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 334:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' < INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 335:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' >= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 336:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' >= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

--Testcase 337:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' <= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;
--Testcase 338:
SELECT * FROM tmp_time WHERE (tags->>'c1')::time + INTERVAL '03:03:03' <= INTERVAL '03:03:03' + ((SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06'))::interval;

-- Sub-query in multiple conditions (does not support OR)
--Testcase 252:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') 
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 253:
SELECT * FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') 
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 339:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 340:
SELECT * FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 341:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 342:
SELECT * FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 343:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 344:
SELECT * FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 345:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 346:
SELECT * FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
AND fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

-- Aggregation with sub-query 
--Testcase 254:
EXPLAIN VERBOSE
SELECT fields->>'c2' FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY fields->>'c2';
--Testcase 255:
SELECT fields->>'c2' FROM tmp_time WHERE tags->>'c1' = (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY fields->>'c2';

--Testcase 347:
EXPLAIN VERBOSE
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06') GROUP BY tags->>'c1';
--Testcase 348:
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' > (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '04:05:06') GROUP BY tags->>'c1';

--Testcase 349:
EXPLAIN VERBOSE
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';
--Testcase 350:
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' < (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';

--Testcase 351:
EXPLAIN VERBOSE
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';
--Testcase 352:
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' >= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';

--Testcase 353:
EXPLAIN VERBOSE
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';
--Testcase 354:
SELECT tags->>'c1' FROM tmp_time WHERE tags->>'c1' <= (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') GROUP BY tags->>'c1';

-- Aggregation + Having clause with sub-query 
--Testcase 256:
EXPLAIN VERBOSE
SELECT fields->>'c3', fields->>'c2' FROM tmp_time WHERE tags->>'c1' =  (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
GROUP BY fields->>'c3', fields->>'c2' HAVING fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 257:
SELECT fields->>'c3', fields->>'c2' FROM tmp_time WHERE tags->>'c1' =  (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09')
GROUP BY fields->>'c3', fields->>'c2' HAVING fields->>'c2' = (SELECT fields->>'c2' FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

-- JOIN with sub-query
--Testcase 258:
EXPLAIN VERBOSE
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON t1.tags->>'c1' = t2.tags->>'c1'
AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 259:
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON t1.tags->>'c1' = t2.tags->>'c1'
AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

--Testcase 355:
EXPLAIN VERBOSE
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');
--Testcase 356:
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09');

-- Aggregation and JOIN with sub-query
--Testcase 357:
EXPLAIN VERBOSE
SELECT t1.tags->>'c1' FROM tmp_time t1 JOIN tmp_time t2 ON t1.tags->>'c1' = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09') GROUP BY t1.tags->>'c1';
--Testcase 358:
SELECT t1.tags->>'c1' FROM tmp_time t1 JOIN tmp_time t2 ON t1.tags->>'c1' = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09') GROUP BY t1.tags->>'c1';

--Testcase 359:
EXPLAIN VERBOSE
SELECT t1.tags->>'c1' FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09') GROUP BY t1.tags->>'c1';
--Testcase 360:
SELECT t1.tags->>'c1' FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(tags->>'c1') FROM tmp_time WHERE tags->>'c1' = '07:08:09') = t2.tags->>'c1' AND t1.fields->>'c2' = (SELECT max(fields->>'c2') FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09') GROUP BY t1.tags->>'c1';

-- Test case is reported in the Github Issue #40 of influxdb_fdw
--Testcase 260:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 361:
SELECT * FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time > now()-interval '1d');

/* InfluxDB FDW does not pushdown comparision between tags/fields with tags/fields, time constant, time parameter using
 the operators <, >, <=, >= */
--Testcase 466:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' > fields->>'c4';
--Testcase 467:
SELECT * FROM tmp_time WHERE fields->>'c2' > fields->>'c4';

--Testcase 468:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' >= fields->>'c4';
--Testcase 469:
SELECT * FROM tmp_time WHERE fields->>'c2' >= fields->>'c4';

--Testcase 470:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' < fields->>'c4';
--Testcase 471:
SELECT * FROM tmp_time WHERE fields->>'c2' < fields->>'c4';

--Testcase 472:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <= fields->>'c4';
--Testcase 473:
SELECT * FROM tmp_time WHERE fields->>'c2' <= fields->>'c4';

--Testcase 289:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' > '1950-02-02 02:02:02';
--Testcase 290:
SELECT * FROM tmp_time WHERE fields->>'c2' > '1950-02-02 02:02:02';

--Testcase 291:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' < '2022-05-06 07:08:09';
--Testcase 292:
SELECT * FROM tmp_time WHERE fields->>'c2' < '2022-05-06 07:08:09';

--Testcase 293:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' >= '1950-02-02 02:02:02';
--Testcase 294:
SELECT * FROM tmp_time WHERE fields->>'c2' >= '1950-02-02 02:02:02';

--Testcase 295:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <= '2022-05-06 07:08:09';
--Testcase 296:
SELECT * FROM tmp_time WHERE fields->>'c2' <= '2022-05-06 07:08:09';

--Testcase 297:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09';
--Testcase 298:
SELECT * FROM tmp_time WHERE fields->>'c2' = '2022-05-06 07:08:09';

--Testcase 219:
EXPLAIN VERBOSE
SELECT fields->>'c3' FROM tmp_time WHERE fields->>'c3' = '2022-05-06 07:08:09+09';
--Testcase 220:
SELECT fields->>'c3' FROM tmp_time WHERE fields->>'c3' = '2022-05-06 07:08:09+09';

--Testcase 474:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' > (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 475:
SELECT * FROM tmp_time WHERE fields->>'c2' > (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 476:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' >= (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 477:
SELECT * FROM tmp_time WHERE fields->>'c2' >= (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 478:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' < (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 479:
SELECT * FROM tmp_time WHERE fields->>'c2' < (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 480:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE fields->>'c2' <= (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 481:
SELECT * FROM tmp_time WHERE fields->>'c2' <= (SELECT max(fields->>'c2') FROM tmp_time WHERE time > now()-interval '1d');

-- DELETE with sub-query returning time value.
--Testcase 227:
EXPLAIN (VERBOSE, COSTS OFF)
DELETE FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time = '1900-01-01 01:01:01');
--Testcase 228:
DELETE FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time = '1900-01-01 01:01:01');

--Testcase 229:
SELECT * FROM tmp_time;

-- Test time conversion in comparison with tags/field column
--Testcase 510:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (fields->>'c3')::timestamptz = '1800-02-02 02:02:02+9';
--Testcase 511:
SELECT * FROM tmp_time WHERE (fields->>'c3')::timestamptz = '1800-02-02 02:02:02+9';

-- Test time conversion in comparison with time key column
--Testcase 512:
ALTER FOREIGN TABLE tmp_time_nsc ALTER COLUMN time TYPE timestamptz;
--Testcase 519:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamptz;
--Testcase 513:
INSERT INTO tmp_time_nsc (time, c1, agvState, value) VALUES ('1900-01-01 01:01:01+9', '02:02:04', 'state 10', 1);

--Testcase 514:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = '1900-01-01 01:01:01+9';
--Testcase 515:
SELECT * FROM tmp_time WHERE time = '1900-01-01 01:01:01+9';

--Testcase 516:
DELETE FROM tmp_time WHERE time = '1900-01-01 01:01:01+9';

--Testcase 517:
SELECT * FROM tmp_time;

--Testcase 518:
ALTER FOREIGN TABLE tmp_time_nsc ALTER COLUMN time TYPE timestamp;
--Testcase 520:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamp;

-- Recover data
:RECOVER_INIT_TXT_DROP_BUCKET;
:RECOVER_INIT_TXT_CREATE_BUCKET;
:RECOVER_INIT_TXT;

--Testcase 201:
DROP FOREIGN TABLE cpu_nsc;

-- Validate foreign table in schemaless mode
-- time column data type is not either timestamp or timestamp without timezone
--Testcase 206:
CREATE FOREIGN TABLE ftcpu (time time, tags jsonb options (tags 'true'), fields jsonb options(fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 207:
SELECT * FROM ftcpu;
--Testcase 208:
DROP FOREIGN TABLE ftcpu;

-- time_text column data type is not text
--Testcase 209:
CREATE FOREIGN TABLE ftcpu (time timestamp, time_text int, tags jsonb options (tags 'true'), fields jsonb options(fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 210:
SELECT * FROM ftcpu;
--Testcase 211:
DROP FOREIGN TABLE ftcpu;

-- time column option value is not 'time'
--Testcase 212:
CREATE FOREIGN TABLE ftcpu (t timestamp options (column_name 'time1'), tags jsonb options (tags 'true'), fields jsonb options(fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 213:
SELECT * FROM ftcpu;
--Testcase 214:
DROP FOREIGN TABLE ftcpu;

-- tags and fields column data type is not jsonb
--Testcase 215:
CREATE FOREIGN TABLE ftcpu (time timestamp, tags json options (tags 'true'), fields json options(fields 'true')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 216:
SELECT * FROM ftcpu;
--Testcase 217:
DROP FOREIGN TABLE ftcpu;

-- tags and fields column option values are not 'true'
--Testcase 218:
CREATE FOREIGN TABLE ftcpu (time timestamp, tags jsonb options (tags 'false'), fields jsonb options(fields 'false')) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 219:
SELECT * FROM ftcpu;
--Testcase 220:
DROP FOREIGN TABLE ftcpu;

-- using other column name which is not 'time', 'time_text', 'tags' and 'fields'.
--Testcase 221:
CREATE FOREIGN TABLE ftcpu (time timestamp, time_text text, tags jsonb options (tags 'true'), fields jsonb options(fields 'true'), other timestamp) SERVER server1 OPTIONS (table 'cpu', schemaless 'true');
--Testcase 222:
SELECT * FROM ftcpu;

--Testcase 223:
ALTER FOREIGN TABLE ftcpu DROP other;
--Testcase 224:
ALTER FOREIGN TABLE ftcpu ADD other text;
--Testcase 225:
SELECT * FROM ftcpu;

--Testcase 226:
ALTER FOREIGN TABLE ftcpu DROP other;
--Testcase 227:
ALTER FOREIGN TABLE ftcpu ADD other jsonb;
--Testcase 228:
SELECT * FROM ftcpu;

--Testcase 229:
ALTER FOREIGN TABLE ftcpu DROP other;
--Testcase 230:
ALTER FOREIGN TABLE ftcpu ADD other int;
--Testcase 231:
SELECT * FROM ftcpu;
--Testcase 232:
DROP FOREIGN TABLE ftcpu;

--Testcase 767:
CREATE FOREIGN TABLE sensor_tbl (
time timestamp,
tags jsonb OPTIONS (tags 'true'),
fields jsonb OPTIONS (fields 'true')
) SERVER server1 OPTIONS (table 'sensor', schemaless 'true', tags 'device');

--Testcase 484:
CREATE FOREIGN TABLE sensor_tbl_nsc (
  time timestamp with time zone,
  device text,
  line text,
  sensor text,
  value int
) SERVER server1 OPTIONS (table 'sensor', tags 'device');

--Testcase 485:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.297985+09', 'D01', 'L01', 'A32', 1);
--Testcase 486:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.319444+09', 'D02', 'L02', 'A31', 2);
--Testcase 487:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.325517+09', 'D03', 'L03', 'Alarm', 3);
--Testcase 488:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.331317+09', 'D04', 'L04', 'PS5A_PS2', 4);
--Testcase 489:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.336539+09', 'D05', 'L05', '^PS5A_PS2', 5);
--Testcase 490:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.341984+09', 'D06', 'L06', 'PS5A_PS2$', 6);
--Testcase 491:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.347979+09', 'D07', 'L07', '^PS5A_PS2$', 7);
--Testcase 492:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.353777+09', 'D08', 'L08', '_PS5A_PS2_', 8);
--Testcase 493:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.361595+09', 'D09', 'L09', '%PS5A%PS2%', 9);
--Testcase 494:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.368482+09', 'D10', 'L10', '\^$.|?aBc*+()[{', 10);
--Testcase 585:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.297985+09', 'D11', 'L11', 'A32\%', 11);
--Testcase 700:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.297988+09', 'D12', 'L12', '\%', 12);
--Testcase 701:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.297998+09', 'D13', 'L13', '%', 13);

--Testcase 495:
SELECT * FROM sensor_tbl;

-- Test LIKE pattern matching (case sensitive)
--Testcase 496:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A%';
--Testcase 497:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A%';

--Testcase 498:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS2';
--Testcase 499:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS2';

--Testcase 500:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%A%';
--Testcase 501:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%A%';

--Testcase 502:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'PS5A_PS2';
--Testcase 503:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'PS5A_PS2';

--Testcase 504:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'PS5A\_PS2';
--Testcase 505:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'PS5A\_PS2';

--Testcase 506:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A_PS2';
--Testcase 507:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A_PS2';

--Testcase 508:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A\_PS2';
--Testcase 509:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A\_PS2';

--Testcase 560:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A_PS2$';
--Testcase 561:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^PS5A_PS2$';

--Testcase 562:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '_PS5A_PS2_';
--Testcase 563:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '_PS5A_PS2_';

--Testcase 564:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\_PS5A\_PS2\_';
--Testcase 565:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\_PS5A\_PS2\_';

--Testcase 566:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS5A%PS2%';
--Testcase 567:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS5A%PS2%';

--Testcase 568:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS5A%PS2\%';
--Testcase 569:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%PS5A%PS2\%';

--Testcase 570:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A%PS2%';
--Testcase 571:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A%PS2%';

--Testcase 572:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A\%PS2\%';
--Testcase 573:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A\%PS2\%';

--Testcase 574:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A\%PS2\%';
--Testcase 575:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%PS5A\%PS2\%';

--Testcase 576:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\^$.|?aBc*+()[{';
--Testcase 577:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\^$.|?aBc*+()[{';

--Testcase 581:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~~ 'A%';
--Testcase 582:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~~ 'A%';

--Testcase 583:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~ 'A%';
--Testcase 584:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~ 'A%';

--Testcase 586:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A32\\\%';
--Testcase 587:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A32\\\%';

--Testcase 588:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A32\\%';
--Testcase 589:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE 'A32\\%';

--Testcase 702:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%';
--Testcase 703:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\%';

--Testcase 704:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\%';
--Testcase 705:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\%';

--Testcase 706:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\\%';
--Testcase 707:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '\\\%';

--Testcase 708:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%';
--Testcase 709:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%';

--Testcase 710:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '__PS5A__PS2__' ESCAPE '_';
--Testcase 711:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '__PS5A__PS2__' ESCAPE '_';

--Testcase 712:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^^PS5A^_PS2' ESCAPE '^';
--Testcase 713:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '^^PS5A^_PS2' ESCAPE '^';

--Testcase 714:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%%';
--Testcase 715:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%%';

--Testcase 716:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%_%';
--Testcase 717:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%_%';

--Testcase 718:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%2_';
--Testcase 719:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%2_';

--Testcase 720:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%c_+%{';
--Testcase 720:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' LIKE '%c_+%{';

--Testcase 721:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl
WHERE time between '2024-10-18 14:44:24.297985+09' and '2024-10-18 14:44:24.341984+09'
AND tags->>'device' = 'D02' AND (fields->>'value')::int <> 0
AND fields->>'sensor' LIKE 'A%';
--Testcase 722:
SELECT * FROM sensor_tbl
WHERE time between '2024-10-18 14:44:24.297985+09' and '2024-10-18 14:44:24.341984+09'
AND tags->>'device' = 'D02' AND (fields->>'value')::int <> 0
AND fields->>'sensor' LIKE 'A%';

--Testcase 723:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl
WHERE time between '2024-10-18 14:44:24.297985+09' and '2024-10-18 14:44:24.341984+09'
AND tags->>'device' = 'D02' AND (fields->>'value')::int <> 0
AND fields->>'sensor' LIKE 'A';
--Testcase 724:
SELECT * FROM sensor_tbl
WHERE time between '2024-10-18 14:44:24.297985+09' and '2024-10-18 14:44:24.341984+09'
AND tags->>'device' = 'D02' AND (fields->>'value')::int <> 0
AND fields->>'sensor' LIKE 'A';

-- Test LIKE pattern un-matching (case sensitive)
--Testcase 579:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT LIKE 'A%';
--Testcase 580:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT LIKE 'A%';

--Testcase 583:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~ 'A%';
--Testcase 584:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~ 'A%';

-- Test ILIKE pattern matching (case insensitive)
--Testcase 594:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'a3%';
--Testcase 595:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'a3%';

--Testcase 881:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'PS5A_PS2';
--Testcase 882:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'PS5A_PS2';

--Testcase 883:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'PS5A\_PS2';
--Testcase 884:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE 'PS5A\_PS2';

--Testcase 885:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A_PS2';
--Testcase 886:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A_PS2';

--Testcase 887:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A\_PS2';
--Testcase 888:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A\_PS2';

--Testcase 889:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A_PS2$';
--Testcase 890:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '^PS5A_PS2$';

--Testcase 891:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '_PS5A_PS2_';
--Testcase 892:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '_PS5A_PS2_';

--Testcase 893:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '\_PS5A\_PS2\_';
--Testcase 894:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ILIKE '\_PS5A\_PS2\_';

--Testcase 590:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~~* 'a3%';
--Testcase 591:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~~* 'a3%';

-- Test ILIKE pattern un-matching (case insensitive)
--Testcase 596:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'a3%';
--Testcase 597:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'a3%';

--Testcase 895:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'PS5A_PS2';
--Testcase 896:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'PS5A_PS2';

--Testcase 897:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'PS5A\_PS2';
--Testcase 898:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE 'PS5A\_PS2';

--Testcase 899:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A_PS2';
--Testcase 900:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A_PS2';

--Testcase 901:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A\_PS2';
--Testcase 902:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A\_PS2';

--Testcase 903:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A_PS2$';
--Testcase 904:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '^PS5A_PS2$';

--Testcase 905:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '_PS5A_PS2_';
--Testcase 906:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '_PS5A_PS2_';

--Testcase 907:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '\_PS5A\_PS2\_';
--Testcase 908:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' NOT ILIKE '\_PS5A\_PS2\_';

--Testcase 592:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~* 'a3%';
--Testcase 593:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~~* 'a3%';

-- Test REGEX operators
-- Test REGEX pattern matching (case sensitive)
--Testcase 725:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A(.*)';
--Testcase 726:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A(.*)';

--Testcase 727:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.*)PS2$';
--Testcase 728:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.*)PS2$';

--Testcase 729:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.*)A(.*)';
--Testcase 730:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.*)A(.*)';

--Testcase 731:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'PS5A(.{1})PS2';
--Testcase 732:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'PS5A(.{1})PS2';

--Testcase 733:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'PS5A\_PS2s';
--Testcase 734:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'PS5A\_PS2';

--Testcase 735:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A(.{1})PS2';
--Testcase 736:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A(.{1})PS2';

--Testcase 737:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A\_PS2';
--Testcase 738:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A\_PS2';

--Testcase 739:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A(.{1})PS2$';
--Testcase 740:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^PS5A(.{1})PS2$';

--Testcase 741:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.{1})PS5A(.{1})PS2(.{1})';
--Testcase 742:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(.{1})PS5A(.{1})PS2(.{1})';

--Testcase 743:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\_PS5A\_PS2\_';
--Testcase 744:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\_PS5A\_PS2\_';

--Testcase 745:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '%PS5A%PS2%';
--Testcase 746:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '%PS5A%PS2%';

--Testcase 747:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '%PS5A%PS2\%';
--Testcase 748:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '%PS5A%PS2\%';

--Testcase 749:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A%PS2%';
--Testcase 750:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A%PS2%';

--Testcase 751:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A\%PS2\%';
--Testcase 752:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A\%PS2\%';

--Testcase 753:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A\%PS2\%';
--Testcase 754:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\%PS5A\%PS2\%';

--Testcase 755:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'A32\\\%';
--Testcase 756:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'A32\\\%';

--Testcase 757:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A32\\(.*)';
--Testcase 758:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A32\\(.*)';

-- Test REGEX pattern un-matching (case sensitive)
--Testcase 759:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~ '^A(.*)';
--Testcase 760:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~ '^A(.*)';

-- Test REGEX pattern matching (case insensitive)
--Testcase 761:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~* '^a3(.*)';
--Testcase 762:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~* '^a3(.*)';

-- Test REGEX pattern un-matching (case insensitive)
--Testcase 763:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~* '^a3(.*)';
--Testcase 764:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' !~* '^a3(.*)';

-- Test mix of REGEX patterns
--Testcase 765:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A(.*)' AND fields->>'sensor' !~ '^A3(.*)' ;
--Testcase 766:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A(.*)' AND fields->>'sensor' !~ '^A3(.*)' ;

-- Test REGEX syntax
--Testcase 767:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.397988+09', 'D14', 'L14', 'grey', 14);
--Testcase 768:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.397998+09', 'D15', 'L15', 'gray', 15);
--Testcase 769:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.497988+09', 'D16', 'L16', 'grey
1234', 16);
--Testcase 770:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.597988+09', 'D17', 'L17', 'color', 17);
--Testcase 771:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.697988+09', 'D18', 'L18', 'colour', 18);
--Testcase 772:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.797988+09', 'D19', 'L19', 'colouur', 19);
--Testcase 773:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.897988+09', 'D20', 'L20', 'colr', 20);
--Testcase 774:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:24.997988+09', 'D21', 'L21', 'c ol or', 21);

-- Characters
-- Backslash escapes one metacharacter, '^' is a metacharacter, use backslash to escape it.
--Testcase 775:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\^PS5A_PS2';
--Testcase 776:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\^PS5A_PS2';

-- Character Classes or Character Sets
-- [abc] character class
--Testcase 777:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gr[ae]y';
--Testcase 778:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gr[ae]y';
-- [^abc] negated character class
--Testcase 779:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gr[^e]y';
--Testcase 780:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gr[^e]y';
-- [a-z] character class range
--Testcase 781:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[a-z]';
--Testcase 782:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[a-z]';

-- Perl Character Classes (all ASCII-only)
-- \d digits ([0-9])
--Testcase 783:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\d';
--Testcase 784:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\d';

--Testcase 785:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[0-9]';
--Testcase 786:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[0-9]';

-- \D not digits ([^0-9])
--Testcase 787:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\D';
--Testcase 788:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\D';

--Testcase 789:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^0-9]';
--Testcase 790:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^0-9]';

-- \s whitespace ([\t\n\f\r ])
--Testcase 791:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\s';
--Testcase 792:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\s';

--Testcase 793:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[\t\n\f\r ]';
--Testcase 794:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[\t\n\f\r ]';

-- \S not whitespace (≡ [^\t\n\f\r ])
--Testcase 795:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\S';
--Testcase 796:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\S';

--Testcase 797:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^\t\n\f\r ]';
--Testcase 798:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^\t\n\f\r ]';

-- \w word characters (≡ [0-9A-Za-z_])
--Testcase 799:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\w';
--Testcase 800:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\w';

--Testcase 801:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[0-9A-Za-z_]';
--Testcase 802:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[0-9A-Za-z_]';
-- \W not word characters (≡ [^0-9A-Za-z_])
--Testcase 803:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\W';
--Testcase 804:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\W';

--Testcase 805:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^0-9A-Za-z_]';
--Testcase 806:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[^0-9A-Za-z_]';

-- ASCII character classes
-- [[:alpha:]]	alphabetic (≡ [A-Za-z])
--Testcase 807:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[[:alpha:]]';
--Testcase 808:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[[:alpha:]]';

-- [[:alnum:]] alphanumeric (≡ [0-9A-Za-z])
--Testcase 809:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[[:alnum:]]';
--Testcase 810:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '[[:alnum:]]';

-- Dot
-- . (dot; any character)
--Testcase 811:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '.A';
--Testcase 812:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '.A';

-- . with line break character
--Testcase 813:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '.\n';
--Testcase 814:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '.\n';

-- Anchors
-- ^ (start of string/line)
--Testcase 815:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A';
--Testcase 816:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '^A';
-- $ (end of string/line)
--Testcase 817:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'S2$';
--Testcase 818:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'S2$';
--  \A (start of string)
--Testcase 819:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\AA';
--Testcase 820:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\AA';

-- \b at ASCII word boundary (\w on one side and \W, \A, or \z on the other)
--Testcase 821:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\bA';
--Testcase 822:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\bA';

-- \B not at ASCII word boundary
--Testcase 823:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\BA';
--Testcase 824:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\BA';

-- \m matches only at the beginning of a word - not supported by InfluxDB
--Testcase 825:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\mA';
--Testcase 826:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '\mA';

-- \M matches only at the end of a word - not supported by InfluxDB
--Testcase 827:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'y\M';
--Testcase 828:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'y\M';

-- Alternation
-- | (alternation)
--Testcase 829:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gray|grey';
--Testcase 830:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'gray|grey';

-- Quantifiers
-- ? (0 or 1)
--Testcase 831:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou?r';
--Testcase 832:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou?r';
-- * (0 or more)
--Testcase 833:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou*r';
--Testcase 834:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou*r';

--Testcase 835:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'u*r';
--Testcase 836:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'u*r';

-- + (1 or more)
--Testcase 837:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou+r';
--Testcase 838:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou+r';

-- {n} (exactly n)
--Testcase 839:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{1}r';
--Testcase 840:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{1}r';

--Testcase 841:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{2}r';
--Testcase 842:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{2}r';

-- {n,m} (between n and m)
--Testcase 843:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,2}r';
--Testcase 844:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,2}r';

-- {n,} (n or more)
--Testcase 845:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{1,}r';
--Testcase 846:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{1,}r';

-- *? zero or more, prefer fewer
--Testcase 847:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou*?r';
--Testcase 848:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou*?r';

-- +? one or more, prefer fewer
--Testcase 849:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou+?r';
--Testcase 850:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou+?r';

-- ?? zero or one, prefer zero
--Testcase 851:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou??r';
--Testcase 852:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou??r';

-- {n,m}? n or n+1 or ... or m, prefer fewer
--Testcase 853:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,2}?r';
--Testcase 854:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,2}?r';

-- {n,}? n or more, prefer fewer
--Testcase 855:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,}?r';
--Testcase 856:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'colou{0,}?r';

-- Grouping and Backreferences
-- (regex) (numbered capturing group)
--Testcase 857:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'col(ou)?r';
--Testcase 858:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ 'col(ou)?r';

-- (?:regex) non-capturing group
--Testcase 859:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?:ou)';
--Testcase 860:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?:ou)';

-- Modifiers
-- (?flags)regex set flags within current group; non-capturing
-- i	case-insensitive (default false)
--Testcase 861:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?i)a';
--Testcase 862:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?i)a';

-- m multi-line mode: ^ and $ match begin/end line in addition to begin/end text (default false)
--Testcase 863:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?m)1';
--Testcase 864:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?m)1';

-- s let . match \n (default false)
--Testcase 865:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?s)A';
--Testcase 866:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?s)A';

-- U ungreedy: swap meaning of x* and x*?, x+ and x+?, etc (default false) -- Not supported by PostgreSQL
--Testcase 867:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?U)color';
--Testcase 868:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?U)color';

-- (?flags:re) set flags during re; non-capturing -- Not supported by Postgres
--Testcase 869:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?i:a)';
--Testcase 870:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?i:a)';

--Testcase 871:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?m:a)';
--Testcase 872:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?m:a';

--Testcase 873:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?s:A)';
--Testcase 874:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?s:A)';

--Testcase 875:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?U:color)';
--Testcase 876:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?U:color)';

-- (?P=name) (Python-style named backreference) - Not supported by Postgres
--Testcase 877:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?P=color)';
--Testcase 878:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '(?P=color)';

-- backreferences - not supported by InfluxDB
--Testcase 881:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:22.897988+09', 'D22', 'L22', 'axaxax', 22);
--Testcase 882:
INSERT INTO sensor_tbl_nsc (time, device, line, sensor, value) values ('2024-10-18 14:44:23.997988+09', 'D23', 'L23', 'bxbxbx', 23);
-- \1 match the first capturing group. For example ([ab])x\1x\1 matches axaxa, bxbxb.
--Testcase 879:
EXPLAIN VERBOSE
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '([ab])x\1';
--Testcase 880:
SELECT * FROM sensor_tbl WHERE fields->>'sensor' ~ '([ab])x\1';

-- clean-up
--Testcase 578:
DELETE FROM sensor_tbl;

--Testcase 205:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 202:
DROP SERVER server1 CASCADE;
--Testcase 203:
DROP EXTENSION influxdb_fdw;
