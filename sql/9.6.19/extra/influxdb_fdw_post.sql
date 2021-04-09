-- ===================================================================
-- create FDW objects
-- ===================================================================
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 589:
CREATE EXTENSION influxdb_fdw;

--Testcase 590:
CREATE SERVER testserver1 FOREIGN DATA WRAPPER influxdb_fdw;

CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
    OPTIONS (dbname 'postdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
CREATE SERVER influxdb_svr2 FOREIGN DATA WRAPPER influxdb_fdw
    OPTIONS (dbname 'postdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);

--Testcase 591:
CREATE USER MAPPING FOR public SERVER testserver1 OPTIONS (user 'value', password 'value');
--Testcase 592:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
--Testcase 593:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr2 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

-- import time column as timestamp and text type
--Testcase 594:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 595:
CREATE SCHEMA "S 1";
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO "S 1";

-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 596:
CREATE FOREIGN TABLE ft1 (
	c0 int,
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	time timestamp,
	-- c4 timestamptz,
	-- c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 text
) SERVER influxdb_svr;
ALTER FOREIGN TABLE ft1 DROP COLUMN c0;

--Testcase 597:
CREATE FOREIGN TABLE ft2 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	cx int,
	c3 text,
	time timestamp,
	-- c4 timestamptz,
	-- c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 text
) SERVER influxdb_svr;
ALTER FOREIGN TABLE ft2 DROP COLUMN cx;

--Testcase 598:
CREATE FOREIGN TABLE ft4 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T3');

--Testcase 599:
CREATE FOREIGN TABLE ft5 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T4');

--Testcase 600:
CREATE FOREIGN TABLE ft6 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr2 OPTIONS (table 'T4');

-- ===================================================================
-- tests for validator
-- ===================================================================
-- requiressl, krbsrvname and gsslib are omitted because they depend on
-- configure options
ALTER SERVER testserver1 OPTIONS (
	-- use_remote_estimate 'false',
	-- updatable 'true',
	-- fdw_startup_cost '123.456',
	-- fdw_tuple_cost '0.123',
	-- service 'value',
	-- connect_timeout 'value',
	dbname 'value',
	host 'value',
	-- hostaddr 'value',
	port 'value'
	--client_encoding 'value',
	-- application_name 'value',
	--fallback_application_name 'value',
	-- keepalives 'value',
	-- keepalives_idle 'value',
	-- keepalives_interval 'value',
	-- tcp_user_timeout 'value',
	-- requiressl 'value',
	-- sslcompression 'value',
	-- sslmode 'value',
	-- sslcert 'value',
	-- sslkey 'value',
	-- sslrootcert 'value',
	-- sslcrl 'value',
	--requirepeer 'value',
	-- krbsrvname 'value',
	-- gsslib 'value',
	--replication 'value'
);

-- InfluxDB does not support option extensions
-- Error, invalid list syntax
--ALTER SERVER testserver1 OPTIONS (ADD extensions 'foo; bar');

-- OK but gets a warning
--ALTER SERVER testserver1 OPTIONS (ADD extensions 'foo, bar');
--ALTER SERVER testserver1 OPTIONS (DROP extensions);

ALTER USER MAPPING FOR public SERVER testserver1
	OPTIONS (DROP user, DROP password);

ALTER FOREIGN TABLE ft1 OPTIONS (table 'T1');
ALTER FOREIGN TABLE ft2 OPTIONS (table 'T1');
ALTER FOREIGN TABLE ft1 ALTER COLUMN c1 OPTIONS (column_name 'C1');
ALTER FOREIGN TABLE ft2 ALTER COLUMN c1 OPTIONS (column_name 'C1');
--Testcase 1:
\det+

-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 8:
SELECT c3, time FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
ALTER SERVER influxdb_svr OPTIONS (SET dbname 'no such database');
--Testcase 9:
SELECT c3, time FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER influxdb_svr
            OPTIONS (SET dbname 'postdb')$$;
    END;
$d$;
--Testcase 10:
SELECT c3, time FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work again

-- InfluxDB cannot add user more than one
-- Test that alteration of user mapping options causes reconnection
--ALTER USER MAPPING FOR CURRENT_USER SERVER influxdb_svr
--  OPTIONS (ADD user 'no such user');
--Testcase 11:
--SELECT c3, time FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should fail
--ALTER USER MAPPING FOR CURRENT_USER SERVER influxdb_svr
--  OPTIONS (DROP user);
--Testcase 12:
SELECT c3, time FROM ft1 ORDER BY c3, c1 LIMIT 1;  -- should work
\set VERBOSITY default

-- Now we should be able to run ANALYZE.
-- To exercise multiple code paths, we use local stats on ft1
-- and remote-estimate mode on ft2.
--ANALYZE ft1;
--ALTER FOREIGN TABLE ft2 OPTIONS (use_remote_estimate 'true');

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 13:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
--Testcase 14:
SELECT * FROM ft1 ORDER BY c3, c1 OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 15:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 16:
SELECT * FROM ft1 t1 ORDER BY t1.c3, t1.c1, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 17:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 18:
SELECT t1 FROM ft1 t1 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- empty result
--Testcase 19:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 20:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
--Testcase 21:
SELECT * FROM ft1 t1 WHERE t1.c1 = 101 AND t1.c6 = '1' AND t1.c7 >= '1';
-- with FOR UPDATE/SHARE
--Testcase 22:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 23:
SELECT * FROM ft1 t1 WHERE c1 = 101 FOR UPDATE;
--Testcase 24:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
--Testcase 25:
SELECT * FROM ft1 t1 WHERE c1 = 102 FOR SHARE;
-- aggregate
--Testcase 26:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 27:
SELECT * FROM ft1 t1 WHERE t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 <= 10) ORDER BY c1;
-- subquery+MAX
--Testcase 28:
SELECT * FROM ft1 t1 WHERE t1.c3 = (SELECT MAX(c3) FROM ft2 t2) ORDER BY c1;
-- used in CTE
--Testcase 29:
WITH t1 AS (SELECT * FROM ft1 WHERE c1 <= 10) SELECT t2.c1, t2.c2, t2.c3, t2.time FROM t1, ft2 t2 WHERE t1.c1 = t2.c1 ORDER BY t1.c1;
-- fixed values
--Testcase 30:
SELECT 'fixed', NULL FROM ft1 t1 WHERE c1 = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
SET enable_hashjoin TO false;
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 31:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C1") OFFSET 100 LIMIT 10;
--Testcase 32:
SELECT t1.c1, t2."C1" FROM ft2 t1 JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C1") OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 33:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C1") OFFSET 100 LIMIT 10;
--Testcase 34:
SELECT t1.c1, t2."C1" FROM ft2 t1 LEFT JOIN "S 1"."T1" t2 ON (t1.c1 = t2."C1") OFFSET 100 LIMIT 10;
-- A join between local table and foreign join. ORDER BY clause is added to the
-- foreign join so that the local table can be joined using merge join strategy.
--Testcase 35:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
--Testcase 36:
SELECT t1."C1" FROM "S 1"."T1" t1 left join ft1 t2 join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 37:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
--Testcase 38:
SELECT t1."C1", t2.c1, t3.c1 FROM "S 1"."T1" t1 left join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 39:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
--Testcase 40:
SELECT t1."C1", t2.c1, t3.c1 FROM "S 1"."T1" t1 full join ft1 t2 full join ft2 t3 on (t2.c1 = t3.c1) on (t3.c1 = t1."C1") OFFSET 100 LIMIT 10;
RESET enable_hashjoin;
RESET enable_nestloop;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 41:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 1;         -- Var, OpExpr(b), Const
--Testcase 42:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE t1.c1 = 100 AND t1.c2 = 0; -- BoolExpr
--Testcase 43:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NULL;        -- NullTest
--Testcase 44:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 IS NOT NULL;    -- NullTest
--Testcase 45:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs(c1), 0) = 1; -- FuncExpr
--Testcase 46:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = -c1;          -- OpExpr(l)
--Testcase 47:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE 1 = c1!;           -- OpExpr(r)
--Testcase 48:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c1 IS NOT NULL); -- DistinctExpr
--Testcase 49:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]); -- ScalarArrayOpExpr
--Testcase 50:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c1 = (ARRAY[c1,c2,3])[1]; -- SubscriptingRef
--Testcase 51:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c6 = E'foo''s\\bar';  -- check special chars
--Testcase 52:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE c8 = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 53:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T1" a, ft2 b WHERE a."C1" = 47 AND b.c1 = a.c2;
--Testcase 54:
SELECT * FROM ft2 a, ft2 b WHERE a.c1 = 47 AND b.c1 = a.c2;

-- check both safe and unsafe join conditions
--Testcase 55:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
--Testcase 56:
SELECT * FROM ft2 a, ft2 b
WHERE a.c2 = 6 AND b.c1 = a.c1 AND a.c8 = 'foo' AND b.c7 = upper(a.c7);
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
--Testcase 57:
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 58:
SELECT * FROM ft2 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft1 WHERE c1 < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 59:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, random();
--Testcase 60:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY ft2.c1, ft2.c3 collate "C";

-- user-defined operator/function
--Testcase 601:
CREATE FUNCTION influxdb_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
--Testcase 602:
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 61:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 62:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = abs(t1.c2);
--Testcase 63:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 64:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = t1.c2;

-- by default, user-defined ones cannot
--Testcase 65:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = influxdb_fdw_abs(t1.c2);
--Testcase 66:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = influxdb_fdw_abs(t1.c2);
--Testcase 67:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 68:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- ORDER BY can be shipped, though
--Testcase 69:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 70:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- but let's put them in an extension ...
ALTER EXTENSION influxdb_fdw ADD FUNCTION influxdb_fdw_abs(int);
ALTER EXTENSION influxdb_fdw ADD OPERATOR === (int, int);
-- ALTER SERVER loopback OPTIONS (ADD extensions 'postgres_fdw');

-- ... now they can be shipped
--Testcase 71:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = influxdb_fdw_abs(t1.c2);
--Testcase 72:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 = influxdb_fdw_abs(t1.c2);
--Testcase 73:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 74:
SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 75:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;
--Testcase 76:
SELECT * FROM ft1 t1 WHERE t1.c1 === t1.c2 order by t1.c2 limit 1;

-- ===================================================================
-- JOIN queries
-- ===================================================================
-- Analyze ft4 and ft5 so that we have better statistics. These tables do not
-- have use_remote_estimate set.
--ANALYZE ft4;
--ANALYZE ft5;

-- join two tables
--Testcase 77:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 78:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 79:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 80:
SELECT t1.c1, t2.c2, t3.c3 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) JOIN ft4 t3 ON (t3.c1 = t1.c1) ORDER BY t1.c3, t1.c1 OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 81:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 82:
SELECT t1.c1, t2.c1 FROM ft4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 83:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 84:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 85:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
--Testcase 86:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1) WHERE t1.c1 < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 87:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 88:
SELECT t1.c1, t1.c2, t2.c1, t2.c2 FROM ft4 t1 LEFT JOIN (SELECT * FROM ft5 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
			WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
-- right outer join
--Testcase 89:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
--Testcase 90:
SELECT t1.c1, t2.c1 FROM ft5 t1 RIGHT JOIN ft4 t2 ON (t1.c1 = t2.c1) ORDER BY t2.c1, t1.c1 OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 91:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 92:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 93:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
--Testcase 94:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 95:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 96:
SELECT t1.c1, t2.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1;
--Testcase 97:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 98:
SELECT 1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 99:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 100:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM ft4 t2 LEFT JOIN ft5 t3 ON (t2.c1 = t3.c1) WHERE (t2.c1 between 50 and 60)) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 101:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
--Testcase 102:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t1 FULL JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (t1.c1 = ss.a) ORDER BY t1.c1, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 103:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 104:
SELECT t1.c1, ss.a, ss.b FROM (SELECT c1 FROM "S 1"."T3" WHERE c1 = 50) t1 INNER JOIN (SELECT t2.c1, t3.c1 FROM (SELECT c1 FROM ft4 WHERE c1 between 50 and 60) t2 FULL JOIN (SELECT c1 FROM ft5 WHERE c1 between 50 and 60) t3 ON (t2.c1 = t3.c1) WHERE t2.c1 IS NULL OR t2.c1 IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY t1.c1, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 105:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
--Testcase 106:
SELECT t1.c1, t2.c1, t3.c1 FROM ft4 t1 INNER JOIN ft5 t2 ON (t1.c1 = t2.c1 + 1 and t1.c1 between 50 and 60) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) ORDER BY t1.c1, t2.c1, t3.c1 LIMIT 10;
-- full outer join three tables
--Testcase 107:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 108:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 109:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 110:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 111:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 112:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 113:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 114:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 115:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 116:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) FULL JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- right outer join + left outer join
--Testcase 117:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 118:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 RIGHT JOIN ft2 t2 ON (t1.c1 = t2.c1) LEFT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- left outer join + right outer join
--Testcase 119:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
--Testcase 120:
SELECT t1.c1, t2.c2, t3.c3 FROM ft2 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN ft4 t3 ON (t2.c1 = t3.c1) OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 121:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
--Testcase 122:
SELECT t1.c1, t2.c1 FROM ft4 t1 FULL JOIN ft5 t2 ON (t1.c1 = t2.c1) WHERE (t1.c1 = t2.c1 OR t1.c1 IS NULL) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 123:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE influxdb_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
-- skip, influxdb does not have option 'extensions'
-- ALTER SERVER influxdb_svr OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE postgres_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
-- ALTER SERVER loopback OPTIONS (ADD extensions 'postgres_fdw');
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 125:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 127:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 129:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 131:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 132:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 133:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 134:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 135:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 136:
SELECT t1.c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c1) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 137:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
--Testcase 138:
SELECT t1.c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE t1.c1 = t2.c2) ORDER BY t1.c1 OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 139:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 140:
SELECT t1.c1, t2.c1 FROM ft1 t1 CROSS JOIN ft2 t2 ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 141:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 142:
SELECT t1.c1, t2.c1 FROM ft5 t1 JOIN ft6 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 143:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
--Testcase 144:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c8 = t2.c8) ORDER BY t1.c1, t2.c1 OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 145:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 146:
SELECT t1.c1, t2.c1 FROM ft1 t1 LEFT JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = 'foo' ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
--Testcase 148:
SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, t1.c1 OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 149:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 150:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1) UNION SELECT t1.c1, t2.c1 FROM ft1 t1 JOIN ft2 t2 ON (t1.c1 = t2.c1)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 151:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C1" OFFSET 10 LIMIT 10;
--Testcase 152:
SELECT t1."C1" FROM "S 1"."T1" t1, LATERAL (SELECT DISTINCT t2.c1, t3.c1 FROM ft1 t2, ft2 t3 WHERE t2.c1 = t3.c1 AND t2.c2 = t1.c2) q ORDER BY t1."C1" OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 153:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;
--Testcase 154:
SELECT q.a, ft2.c1 FROM (SELECT 13 FROM ft1 WHERE c1 = 13) q(a) RIGHT JOIN ft2 ON (q.a = ft2.c1) WHERE ft2.c1 BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 155:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15;
--Testcase 156:
SELECT ft4.c1, q.* FROM ft4 LEFT JOIN (SELECT 13, ft1.c1, ft2.c1 FROM ft1 RIGHT JOIN ft2 ON (ft1.c1 = ft2.c1) WHERE ft1.c1 = 12) q(a, b, c) ON (ft4.c1 = q.b) WHERE ft4.c1 BETWEEN 10 AND 15 ORDER BY ft4.c1;

-- join with nullable side with some columns with null values
-- InfluxDB_FDW does not support UPDATE
-- UPDATE ft5 SET c3 = null where c1 % 9 = 0;
--Testcase 157:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;
--Testcase 158:
SELECT ft5, ft5.c1, ft5.c2, ft5.c3, ft4.c1, ft4.c2 FROM ft5 left join ft4 on ft5.c1 = ft4.c1 WHERE ft4.c1 BETWEEN 10 and 30 ORDER BY ft5.c1, ft4.c1;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
--Testcase 603:
CREATE FOREIGN TABLE local_tbl (c1 int NOT NULL, c2 int NOT NULL, c3 text) SERVER influxdb_svr;
--Testcase 159:
--INSERT INTO local_tbl SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
--ANALYZE local_tbl;
SET enable_nestloop TO false;
SET enable_hashjoin TO false;
--Testcase 160:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 ORDER BY ft1.c1 FOR UPDATE;
--Testcase 161:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE ft1.c1 = ft2.c1 AND ft1.c2 = ft4.c1
    AND ft1.c2 = ft5.c1 AND ft1.c2 = local_tbl.c1 AND ft1.c1 < 100 AND ft2.c1 < 100 ORDER BY ft1.c1 FOR UPDATE;
RESET enable_nestloop;
RESET enable_hashjoin;
--Testcase 604:
DROP FOREIGN TABLE local_tbl;

-- check join pushdown in situations where multiple userids are involved
--Testcase 605:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 606:
CREATE USER MAPPING FOR regress_view_owner SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

--Testcase 607:
CREATE VIEW v4 AS SELECT * FROM ft4;
--Testcase 608:
CREATE VIEW v5 AS SELECT * FROM ft5;
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 162:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 163:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 164:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 165:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN v5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;

--Testcase 166:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 167:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 168:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 169:
SELECT t1.c1, t2.c2 FROM v4 t1 LEFT JOIN ft5 t2 ON (t1.c1 = t2.c1) ORDER BY t1.c1, t2.c1 OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
--Testcase 609:
DROP OWNED BY regress_view_owner;
--Testcase 610:
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 170:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;
--Testcase 171:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2;

--Testcase 172:
explain (verbose, costs off)
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;
--Testcase 173:
select count(c6), sum(c1), avg(c1), min(c2), max(c1), stddev(c2), sum(c1) * (random() <= 1)::int as sum2 from ft1 where c2 < 5 group by c2 order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 174:
explain (verbose, costs off)
select sum(c1 * (random() <= 1)::int) as sum, avg(c1) from ft1;

-- Aggregate over join query
--Testcase 175:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;
--Testcase 176:
select count(*), sum(t1.c1), avg(t2.c1) from ft1 t1 inner join ft1 t2 on (t1.c2 = t2.c2) where t1.c2 = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 177:
explain (verbose, costs off)
select sum(t1.c1), count(t2.c1) from ft1 t1 inner join ft2 t2 on (t1.c1 = t2.c1) where ((t1.c1 * t2.c1)/(t1.c1 * t2.c1)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 178:
explain (verbose, costs off)
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;
--Testcase 179:
select c2/2, sum(c2) * (c2/2) from ft1 group by c2/2 order by c2/2;

-- Aggregates in subquery are pushed down.
--Testcase 180:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;
--Testcase 181:
select count(x.a), sum(x.a) from (select c2 a, sum(c1) b from ft1 group by c2, sqrt(c1) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 182:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;
--Testcase 183:
select c2 * (random() <= 1)::int as sum1, sum(c1) * c2 as sum2 from ft1 group by c2 order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 184:
explain (verbose, costs off)
select c2 * (random() <= 1)::int as c2 from ft2 group by c2 * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 185:
explain (verbose, costs off)
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 186:
select count(c2) w, c2 x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 187:
explain (verbose, costs off)
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);
--Testcase 188:
select c2, c2 from ft1 where c2 > 6 group by 1, 2 order by sum(c1);

-- Testing HAVING clause shippability
--Testcase 189:
explain (verbose, costs off)
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;
--Testcase 190:
select c2, sum(c1) from ft2 group by c2 having avg(c1) < 500 and sum(c1) < 49800 order by c2;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 191:
explain (verbose, costs off)
select count(*) from (select time, count(c1) from ft1 group by time, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;
--Testcase 192:
select count(*) from (select time, count(c1) from ft1 group by time, sqrt(c2) having (avg(c1) / avg(c1)) * random() <= 1 and avg(c1) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 193:
explain (verbose, costs off)
select sum(c1) from ft1 group by c2 having avg(c1 * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 194:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1;
--Testcase 195:
select exists(select 1 from pg_enum), sum(c1) from ft1;

--Testcase 196:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;
--Testcase 197:
select exists(select 1 from pg_enum), sum(c1) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 198:
explain (verbose, costs off)
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;
--Testcase 199:
select array_agg(c1 order by c1) from ft1 where c1 < 100 group by c2 order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 200:
explain (verbose, costs off)
select array_agg(time order by c1 desc) from ft2 where c2 = 6 and c1 < 50;
--Testcase 201:
select array_agg(time order by c1 desc) from ft2 where c2 = 6 and c1 < 50;

-- DISTINCT within aggregate
--Testcase 202:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 203:
select array_agg(distinct (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 204:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 205:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

--Testcase 206:
explain (verbose, costs off)
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;
--Testcase 207:
select array_agg(distinct (t1.c1)%5 order by (t1.c1)%5 desc nulls last) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) where t1.c1 < 20 or (t1.c1 is null and t2.c1 < 5) group by (t2.c1)%3 order by 1;

-- FILTER within aggregate
--Testcase 208:
explain (verbose, costs off)
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;
--Testcase 209:
select sum(c1) filter (where c1 < 100 and c2 > 5) from ft1 group by c2 order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 210:
explain (verbose, costs off)
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;
--Testcase 211:
select sum(c1%3), sum(distinct c1%3 order by c1%3) filter (where c1%3 < 2), c2 from ft1 where c2 = 6 group by c2;

-- Outer query is aggregation query
--Testcase 212:
explain (verbose, costs off)
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 213:
select distinct (select count(*) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 214:
explain (verbose, costs off)
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;
--Testcase 215:
select distinct (select count(t1.c1) filter (where t2.c2 = 6 and t2.c1 < 10) from ft1 t1 where t1.c1 = 6) from ft2 t2 where t2.c2 % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 216:
explain (verbose, costs off)
select sum(c1) filter (where (c1 / c1) * random() <= 1) from ft1 group by c2 order by 1;
--Testcase 217:
explain (verbose, costs off)
select sum(c2) filter (where c2 in (select c2 from ft1 where c2 < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 218:
explain (verbose, costs off)
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;
--Testcase 219:
select c2, rank('10'::varchar) within group (order by c6), percentile_cont(c2/10::numeric) within group (order by c1) from ft1 where c2 < 10 group by c2 having percentile_cont(c2/10::numeric) within group (order by c1) < 500 order by c2;

-- Using multiple arguments within aggregates
--Testcase 220:
explain (verbose, costs off)
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;
--Testcase 221:
select c1, rank(c1, c2) within group (order by c1, c2) from ft1 group by c1, c2 having c1 = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 611:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 612:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 222:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Add function and aggregate into extension
alter extension influxdb_fdw add function least_accum(anyelement, variadic anyarray);
alter extension influxdb_fdw add aggregate least_agg(variadic items anyarray);

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 223:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;
--Testcase 224:
select c2, least_agg(c1) from ft1 where c2 < 100 group by c2 order by c2;

-- Remove function and aggregate from extension
alter extension influxdb_fdw drop function least_accum(anyelement, variadic anyarray);
alter extension influxdb_fdw drop aggregate least_agg(variadic items anyarray);

-- Not pushed down as we have dropped objects from extension.
--Testcase 225:
explain (verbose, costs off)
select c2, least_agg(c1) from ft1 group by c2 order by c2;

-- Cleanup
reset enable_hashagg;
--Testcase 613:
drop aggregate least_agg(variadic items anyarray);
--Testcase 614:
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
--Testcase 615:
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

--Testcase 616:
create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

--Testcase 617:
create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

--Testcase 618:
create operator family my_op_family using btree;

--Testcase 619:
create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

--Testcase 620:
create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 226:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Update local stats on ft2
ANALYZE ft2;

-- Add into extension
alter extension influxdb_fdw add operator class my_op_class using btree;
alter extension influxdb_fdw add function my_op_cmp(a int, b int);
alter extension influxdb_fdw add operator family my_op_family using btree;
alter extension influxdb_fdw add operator public.<^(int, int);
alter extension influxdb_fdw add operator public.=^(int, int);
alter extension influxdb_fdw add operator public.>^(int, int);

-- Now this will be pushed as sort operator is part of the extension.
--Testcase 227:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;
--Testcase 228:
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Remove from extension
alter extension influxdb_fdw drop operator class my_op_class using btree;
alter extension influxdb_fdw drop function my_op_cmp(a int, b int);
alter extension influxdb_fdw drop operator family my_op_family using btree;
alter extension influxdb_fdw drop operator public.<^(int, int);
alter extension influxdb_fdw drop operator public.=^(int, int);
alter extension influxdb_fdw drop operator public.>^(int, int);

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 229:
explain (verbose, costs off)
select array_agg(c1 order by c1 using operator(public.<^)) from ft2 where c2 = 6 and c1 < 100 group by c2;

-- Cleanup
--Testcase 621:
drop operator class my_op_class using btree;
--Testcase 622:
drop function my_op_cmp(a int, b int);
--Testcase 623:
drop operator family my_op_family using btree;
--Testcase 624:
drop operator public.>^(int, int);
--Testcase 625:
drop operator public.=^(int, int);
--Testcase 626:
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 230:
explain (verbose, costs off)
select count(t1.c3) from ft2 t1 left join ft2 t2 on (t1.c1 = random() * t2.c2);

-- Subquery in FROM clause having aggregate
--Testcase 231:
explain (verbose, costs off)
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;
--Testcase 232:
select count(*), x.b from ft1, (select c2 a, sum(c1) b from ft1 group by c2) x where ft1.c2 = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 233:
explain (verbose, costs off)
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;
--Testcase 234:
select avg(t1.c1), sum(t2.c1) from ft4 t1 full join ft5 t2 on (t1.c1 = t2.c1) group by t2.c1 having (avg(t1.c1) is null and sum(t2.c1) < 10) or sum(t2.c1) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 235:
explain (verbose, costs off)
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);
--Testcase 236:
select count(*), sum(t1.c1), avg(t2.c1) from (select c1 from ft4 where c1 between 50 and 60) t1 full join (select c1 from ft5 where c1 between 50 and 60) t2 on (t1.c1 = t2.c1);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 237:
explain (verbose, costs off)
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 238:
select sum(c2) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
set enable_hashagg to false;
--Testcase 239:
explain (verbose, costs off)
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C1" < 100 order by 1;
--Testcase 240:
select c2, sum from "S 1"."T1" t1, lateral (select sum(t2.c1 + t1."C1") sum from ft2 t2 group by t2.c1) qry where t1.c2 * 2 = qry.sum and t1.c2 < 3 and t1."C1" < 100 order by 1;
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 241:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C1";

--Testcase 242:
SELECT ref_0.c2, subq_1.*
FROM
    "S 1"."T1" AS ref_0,
    LATERAL (
        SELECT ref_0."C1" c1, subq_0.*
        FROM (SELECT ref_0.c2, ref_1.c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.c3)
    ) AS subq_1
WHERE ref_0."C1" < 10 AND subq_1.c3 = '00001'
ORDER BY ref_0."C1";

-- Check with placeHolderVars
--Testcase 243:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);
--Testcase 244:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg(ft1.c1), sum(ft2.c1) from ft1 right join ft2 on (ft1.c1 = ft2.c1)) q(a, b, c) on (ft4.c1 <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 245:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 246:
select c2, sum(c1) from ft1 where c2 < 3 group by rollup(c2) order by 1 nulls last;
--Testcase 247:
explain (verbose, costs off)
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 248:
select c2, sum(c1) from ft1 where c2 < 3 group by cube(c2) order by 1 nulls last;
--Testcase 249:
explain (verbose, costs off)
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 250:
select c2, c6, sum(c1) from ft1 where c2 < 3 group by grouping sets(c2, c6) order by 1 nulls last, 2 nulls last;
--Testcase 251:
explain (verbose, costs off)
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;
--Testcase 252:
select c2, sum(c1), grouping(c2) from ft1 where c2 < 3 group by c2 order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
--Testcase 253:
explain (verbose, costs off)
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;
--Testcase 254:
select distinct sum(c1)/1000 s from ft2 where c2 < 6 group by c2 order by 1;

-- WindowAgg
--Testcase 255:
explain (verbose, costs off)
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 256:
select c2, sum(c2), count(c2) over (partition by c2%2) from ft2 where c2 < 10 group by c2 order by 1;
--Testcase 257:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 258:
select c2, array_agg(c2) over (partition by c2%2 order by c2 desc) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 259:
explain (verbose, costs off)
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;
--Testcase 260:
select c2, array_agg(c2) over (partition by c2%2 order by c2 range between current row and unbounded following) from ft1 where c2 < 10 group by c2 order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 261:
PREPARE st1(int, int) AS SELECT t1.c3, t2.c3 FROM ft1 t1, ft2 t2 WHERE t1.c1 = $1 AND t2.c1 = $2;
--Testcase 262:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 263:
EXECUTE st1(1, 1);
--Testcase 264:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 265:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(time) = '1970-01-17'::date) ORDER BY c1;
--Testcase 266:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 267:
EXECUTE st2(10, 20);
--Testcase 268:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 269:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 < $2 AND t1.c3 IN (SELECT c3 FROM ft2 t2 WHERE c1 > $1 AND date(time) = '1970-01-17'::date) ORDER BY c1;
--Testcase 270:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 271:
EXECUTE st3(10, 20);
--Testcase 272:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 273:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE t1.c1 = $1;
--Testcase 274:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 275:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 276:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 277:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 278:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 279:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 280:
PREPARE st5(text,int) AS SELECT * FROM ft1 t1 WHERE c8 = $1 and c1 = $2;
--Testcase 281:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 282:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 283:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 284:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 285:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 286:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 287:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 288:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE t1.c1 = t1.c2;
--Testcase 289:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
-- influxdb doesnot support INSERT
-- PREPARE st7 AS INSERT INTO ft1 (c1,c2,c3) VALUES (1001,101,'foo');
-- EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
-- ALTER TABLE "S 1"."T 1" RENAME TO "T 0";
ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T0');
--Testcase 290:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 291:
EXECUTE st6;
-- EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
--ALTER TABLE "S 1"."T 0" RENAME TO "T 1";
ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T1');

--Testcase 292:
PREPARE st8 AS SELECT count(c3) FROM ft1 t1 WHERE t1.c1 === t1.c2;
--Testcase 293:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
-- Skip, Influxdb does not support extensions
-- ALTER SERVER loopback OPTIONS (DROP extensions);
-- EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
-- EXECUTE st8;
-- ALTER SERVER loopback OPTIONS (ADD extensions 'postgres_fdw');

-- cleanup
DEALLOCATE st1;
DEALLOCATE st2;
DEALLOCATE st3;
DEALLOCATE st4;
DEALLOCATE st5;
DEALLOCATE st6;
-- DEALLOCATE st7;
DEALLOCATE st8;

-- System columns, except ctid and oid, should not be sent to remote
--Testcase 294:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 295:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass LIMIT 1;
--Testcase 296:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 297:
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 298:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 299:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 300:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 301:
SELECT ctid, * FROM ft1 t1 LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
--Testcase 627:
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
--Testcase 628:
    SELECT c1 INTO v_c1 FROM ft1 WHERE c1 = p_c1 LIMIT 1;
    PERFORM c1 FROM ft1 WHERE c1 = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 302:
SELECT f_test(100);
--Testcase 629:
DROP FUNCTION f_test(int);

-- ===================================================================
-- conversion error
-- ===================================================================
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
--Testcase 303:
SELECT * FROM ft1 WHERE c1 = 1;  -- ERROR
--Testcase 304:
SELECT  ft1.c1,  ft2.c2, ft1.c8 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
--Testcase 305:
SELECT  ft1.c1,  ft2.c2, ft1 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
--Testcase 306:
SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE text;

-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
BEGIN;
DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
--Testcase 308:
FETCH c;
SAVEPOINT s;
ERROR OUT;          -- ERROR
ROLLBACK TO s;
--Testcase 309:
FETCH c;
SAVEPOINT s;
-- InfluxDB does not display ERROR "division by zero", just displays the record success
--Testcase 310:
SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
ROLLBACK TO s;
--Testcase 311:
FETCH c;
--Testcase 312:
SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
COMMIT;

-- ===================================================================
-- test handling of collations
-- ===================================================================
--Testcase 630:
create foreign table loct3 (f1 text collate "C", f2 text, f3 varchar(10)) server influxdb_svr;
--Testcase 631:
create foreign table ft3 (f1 text collate "C", f2 text, f3 varchar(10))
  server influxdb_svr options (table 'loct3');

-- can be sent to remote
--Testcase 313:
explain (verbose, costs off) select * from ft3 where f1 = 'foo';
--Testcase 314:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "C" = 'foo';
--Testcase 315:
explain (verbose, costs off) select * from ft3 where f2 = 'foo';
--Testcase 316:
explain (verbose, costs off) select * from ft3 where f3 = 'foo';
--Testcase 317:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 and l.f1 = 'foo';
-- can't be sent to remote
--Testcase 318:
explain (verbose, costs off) select * from ft3 where f1 COLLATE "POSIX" = 'foo';
--Testcase 319:
explain (verbose, costs off) select * from ft3 where f1 = 'foo' COLLATE "C";
--Testcase 320:
explain (verbose, costs off) select * from ft3 where f2 COLLATE "C" = 'foo';
--Testcase 321:
explain (verbose, costs off) select * from ft3 where f2 = 'foo' COLLATE "C";
--Testcase 322:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.f3 = l.f3 COLLATE "POSIX" and l.f1 = 'foo';

/*
-- Skip test because InfluxDB_FDW does not support INSERT, UPDATE, DELETE
-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
INSERT INTO ft2 (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2 LIMIT 20;
INSERT INTO ft2 (c1,c2,c3)
  VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc') RETURNING *;
INSERT INTO ft2 (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;  -- can be pushed down
UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;
EXPLAIN (verbose, costs off)
  DELETE FROM ft2 WHERE c1 % 10 = 5 RETURNING c1, c4;                               -- can be pushed down
DELETE FROM ft2 WHERE c1 % 10 = 5 RETURNING c1, c4;
EXPLAIN (verbose, costs off)
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;                -- can be pushed down
DELETE FROM ft2 USING ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 2;
SELECT c1,c2,c3,c4 FROM ft2 ORDER BY c1;
EXPLAIN (verbose, costs off)
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
INSERT INTO ft2 (c1,c2,c3) VALUES (1200,999,'foo') RETURNING tableoid::regclass;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;             -- can be pushed down
UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;
EXPLAIN (verbose, costs off)
DELETE FROM ft2 WHERE c1 = 1200 RETURNING tableoid::regclass;                       -- can be pushed down
DELETE FROM ft2 WHERE c1 = 1200 RETURNING tableoid::regclass;

-- Test UPDATE/DELETE with RETURNING on a three-table join
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1
  RETURNING ft2, ft2.*, ft4, ft4.*;       -- can be pushed down
UPDATE ft2 SET c3 = 'foo'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1
  RETURNING ft2, ft2.*, ft4, ft4.*;
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1
  RETURNING 100;                          -- can be pushed down
DELETE FROM ft2
  USING ft4 LEFT JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 1200 AND ft2.c1 % 10 = 0 AND ft2.c2 = ft4.c1
  RETURNING 100;
DELETE FROM ft2 WHERE ft2.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
EXPLAIN (verbose, costs off)
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;
UPDATE ft2 AS target SET (c2, c7) = (
    SELECT c2 * 10, c7
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

UPDATE ft2 AS target SET (c2) = (
    SELECT c2 / 10
        FROM ft2 AS src
        WHERE target.c1 = src.c1
) WHERE c1 > 1100;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
ALTER SERVER loopback OPTIONS (DROP extensions);
INSERT INTO ft2 (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;            -- can't be pushed down
UPDATE ft2 SET c3 = 'bar' WHERE postgres_fdw_abs(c1) > 2000 RETURNING *;
EXPLAIN (verbose, costs off)
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1
  RETURNING ft2.*, ft4.*, ft5.*;                                                    -- can't be pushed down
UPDATE ft2 SET c3 = 'baz'
  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1
  RETURNING ft2.*, ft4.*, ft5.*;
EXPLAIN (verbose, costs off)
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1
  RETURNING ft2.c1, ft2.c2, ft2.c3;       -- can't be pushed down
DELETE FROM ft2
  USING ft4 INNER JOIN ft5 ON (ft4.c1 === ft5.c1)
  WHERE ft2.c1 > 2000 AND ft2.c2 = ft4.c1
  RETURNING ft2.c1, ft2.c2, ft2.c3;
DELETE FROM ft2 WHERE ft2.c1 > 2000;
ALTER SERVER loopback OPTIONS (ADD extensions 'postgres_fdw');

-- Test that trigger on remote table works as expected
CREATE OR REPLACE FUNCTION "S 1".F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1"."T 1" FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();

INSERT INTO ft2 (c1,c2,c3) VALUES (1208, 818, 'fff') RETURNING *;
INSERT INTO ft2 (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;') RETURNING *;
UPDATE ft2 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200 RETURNING *;

-- Test errors thrown on remote side during update
ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK (c2 >= 0);

INSERT INTO ft1(c1, c2) VALUES(11, 12);  -- duplicate key
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- works
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
INSERT INTO ft1(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

-- Test savepoint/rollback behavior
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;
begin;
update ft2 set c2 = 42 where c2 = 0;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
savepoint s1;
update ft2 set c2 = 44 where c2 = 4;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
release savepoint s1;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
savepoint s2;
update ft2 set c2 = 46 where c2 = 6;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
rollback to savepoint s2;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
release savepoint s2;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
savepoint s3;
update ft2 set c2 = -2 where c2 = 42 and c1 = 10; -- fail on remote side
rollback to savepoint s3;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
release savepoint s3;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
-- none of the above is committed yet remotely
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;
commit;
select c2, count(*) from ft2 where c2 < 500 group by 1 order by 1;
select c2, count(*) from "S 1"."T 1" where c2 < 500 group by 1 order by 1;

VACUUM ANALYZE "S 1"."T 1";
*/

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 323:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795 LIMIT 10;
--Testcase 324:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS LAST, c1 OFFSET 795  LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 325:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 326:
SELECT * FROM ft1 ORDER BY c6 DESC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 327:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;
--Testcase 328:
SELECT * FROM ft1 ORDER BY c6 ASC NULLS FIRST, c1 OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK (c2 >= 0);
--Testcase 329:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
-- InfluxDB return null value because it does not have any record.
--Testcase 330:
SELECT count(*) FROM ft1 WHERE c2 < 0;
SET constraint_exclusion = 'on';
--Testcase 331:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 < 0;
--Testcase 332:
SELECT count(*) FROM ft1 WHERE c2 < 0;
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
-- INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
-- UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK (c2 < 0);
--Testcase 333:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 334:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
SET constraint_exclusion = 'on';
--Testcase 335:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE c2 >= 0;
--Testcase 336:
SELECT count(*) FROM ft1 WHERE c2 >= 0;
RESET constraint_exclusion;
-- local check constraint is not actually enforced
-- INSERT INTO ft1(c1, c2) VALUES(1111, 2);
-- UPDATE ft1 SET c2 = c2 + 1 WHERE c1 = 1;
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================

--Testcase 632:
CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;

--Testcase 633:
CREATE TABLE base_tbl (a int, b int);
ALTER TABLE base_tbl SET (autovacuum_enabled = 'false');
--Testcase 634:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON base_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
-- skip, Influxdb does not support INSERT. However, we keep this test case to test locally
--CREATE FOREIGN TABLE foreign_tbl (a int, b int)
--  SERVER influxdb_svr OPTIONS (table 'base_tbl');
--Testcase 635:
CREATE VIEW rw_view AS SELECT * FROM base_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 636:
\d+ rw_view

--Testcase 337:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 5);
--Testcase 338:
INSERT INTO rw_view VALUES (0, 5); -- should fail
--Testcase 339:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 15);
--Testcase 340:
INSERT INTO rw_view VALUES (0, 15); -- ok
--Testcase 341:
SELECT * FROM base_tbl;

--Testcase 342:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 5;
--Testcase 343:
UPDATE rw_view SET b = b + 5; -- should fail
--Testcase 344:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 15;
--Testcase 345:
UPDATE rw_view SET b = b + 15; -- ok
--Testcase 346:
SELECT * FROM base_tbl;

--DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 637:
DROP TRIGGER row_before_insupd_trigger ON base_tbl;
--Testcase 638:
DROP TABLE base_tbl CASCADE;

-- test WCO for partitions

--Testcase 639:
CREATE TABLE child_tbl (a int, b int);
ALTER TABLE child_tbl SET (autovacuum_enabled = 'false');
--Testcase 640:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON child_tbl FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
--CREATE FOREIGN TABLE foreign_tbl (a int, b int)
--  SERVER influxdb_svr OPTIONS (table 'child_tbl');

--Testcase 641:
CREATE TABLE parent_tbl (a int, b int) PARTITION BY RANGE(a);
ALTER TABLE parent_tbl ATTACH PARTITION child_tbl FOR VALUES FROM (0) TO (100);

--Testcase 642:
CREATE VIEW rw_view AS SELECT * FROM parent_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 643:
\d+ rw_view

--Testcase 347:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 5);
--Testcase 348:
INSERT INTO rw_view VALUES (0, 5); -- should fail
--Testcase 349:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 15);
--Testcase 350:
INSERT INTO rw_view VALUES (0, 15); -- ok
--Testcase 351:
SELECT * FROM child_tbl;

--Testcase 352:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 5;
--Testcase 353:
UPDATE rw_view SET b = b + 5; -- should fail
--Testcase 354:
EXPLAIN (VERBOSE, COSTS OFF)
UPDATE rw_view SET b = b + 15;
--Testcase 355:
UPDATE rw_view SET b = b + 15; -- ok
--Testcase 356:
SELECT * FROM child_tbl;

--DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 644:
DROP TRIGGER row_before_insupd_trigger ON child_tbl;
--Testcase 645:
DROP TABLE parent_tbl CASCADE;

--Testcase 646:
DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
--Testcase 647:
create table loc1 (f1 serial, f2 text);
alter table loc1 set (autovacuum_enabled = 'false');
--create foreign table rem1 (f1 serial, f2 text)
--  server influxdb_svr options(table 'loc1');
--Testcase 357:
select pg_catalog.setval('loc1_f1_seq', 10, false);
--Testcase 358:
insert into loc1(f2) values('hi');
--Testcase 359:
insert into loc1(f2) values('hi remote');
--Testcase 360:
insert into loc1(f2) values('bye');
--Testcase 361:
insert into loc1(f2) values('bye remote');
--Testcase 362:
select * from loc1;
--select * from rem1;

-- ===================================================================
-- test generated columns
-- ===================================================================
--Testcase 648:
create table gloc1 (a int, b int generated always as (a * 2) stored);
alter table gloc1 set (autovacuum_enabled = 'false');
--create foreign table grem1 (
--  a int,
--  b int generated always as (a * 2) stored)
--  server influxdb_svr options(table 'gloc1');
--Testcase 363:
insert into gloc1 (a) values (1), (2);
--Testcase 364:
update gloc1 set a = 22 where a = 2;
--Testcase 365:
select * from gloc1;
--select * from grem1;

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
--Testcase 649:
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

--Testcase 650:
CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON loc1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 651:
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON loc1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--Testcase 652:
CREATE OR REPLACE FUNCTION trigger_data()  RETURNS trigger
LANGUAGE plpgsql AS $$

declare
	oldnew text[];
	relid text;
    argstr text;
begin

	relid := TG_relid::regclass;
	argstr := '';
	for i in 0 .. TG_nargs - 1 loop
		if i > 0 then
			argstr := argstr || ', ';
		end if;
		argstr := argstr || TG_argv[i];
	end loop;

    RAISE NOTICE '%(%) % % % ON %',
		tg_name, argstr, TG_when, TG_level, TG_OP, relid;
    oldnew := '{}'::text[];
	if TG_OP != 'INSERT' then
		oldnew := array_append(oldnew, format('OLD: %s', OLD));
	end if;

	if TG_OP != 'DELETE' then
		oldnew := array_append(oldnew, format('NEW: %s', NEW));
	end if;

    RAISE NOTICE '%', array_to_string(oldnew, ',');

	if TG_OP = 'DELETE' then
		return OLD;
	else
		return NEW;
	end if;
end;
$$;

-- Test basic functionality
--Testcase 653:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 654:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 366:
delete from loc1;
--Testcase 367:
insert into loc1 values(1,'insert');
--Testcase 368:
update loc1 set f2  = 'update' where f1 = 1;
--Testcase 369:
update loc1 set f2 = f2 || f2;


-- cleanup
--Testcase 655:
DROP TRIGGER trig_row_before ON loc1;
--Testcase 656:
DROP TRIGGER trig_row_after ON loc1;
--Testcase 657:
DROP TRIGGER trig_stmt_before ON loc1;
--Testcase 658:
DROP TRIGGER trig_stmt_after ON loc1;

--Testcase 370:
DELETE from loc1;

-- Test multiple AFTER ROW triggers on a foreign table
--Testcase 659:
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 660:
CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 661:
insert into loc1 values(1,'insert');
--Testcase 662:
update loc1 set f2  = 'update' where f1 = 1;
--Testcase 663:
update loc1 set f2 = f2 || f2;
--Testcase 664:
delete from loc1;

-- cleanup
--Testcase 665:
DROP TRIGGER trig_row_after1 ON loc1;
--Testcase 666:
DROP TRIGGER trig_row_after2 ON loc1;

-- Test WHEN conditions

--Testcase 667:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 668:
CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON loc1
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 373:
INSERT INTO loc1 values(1, 'insert');
--Testcase 374:
UPDATE loc1 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 375:
INSERT INTO loc1 values(2, 'update');
--Testcase 376:
UPDATE loc1 set f2 = 'update update' where f1 = '2';

--Testcase 669:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON loc1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 670:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON loc1
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 379:
DELETE FROM loc1;

-- cleanup
--Testcase 671:
DROP TRIGGER trig_row_before_insupd ON loc1;
--Testcase 672:
DROP TRIGGER trig_row_after_insupd ON loc1;
--Testcase 673:
DROP TRIGGER trig_row_before_delete ON loc1;
--Testcase 674:
DROP TRIGGER trig_row_after_delete ON loc1;


-- Test various RETURN statements in BEFORE triggers.

--Testcase 675:
CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

--Testcase 676:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 380:
INSERT INTO loc1 values(1, 'insert');
--Testcase 381:
SELECT * from loc1;
--Testcase 382:
INSERT INTO loc1 values(2, 'insert') RETURNING f2;
--Testcase 383:
SELECT * from loc1;
--Testcase 384:
UPDATE loc1 set f2 = '';
--Testcase 385:
SELECT * from loc1;
--Testcase 386:
UPDATE loc1 set f2 = 'skidoo' RETURNING f2;
--Testcase 387:
SELECT * from loc1;

--Testcase 388:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f1 = 10;          -- all columns should be transmitted
--Testcase 389:
UPDATE loc1 set f1 = 10;
--Testcase 390:
SELECT * from loc1;

--Testcase 391:
DELETE FROM loc1;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
--Testcase 677:
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 392:
INSERT INTO loc1 values(1, 'insert');
--Testcase 393:
SELECT * from loc1;
--Testcase 394:
INSERT INTO loc1 values(2, 'insert') RETURNING f2;
--Testcase 395:
SELECT * from loc1;
--Testcase 396:
UPDATE loc1 set f2 = '';
--Testcase 397:
SELECT * from loc1;
--Testcase 398:
UPDATE loc1 set f2 = 'skidoo' RETURNING f2;
--Testcase 399:
SELECT * from loc1;

--Testcase 678:
DROP TRIGGER trig_row_before_insupd ON loc1;
--Testcase 679:
DROP TRIGGER trig_row_before_insupd2 ON loc1;

--Testcase 400:
DELETE from loc1;

--Testcase 401:
INSERT INTO loc1 VALUES (1, 'test');

-- Test with a trigger returning NULL
--Testcase 680:
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

--Testcase 681:
CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 402:
INSERT INTO loc1 VALUES (2, 'test2');

--Testcase 403:
SELECT * from loc1;

--Testcase 404:
UPDATE loc1 SET f2 = 'test2';

--Testcase 405:
SELECT * from loc1;

--Testcase 406:
DELETE from loc1;

--Testcase 407:
SELECT * from loc1;

--Testcase 682:
DROP TRIGGER trig_null ON loc1;
--Testcase 408:
DELETE from loc1;

-- Test a combination of local and remote triggers
--Testcase 683:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 684:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 685:
CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 409:
INSERT INTO loc1(f2) VALUES ('test');
--Testcase 410:
UPDATE loc1 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 411:
INSERT INTO loc1(f2) VALUES ('test') RETURNING ctid;

-- cleanup
--Testcase 686:
DROP TRIGGER trig_row_before ON loc1;
--Testcase 687:
DROP TRIGGER trig_row_after ON loc1;
--Testcase 688:
DROP TRIGGER trig_local_before ON loc1;


-- Test direct foreign table modification functionality

-- Test with statement-level triggers
--Testcase 689:
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON loc1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 412:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 413:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 690:
DROP TRIGGER trig_stmt_before ON loc1;

--Testcase 691:
CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON loc1
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 414:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 415:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 692:
DROP TRIGGER trig_stmt_after ON loc1;

-- Test with row-level ON INSERT triggers
--Testcase 693:
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 416:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 417:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 694:
DROP TRIGGER trig_row_before_insert ON loc1;

--Testcase 695:
CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 418:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 419:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 696:
DROP TRIGGER trig_row_after_insert ON loc1;

-- Test with row-level ON UPDATE triggers
--Testcase 697:
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 420:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can't be pushed down
--Testcase 421:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 698:
DROP TRIGGER trig_row_before_update ON loc1;

--Testcase 699:
CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 422:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can't be pushed down
--Testcase 423:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can be pushed down
--Testcase 700:
DROP TRIGGER trig_row_after_update ON loc1;

-- Test with row-level ON DELETE triggers
--Testcase 701:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 424:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 425:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can't be pushed down
--Testcase 702:
DROP TRIGGER trig_row_before_delete ON loc1;

--Testcase 703:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON loc1
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--Testcase 426:
EXPLAIN (verbose, costs off)
UPDATE loc1 set f2 = '';          -- can be pushed down
--Testcase 427:
EXPLAIN (verbose, costs off)
DELETE FROM loc1;                 -- can't be pushed down
--Testcase 704:
DROP TRIGGER trig_row_after_delete ON loc1;

-- ===================================================================
-- test inheritance features
-- ===================================================================

--Testcase 705:
CREATE TABLE a (aa TEXT);
--CREATE TABLE loct (aa TEXT, bb TEXT);
ALTER TABLE a SET (autovacuum_enabled = 'false');
--ALTER TABLE loct SET (autovacuum_enabled = 'false');
-- Because Influxdb does not support UPDATE, to test locally 
-- we create local table.
--Testcase 706:
CREATE TABLE b (bb TEXT) INHERITS (a);


--Testcase 428:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 429:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 430:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 431:
INSERT INTO b(aa) VALUES('bbb');
--Testcase 432:
INSERT INTO b(aa) VALUES('bbbb');
--Testcase 433:
INSERT INTO b(aa) VALUES('bbbbb');

--Testcase 434:
SELECT tableoid::regclass, * FROM a;
--Testcase 435:
SELECT tableoid::regclass, * FROM b;
--Testcase 436:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 437:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 438:
SELECT tableoid::regclass, * FROM a;
--Testcase 439:
SELECT tableoid::regclass, * FROM b;
--Testcase 440:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 441:
UPDATE b SET aa = 'new';

--Testcase 442:
SELECT tableoid::regclass, * FROM a;
--Testcase 443:
SELECT tableoid::regclass, * FROM b;
--Testcase 444:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 445:
UPDATE a SET aa = 'newtoo';

--Testcase 446:
SELECT tableoid::regclass, * FROM a;
--Testcase 447:
SELECT tableoid::regclass, * FROM b;
--Testcase 448:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 449:
DELETE FROM a;

--Testcase 450:
SELECT tableoid::regclass, * FROM a;
--Testcase 451:
SELECT tableoid::regclass, * FROM b;
--Testcase 452:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 707:
DROP TABLE a CASCADE;
--DROP TABLE loct;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table
--create table loct1 (f1 int, f2 int, f3 int);
--create table loct2 (f1 int, f2 int, f3 int);

--alter table loct1 set (autovacuum_enabled = 'false');
--alter table loct2 set (autovacuum_enabled = 'false');

--Testcase 708:
create table foo (f1 int, f2 int);
--Testcase 709:
create foreign table foo2 (f3 int) inherits (foo)
  server influxdb_svr options (table 'loct1_1');
--Testcase 710:
create table bar (f1 int, f2 int);
--Testcase 711:
create foreign table bar2 (f3 int) inherits (bar)
  server influxdb_svr options (table 'loct2_1');

alter table foo set (autovacuum_enabled = 'false');
alter table bar set (autovacuum_enabled = 'false');

--Testcase 453:
insert into foo values(1,1);
--Testcase 454:
insert into foo values(3,3);
-- insert into foo2 values(2,2,2);
-- insert into foo2 values(4,4,4);
--Testcase 455:
insert into bar values(1,11);
--Testcase 456:
insert into bar values(2,22);
--Testcase 457:
insert into bar values(6,66);
-- insert into bar2 values(3,33,33);
-- insert into bar2 values(4,44,44);
-- insert into bar2 values(7,77,77);

--Testcase 458:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for update;
--Testcase 459:
select * from bar where f1 in (select f1 from foo) for update;

--Testcase 460:
explain (verbose, costs off)
select * from bar where f1 in (select f1 from foo) for share;
--Testcase 461:
select * from bar where f1 in (select f1 from foo) for share;

/*
-- Check UPDATE with inherited target and an inherited source table
-- skip, if we update to bar, bar2 also is updated because it inherits bar
-- and Influxdb fdw does not support update on bar2.
explain (verbose, costs off)
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);
update bar set f2 = f2 + 100 where f1 in (select f1 from foo);

select tableoid::regclass, * from bar order by 1,2;

-- Check UPDATE with inherited target and an appendrel subquery
explain (verbose, costs off)
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;
update bar set f2 = f2 + 100
from
  ( select f1 from foo union all select f1+3 from foo ) ss
where bar.f1 = ss.f1;

select tableoid::regclass, * from bar order by 1,2;

-- Test forcing the remote server to produce sorted data for a merge join,
-- but the foreign table is an inheritance child.
truncate table loct1;
truncate table only foo;
\set num_rows_foo 2000
insert into loct1 select generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2), generate_series(0, :num_rows_foo, 2);
insert into foo select generate_series(1, :num_rows_foo, 2), generate_series(1, :num_rows_foo, 2);
SET enable_hashjoin to false;
SET enable_nestloop to false;
alter foreign table foo2 options (use_remote_estimate 'true');
create index i_loct1_f1 on loct1(f1);
create index i_foo_f1 on foo(f1);
analyze foo;
analyze loct1;
-- inner join; expressions in the clauses appear in the equivalence class list
explain (verbose, costs off)
	select foo.f1, loct1.f1 from foo join loct1 on (foo.f1 = loct1.f1) order by foo.f2 offset 10 limit 10;
select foo.f1, loct1.f1 from foo join loct1 on (foo.f1 = loct1.f1) order by foo.f2 offset 10 limit 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
explain (verbose, costs off)
	select foo.f1, loct1.f1 from foo left join loct1 on (foo.f1 = loct1.f1) order by foo.f2 offset 10 limit 10;
select foo.f1, loct1.f1 from foo left join loct1 on (foo.f1 = loct1.f1) order by foo.f2 offset 10 limit 10;
RESET enable_hashjoin;
RESET enable_nestloop;

-- Test that WHERE CURRENT OF is not supported
begin;
declare c cursor for select * from bar where f1 = 7;
fetch from c;
update bar set f2 = null where current of c;
rollback;

explain (verbose, costs off)
delete from foo where f1 < 5 returning *;
delete from foo where f1 < 5 returning *;
explain (verbose, costs off)
update bar set f2 = f2 + 100 returning *;
update bar set f2 = f2 + 100 returning *;

-- Test that UPDATE/DELETE with inherited target works with row-level triggers
CREATE TRIGGER trig_row_before
BEFORE UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

CREATE TRIGGER trig_row_after
AFTER UPDATE OR DELETE ON bar2
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

explain (verbose, costs off)
update bar set f2 = f2 + 100;
update bar set f2 = f2 + 100;

explain (verbose, costs off)
delete from bar where f2 < 400;
delete from bar where f2 < 400;

-- cleanup
drop table foo cascade;
drop table bar cascade;
drop table loct1;
drop table loct2;

-- Test pushing down UPDATE/DELETE joins to the remote server
create table parent (a int, b text);
create table loct1 (a int, b text);
create table loct2 (a int, b text);
create foreign table remt1 (a int, b text)
  server influxdb_svr options (table 'loct1');
create foreign table remt2 (a int, b text)
  server influxdb_svr options (table 'loct2');
alter foreign table remt1 inherit parent;

insert into remt1 values (1, 'foo');
insert into remt1 values (2, 'bar');
insert into remt2 values (1, 'foo');
insert into remt2 values (2, 'bar');

analyze remt1;
analyze remt2;

explain (verbose, costs off)
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
update parent set b = parent.b || remt2.b from remt2 where parent.a = remt2.a returning *;
explain (verbose, costs off)
delete from parent using remt2 where parent.a = remt2.a returning parent;
delete from parent using remt2 where parent.a = remt2.a returning parent;

-- cleanup
drop foreign table remt1;
drop foreign table remt2;
drop table loct1;
drop table loct2;
drop table parent;
*/
/*
-- Skip test because influxdb does not support partitions table, COPY
-- ===================================================================
-- test tuple routing for foreign-table partitions
-- ===================================================================

-- Test insert tuple routing
create table itrtest (a int, b text) partition by list (a);
create table loct1 (a int check (a in (1)), b text);
create foreign table remp1 (a int check (a in (1)), b text) server loopback options (table_name 'loct1');
create table loct2 (a int check (a in (2)), b text);
create foreign table remp2 (b text, a int check (a in (2))) server loopback options (table_name 'loct2');
alter table itrtest attach partition remp1 for values in (1);
alter table itrtest attach partition remp2 for values in (2);

--Testcase 492:
insert into itrtest values (1, 'foo');
--Testcase 493:
insert into itrtest values (1, 'bar') returning *;
--Testcase 494:
insert into itrtest values (2, 'baz');
--Testcase 495:
insert into itrtest values (2, 'qux') returning *;
--Testcase 496:
insert into itrtest values (1, 'test1'), (2, 'test2') returning *;

--Testcase 497:
select tableoid::regclass, * FROM itrtest;
--Testcase 498:
select tableoid::regclass, * FROM remp1;
--Testcase 499:
select tableoid::regclass, * FROM remp2;

--Testcase 500:
delete from itrtest;

create unique index loct1_idx on loct1 (a);

-- DO NOTHING without an inference specification is supported
--Testcase 501:
insert into itrtest values (1, 'foo') on conflict do nothing returning *;
--Testcase 502:
insert into itrtest values (1, 'foo') on conflict do nothing returning *;

-- But other cases are not supported
--Testcase 503:
insert into itrtest values (1, 'bar') on conflict (a) do nothing;
--Testcase 504:
insert into itrtest values (1, 'bar') on conflict (a) do update set b = excluded.b;

--Testcase 505:
select tableoid::regclass, * FROM itrtest;

--Testcase 506:
delete from itrtest;

drop index loct1_idx;

-- Test that remote triggers work with insert tuple routing
create function br_insert_trigfunc() returns trigger as $$
begin
	new.b := new.b || ' triggered !';
	return new;
end
$$ language plpgsql;
create trigger loct1_br_insert_trigger before insert on loct1
	for each row execute procedure br_insert_trigfunc();
create trigger loct2_br_insert_trigger before insert on loct2
	for each row execute procedure br_insert_trigfunc();

-- The new values are concatenated with ' triggered !'
--Testcase 507:
insert into itrtest values (1, 'foo') returning *;
--Testcase 508:
insert into itrtest values (2, 'qux') returning *;
--Testcase 509:
insert into itrtest values (1, 'test1'), (2, 'test2') returning *;
with result as (insert into itrtest values (1, 'test1'), (2, 'test2') returning *) select * from result;

drop trigger loct1_br_insert_trigger on loct1;
drop trigger loct2_br_insert_trigger on loct2;

drop table itrtest;
drop table loct1;
drop table loct2;

-- Test update tuple routing
create table utrtest (a int, b text) partition by list (a);
create table loct (a int check (a in (1)), b text);
create foreign table remp (a int check (a in (1)), b text) server loopback options (table_name 'loct');
create table locp (a int check (a in (2)), b text);
alter table utrtest attach partition remp for values in (1);
alter table utrtest attach partition locp for values in (2);

--Testcase 510:
insert into utrtest values (1, 'foo');
--Testcase 511:
insert into utrtest values (2, 'qux');

--Testcase 512:
select tableoid::regclass, * FROM utrtest;
--Testcase 513:
select tableoid::regclass, * FROM remp;
--Testcase 514:
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
--Testcase 515:
update utrtest set a = 2 where b = 'foo' returning *;

-- But the reverse is allowed
--Testcase 516:
update utrtest set a = 1 where b = 'qux' returning *;

--Testcase 517:
select tableoid::regclass, * FROM utrtest;
--Testcase 518:
select tableoid::regclass, * FROM remp;
--Testcase 519:
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
--Testcase 520:
update utrtest set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
create trigger loct_br_insert_trigger before insert on loct
	for each row execute procedure br_insert_trigfunc();

--Testcase 521:
delete from utrtest;
--Testcase 522:
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
--Testcase 523:
explain (verbose, costs off)
update utrtest set a = 1 where a = 1 or a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 524:
update utrtest set a = 1 where a = 1 or a = 2 returning *;

--Testcase 525:
delete from utrtest;
--Testcase 526:
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
--Testcase 527:
explain (verbose, costs off)
update utrtest set a = 1 where a = 2 returning *;
-- The new values are concatenated with ' triggered !'
--Testcase 528:
update utrtest set a = 1 where a = 2 returning *;

drop trigger loct_br_insert_trigger on loct;

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

--Testcase 529:
delete from utrtest;
--Testcase 530:
insert into utrtest values (1, 'foo');
--Testcase 531:
insert into utrtest values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
--Testcase 532:
explain (verbose, costs off)
update utrtest set a = 1 returning *;
--Testcase 533:
update utrtest set a = 1 returning *;

--Testcase 534:
delete from utrtest;
--Testcase 535:
insert into utrtest values (1, 'foo');
--Testcase 536:
insert into utrtest values (2, 'qux');

-- with a non-direct modification plan
--Testcase 537:
explain (verbose, costs off)
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;
--Testcase 538:
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
--Testcase 539:
delete from utrtest;
alter table utrtest detach partition remp;
drop foreign table remp;
alter table loct drop constraint loct_a_check;
alter table loct add check (a in (3));
create foreign table remp (a int check (a in (3)), b text) server loopback options (table_name 'loct');
alter table utrtest attach partition remp for values in (3);
--Testcase 540:
insert into utrtest values (2, 'qux');
--Testcase 541:
insert into utrtest values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
--Testcase 542:
explain (verbose, costs off)
update utrtest set a = 3 returning *;
--Testcase 543:
update utrtest set a = 3 returning *; -- ERROR

-- with a non-direct modification plan
--Testcase 544:
explain (verbose, costs off)
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x returning *;
--Testcase 545:
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x returning *; -- ERROR

drop table utrtest;
drop table loct;

-- Test copy tuple routing
create table ctrtest (a int, b text) partition by list (a);
create table loct1 (a int check (a in (1)), b text);
create foreign table remp1 (a int check (a in (1)), b text) server loopback options (table_name 'loct1');
create table loct2 (a int check (a in (2)), b text);
create foreign table remp2 (b text, a int check (a in (2))) server loopback options (table_name 'loct2');
alter table ctrtest attach partition remp1 for values in (1);
alter table ctrtest attach partition remp2 for values in (2);

copy ctrtest from stdin;
1	foo
2	qux
\.

--Testcase 546:
select tableoid::regclass, * FROM ctrtest;
--Testcase 547:
select tableoid::regclass, * FROM remp1;
--Testcase 548:
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1 from stdin;
1	bar
\.

--Testcase 549:
select tableoid::regclass, * FROM remp1;

drop table ctrtest;
drop table loct1;
drop table loct2;

-- ===================================================================
-- test COPY FROM
-- ===================================================================

create table loc2 (f1 int, f2 text);
alter table loc2 set (autovacuum_enabled = 'false');
create foreign table rem2 (f1 int, f2 text) server loopback options(table_name 'loc2');

-- Test basic functionality
copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 550:
select * from rem2;

--Testcase 551:
delete from rem2;

-- Test check constraints
alter table loc2 add constraint loc2_f1positive check (f1 >= 0);
alter foreign table rem2 add constraint rem2_f1positive check (f1 >= 0);

-- check constraint is enforced on the remote side, not locally
copy rem2 from stdin;
1	foo
2	bar
\.
copy rem2 from stdin; -- ERROR
-1	xyzzy
\.
--Testcase 552:
select * from rem2;

alter foreign table rem2 drop constraint rem2_f1positive;
alter table loc2 drop constraint loc2_f1positive;

--Testcase 553:
delete from rem2;

-- Test local triggers
create trigger trig_stmt_before before insert on rem2
	for each statement execute procedure trigger_func();
create trigger trig_stmt_after after insert on rem2
	for each statement execute procedure trigger_func();
create trigger trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');

copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 554:
select * from rem2;

drop trigger trig_row_before on rem2;
drop trigger trig_row_after on rem2;
drop trigger trig_stmt_before on rem2;
drop trigger trig_stmt_after on rem2;

--Testcase 555:
delete from rem2;

create trigger trig_row_before_insert before insert on rem2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 556:
select * from rem2;

drop trigger trig_row_before_insert on rem2;

--Testcase 557:
delete from rem2;

create trigger trig_null before insert on rem2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 558:
select * from rem2;

drop trigger trig_null on rem2;

--Testcase 559:
delete from rem2;

-- Test remote triggers
create trigger trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 560:
select * from rem2;

drop trigger trig_row_before_insert on loc2;

--Testcase 561:
delete from rem2;

create trigger trig_null before insert on loc2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 562:
select * from rem2;

drop trigger trig_null on loc2;

--Testcase 563:
delete from rem2;

-- Test a combination of local and remote triggers
create trigger rem2_trig_row_before before insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger rem2_trig_row_after after insert on rem2
	for each row execute procedure trigger_data(23,'skidoo');
create trigger loc2_trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

copy rem2 from stdin;
1	foo
2	bar
\.
--Testcase 564:
select * from rem2;

drop trigger rem2_trig_row_before on rem2;
drop trigger rem2_trig_row_after on rem2;
drop trigger loc2_trig_row_before_insert on loc2;

--Testcase 565:
delete from rem2;

-- test COPY FROM with foreign table created in the same transaction
create table loc3 (f1 int, f2 text);
begin;
create foreign table rem3 (f1 int, f2 text)
	server loopback options(table_name 'loc3');
copy rem3 from stdin;
1	foo
2	bar
\.
commit;
--Testcase 566:
select * from rem3;
drop foreign table rem3;
drop table loc3;
*/
-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================

--Testcase 712:
CREATE SCHEMA import_influx1;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx1;
--Testcase 567:
\det+ import_influx1.*
--Testcase 568:
\d import_influx1.*

-- Options
--Testcase 713:
CREATE SCHEMA import_influx2;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx2
  OPTIONS (import_default 'true');
--Testcase 714:
\det+ import_influx2.*
--Testcase 715:
\d import_influx2.*

--Testcase 716:
CREATE SCHEMA import_influx3;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx3
  OPTIONS (import_collate 'false', import_not_null 'false');
--Testcase 717:
\det+ import_influx3.*
--Testcase 718:
\d import_influx3.*

-- Check LIMIT TO and EXCEPT
--Testcase 719:
CREATE SCHEMA import_influx4;
IMPORT FOREIGN SCHEMA public LIMIT TO ("T1", loct, nonesuch)
  FROM SERVER influxdb_svr INTO import_influx4;
--Testcase 569:
\det+ import_influx4.*
IMPORT FOREIGN SCHEMA public EXCEPT ("T1", loct, nonesuch)
  FROM SERVER influxdb_svr INTO import_influx4;
--Testcase 570:
\det+ import_influx4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx4;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER influxdb_svr INTO import_influx4; -- same as 'public'
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER influxdb_svr INTO notthere;
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere;

/*
-- Skip test
-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");

CREATE SCHEMA import_dest5;
BEGIN;
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER influxdb_svr INTO import_dest5;  -- ERROR

ROLLBACK;

BEGIN;


CREATE SERVER fetch101 FOREIGN DATA WRAPPER postgres_fdw OPTIONS( fetch_size '101' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

ALTER SERVER fetch101 OPTIONS( SET fetch_size '202' );

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=101'];

SELECT count(*)
FROM pg_foreign_server
WHERE srvname = 'fetch101'
AND srvoptions @> array['fetch_size=202'];

CREATE FOREIGN TABLE table30000 ( x int ) SERVER fetch101 OPTIONS ( fetch_size '30000' );

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

ALTER FOREIGN TABLE table30000 OPTIONS ( SET fetch_size '60000');

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=30000'];

SELECT COUNT(*)
FROM pg_foreign_table
WHERE ftrelid = 'table30000'::regclass
AND ftoptions @> array['fetch_size=60000'];

ROLLBACK;
*/

-- ===================================================================
-- test partitionwise joins
-- ===================================================================
SET enable_partitionwise_join=on;

--Testcase 720:
CREATE TABLE fprt1 (a int, b int, c text) PARTITION BY RANGE(a);
--CREATE TABLE fprt1_p1 (LIKE fprt1);
--CREATE TABLE fprt1_p2 (LIKE fprt1);
--ALTER TABLE fprt1_p1 SET (autovacuum_enabled = 'false');
--ALTER TABLE fprt1_p2 SET (autovacuum_enabled = 'false');
--INSERT INTO fprt1_p1 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(0, 249, 2) i;
--INSERT INTO fprt1_p2 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(250, 499, 2) i;
--Testcase 721:
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER influxdb_svr OPTIONS (table 'fprt1_p1');
--Testcase 722:
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER influxdb_svr OPTIONS (TABLE 'fprt1_p2');
--ANALYZE fprt1;
--ANALYZE fprt1_p1;
--ANALYZE fprt1_p2;


--Testcase 723:
CREATE TABLE fprt2 (a int, b int, c text) PARTITION BY RANGE(b);
--CREATE TABLE fprt2_p1 (LIKE fprt2);
--CREATE TABLE fprt2_p2 (LIKE fprt2);
--ALTER TABLE fprt2_p1 SET (autovacuum_enabled = 'false');
--ALTER TABLE fprt2_p2 SET (autovacuum_enabled = 'false');
--INSERT INTO fprt2_p1 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(0, 249, 3) i;
--INSERT INTO fprt2_p2 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(250, 499, 3) i;
--Testcase 724:
CREATE FOREIGN TABLE ftprt2_p1 (a int, b int, c text)
	SERVER influxdb_svr OPTIONS (table 'fprt2_p1');
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1 FOR VALUES FROM (0) TO (250);
--Testcase 725:
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER influxdb_svr OPTIONS (table 'fprt2_p2');
-- ANALYZE fprt2;
-- ANALYZE fprt2_p1;
-- ANALYZE fprt2_p2;

-- inner join three tables
--Testcase 571:
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
--Testcase 572:
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
--Testcase 573:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
--Testcase 574:
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
--Testcase 575:
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
--Testcase 576:
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
--Testcase 577:
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
--Testcase 578:
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
--Testcase 579:
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
--Testcase 580:
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
--Testcase 581:
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
--Testcase 582:
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

--Testcase 726:
CREATE TABLE pagg_tab (t int, a int, b int, c text) PARTITION BY RANGE(a);

--CREATE TABLE pagg_tab_p1 (LIKE pagg_tab);
--CREATE TABLE pagg_tab_p2 (LIKE pagg_tab);
--CREATE TABLE pagg_tab_p3 (LIKE pagg_tab);

--INSERT INTO pagg_tab_p1 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 10;
--INSERT INTO pagg_tab_p2 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 20 and (i % 30) >= 10;
--INSERT INTO pagg_tab_p3 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 30 and (i % 30) >= 20;

-- Create foreign partitions
--Testcase 727:
CREATE FOREIGN TABLE fpagg_tab_p1 PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10) SERVER influxdb_svr OPTIONS (table 'pagg_tab_p1');
--Testcase 728:
CREATE FOREIGN TABLE fpagg_tab_p2 PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20) SERVER influxdb_svr OPTIONS (table 'pagg_tab_p2');;
--Testcase 729:
CREATE FOREIGN TABLE fpagg_tab_p3 PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30) SERVER influxdb_svr2 OPTIONS (table 'pagg_tab_p3');;

-- ANALYZE pagg_tab;
-- ANALYZE fpagg_tab_p1;
-- ANALYZE fpagg_tab_p2;
-- ANALYZE fpagg_tab_p3;

-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
SET enable_partitionwise_aggregate TO false;
--Testcase 583:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
SET enable_partitionwise_aggregate TO true;
--Testcase 584:
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 585:
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
--Testcase 586:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
--Testcase 587:
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
--Testcase 588:
EXPLAIN (COSTS OFF)
SELECT b, avg(a), max(a), count(*) FROM pagg_tab GROUP BY b HAVING sum(a) < 700 ORDER BY 1;

/*
-- Skip test, influxdb_fdw does not support nosuperuser
-- ===================================================================
-- access rights and superuser
-- ===================================================================

-- Non-superuser cannot create a FDW without a password in the connstr
CREATE ROLE regress_nosuper NOSUPERUSER;

GRANT USAGE ON FOREIGN DATA WRAPPER postgres_fdw TO regress_nosuper;

SET ROLE regress_nosuper;

SHOW is_superuser;

-- This will be OK, we can create the FDW
DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER loopback_nopw FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (dbname '$$||current_database()||$$',
                     port '$$||current_setting('port')||$$'
            )$$;
    END;
$d$;

-- But creation of user mappings for non-superusers should fail
CREATE USER MAPPING FOR public SERVER loopback_nopw;
CREATE USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

CREATE FOREIGN TABLE ft1_nopw (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	c4 timestamptz,
	c5 timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 user_enum
) SERVER loopback_nopw OPTIONS (schema_name 'public', table_name 'ft1');

SELECT * FROM ft1_nopw LIMIT 1;

-- If we add a password to the connstr it'll fail, because we don't allow passwords
-- in connstrs only in user mappings.

DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER loopback_nopw OPTIONS (ADD password 'dummypw')$$;
    END;
$d$;

-- If we add a password for our user mapping instead, we should get a different
-- error because the password wasn't actually *used* when we run with trust auth.
--
-- This won't work with installcheck, but neither will most of the FDW checks.

ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password 'dummypw');

SELECT * FROM ft1_nopw LIMIT 1;

-- Unpriv user cannot make the mapping passwordless
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD password_required 'false');


SELECT * FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- But the superuser can
ALTER USER MAPPING FOR regress_nosuper SERVER loopback_nopw OPTIONS (ADD password_required 'false');

SET ROLE regress_nosuper;

-- Should finally work now
SELECT * FROM ft1_nopw LIMIT 1;

-- unpriv user also cannot set sslcert / sslkey on the user mapping
-- first set password_required so we see the right error messages
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (SET password_required 'true');
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslcert 'foo.crt');
ALTER USER MAPPING FOR CURRENT_USER SERVER loopback_nopw OPTIONS (ADD sslkey 'foo.key');

-- We're done with the role named after a specific user and need to check the
-- changes to the public mapping.
DROP USER MAPPING FOR CURRENT_USER SERVER loopback_nopw;

-- This will fail again as it'll resolve the user mapping for public, which
-- lacks password_required=false
SELECT * FROM ft1_nopw LIMIT 1;

RESET ROLE;

-- The user mapping for public is passwordless and lacks the password_required=false
-- mapping option, but will work because the current user is a superuser.
SELECT * FROM ft1_nopw LIMIT 1;

-- cleanup
DROP USER MAPPING FOR public SERVER loopback_nopw;
DROP OWNED BY regress_nosuper;
DROP ROLE regress_nosuper;
*/

-- Clean-up
--Testcase 730:
DROP USER MAPPING FOR public SERVER testserver1;
--Testcase 731:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 732:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr2;

--Testcase 733:
DROP SERVER testserver1 CASCADE;
--Testcase 734:
DROP SERVER influxdb_svr CASCADE;
--Testcase 735:
DROP SERVER influxdb_svr2 CASCADE;
--Testcase 736:
DROP EXTENSION influxdb_fdw CASCADE;
