-- ===================================================================
-- create FDW objects
-- ===================================================================
\set ECHO none
\ir sql/parameters.conf
\set DATA_SIZE '1000'
\set ECHO all
\timing

SET datestyle = ISO;
--Testcase 1:
CREATE EXTENSION influxdb_fdw;

-- need change base on multi version support

--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
    OPTIONS (dbname 'performance_test', :SERVER);

--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (:AUTHENTICATION);

--Testcase 4:
CREATE FOREIGN TABLE tbl1 (
	tag1 text,
	tag2 text,
	tag3 text,
	c1 bigint,
	c2 text,
	c3 double precision,
	c4 boolean,
	time timestamp
) SERVER influxdb_svr OPTIONS (table 'tbl1', tags 'tag1, tag2, tag3');

-- ===================================================================
-- test for insert data
-- ===================================================================
--
-- batch size 1
--
--Testcase 5:
EXPLAIN VERBOSE
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 6:
EXPLAIN VERBOSE
SELECT count(*) FROM tbl1;
--
-- batch size 10
--
ALTER SERVER influxdb_svr OPTIONS (ADD batch_size '10');

--Testcase 7:
EXPLAIN VERBOSE
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 8:
EXPLAIN VERBOSE
SELECT count(*) FROM tbl1;

--
-- batch size 1000
--
ALTER SERVER influxdb_svr OPTIONS (SET batch_size '1000');

--Testcase 9:
EXPLAIN VERBOSE
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 10:
EXPLAIN VERBOSE
SELECT count(*) FROM tbl1;
--
-- batch size 5000
--

ALTER SERVER influxdb_svr OPTIONS (SET batch_size '5000');
--Testcase 11:
EXPLAIN VERBOSE
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 12:
SELECT count(*) FROM tbl1;
-- clean-up
--Testcase 13:
DELETE FROM tbl1;

--
-- batch size 20000
--
ALTER SERVER influxdb_svr OPTIONS (SET batch_size '20000');

--Testcase 14:
EXPLAIN VERBOSE
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 15:
EXPLAIN VERBOSE
SELECT count(*) FROM tbl1;
-- does not clean-up, using inserted data to test SELECT

-- ===================================================================
-- test for SELECT data
-- ===================================================================
-- select all column
--Testcase 16:
EXPLAIN VERBOSE
SELECT * FROM tbl1;
-- select one column
--Testcase 17:
EXPLAIN VERBOSE
SELECT c1 FROM tbl1;
--
-- WHERE condition
--
-- 20%
--Testcase 18:
EXPLAIN VERBOSE
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 5;
-- 10%
--Testcase 19:
EXPLAIN VERBOSE
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 10;
-- 1%
--Testcase 20:
EXPLAIN VERBOSE
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 100;
--
-- agg push down
--
--Testcase 21:
EXPLAIN VERBOSE
SELECT avg(c1), count(*) FROM tbl1;
--
-- select data based on time series as: time period, data frequency
--

--Testcase 22:
EXPLAIN VERBOSE
SELECT * FROM tbl1 WHERE time <= now() AND time > now() - interval '1 day' GROUP BY tag2, tag3, tag1, c1, c2, c3, c4, time;
--Testcase 23:
EXPLAIN VERBOSE
SELECT DISTINCT (tag1) FROM tbl1 GROUP BY tag1;
--Testcase 24:
EXPLAIN VERBOSE SELECT avg(c1), sum(c3)/:DATA_SIZE FROM tbl1 WHERE time < now() AND time > now() - interval '2 days';
--Testcase 25:
EXPLAIN VERBOSE SELECT count(tag1), avg(c1) FROM tbl1 WHERE time > now() - interval '1 day' GROUP BY tag1;
--Testcase 26:
EXPLAIN VERBOSE SELECT tag1, avg(c3), avg(c1), c2 FROM tbl1 WHERE time > '1970-02-11 00:00:00'::timestamp AND time < now() GROUP BY tag1, c1, c2, c3;
--Testcase 27:
EXPLAIN VERBOSE SELECT max(c1), min(c2), min(c3) FROM tbl1 WHERE time > now() - interval '3 days';
--
-- DELETE
--
--Testcase 28:
EXPLAIN VERBOSE DELETE FROM tbl1 WHERE tag1 = '000';
--Testcase 29:
EXPLAIN  VERBOSE DELETE FROM tbl1 WHERE tag2 = 'tag2_111';
--Testcase 30:
EXPLAIN VERBOSE DELETE FROM tbl1 WHERE tag1 = '011' AND tag2 IS NOT NULL;
--Testcase 31:
EXPLAIN VERBOSE DELETE FROM tbl1;
-- Execute phase

-- ===================================================================
-- test for insert data
-- ===================================================================

-- batch size 1
--Testcase 32:
DELETE FROM tbl1;

ALTER SERVER influxdb_svr OPTIONS (DROP batch_size);
--Testcase 33:
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 34:
SELECT count(*) FROM tbl1;
--Testcase 35:
SELECT * FROM tbl1;
-- clean-up
--Testcase 36:
DELETE FROM tbl1;
--
-- batch size 10
--
ALTER SERVER influxdb_svr OPTIONS (ADD batch_size '10');

--Testcase 37:
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 38:
SELECT count(*) FROM tbl1;
-- clean-up
--Testcase 39:
DELETE FROM tbl1;
--
-- batch size 1000
--
ALTER SERVER influxdb_svr OPTIONS (SET batch_size '1000');
--Testcase 40:
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 41:
SELECT count(*) FROM tbl1;
-- clean-up
--Testcase 42:
DELETE FROM tbl1;
--
-- batch size 5000
--
ALTER SERVER influxdb_svr OPTIONS (SET batch_size '5000');
--Testcase 43:
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 44:
SELECT count(*) FROM tbl1;
-- clean-up
--Testcase 45:
DELETE FROM tbl1;
--
-- batch size 20000
--

ALTER SERVER influxdb_svr OPTIONS (SET batch_size '20000');
--Testcase 46:
INSERT INTO tbl1 (tag1, tag2, tag3, c1, c2, c3, c4)
	SELECT to_char(id % 100, 'FM000'),
			to_char(id % 1000, 'FM0000'),
			to_char(id % 5000, 'FM0000'),
			id,
	       to_char(id % 100, 'FM00000000000000000000'), -- 20 digits
		   sqrt(id),
		   true
	FROM generate_series(1, :DATA_SIZE) id;

-- checking all record is inserted
--Testcase 47:
SELECT count(*) FROM tbl1;

-- does not clean-up, using inserted data to test SELECT

-- ===================================================================
-- test for SELECT data
-- ===================================================================
-- select all column
--Testcase 48:
SELECT * FROM tbl1;
-- select one column
--Testcase 49:
SELECT c1 FROM tbl1;

--
-- WHERE condition
--
-- 20%
--Testcase 50:
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 5;
-- 10%
--Testcase 51:
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 10;
-- 1%
--Testcase 52:
SELECT * FROM tbl1 WHERE c1 < :DATA_SIZE / 100;
--
-- agg push down
--
--Testcase 53:
SELECT avg(c1), count(*) FROM tbl1;
--
-- select data based on time series as: time period, data frequency
--
--Testcase 54:
SELECT * FROM tbl1 WHERE time <= now() AND time > now() - interval '1 day' GROUP BY tag2, tag3, tag1, c1, c2, c3, c4, time;
--Testcase 55:
SELECT DISTINCT (tag1) FROM tbl1 GROUP BY tag1;
--Testcase 56:
SELECT avg(c1), sum(c3)/:DATA_SIZE FROM tbl1 WHERE time < now() AND time > now() - interval '2 days';
--Testcase 57:
SELECT count(tag1), avg(c1) FROM tbl1 WHERE time > now() - interval '1 day' GROUP BY tag1;
--Testcase 58:
SELECT tag1, avg(c3), avg(c1), c2 FROM tbl1 WHERE time > '1970-02-11 00:00:00'::timestamp AND time < now() GROUP BY tag1, c1, c2, c3;
--Testcase 59:
SELECT max(c1), min(c2), min(c3) FROM tbl1 WHERE time > now() - interval '3 days';
--
-- DELETE
--
--Testcase 60:
DELETE FROM tbl1 WHERE tag1 = '000';
--Testcase 61:
DELETE FROM tbl1 WHERE tag2 = 'tag2_111';
--Testcase 62:
DELETE FROM tbl1 WHERE tag1 = '011' AND tag2 IS NOT NULL;
--Testcase 63:
DELETE FROM tbl1;

--Testcase 64:
DROP EXTENSION influxdb_fdw CASCADE;
