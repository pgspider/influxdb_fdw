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
(dbname 'mydb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
--Testcase 6:
SELECT * FROM cpu;
--Testcase 7:
SELECT tag1, value1 FROM cpu;
--Testcase 8:
SELECT value1, time, value2 FROM cpu;
--Testcase 9:
SELECT value1, time_text, value2 FROM cpu;

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
IMPORT FOREIGN SCHEMA public EXCEPT (cpu, t3, t4, tx, numbers) FROM SERVER server1 INTO public;
--Testcase 15:
SELECT ftoptions FROM pg_foreign_table;

-- test LIMIT TO
IMPORT FOREIGN SCHEMA public LIMIT TO (cpu) FROM SERVER server1 INTO public;
--Testcase 16:
SELECT ftoptions FROM pg_foreign_table;
--Testcase 17:
DROP FOREIGN TABLE cpu;

IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');

--Testcase 18:
SELECT * FROM cpu;
--Testcase 19:
SELECT tag1, value1 FROM cpu;
--Testcase 20:
SELECT value1, time, value2 FROM cpu;
--Testcase 21:
SELECT tag1 FROM cpu;
--Testcase 22:
SELECT * FROM numbers;

--Testcase 23:
\d cpu;

--Testcase 24:
SELECT * FROM cpu WHERE value1=100;
--Testcase 25:
SELECT * FROM cpu WHERE value2=0.5;
--Testcase 26:
SELECT * FROM cpu WHERE value3='str';
--Testcase 27:
SELECT * FROM cpu WHERE value4=true;
--Testcase 28:
SELECT * FROM cpu WHERE NOT (value4 AND value1=100);
--Testcase 29:
SELECT * FROM cpu WHERE tag1='tag1_A';

--Testcase 30:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 31:
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 32:
SELECT * FROM cpu WHERE tag2 IS NULL;
--Testcase 33:
SELECT * FROM cpu WHERE value3 IS NOT NULL;
--Testcase 34:
SELECT * FROM cpu WHERE tag2 IS NOT NULL;

-- InfluxDB not support compare timestamp with OR condition
--Testcase 35:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- InfluxDB not support compare timestamp with != or <>
--Testcase 36:
SELECT * FROM cpu WHERE time != '2015-08-18 09:48:08+09';
--Testcase 37:
SELECT * FROM cpu WHERE time <> '2015-08-18 09:48:08+09';

--Testcase 38:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- There is inconsitency for search of missing values between tag and field
--Testcase 39:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE value3 = '';
--Testcase 40:
SELECT * FROM cpu WHERE value3 = '';

--Testcase 41:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE tag2 = '';
--Testcase 42:
SELECT * FROM cpu WHERE tag2 = '';

--Testcase 43:
SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');
--Testcase 44:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');

-- Rows which have no tag are considered to have empty string
--Testcase 45:
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');
--Testcase 46:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');

-- test IN/NOT IN
--Testcase 47:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 48:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 49:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 50:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 51:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 52:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 53:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 54:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 55:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 56:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 57:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 58:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 59:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 60:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 61:
SELECT * FROM cpu WHERE value4 IN ('f', 't');

--Testcase 62:
CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, value1 integer) SERVER server1 OPTIONS (table 'cpu');
--Testcase 63:
CREATE FOREIGN TABLE t2(time timestamp , tag1 text, value1 integer) SERVER server1 OPTIONS (table 'cpu');

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
SELECT * FROM t2 WHERE value1 = ANY (ARRAY(SELECT value1 FROM t1 WHERE value1 < 1000));

-- ANY with ARRAY expression
--Testcase 77:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, a + 1]);
--Testcase 78:
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, a + 1]);

--Testcase 79:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, a + 1]);
--Testcase 80:
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, a + 1]);

--Testcase 81:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, a + 1]);
--Testcase 82:
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, a + 1]);

--Testcase 83:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, a + 1]);
--Testcase 84:
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, a + 1]);

--Testcase 85:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, a + 1]);
--Testcase 86:
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, a + 1]);

--Testcase 87:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, a + 1]);
--Testcase 88:
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, a + 1]);

-- ANY with ARRAY const
--Testcase 89:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, 2]);
--Testcase 90:
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, 2]);

--Testcase 91:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, 2]);
--Testcase 92:
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, 2]);

--Testcase 93:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, 2]);
--Testcase 94:
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, 2]);

--Testcase 95:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, 2]);
--Testcase 96:
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, 2]);

--Testcase 97:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, 2]);
--Testcase 98:
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, 2]);

--Testcase 99:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, 2]);
--Testcase 100:
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, 2]);

--Testcase 101:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY('{1, 2, 3}');
--Testcase 102:
SELECT a, b FROM numbers WHERE a = ANY('{1, 2, 3}');
--Testcase 103:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY('{1, 2, 3}');
--Testcase 104:
SELECT a, b FROM numbers WHERE a <> ANY('{1, 2, 3}');

-- ALL with ARRAY expression
--Testcase 105:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, a * 1]);
--Testcase 106:
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, a * 1]);

--Testcase 107:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, a + 1]);
--Testcase 108:
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, a + 1]);

--Testcase 109:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, a / 1]);
--Testcase 110:
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, a / 1]);

--Testcase 111:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, a + 1]);
--Testcase 112:
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, a + 1]);

--Testcase 113:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[1, a - 1]);
--Testcase 114:
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[1, a - 1]);

--Testcase 115:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, a + 1]);
--Testcase 116:
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, a + 1]);

-- ALL with ARRAY const
--Testcase 117:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, 1]);
--Testcase 118:
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, 1]);

--Testcase 119:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, 3]);
--Testcase 120:
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, 3]);

--Testcase 121:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, 2]);
--Testcase 122:
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, 2]);

--Testcase 123:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, 2]);
--Testcase 124:
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, 2]);

--Testcase 125:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[0, 1]);
--Testcase 126:
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[0, 1]);

--Testcase 127:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, 3]);
--Testcase 128:
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, 3]);

-- ANY/ALL with TEXT ARRAY const
--Testcase 129:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b = ANY(ARRAY['One', 'Two']);
--Testcase 130:
SELECT a, b FROM numbers WHERE b = ANY(ARRAY['One', 'Two']);

--Testcase 131:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b <> ALL(ARRAY['One', 'Four']);
--Testcase 132:
SELECT a, b FROM numbers WHERE b <> ALL(ARRAY['One', 'Four']);

--Testcase 133:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b > ANY(ARRAY['One', 'Two']);
--Testcase 134:
SELECT a, b FROM numbers WHERE b > ANY(ARRAY['One', 'Two']);

--Testcase 135:
EXPLAIN VERBOSE
SELECT * FROM numbers WHERE b > ALL(ARRAY['Four', 'Five']);
--Testcase 136:
SELECT a, b FROM numbers WHERE b > ALL(ARRAY['Four', 'Five']);

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
CREATE FOREIGN TABLE t5(t timestamp OPTIONS (column_name 'time'), tag1 text OPTIONS (column_name 'time'), v1 integer OPTIONS (column_name 'value1')) SERVER server1 OPTIONS (table 'cpu');
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
  ON t2.value1 = 123,
  LATERAL (SELECT t2.value1, t1.tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss
WHERE t1.value1 = ss.value1;

--Testcase 156:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM
  t1
  LEFT JOIN t2
  ON t2.value1 = 123,
  LATERAL (SELECT t2.value1, t1.tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss1,
  LATERAL (SELECT ss1.* from t3 LIMIT 1 OFFSET 20) AS ss2
WHERE t1.value1 = ss2.value1;

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
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
--Testcase 164:
SELECT * FROM cpu;
--Testcase 165:
EXPLAIN VERBOSE
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test1', true);
--Testcase 166:
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test', true);
--Testcase 167:
SELECT * FROM cpu;

--Testcase 168:
EXPLAIN VERBOSE
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 169:
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 170:
SELECT * FROM cpu;

--Testcase 171:
INSERT INTO cpu(tag2, value1) VALUES('tag2_KH', 400);
--Testcase 172:
SELECT tag1, tag2, value1, value2, value3, value4 FROM cpu;

--Testcase 173:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE tag2 = 'tag2_KH';
--Testcase 174:
DELETE FROM cpu WHERE tag2 = 'tag2_KH';
--Testcase 175:
SELECT tag1, tag2, value1, value2, value3, value4 FROM cpu;

--Testcase 176:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 177:
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 178:
SELECT * FROM cpu;

--Testcase 179:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 180:
DELETE FROM cpu WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 181:
SELECT * FROM cpu;

-- Test INSERT, DELETE with time_text column
--Testcase 182:
INSERT INTO cpu(time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02T00:00:00Z', 'tag1_D', 'tag2_E', 600, 20.2, 'test3', true);
--Testcase 183:
SELECT * FROM cpu;

--Testcase 184:
INSERT INTO cpu(time_text, tag1, value2) VALUES('2021-02-02T00:00:00.123456789Z', 'tag1_P', 25.8);
--Testcase 185:
SELECT * FROM cpu;

--Testcase 186:
INSERT INTO cpu(time_text, tag1, value2) VALUES('2021-02-02 00:00:01', 'tag1_J', 37.1);
--Testcase 187:
SELECT * FROM cpu;

--Testcase 188:
INSERT INTO cpu(time, time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02 00:00:01+05', '2021-02-02T00:00:02.123456789Z', 'tag1_A', 'tag2_B', 200, 5.5, 'test', true);
--Testcase 189:
SELECT * FROM cpu;

--Testcase 190:
INSERT INTO cpu(time_text, time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-03T00:00:03.123456789Z', '2021-03-03 00:00:01+07', 'tag1_C', 'tag2_D', 200, 5.5, 'test', true);
--Testcase 191:
SELECT * FROM cpu;

--Testcase 192:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 193:
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 194:
SELECT * FROM cpu;

--Testcase 195:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 196:
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 197:
SELECT * FROM cpu;

--Testcase 198:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 199:
DELETE FROM cpu WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 200:
SELECT * FROM cpu;

--Testcase 201:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 202:
DROP SERVER server1 CASCADE;
--Testcase 203:
DROP EXTENSION influxdb_fdw CASCADE;
