--SET log_min_messages=debug1;
--SET client_min_messages=debug1;
SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 1:
CREATE EXTENSION influxdb_fdw;
--Testcase 2:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
-- import time column as timestamp and text type
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
--Testcase 4:
SELECT * FROM cpu;
--Testcase 5:
SELECT tag1, value1 FROM cpu;
--Testcase 6:
SELECT value1, time, value2 FROM cpu;
--Testcase 7:
SELECT value1, time_text, value2 FROM cpu;

--Testcase 8:
DROP FOREIGN TABLE cpu;
--Testcase 9:
DROP FOREIGN TABLE t3;
--Testcase 10:
DROP FOREIGN TABLE t4;
DROP FOREIGN TABLE tx;
--Testcase 11:
DROP FOREIGN TABLE numbers;

-- test EXECPT
IMPORT FOREIGN SCHEMA public EXCEPT (cpu, t3, t4, tx, numbers) FROM SERVER server1 INTO public;
--Testcase 12:
SELECT ftoptions FROM pg_foreign_table;

-- test LIMIT TO
IMPORT FOREIGN SCHEMA public LIMIT TO (cpu) FROM SERVER server1 INTO public;
--Testcase 13:
SELECT ftoptions FROM pg_foreign_table;
--Testcase 14:
DROP FOREIGN TABLE cpu;

IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');

--Testcase 15:
SELECT * FROM cpu;
--Testcase 16:
SELECT tag1, value1 FROM cpu;
--Testcase 17:
SELECT value1, time, value2 FROM cpu;
--Testcase 18:
SELECT tag1 FROM cpu;
--Testcase 19:
SELECT * FROM numbers;

--Testcase 20:
\d cpu;

--Testcase 21:
SELECT * FROM cpu WHERE value1=100;
--Testcase 22:
SELECT * FROM cpu WHERE value2=0.5;
--Testcase 23:
SELECT * FROM cpu WHERE value3='str';
--Testcase 24:
SELECT * FROM cpu WHERE value4=true;
--Testcase 25:
SELECT * FROM cpu WHERE NOT (value4 AND value1=100);
--Testcase 26:
SELECT * FROM cpu WHERE tag1='tag1_A';

--Testcase 27:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 28:
SELECT * FROM cpu WHERE value3 IS NULL;
--Testcase 29:
SELECT * FROM cpu WHERE tag2 IS NULL;
--Testcase 30:
SELECT * FROM cpu WHERE value3 IS NOT NULL;
--Testcase 31:
SELECT * FROM cpu WHERE tag2 IS NOT NULL;

-- InfluxDB not support compare timestamp with OR condition
--Testcase 32:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- InfluxDB not support compare timestamp with != or <>
--Testcase 33:
SELECT * FROM cpu WHERE time != '2015-08-18 09:48:08+09';
--Testcase 34:
SELECT * FROM cpu WHERE time <> '2015-08-18 09:48:08+09';

--Testcase 35:
SELECT * FROM cpu WHERE time = '2015-08-18 09:48:08+09' OR value2 = 0.5;

-- There is inconsitency for search of missing values between tag and field
--Testcase 36:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE value3 = '';
--Testcase 37:
SELECT * FROM cpu WHERE value3 = '';

--Testcase 38:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM cpu WHERE tag2 = '';
--Testcase 39:
SELECT * FROM cpu WHERE tag2 = '';

--Testcase 40:
SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');
--Testcase 41:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tag1 IN ('tag1_A', 'tag1_B');

-- Rows which have no tag are considered to have empty string
--Testcase 42:
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');
--Testcase 43:
EXPLAIN VERBOSE
SELECT * FROM cpu WHERE tag1 NOT IN ('tag1_A', 'tag1_B');

-- test IN/NOT IN
--Testcase 44:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 45:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 46:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 47:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 48:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 49:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 50:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 51:
SELECT * FROM cpu WHERE time IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 52:
SELECT * FROM cpu WHERE time NOT IN ('2015-08-18 09:48:08+09','2016-08-28 07:44:00+07');
--Testcase 53:
SELECT * FROM cpu WHERE value1 NOT IN (100, 97);
--Testcase 54:
SELECT * FROM cpu WHERE value1 IN (100, 97);
--Testcase 55:
SELECT * FROM cpu WHERE value2 IN (0.5, 10.9);
--Testcase 56:
SELECT * FROM cpu WHERE value2 NOT IN (2, 9.7);
--Testcase 57:
SELECT * FROM cpu WHERE value4 NOT IN ('true', 'true');
--Testcase 58:
SELECT * FROM cpu WHERE value4 IN ('f', 't');

--Testcase 59:
CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, value1 integer) SERVER server1 OPTIONS (table 'cpu');
--Testcase 60:
CREATE FOREIGN TABLE t2(time timestamp , tag1 text, value1 integer) SERVER server1 OPTIONS (table 'cpu');

--Testcase 61:
SELECT * FROM t1;
--Testcase 62:
SELECT * FROM t2;
-- In following four queries, timestamp condition is added to InfluxQL as "time = '2015-08-18 00:00:00'"
--Testcase 63:
SELECT * FROM t1 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 64:
SELECT * FROM t1 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

--Testcase 65:
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-18 09:00:00+09';
--Testcase 66:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-08-18 00:00:00';

-- pushdown now()
--Testcase 67:
SELECT * FROM t2 WHERE now() > time;
--Testcase 68:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE now() > time;

--Testcase 69:
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';
--Testcase 70:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00' - interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond';

-- InfluxDB does not seem to support time column + interval, so below query returns empty result
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00';
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT * FROM t2 WHERE time + interval '1 week 1 day 5 hour 43 minute 21 second 100 millisecond' = TIMESTAMP WITH TIME ZONE '2015-08-26 05:43:21.1+00';

-- InfluxDB does not support month or year interval, so not push down
--Testcase 71:
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';
--Testcase 72:
EXPLAIN VERBOSE
SELECT * FROM t2 WHERE time = TIMESTAMP '2015-09-18 00:00:00' - interval '1 months';

--Testcase 73:
SELECT * FROM t2 WHERE value1 = ANY (ARRAY(SELECT value1 FROM t1 WHERE value1 < 1000));

-- ANY with ARRAY expression
--Testcase 74:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, a + 1]);
--Testcase 75:
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, a + 1]);

--Testcase 76:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, a + 1]);
--Testcase 77:
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, a + 1]);

--Testcase 78:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, a + 1]);
--Testcase 79:
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, a + 1]);

--Testcase 80:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, a + 1]);
--Testcase 81:
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, a + 1]);

--Testcase 82:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, a + 1]);
--Testcase 83:
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, a + 1]);

--Testcase 84:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, a + 1]);
--Testcase 85:
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, a + 1]);

-- ANY with ARRAY const
--Testcase 86:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, 2]);
--Testcase 87:
SELECT a, b FROM numbers WHERE a = ANY(ARRAY[1, 2]);

--Testcase 88:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, 2]);
--Testcase 89:
SELECT a, b FROM numbers WHERE a <> ANY(ARRAY[1, 2]);

--Testcase 90:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, 2]);
--Testcase 91:
SELECT a, b FROM numbers WHERE a >= ANY(ARRAY[1, 2]);

--Testcase 92:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, 2]);
--Testcase 93:
SELECT a, b FROM numbers WHERE a <= ANY(ARRAY[1, 2]);

--Testcase 94:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, 2]);
--Testcase 95:
SELECT a, b FROM numbers WHERE a > ANY(ARRAY[1, 2]);

--Testcase 96:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, 2]);
--Testcase 97:
SELECT a, b FROM numbers WHERE a < ANY(ARRAY[1, 2]);

--Testcase 98:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ANY('{1, 2, 3}');
--Testcase 99:
SELECT a, b FROM numbers WHERE a = ANY('{1, 2, 3}');
--Testcase 100:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ANY('{1, 2, 3}');
--Testcase 101:
SELECT a, b FROM numbers WHERE a <> ANY('{1, 2, 3}');

-- ALL with ARRAY expression
--Testcase 102:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, a * 1]);
--Testcase 103:
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, a * 1]);

--Testcase 104:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, a + 1]);
--Testcase 105:
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, a + 1]);

--Testcase 106:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, a / 1]);
--Testcase 107:
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, a / 1]);

--Testcase 108:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, a + 1]);
--Testcase 109:
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, a + 1]);

--Testcase 110:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[1, a - 1]);
--Testcase 111:
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[1, a - 1]);

--Testcase 112:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, a + 1]);
--Testcase 113:
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, a + 1]);

-- ALL with ARRAY const
--Testcase 114:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, 1]);
--Testcase 115:
SELECT a, b FROM numbers WHERE a = ALL(ARRAY[1, 1]);

--Testcase 116:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, 3]);
--Testcase 117:
SELECT a, b FROM numbers WHERE a <> ALL(ARRAY[1, 3]);

--Testcase 118:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, 2]);
--Testcase 119:
SELECT a, b FROM numbers WHERE a >= ALL(ARRAY[1, 2]);

--Testcase 120:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, 2]);
--Testcase 121:
SELECT a, b FROM numbers WHERE a <= ALL(ARRAY[1, 2]);

--Testcase 122:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[0, 1]);
--Testcase 123:
SELECT a, b FROM numbers WHERE a > ALL(ARRAY[0, 1]);

--Testcase 124:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, 3]);
--Testcase 125:
SELECT a, b FROM numbers WHERE a < ALL(ARRAY[2, 3]);

-- ANY/ALL with TEXT ARRAY const
--Testcase 126:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b = ANY(ARRAY['One', 'Two']);
--Testcase 127:
SELECT a, b FROM numbers WHERE b = ANY(ARRAY['One', 'Two']);

--Testcase 128:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b <> ALL(ARRAY['One', 'Four']);
--Testcase 129:
SELECT a, b FROM numbers WHERE b <> ALL(ARRAY['One', 'Four']);

--Testcase 130:
EXPLAIN VERBOSE
SELECT a, b FROM numbers WHERE b > ANY(ARRAY['One', 'Two']);
--Testcase 131:
SELECT a, b FROM numbers WHERE b > ANY(ARRAY['One', 'Two']);

--Testcase 132:
EXPLAIN VERBOSE
SELECT * FROM numbers WHERE b > ALL(ARRAY['Four', 'Five']);
--Testcase 133:
SELECT a, b FROM numbers WHERE b > ALL(ARRAY['Four', 'Five']);

--Testcase 134:
DROP FOREIGN TABLE numbers;

ALTER SERVER server1 OPTIONS (SET dbname 'no such database');
--Testcase 135:
SELECT * FROM t1;
ALTER SERVER server1 OPTIONS (SET dbname 'mydb');
--Testcase 136:
SELECT * FROM t1;

-- map time column to both timestamp and text
--Testcase 137:
CREATE FOREIGN TABLE t5(t timestamp OPTIONS (column_name 'time'), tag1 text OPTIONS (column_name 'time'), v1 integer OPTIONS (column_name 'value1')) SERVER server1 OPTIONS (table 'cpu');
--Testcase 138:
SELECT * FROM t5;

--Test pushdown LIMIT...OFFSET
--Testcase 139:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 140:
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 141:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 1;

--Testcase 142:
SELECT tableoid::regclass, * FROM t1 LIMIT 1 OFFSET 1;

--Testcase 143:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 144:
SELECT ctid, * FROM t1 LIMIT 1 OFFSET 0;

--Testcase 145:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM t2 LIMIT 10 OFFSET 20;

--Testcase 146:
SELECT ctid, * FROM t2 LIMIT 10 OFFSET 20;

--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM
  t1
  LEFT JOIN t2
  ON t2.value1 = 123,
  LATERAL (SELECT t2.value1, t1.tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss
WHERE t1.value1 = ss.value1;

--Testcase 148:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM
  t1
  LEFT JOIN t2
  ON t2.value1 = 123,
  LATERAL (SELECT t2.value1, t1.tag1 FROM t1 LIMIT 1 OFFSET 0) AS ss1,
  LATERAL (SELECT ss1.* from t3 LIMIT 1 OFFSET 20) AS ss2
WHERE t1.value1 = ss2.value1;

--Testcase 149:
DROP FOREIGN TABLE cpu;
--Testcase 150:
DROP FOREIGN TABLE t1;
--Testcase 151:
DROP FOREIGN TABLE t2;
--Testcase 152:
DROP FOREIGN TABLE t3;
--Testcase 153:
DROP FOREIGN TABLE t4;
--Testcase 154:
DROP FOREIGN TABLE t5;
DROP FOREIGN TABLE tx;

-- test INSERT, DELETE
IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'true');
--Testcase 155:
SELECT * FROM cpu;
--Testcase 156:
EXPLAIN VERBOSE
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test1', true);
--Testcase 157:
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-01 00:00:01+09', 'tag1_K', 'tag2_H', 200, 5.5, 'test', true);
--Testcase 158:
SELECT * FROM cpu;

--Testcase 159:
EXPLAIN VERBOSE
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 160:
INSERT INTO cpu(time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-01-02 00:00:02+05', 'tag1_I', 'tag2_E', 300, 15.5, 'test2', false),
  ('2029-02-02 00:02:02+04', 'tag1_U', 'tag2_DZ', (SELECT 350), (SELECT i FROM (VALUES(6.9)) AS foo (i)), 'funny', true);
--Testcase 161:
SELECT * FROM cpu;

--Testcase 162:
INSERT INTO cpu(tag2, value1) VALUES('tag2_KH', 400);
--Testcase 163:
SELECT tag1, tag2, value1, value2, value3, value4 FROM cpu;

--Testcase 164:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE tag2 = 'tag2_KH';
--Testcase 165:
DELETE FROM cpu WHERE tag2 = 'tag2_KH';
--Testcase 166:
SELECT tag1, tag2, value1, value2, value3, value4 FROM cpu;

--Testcase 167:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 168:
DELETE FROM cpu WHERE time = '2021-01-02 04:00:02+09';
--Testcase 169:
SELECT * FROM cpu;

--Testcase 170:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 171:
DELETE FROM cpu WHERE time < '2018-07-07' AND tag1 != 'tag1_B';
--Testcase 172:
SELECT * FROM cpu;

-- Test INSERT, DELETE with time_text column
--Testcase 173:
INSERT INTO cpu(time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02T00:00:00Z', 'tag1_D', 'tag2_E', 600, 20.2, 'test3', true);
--Testcase 174:
SELECT * FROM cpu;

--Testcase 175:
INSERT INTO cpu(time_text, tag1, value2) VALUES('2021-02-02T00:00:00.123456789Z', 'tag1_P', 25.8);
--Testcase 176:
SELECT * FROM cpu;

--Testcase 177:
INSERT INTO cpu(time_text, tag1, value2) VALUES('2021-02-02 00:00:01', 'tag1_J', 37.1);
--Testcase 178:
SELECT * FROM cpu;

--Testcase 179:
INSERT INTO cpu(time, time_text, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-02 00:00:01+05', '2021-02-02T00:00:02.123456789Z', 'tag1_A', 'tag2_B', 200, 5.5, 'test', true);
--Testcase 180:
SELECT * FROM cpu;

--Testcase 181:
INSERT INTO cpu(time_text, time, tag1, tag2, value1, value2, value3, value4) VALUES('2021-02-03T00:00:03.123456789Z', '2021-03-03 00:00:01+07', 'tag1_C', 'tag2_D', 200, 5.5, 'test', true);
--Testcase 182:
SELECT * FROM cpu;

--Testcase 183:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 184:
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:00.123456789Z';
--Testcase 185:
SELECT * FROM cpu;

--Testcase 186:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 187:
DELETE FROM cpu WHERE time_text = '2021-02-02T00:00:01Z' AND tag1 = 'tag1_J';
--Testcase 188:
SELECT * FROM cpu;

--Testcase 189:
EXPLAIN VERBOSE
DELETE FROM cpu WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 190:
DELETE FROM cpu WHERE time_text = '2021-02-02 00:00:00' OR time ='2029-02-02 05:02:02+09';
--Testcase 191:
SELECT * FROM cpu;

--Testcase 192:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 193:
DROP SERVER server1 CASCADE;
--Testcase 194:
DROP EXTENSION influxdb_fdw CASCADE;
