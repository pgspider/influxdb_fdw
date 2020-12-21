--
-- SELECT_HAVING
--
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 12:
CREATE EXTENSION influxdb_fdw;

--Testcase 13:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 14:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--Testcase 15:
CREATE FOREIGN TABLE test_having(a int, b int, c char(8), d char) SERVER influxdb_svr;

--Testcase 1:
SELECT b, c FROM test_having
	GROUP BY b, c HAVING count(*) = 1 ORDER BY b, c;

-- HAVING is effectively equivalent to WHERE in this case
--Testcase 2:
SELECT b, c FROM test_having
	GROUP BY b, c HAVING b = 3 ORDER BY b, c;

--Testcase 3:
SELECT lower(c), count(c) FROM test_having
	GROUP BY lower(c) HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY lower(c);

--Testcase 4:
SELECT c, max(a) FROM test_having
	GROUP BY c HAVING count(*) > 2 OR min(a) = max(a)
	ORDER BY c;

-- test degenerate cases involving HAVING without GROUP BY
-- Per SQL spec, these should generate 0 or 1 row, even without aggregates

--Testcase 5:
SELECT min(a), max(a) FROM test_having HAVING min(a) = max(a);
--Testcase 6:
SELECT min(a), max(a) FROM test_having HAVING min(a) < max(a);

-- errors: ungrouped column references
--Testcase 7:
SELECT a FROM test_having HAVING min(a) < max(a);
--Testcase 8:
SELECT 1 AS one FROM test_having HAVING a > 1;

-- the really degenerate case: need not scan table at all
--Testcase 9:
SELECT 1 AS one FROM test_having HAVING 1 > 2;
--Testcase 10:
SELECT 1 AS one FROM test_having HAVING 1 < 2;

-- and just to prove that we aren't scanning the table:
--Testcase 11:
SELECT 1 AS one FROM test_having WHERE 1/a = 1 HAVING 1 < 2;

--Testcase 16:
DROP FOREIGN TABLE test_having;
--Testcase 17:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 18:
DROP SERVER influxdb_svr CASCADE;
--Testcase 19:
DROP EXTENSION influxdb_fdw CASCADE;
