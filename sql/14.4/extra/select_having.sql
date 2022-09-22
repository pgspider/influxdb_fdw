--
-- SELECT_HAVING
--
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 1:
CREATE EXTENSION influxdb_fdw;

--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE test_having (a int, b int, c char(8), d char) SERVER influxdb_svr;

--Testcase 5:
INSERT INTO test_having VALUES (0, 1, 'XXXX', 'A');
--Testcase 6:
INSERT INTO test_having VALUES (1, 2, 'AAAA', 'b');
--Testcase 7:
INSERT INTO test_having VALUES (2, 2, 'AAAA', 'c');
--Testcase 8:
INSERT INTO test_having VALUES (3, 3, 'BBBB', 'D');
--Testcase 9:
INSERT INTO test_having VALUES (4, 3, 'BBBB', 'e');
--Testcase 10:
INSERT INTO test_having VALUES (5, 3, 'bbbb', 'F');
--Testcase 11:
INSERT INTO test_having VALUES (6, 4, 'cccc', 'g');
--Testcase 12:
INSERT INTO test_having VALUES (7, 4, 'cccc', 'h');
--Testcase 13:
INSERT INTO test_having VALUES (8, 4, 'CCCC', 'I');
--Testcase 14:
INSERT INTO test_having VALUES (9, 4, 'CCCC', 'j');

--Testcase 15:
SELECT b, c FROM test_having
	GROUP BY b, c HAVING count(*) = 1 ORDER BY b, c;

-- HAVING is effectively equivalent to WHERE in this case
--Testcase 16:
SELECT b, c FROM test_having
	GROUP BY b, c HAVING b = 3 ORDER BY b, c;

--Testcase 17:
SELECT lower(c), count(c) FROM test_having
	GROUP BY lower(c) HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY lower(c);

--Testcase 18:
SELECT c, max(a) FROM test_having
	GROUP BY c HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY c;

-- test degenerate cases involving HAVING without GROUP BY
-- Per SQL spec, these should generate 0 or 1 row, even without aggregates

--Testcase 19:
SELECT min(a), max(a) FROM test_having HAVING min(a) = max(a);
--Testcase 20:
SELECT min(a), max(a) FROM test_having HAVING min(a) < max(a);

-- errors: ungrouped column references
--Testcase 21:
SELECT a FROM test_having HAVING min(a) < max(a);
--Testcase 22:
SELECT 1 AS one FROM test_having HAVING a > 1;

-- the really degenerate case: need not scan table at all
--Testcase 23:
SELECT 1 AS one FROM test_having HAVING 1 > 2;
--Testcase 24:
SELECT 1 AS one FROM test_having HAVING 1 < 2;

-- and just to prove that we aren't scanning the table:
--Testcase 25:
SELECT 1 AS one FROM test_having WHERE 1/a = 1 HAVING 1 < 2;

--Testcase 26:
-- Clean up:
DELETE FROM test_having;
DROP FOREIGN TABLE test_having;
--Testcase 27:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 28:
DROP SERVER influxdb_svr CASCADE;
--Testcase 29:
DROP EXTENSION influxdb_fdw CASCADE;
