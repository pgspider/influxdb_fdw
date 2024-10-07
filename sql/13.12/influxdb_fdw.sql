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

-- InfluxDB_FDW will store time data for Field values as a strings
--Testcase 204:
CREATE FOREIGN TABLE tmp_time (
time timestamp,
c1 time,
c2 timestamp,
c3 timestamp with time zone,
c4 timestamp,
c5 timestamp with time zone,
agvState character varying NULL COLLATE pg_catalog."default",
value numeric NULL
) SERVER server1 OPTIONS (table 'tmp_time');

-- Test binding NULL parameter in the condition
-- Testcase 600:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = (SELECT max(c2) FROM tmp_time);
-- Testcase 601:
SELECT * FROM tmp_time WHERE time = (SELECT max(c2) FROM tmp_time);
-- Testcase 602:
EXPLAIN VERBOSE
DELETE FROM tmp_time WHERE time = (SELECT max(c2) FROM tmp_time);
-- Testcase 603:
DELETE FROM tmp_time WHERE time = (SELECT max(c2) FROM tmp_time);

--Testcase 205:
SELECT * FROM tmp_time;
--Testcase 206:
INSERT INTO tmp_time (time, c1, agvState, value) VALUES ('1900-01-01 01:01:01', '01:02:03', 'state 1', 0.1);
--Testcase 207:
INSERT INTO tmp_time (time, c1, agvState, value) VALUES ('2100-01-01 01:01:01', '04:05:06', 'state 2', 0.2);
--Testcase 208:
INSERT INTO tmp_time (time, c1, agvState, value) VALUES ('1990-01-01 01:01:01', '07:08:09', 'state 3', 0.3);
--Testcase 209:
INSERT INTO tmp_time (time, c2) VALUES ('2020-12-27 03:02:56.634467', '1950-02-02 02:02:02');
--Testcase 210:
INSERT INTO tmp_time (time, c3, agvState, value) VALUES ('2021-12-27 03:02:56.668301', '1800-02-02 02:02:02+9', 'state 5', 0.5);
--Testcase 210:
INSERT INTO tmp_time (time, c1, c2, c3, agvState, value) VALUES ('2022-05-06 07:08:09', '07:08:09', '2022-05-06 07:08:09', '2022-05-06 07:08:09+9', 'state 6', 0.6);
--Testcase 261:
INSERT INTO tmp_time (time, c1, c2, c3, agvState, value) VALUES ('2023-05-06 07:08:09', '07:08:10', '2023-05-06 07:08:09', '2023-05-06 07:08:09+9', 'state 7', 0.7);
--Testcase 482:
INSERT INTO tmp_time (time, c1, c2, c3, c4, c5, agvState, value) VALUES ('2023-05-06 07:08:09', '07:08:10', '2023-05-06 07:08:09', '2023-05-06 07:08:09+9', '2023-05-06 08:08:09', '2023-05-06 08:08:09+9', 'state 8', 0.8);
--Testcase 483:
INSERT INTO tmp_time (time, c1, c2, c3, c4, c5, agvState, value) VALUES ('2025-05-06 07:08:09', '07:08:10', '2025-05-06 07:08:09', '2025-05-06 07:08:09+9', '2025-05-06 08:08:09', '2025-05-06 08:08:09+9', 'state 9', 0.9);
--Testcase 211:
-- 1800-02-02 02:02:02+9 is Daylight Saving Time (DST) changes in Japan.
-- Timezone setting Japan so it will plus 18s:59
-- https://www.timeanddate.com/time/zone/japan/tokyo?syear=1850
--Testcase 262:
SELECT * FROM tmp_time;

/* For time key column, InfluxDB does not support the operators !=, <> */
--Testcase 362:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != '2022-05-06 07:08:09';
--Testcase 363:
SELECT * FROM tmp_time WHERE time != '2022-05-06 07:08:09';

--Testcase 364:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <> '2022-05-06 07:08:09';
--Testcase 365:
SELECT * FROM tmp_time WHERE time <> '2022-05-06 07:08:09';

--Testcase 416:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != c2;
--Testcase 417:
SELECT * FROM tmp_time WHERE time != c2;

--Testcase 418:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != c2 + interval '1d';
--Testcase 419:
SELECT * FROM tmp_time WHERE time != c2 + interval '1d'; 

--Testcase 420:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time != (select max(c2) from tmp_time) ;
--Testcase 421:
SELECT * FROM tmp_time WHERE time != (select max(c2) from tmp_time) ;

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
--Testcase 366:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 != '2022-05-06 07:08:09+9';
--Testcase 367:
SELECT * FROM tmp_time WHERE c3 != '2022-05-06 07:08:09+9';
--Testcase 368:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 <> '2022-05-06 07:08:09+9';
--Testcase 369:
SELECT * FROM tmp_time WHERE c3 <> '2022-05-06 07:08:09+9';

--Testcase 370:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 != '2022-05-06 07:08:09';
--Testcase 371:
SELECT * FROM tmp_time WHERE c2 != '2022-05-06 07:08:09';

--Testcase 372:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <> '2022-05-06 07:08:09';
--Testcase 373:
SELECT * FROM tmp_time WHERE c2 <> '2022-05-06 07:08:09';

--Testcase 374:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 != '07:08:09';
--Testcase 375:
SELECT * FROM tmp_time WHERE c1 != '07:08:09';

--Testcase 376:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 <> '07:08:09';

--Testcase 377:
SELECT * FROM tmp_time WHERE c1 <> '07:08:09';

--Testcase 426:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <> c4;
--Testcase 427:
SELECT * FROM tmp_time WHERE c2 <> c4;

--Testcase 428:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 != (select max(c2) from tmp_time) ;
--Testcase 429:
SELECT * FROM tmp_time WHERE c2 != (select max(c2) from tmp_time) ;

--Testcase 430:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 != time;
--Testcase 431:
SELECT * FROM tmp_time WHERE c2 != time;

--Testcase 432:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 != now();
--Testcase 433:
SELECT * FROM tmp_time WHERE c2 != now();

--Testcase 434:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 != now() + interval '1d';
--Testcase 435:
SELECT * FROM tmp_time WHERE c2 != now() + interval '1d';

/* InfluxDB does not pushdown comparison between interval and interval */
--Testcase 263:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - c2 <= interval '1d';
--Testcase 264:
SELECT * FROM tmp_time WHERE time - c2 <= interval '1d';

--Testcase 265:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - c2 >= interval '1d';
--Testcase 266:
SELECT * FROM tmp_time WHERE time - c2 >= interval '1d';

--Testcase 267:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - c2 = interval '25896 days 01:00:54.634467';
--Testcase 268:
SELECT * FROM tmp_time WHERE time - c2 = interval '25896 days 01:00:54.634467';

--Testcase 269:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - c2 > interval '1d';
--Testcase 270:
SELECT * FROM tmp_time WHERE time - c2 > interval '1d';

--Testcase 271:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - c2 < interval '1d';
--Testcase 272:
SELECT * FROM tmp_time WHERE time - c2 < interval '1d';

--Testcase 273:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time - c2) - (c1 - c1) > interval '-1d';
--Testcase 274:
SELECT * FROM tmp_time WHERE (time - c2) - (c1 - c1) > interval '-1d';

--Testcase 275:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time - c2) > (c1 - c1) + interval '-1d';
--Testcase 276:
SELECT * FROM tmp_time WHERE (time - c2) > (c1 - c1) + interval '-1d';

--Testcase 383:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (time + interval '1d') - (c2 + interval '1d') > interval '-1d';
--Testcase 384:
SELECT * FROM tmp_time WHERE (time + interval '1d') - (c2 + interval '1d') > interval '-1d';

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
SELECT * FROM tmp_time WHERE (c2 + interval '1d') < now() + interval '-1d';
--Testcase 390:
SELECT * FROM tmp_time WHERE (c2 + interval '1d') < now() + interval '-1d';

--Testcase 391:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (c2 - interval '1d') < now() - interval '-1d';
--Testcase 392:
SELECT * FROM tmp_time WHERE (c2 - interval '1d') < now() - interval '-1d';

-- Result is empty, the purpose is to check pushdown or not
--Testcase 397:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 = now() + interval '-1d';
--Testcase 398:
SELECT * FROM tmp_time WHERE c2 = now() + interval '-1d';  -- empty

--Testcase 399:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = c2 + interval '25896 days 01:00:54.634467';
--Testcase 400:
SELECT * FROM tmp_time WHERE time = c2 + interval '25896 days 01:00:54.634467';

--Testcase 277:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time - (select max(c3) from tmp_time)  < interval '109541 days 00:58:59';
--Testcase 278:
SELECT * FROM tmp_time WHERE time - (select max(c3) from tmp_time)  < interval '109541 days 00:58:59';

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
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') < c3;
--Testcase 437:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') < c3;

--Testcase 438:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') = c3;
--Testcase 439:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') = c3;

--Testcase 440:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') != c3;
--Testcase 441:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') != c3;

--Testcase 442:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > c3;
--Testcase 443:
SELECT * FROM tmp_time WHERE influx_time(time, interval '3m') - interval '3m' > c3;

--Testcase 415:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamp;

/* InfluxDB does not pushdown pseudocontant expression (there is no Var node) */
--Testcase 378:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (select min(c3) from tmp_time) <= '2024-05-06 07:08:09+9';
--Testcase 379:
SELECT * FROM tmp_time WHERE (select min(c3) from tmp_time) <= '2024-05-06 07:08:09+9';

--Testcase 380:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE (select max(c3) from tmp_time) <= (select max(c2) from tmp_time);
--Testcase 381:
SELECT * FROM tmp_time WHERE (select max(c3) from tmp_time) <= (select max(c2) from tmp_time);

/* InfluxDB does not support pushdown =, <, >, >=, <= operators in comparison between time key and time colum */
--Testcase 446:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time = c2;
--Testcase 447:
SELECT * FROM tmp_time WHERE time = c2;

--Testcase 448:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time >= c2;
--Testcase 449:
SELECT * FROM tmp_time WHERE time >= c2;

--Testcase 450:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > c2;
--Testcase 451:
SELECT * FROM tmp_time WHERE time > c2;

--Testcase 452:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < c2;
--Testcase 453:
SELECT * FROM tmp_time WHERE time < c2;

--Testcase 454:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <= c2;
--Testcase 455:
SELECT * FROM tmp_time WHERE time <= c2;

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
SELECT * FROM tmp_time WHERE time = (select max(c2) from tmp_time);
--Testcase 457:
SELECT * FROM tmp_time WHERE time = (select max(c2) from tmp_time);

--Testcase 458:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > (select max(c2) from tmp_time);
--Testcase 459:
SELECT * FROM tmp_time WHERE time > (select max(c2) from tmp_time);

--Testcase 460:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time < (select max(c2) from tmp_time);
--Testcase 461:
SELECT * FROM tmp_time WHERE time < (select max(c2) from tmp_time);

--Testcase 462:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time >= (select max(c2) from tmp_time);
--Testcase 463:
SELECT * FROM tmp_time WHERE time >= (select max(c2) from tmp_time);

--Testcase 464:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time <= (select max(c2) from tmp_time);
--Testcase 465:
SELECT * FROM tmp_time WHERE time <= (select max(c2) from tmp_time);

-- SELECT with sub-query returning timestamp with timezone value
--Testcase 233:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 = (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 234:
SELECT * FROM tmp_time WHERE c3 = (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');

--Testcase 299:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 > (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 300:
SELECT * FROM tmp_time WHERE c3 > (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');

--Testcase 301:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 < (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 302:
SELECT * FROM tmp_time WHERE c3 < (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');

--Testcase 303:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 >= (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 304:
SELECT * FROM tmp_time WHERE c3 >= (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');

--Testcase 305:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 <= (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 306:
SELECT * FROM tmp_time WHERE c3 <= (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');

-- SELECT with sub-query returning timestamp value
--Testcase 235:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 236:
SELECT * FROM tmp_time WHERE c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

--Testcase 307:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 > (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 308:
SELECT * FROM tmp_time WHERE c2 > (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

--Testcase 309:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 < (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 310:
SELECT * FROM tmp_time WHERE c2 < (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

--Testcase 311:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 >= (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 312:
SELECT * FROM tmp_time WHERE c2 >= (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

--Testcase 313:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <= (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 314:
SELECT * FROM tmp_time WHERE c2 <= (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

-- SELECT with sub-query returning time value
--Testcase 237:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 238:
SELECT * FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');

--Testcase 315:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 316:
SELECT * FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');

--Testcase 317:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 318:
SELECT * FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');

--Testcase 319:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 320:
SELECT * FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');

--Testcase 321:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 322:
SELECT * FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');

-- Mixing pushdown condition and not pushdown condition
--Testcase 407:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND c2 > '1950-02-02 02:02:02' AND (select min(c2) from tmp_time) <= time;
--Testcase 408:
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' AND c2 > '1950-02-02 02:02:02' AND (select min(c2) from tmp_time) <= time;

--Testcase 408:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' OR c2 > '1950-02-02 02:02:02' OR (select min(c2) from tmp_time) <= time;
--Testcase 409:
SELECT * FROM tmp_time WHERE time > '1900-01-01 01:01:01' OR c2 > '1950-02-02 02:02:02' OR (select min(c2) from tmp_time) <= time;

-- Sub-query in the expression
--Testcase 248:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 = INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 249:
SELECT * FROM tmp_time WHERE c1 = INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 323:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 < INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 324:
SELECT * FROM tmp_time WHERE c1 < INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 325:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 > INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 326:
SELECT * FROM tmp_time WHERE c1 > INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 327:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 <= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 328:
SELECT * FROM tmp_time WHERE c1 <= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 329:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 >= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 330:
SELECT * FROM tmp_time WHERE c1 >= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 250:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' = INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 251:
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' = INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 331:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' > INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 332:
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' > INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 333:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' < INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 334:
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' < INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 335:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' >= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 336:
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' >= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

--Testcase 337:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' <= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');
--Testcase 338:
SELECT * FROM tmp_time WHERE c1 + INTERVAL '03:03:03' <= INTERVAL '03:03:03' + (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06');

-- Sub-query in multiple conditions (does not support OR)
--Testcase 252:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') 
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 253:
SELECT * FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 339:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 340:
SELECT * FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 341:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 342:
SELECT * FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 343:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 344:
SELECT * FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

--Testcase 345:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';
--Testcase 346:
SELECT * FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
AND c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09')
AND time < now() - INTERVAL '1d';

-- Aggregation with sub-query 
--Testcase 254:
EXPLAIN VERBOSE
SELECT c1 FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;
--Testcase 255:
SELECT c1 FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;

--Testcase 347:
EXPLAIN VERBOSE
SELECT c1 FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06') GROUP BY c1;
--Testcase 348:
SELECT c1 FROM tmp_time WHERE c1 > (SELECT max(c1) FROM tmp_time WHERE c1 = '04:05:06') GROUP BY c1;

--Testcase 349:
EXPLAIN VERBOSE
SELECT c1 FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;
--Testcase 350:
SELECT c1 FROM tmp_time WHERE c1 < (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;

--Testcase 351:
EXPLAIN VERBOSE
SELECT c1 FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;
--Testcase 352:
SELECT c1 FROM tmp_time WHERE c1 >= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;

--Testcase 353:
EXPLAIN VERBOSE
SELECT c1 FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;
--Testcase 354:
SELECT c1 FROM tmp_time WHERE c1 <= (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') GROUP BY c1;

-- Aggregation + Having clause with sub-query 
--Testcase 256:
EXPLAIN VERBOSE
SELECT c1, c2 FROM tmp_time WHERE c1 =  (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
GROUP BY c1, c2 HAVING c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 257:
SELECT c1, c2 FROM tmp_time WHERE c1 =  (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09')
GROUP BY c1, c2 HAVING c2 = (SELECT c2 FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

-- JOIN with sub-query
--Testcase 258:
EXPLAIN VERBOSE
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON t1.c1 = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 259:
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON t1.c1 = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

--Testcase 355:
EXPLAIN VERBOSE
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');
--Testcase 356:
SELECT t1.* FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09');

-- Aggregation and JOIN with sub-query
--Testcase 357:
EXPLAIN VERBOSE
SELECT t1.c1 FROM tmp_time t1 JOIN tmp_time t2 ON t1.c1 = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09') GROUP BY t1.c1;
--Testcase 358:
SELECT t1.c1 FROM tmp_time t1 JOIN tmp_time t2 ON t1.c1 = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09') GROUP BY t1.c1;

--Testcase 359:
EXPLAIN VERBOSE
SELECT t1.c1 FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09') GROUP BY t1.c1;
--Testcase 360:
SELECT t1.c1 FROM tmp_time t1 JOIN tmp_time t2 ON (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09') = t2.c1 AND t1.c2 = (SELECT max(c2) FROM tmp_time WHERE c2 = '2022-05-06 07:08:09') GROUP BY t1.c1;

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
SELECT * FROM tmp_time WHERE c2 > c4;
--Testcase 467:
SELECT * FROM tmp_time WHERE c2 > c4;

--Testcase 468:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 >= c4;
--Testcase 469:
SELECT * FROM tmp_time WHERE c2 >= c4;

--Testcase 470:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 < c4;
--Testcase 471:
SELECT * FROM tmp_time WHERE c2 < c4;

--Testcase 472:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <= c4;
--Testcase 473:
SELECT * FROM tmp_time WHERE c2 <= c4;

--Testcase 289:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 > '1950-02-02 02:02:02';
--Testcase 290:
SELECT * FROM tmp_time WHERE c2 > '1950-02-02 02:02:02';

--Testcase 291:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 < '2022-05-06 07:08:09';
--Testcase 292:
SELECT * FROM tmp_time WHERE c2 < '2022-05-06 07:08:09';

--Testcase 293:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 >= '1950-02-02 02:02:02';
--Testcase 294:
SELECT * FROM tmp_time WHERE c2 >= '1950-02-02 02:02:02';

--Testcase 295:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <= '2022-05-06 07:08:09';
--Testcase 296:
SELECT * FROM tmp_time WHERE c2 <= '2022-05-06 07:08:09';

--Testcase 297:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 = '2022-05-06 07:08:09';
--Testcase 298:
SELECT * FROM tmp_time WHERE c2 = '2022-05-06 07:08:09';

--Testcase 231:
EXPLAIN VERBOSE
SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9';
--Testcase 232:
SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9';

--Testcase 474:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 > (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 475:
SELECT * FROM tmp_time WHERE c2 > (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 476:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 >= (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 477:
SELECT * FROM tmp_time WHERE c2 >= (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 478:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 < (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 479:
SELECT * FROM tmp_time WHERE c2 < (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');

--Testcase 480:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c2 <= (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');
--Testcase 481:
SELECT * FROM tmp_time WHERE c2 <= (SELECT max(c2) FROM tmp_time WHERE time > now()-interval '1d');

-- DELETE with sub-query returning timestamp value
--Testcase 239:
EXPLAIN (VERBOSE, COSTS OFF)
DELETE FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time = '1900-01-01 01:01:01');
--Testcase 240:
DELETE FROM tmp_time WHERE time = (SELECT max(time) FROM tmp_time WHERE time = '1900-01-01 01:01:01');
--Testcase 241:
SELECT * FROM tmp_time;

-- DELETE with sub-query returning time value
--Testcase 242:
EXPLAIN VERBOSE
DELETE FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 243:
DELETE FROM tmp_time WHERE c1 = (SELECT max(c1) FROM tmp_time WHERE c1 = '07:08:09');
--Testcase 244:
SELECT * FROM tmp_time;

-- DELETE with sub-query returning timestamp with timezone value
--Testcase 245:
EXPLAIN VERBOSE
DELETE FROM tmp_time WHERE c3 = (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 246:
DELETE FROM tmp_time WHERE c3 = (SELECT c3 FROM tmp_time WHERE c3 = '2022-05-06 07:08:09+9');
--Testcase 247:
SELECT * FROM tmp_time;

-- Test time conversion in comparison with tags/field column
--Testcase 510:
EXPLAIN VERBOSE
SELECT * FROM tmp_time WHERE c3 = '1800-02-02 02:02:02+9';
--Testcase 511:
SELECT * FROM tmp_time WHERE c3 = '1800-02-02 02:02:02+9';

-- Test time conversion in comparison with time key column
--Testcase 512:
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamptz;
--Testcase 513:
INSERT INTO tmp_time (time, c1, agvState, value) VALUES ('1900-01-01 01:01:01+9', '02:02:04', 'state 10', 1);

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
ALTER FOREIGN TABLE tmp_time ALTER COLUMN time TYPE timestamp;

-- Type mis-match
--Testcase 212:
CREATE FOREIGN TABLE datatype_test (
  time timestamp with time zone,
  tag1 text,
  tag2 text,
  value1 int,
  value2 text
) SERVER server1 OPTIONS (table 'datatype_test', tags 'tag1,tag2');

--Testcase 213:
INSERT INTO datatype_test (tag1, tag2, value1, value2) VALUES ('time', '2021-02-02T00:00:01Z', '1', '2021-02-05T00:00:00Z');
--Testcase 214:
INSERT INTO datatype_test (tag1, tag2, value1, value2) VALUES ('time', '2022-02-02T00:00:01Z', '2', '2022-02-05T00:00:00Z');
--Testcase 215:
SELECT tag1, tag2, value1, value2 FROM datatype_test;
-- Using text as timestamp
--Testcase 216:
ALTER FOREIGN TABLE datatype_test ALTER COLUMN tag2 TYPE timestamptz;
--Testcase 217:
ALTER FOREIGN TABLE datatype_test ALTER COLUMN value2 TYPE timestamptz;

-- SELECT OK without filter
--Testcase 218:
SELECT tag1, tag2, value1, value2 FROM datatype_test;

-- SELECT with timestamp filter, WHERE clause is pushed down
-- InfluxDB cannot compare correctly, 0 row returned
--Testcase 219:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE tag2 > '2021-02-02 00:00:01+00';
--Testcase 220:
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE tag2 > '2021-02-02 00:00:01+00';
--Testcase 221:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE value2 > '2021-02-05 00:00:00+00';
--Testcase 222:
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE value2 > '2021-02-05 00:00:00+00';

--Testcase 223:
ALTER FOREIGN TABLE datatype_test ALTER COLUMN tag2 TYPE text;
--Testcase 224:
ALTER FOREIGN TABLE datatype_test ALTER COLUMN value2 TYPE text;

-- uses explicit cast, WHERE clause is not pushed down
-- compared correctly by postgres, 1 row returned
--Testcase 225:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE tag2::timestamptz > '2021-02-02 00:00:01+00';
--Testcase 226:
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE tag2::timestamptz > '2021-02-02 00:00:01+00';
--Testcase 227:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE value2::timestamptz > '2021-02-05 00:00:00+00';
--Testcase 228:
SELECT tag1, tag2, value1, value2 FROM datatype_test WHERE value2::timestamptz > '2021-02-05 00:00:00+00';

-- clean-up
--Testcase 229:
DELETE FROM datatype_test;
--Testcase 230:
DROP FOREIGN TABLE datatype_test;

-- Recover data
:RECOVER_INIT_TXT_DROP_BUCKET;
:RECOVER_INIT_TXT_CREATE_BUCKET;
:RECOVER_INIT_TXT;

--Testcase 201:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 202:
DROP SERVER server1 CASCADE;
--Testcase 203:
DROP EXTENSION influxdb_fdw CASCADE;
