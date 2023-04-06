\set ECHO none
\ir sql/parameters.conf
\set ECHO all
----------------------------------------------------------------------
-- FDW, server and user mapping for influxdb_fdw
----------------------------------------------------------------------
--Testcase 1:
CREATE EXTENSION influxdb_fdw;
--Testcase 2:
CREATE SERVER influx_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'coredb', :SERVER);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER influx_svr OPTIONS(:AUTHENTICATION);
-- CREATE FOREIGN TABLE
-- no column constraint
--Testcase 4:
CREATE FOREIGN TABLE tbl1 (
    c1	smallint,
    c2	int,
    c3	bigint,
    c4	float,
    c5	double precision,
    c6	numeric,
    c7	bool,
    c8	bpchar,
    c9	time,
    c10	timestamp,
    c11	timestamptz,
    c12	text,
    c13	real,
    c14	char,
    c15	varchar(10)
) SERVER influx_svr OPTIONS (table 'tbl1');
-- no column constraint
--Testcase 5:
CREATE FOREIGN TABLE tbl2 (
    c1	smallint,
    c2	int,
    c3	bigint,
    c4	float,
    c5	double precision,
    c6	numeric,
    c7	bool,
    c8	bpchar,
    c9	time,
    c10	timestamp,
    c11	timestamptz,
    c12	text,
    c13	real,
    c14	char,
    c15	varchar(10)
) SERVER influx_svr OPTIONS (table 'tbl2');
-- full column constraints: "key" option as PRIMARY KEY, NOT NULL, DEFAULT <value>
--Testcase 6:
CREATE FOREIGN TABLE tbl3 (
    c1	smallint,
    c2	int	NOT NULL,
    c3	bigint DEFAULT 10,
    c4	float,
    c5	double precision,
    c6	numeric,
    c7	bool DEFAULT 'f',
    c8	bpchar,
    c9	time DEFAULT '00:00:00',
    c10	timestamp,
    c11	timestamptz,
    c12	text,
    c13	real DEFAULT 1,
    c14	char DEFAULT 'd',
    c15	varchar(10)
) SERVER influx_svr OPTIONS (table 'tbl3');

----------------------------------------------------------------------
-- CREATE NON-EXISTED DATASOURCE TABLE
----------------------------------------------------------------------
--Testcase 7:
SELECT count(*) FROM tbl1; -- failed : table not exists
--Testcase 8:
SELECT count(*) FROM tbl2; -- failed : table not exists
--Testcase 9:
SELECT count(*) FROM tbl3; -- failed : table not exists
-- no table option, no column constraint
--Testcase 10:
CREATE DATASOURCE TABLE tbl1;
-- table option, no column constraint
--Testcase 11:
CREATE DATASOURCE TABLE IF NOT EXISTS tbl2;
-- table option, column constraint
--Testcase 12:
CREATE DATASOURCE TABLE IF NOT EXISTS tbl3;
--  MODIFY: Test INSERT data
--Testcase 13:
INSERT INTO tbl3 VALUES (1, 11, 111, 11.11, 111.111, 11111, 't', 'bpchar', '01:01:01', '2022-05-11', '2022-05-11', 'one', 1e10, '1', 'table 3');
--Testcase 14:
INSERT INTO tbl3 VALUES (2, 22, 222, 22.22, 222.222, 22222, 't', 'bpchar', '02:02:02', '2022-05-22', '2022-05-22', 'two', 2e10, '2', 'table 3');
--Testcase 15:
INSERT INTO tbl3 VALUES (3, 33, 333, 33.33, 333.333, 33333, 't', 'bpchar', '03:03:03', '2022-05-03', '2022-05-03', 'three', 3e10, '3', 'table 3');

--Testcase 16:
SELECT * FROM tbl3;
-- INSERT with data for only non-default column
--Testcase 17:
INSERT INTO tbl3(c1, c2, c4, c5, c6, c8, c10, c11, c12, c15)
          VALUES(4, 44, 44.44, 444.444, 44444, 'bpchar_4', '2022-04-04', '2022-04-04', 'four', 'table 3');
--Testcase 18:
INSERT INTO tbl3(c1, c2, c4, c5, c6, c8, c10, c11, c12, c15)
          VALUES(5, 55, 55.55, 555.555, 55555, 'bpchar_5', '2022-05-05', '2022-05-05', 'four', 'table 3');

--Testcase 19:
SELECT * FROM tbl3;
-- Update NULL to NOT NULL column
--Testcase 20:
UPDATE tbl3 SET c2 = NULL WHERE c1 = 1; -- failed
--Testcase 21:
SELECT * FROM tbl3;
-- INSERT NULL into NOT NULL column
--Testcase 22:
INSERT INTO tbl3(c1, c2) VALUES(6, NULL);  -- failed
--Testcase 23:
INSERT INTO tbl3(c1) VALUES(7);  -- failed
--Testcase 24:
SELECT * FROM tbl3;
-- INSERT duplicated key
--Testcase 25:
INSERT INTO tbl3(c1, c2) VALUES(1, 100);
--Testcase 26:
SELECT * FROM tbl3;

----------------------------------------------------------------------
-- CREATE EXISTED DATASOURCE TABLES
----------------------------------------------------------------------
--Testcase 27:
SELECT count(*) FROM tbl1; -- OK : table exists
--Testcase 28:
SELECT count(*) FROM tbl2; -- OK : table exists
--Testcase 29:
SELECT count(*) FROM tbl3; -- OK : table exists
-- no table option, no column constraint
--Testcase 30:
CREATE DATASOURCE TABLE tbl1; -- OK
-- table option, no column constraint
--Testcase 31:
CREATE DATASOURCE TABLE IF NOT EXISTS tbl2; -- OK
-- table option, column constraint
--Testcase 32:
CREATE DATASOURCE TABLE IF NOT EXISTS tbl3; -- OK

----------------------------------------------------------------------
-- DROP EXISTED DATASOURCE TABLE
----------------------------------------------------------------------
--Testcase 33:
DROP DATASOURCE TABLE tbl1; -- failed: table not exists
--Testcase 34:
DROP DATASOURCE TABLE IF EXISTS tbl2;
-- Confirm datasource table is dropped:
--Testcase 35:
SELECT * FROM tbl1;
--Testcase 36:
SELECT * FROM tbl2;

----------------------------------------------------------------------
-- DROP NON-EXISTED DATASOURCE TABLE
----------------------------------------------------------------------
--Testcase 37:
DROP DATASOURCE TABLE tbl1; -- failed: table not exists
--Testcase 38:
DROP DATASOURCE TABLE IF EXISTS tbl2; -- OK

-- Clear
--Testcase 39:
DROP DATASOURCE TABLE IF EXISTS tbl3;
--Testcase 40:
DROP FOREIGN TABLE tbl1;
--Testcase 41:
DROP FOREIGN TABLE tbl2;
--Testcase 42:
DROP FOREIGN TABLE tbl3;

-- Foreign tables already dropped
-- CREATE datasource without foreign table
--Testcase 43:
CREATE DATASOURCE TABLE tbl1; -- failed: table not exists
-- DROP datasource without foreign table
--Testcase 44:
DROP DATASOURCE TABLE tbl1; -- failed: table not exists

--Testcase 45:
DROP SERVER influx_svr CASCADE;
--Testcase 46:
DROP EXTENSION influxdb_fdw CASCADE;
