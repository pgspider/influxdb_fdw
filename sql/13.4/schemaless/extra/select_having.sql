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
CREATE FOREIGN TABLE test_having (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');
CREATE FOREIGN TABLE test_having_nsc (a int, b int, c char(8), d char) SERVER influxdb_svr OPTIONS (table 'test_having');
--Testcase 5:
INSERT INTO test_having_nsc VALUES (0, 1, 'XXXX', 'A');
--Testcase 6:
INSERT INTO test_having_nsc VALUES (1, 2, 'AAAA', 'b');
--Testcase 7:
INSERT INTO test_having_nsc VALUES (2, 2, 'AAAA', 'c');
--Testcase 8:
INSERT INTO test_having_nsc VALUES (3, 3, 'BBBB', 'D');
--Testcase 9:
INSERT INTO test_having_nsc VALUES (4, 3, 'BBBB', 'e');
--Testcase 10:
INSERT INTO test_having_nsc VALUES (5, 3, 'bbbb', 'F');
--Testcase 11:
INSERT INTO test_having_nsc VALUES (6, 4, 'cccc', 'g');
--Testcase 12:
INSERT INTO test_having_nsc VALUES (7, 4, 'cccc', 'h');
--Testcase 13:
INSERT INTO test_having_nsc VALUES (8, 4, 'CCCC', 'I');
--Testcase 14:
INSERT INTO test_having_nsc VALUES (9, 4, 'CCCC', 'j');
--Testcase 15:
SELECT (fields->>'b')::int b, fields->>'c' c FROM test_having
	GROUP BY fields->>'b', fields->>'c' HAVING count(*) = 1 ORDER BY (fields->>'b')::int, fields->>'c';

-- HAVING is effectively equivalent to WHERE in this case
--Testcase 16:
SELECT (fields->>'b')::int b, fields->>'c' c FROM test_having
	GROUP BY fields->>'b', fields->>'c' HAVING (fields->>'b')::int = 3 ORDER BY (fields->>'b')::int, fields->>'c';

--Testcase 17:
SELECT lower((fields->>'c')::char(8)), count(fields->>'c') FROM test_having
	GROUP BY lower((fields->>'c')::char(8)) HAVING count(*) > 2 OR min((fields->>'a')::int) = max((fields->>'a')::int)
	ORDER BY lower((fields->>'c')::char(8));

--Testcase 18:
SELECT fields->>'c' c, max((fields->>'a')::int) FROM test_having
	GROUP BY fields->>'c' HAVING count(*) > 2 OR min((fields->>'a')::int) = max((fields->>'a')::int)
	ORDER BY fields->>'c';

-- test degenerate cases involving HAVING without GROUP BY
-- Per SQL spec, these should generate 0 or 1 row, even without aggregates

--Testcase 19:
SELECT min((fields->>'a')::int), max((fields->>'a')::int) FROM test_having HAVING min((fields->>'a')::int) = max((fields->>'a')::int);
--Testcase 20:
SELECT min((fields->>'a')::int), max((fields->>'a')::int) FROM test_having HAVING min((fields->>'a')::int) < max((fields->>'a')::int);

-- errors: ungrouped column references
--Testcase 21:
SELECT (fields->>'a')::int a FROM test_having HAVING min((fields->>'a')::int) < max((fields->>'a')::int);
--Testcase 22:
SELECT 1 AS one FROM test_having HAVING (fields->>'a')::int > 1;

-- the really degenerate case: need not scan table at all
--Testcase 23:
SELECT 1 AS one FROM test_having HAVING 1 > 2;
--Testcase 24:
SELECT 1 AS one FROM test_having HAVING 1 < 2;

-- and just to prove that we aren't scanning the table:
--Testcase 25:
SELECT 1 AS one FROM test_having WHERE 1/(fields->>'a')::int = 1 HAVING 1 < 2;

--Testcase 26:
-- Clean up:
DELETE FROM test_having_nsc;
DROP FOREIGN TABLE test_having;
DROP FOREIGN TABLE test_having_nsc;
--Testcase 27:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 28:
DROP SERVER influxdb_svr CASCADE;
--Testcase 29:
DROP EXTENSION influxdb_fdw;
