-- ===================================================================
-- create FDW objects
-- ===================================================================
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 1:
CREATE EXTENSION influxdb_fdw;
--Testcase 2:
CREATE SERVER testserver1 FOREIGN DATA WRAPPER influxdb_fdw;

--Testcase 3:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
    OPTIONS (dbname 'postdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 4:
CREATE SERVER influxdb_svr2 FOREIGN DATA WRAPPER influxdb_fdw
    OPTIONS (dbname 'postdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);

--Testcase 5:
CREATE USER MAPPING FOR public SERVER testserver1 OPTIONS (user 'value', password 'value');
--Testcase 6:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
--Testcase 7:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr2 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

-- ===================================================================
-- create objects used through FDW influxdb server
-- ===================================================================
--Testcase 8:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 9:
CREATE SCHEMA "S 1";
--Testcase 10:
CREATE FOREIGN TABLE "S 1"."T 0" (time timestamp, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T0', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE "S 1".s1t0 (
	"C 1" int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	time timestamp,
	c6 varchar(10),
	c7 char(10),
	c8 text
) SERVER influxdb_svr OPTIONS (table 'T0', tags 'c3');
--Testcase 11:
CREATE FOREIGN TABLE "S 1"."T 1" (time timestamp, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T1', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE "S 1".s1t1 (
	"C 1" int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	time timestamp,
	c6 varchar(10),
	c7 char(10),
	c8 text
) SERVER influxdb_svr OPTIONS (table 'T1', tags 'c3');
--Testcase 12:
CREATE FOREIGN TABLE "S 1"."T 2" (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T2', tags 'c2', schemaless 'true');
CREATE FOREIGN TABLE "S 1".s1t2 (
	c1 int NOT NULL,
	c2 text
) SERVER influxdb_svr OPTIONS (table 'T2', tags 'c2');
--Testcase 13:
CREATE FOREIGN TABLE "S 1"."T 3" (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T3', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE "S 1".s1t3 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T3', tags 'c3');
--Testcase 14:
CREATE FOREIGN TABLE "S 1"."T 4" (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T4', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE "S 1".s1t4 (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T4', tags 'c3');

-- Disable autovacuum for these tables to avoid unexpected effects of that
--ALTER TABLE "S 1"."T 1" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 2" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 3" SET (autovacuum_enabled = 'false');
--ALTER TABLE "S 1"."T 4" SET (autovacuum_enabled = 'false');

--Testcase 15:
INSERT INTO "S 1".s1t1
	SELECT id,
	       id % 10,
	       to_char(id, 'FM00000'),
	       '1970-01-01'::timestamp + ((id % 100) || ' days')::interval,
	       id % 10,
	       id % 10,
	       'foo'::text
	FROM generate_series(1, 1000) id;
--Testcase 16:
INSERT INTO "S 1".s1t2
	SELECT id,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 17:
INSERT INTO "S 1".s1t3
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 18:
DELETE FROM "S 1".s1t3 WHERE c1 % 2 != 0;	-- delete for outer join tests
--Testcase 19:
INSERT INTO "S 1".s1t4
	SELECT id,
	       id + 1,
	       'AAA' || to_char(id, 'FM000')
	FROM generate_series(1, 100) id;
--Testcase 20:
DELETE FROM "S 1".s1t4 WHERE c1 % 3 != 0;	-- delete for outer join tests

--ANALYZE "S 1"."T 1";
--ANALYZE "S 1"."T 2";
--ANALYZE "S 1"."T 3";
--ANALYZE "S 1"."T 4";

-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 21:
CREATE FOREIGN TABLE ft1 (time timestamp, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');
CREATE FOREIGN TABLE ft1_nsc (
	c0 int,
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text,
	time timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft1',
	c8 text
) SERVER influxdb_svr;
ALTER FOREIGN TABLE ft1_nsc DROP COLUMN c0;
--Testcase 22:
CREATE FOREIGN TABLE ft2 (time timestamp, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');
CREATE FOREIGN TABLE ft2_nsc (
	c1 int NOT NULL,
	c2 int NOT NULL,
	cx int,
	c3 text,
	time timestamp,
	c6 varchar(10),
	c7 char(10) default 'ft2',
	c8 text
) SERVER influxdb_svr;
ALTER FOREIGN TABLE ft2_nsc DROP COLUMN cx;
--Testcase 23:
CREATE FOREIGN TABLE ft4 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T3', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE ft4_nsc (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T3', tags 'c3');
--Testcase 24:
CREATE FOREIGN TABLE ft5 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'T4', tags 'c3', schemaless 'true');
CREATE FOREIGN TABLE ft5_nsc (
	c1 int NOT NULL,
	c2 int NOT NULL,
	c3 text
) SERVER influxdb_svr OPTIONS (table 'T4', tags 'c3');
--Testcase 25:
CREATE FOREIGN TABLE ft6 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr2 OPTIONS (table 'T4', tags 'c3', schemaless 'true');
-- ===================================================================
-- tests for validator
-- ===================================================================
-- requiressl and some other parameters are omitted because
-- valid values for them depend on configure options
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

-- influxdb_fdw does not support option extensions
-- Error, invalid list syntax
--ALTER SERVER testserver1 OPTIONS (ADD extensions 'foo; bar');

-- OK but gets a warning
--ALTER SERVER testserver1 OPTIONS (ADD extensions 'foo, bar');
--ALTER SERVER testserver1 OPTIONS (DROP extensions);

ALTER USER MAPPING FOR public SERVER testserver1
	OPTIONS (DROP user, DROP password);

-- Attempt to add a valid option that's not allowed in a user mapping
--ALTER USER MAPPING FOR public SERVER testserver1
--	OPTIONS (ADD sslmode 'require');

-- But we can add valid ones fine
--ALTER USER MAPPING FOR public SERVER testserver1
--	OPTIONS (ADD sslpassword 'dummy');

-- Ensure valid options we haven't used in a user mapping yet are
-- permitted to check validation.
--ALTER USER MAPPING FOR public SERVER testserver1
--	OPTIONS (ADD sslkey 'value', ADD sslcert 'value');

ALTER FOREIGN TABLE ft1 OPTIONS (table 'T1', tags 'c3');
ALTER FOREIGN TABLE ft1_nsc OPTIONS (table 'T1', tags 'c3');
ALTER FOREIGN TABLE ft2 OPTIONS (table 'T1', tags 'c3');
ALTER FOREIGN TABLE ft2_nsc OPTIONS (table 'T1', tags 'c3');
ALTER FOREIGN TABLE ft1_nsc ALTER COLUMN c1 OPTIONS (column_name 'C 1');
ALTER FOREIGN TABLE ft2_nsc ALTER COLUMN c1 OPTIONS (column_name 'C 1');
--Testcase 26:
\det+

-- Test that alteration of server options causes reconnection
-- Remote's errors might be non-English, so hide them to ensure stable results
\set VERBOSITY terse
--Testcase 27:
SELECT tags->>'c3' c3, time FROM ft1 ORDER BY tags->>'c3', (fields->>'C 1')::int LIMIT 1;  -- should work
ALTER SERVER influxdb_svr OPTIONS (SET dbname 'no such database');
--Testcase 28:
SELECT tags->>'c3' c3, time FROM ft1 ORDER BY tags->>'c3', (fields->>'C 1')::int LIMIT 1;  -- should fail
DO $d$
    BEGIN
        EXECUTE $$ALTER SERVER influxdb_svr
            OPTIONS (SET dbname 'postdb')$$;
    END;
$d$;
--Testcase 29:
SELECT tags->>'c3' c3, time FROM ft1 ORDER BY tags->>'c3', (fields->>'C 1')::int LIMIT 1;  -- should work again
\set VERBOSITY default

-- ===================================================================
-- simple queries
-- ===================================================================
-- single table without alias
--Testcase 30:
EXPLAIN (COSTS OFF) SELECT * FROM ft1 ORDER BY tags->>'c3', (fields->>'C 1')::int OFFSET 100 LIMIT 10;
--Testcase 31:
SELECT * FROM ft1 ORDER BY tags->>'c3', (fields->>'C 1')::int OFFSET 100 LIMIT 10;
-- single table with alias - also test that tableoid sort is not pushed to remote side
--Testcase 32:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 ORDER BY t1.tags->>'c3', (t1.fields->>'C 1')::int, t1.tableoid OFFSET 100 LIMIT 10;
--Testcase 33:
SELECT * FROM ft1 t1 ORDER BY t1.tags->>'c3', (t1.fields->>'C 1')::int, t1.tableoid OFFSET 100 LIMIT 10;
-- whole-row reference
--Testcase 34:
EXPLAIN (VERBOSE, COSTS OFF) SELECT t1 FROM ft1 t1 ORDER BY t1.tags->>'c3', (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
--Testcase 35:
SELECT t1 FROM ft1 t1 ORDER BY t1.tags->>'c3', (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
-- empty result
--Testcase 36:
SELECT * FROM ft1 WHERE false;
-- with WHERE clause
--Testcase 37:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = 101 AND t1.fields->>'c6' = '1' AND t1.fields->>'c7' >= '1';
--Testcase 38:
SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = 101 AND t1.fields->>'c6' = '1' AND t1.fields->>'c7' >= '1';
-- with FOR UPDATE/SHARE
--Testcase 39:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (fields->>'C 1')::int = 101 FOR UPDATE;
--Testcase 40:
SELECT * FROM ft1 t1 WHERE (fields->>'C 1')::int = 101 FOR UPDATE;
--Testcase 41:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (fields->>'C 1')::int = 102 FOR SHARE;
--Testcase 42:
SELECT * FROM ft1 t1 WHERE (fields->>'C 1')::int = 102 FOR SHARE;
-- aggregate
--Testcase 43:
SELECT COUNT(*) FROM ft1 t1;
-- subquery
--Testcase 44:
SELECT * FROM ft1 t1 WHERE t1.tags->>'c3' IN (SELECT tags->>'c3' FROM ft2 t2 WHERE (fields->>'C 1')::int <= 10) ORDER BY (fields->>'C 1')::int;
-- subquery+MAX
--Testcase 45:
SELECT * FROM ft1 t1 WHERE t1.tags->>'c3' = (SELECT MAX(tags->>'c3') FROM ft2 t2) ORDER BY (fields->>'C 1')::int;
-- used in CTE
--Testcase 46:
WITH t1 AS (SELECT * FROM ft1 WHERE (fields->>'C 1')::int <= 10) SELECT (t2.fields->>'C 1')::int c1, (t2.fields->>'c2')::int c2, t2.tags->>'c3' c3, t2.time FROM t1, ft2 t2 WHERE (t1.fields->>'C 1')::int = (t2.fields->>'C 1')::int ORDER BY (t1.fields->>'C 1')::int;
-- fixed values
--Testcase 47:
SELECT 'fixed', NULL FROM ft1 t1 WHERE (fields->>'C 1')::int = 1;
-- Test forcing the remote server to produce sorted data for a merge join.
SET enable_hashjoin TO false;
SET enable_nestloop TO false;
-- inner join; expressions in the clauses appear in the equivalence class list
--Testcase 48:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 JOIN (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t2) t2 ON ((t1.c1)::int = (t2."C 1")::int) OFFSET 100 LIMIT 10;
--Testcase 49:
SELECT t1.c1, t2."C 1" FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 JOIN (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t2) t2 ON ((t1.c1)::int = (t2."C 1")::int) OFFSET 100 LIMIT 10;
-- outer join; expressions in the clauses do not appear in equivalence class
-- list but no output change as compared to the previous query
--Testcase 50:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1.c1, t2."C 1" FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t2) t2 ON ((t1.c1)::int = (t2."C 1")::int) OFFSET 100 LIMIT 10;
--Testcase 51:
SELECT t1.c1, t2."C 1" FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t2) t2 ON ((t1.c1)::int = (t2."C 1")::int) OFFSET 100 LIMIT 10;
-- A join between 2 foreign tables. ORDER BY clause is added to the
-- foreign join so that the other table can be joined using merge join strategy.
--Testcase 52:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1" FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 left join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
--Testcase 53:
SELECT t1."C 1" FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 left join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
-- Test similar to above, except that the full join prevents any equivalence
-- classes from being merged. This produces single relation equivalence classes
-- included in join restrictions.
--Testcase 54:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 left join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
--Testcase 55:
SELECT t1."C 1", t2.c1, t3.c1 FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 left join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
-- Test similar to above with all full outer joins
--Testcase 56:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT t1."C 1", t2.c1, t3.c1 FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
--Testcase 57:
SELECT t1."C 1", t2.c1, t3.c1 FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 full join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t3) t3 on ((t2.c1)::int = (t3.c1)::int) on ((t3.c1)::int = (t1."C 1")::int) OFFSET 100 LIMIT 10;
RESET enable_hashjoin;
RESET enable_nestloop;

-- ===================================================================
-- WHERE with remotely-executable conditions
-- ===================================================================
--Testcase 58:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = 1;         -- Var, OpExpr(b), Const
--Testcase 59:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = 100 AND (t1.fields->>'c2')::int = 0; -- BoolExpr
--Testcase 60:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int IS NULL;        -- NullTest
--Testcase 61:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int IS NOT NULL;    -- NullTest
--Testcase 62:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE round(abs((t1.fields->>'C 1')::int), 0) = 1; -- FuncExpr
--Testcase 63:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = -(t1.fields->>'C 1')::int;          -- OpExpr(l)
--Testcase 64:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE 1 = (t1.fields->>'C 1')::int!;           -- OpExpr(r)
--Testcase 65:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE ((t1.fields->>'C 1')::int IS NOT NULL) IS DISTINCT FROM ((t1.fields->>'C 1')::int IS NOT NULL); -- DistinctExpr
--Testcase 66:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = ANY(ARRAY[(fields->>'c2')::int, 1, (t1.fields->>'C 1')::int + 0]); -- ScalarArrayOpExpr
--Testcase 67:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = (ARRAY[(t1.fields->>'C 1')::int,(fields->>'c2')::int,3])[1]; -- SubscriptingRef
--Testcase 68:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE fields->>'c6' = E'foo''s\\bar';  -- check special chars
--Testcase 69:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 t1 WHERE fields->>'c8' = 'foo';  -- can't be sent to remote
-- parameterized remote path for foreign table
--Testcase 70:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM "S 1"."T 1" a, ft2 b WHERE (a.fields->>'C 1')::int = 47 AND (b.fields->>'C 1')::int = (a.fields->>'c2')::int;
--Testcase 71:
SELECT * FROM ft2 a, ft2 b WHERE (a.fields->>'C 1')::int = 47 AND (b.fields->>'C 1')::int = (a.fields->>'c2')::int;

-- check both safe and unsafe join conditions
--Testcase 72:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft2 a, ft2 b
  WHERE (a.fields->>'c2')::int = 6 AND (b.fields->>'C 1')::int = (a.fields->>'C 1')::int AND a.fields->>'c8' = 'foo' AND b.fields->>'c7' = upper(a.fields->>'c7');
--Testcase 73:
SELECT * FROM ft2 a, ft2 b
WHERE (a.fields->>'c2')::int = 6 AND (b.fields->>'C 1')::int = (a.fields->>'C 1')::int AND a.fields->>'c8' = 'foo' AND b.fields->>'c7' = upper(a.fields->>'c7') ORDER BY (a.fields->>'C 1')::int;
-- bug before 9.3.5 due to sloppy handling of remote-estimate parameters
--Testcase 74:
SELECT * FROM ft1 WHERE (fields->>'C 1')::int = ANY (ARRAY(SELECT (fields->>'C 1')::int FROM ft2 WHERE (fields->>'C 1')::int < 5));
--Testcase 75:
SELECT * FROM ft2 WHERE (fields->>'C 1')::int = ANY (ARRAY(SELECT (fields->>'C 1')::int FROM ft1 WHERE (fields->>'C 1')::int < 5));
-- we should not push order by clause with volatile expressions or unsafe
-- collations
--Testcase 76:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY (ft2.fields->>'C 1')::int, random();
--Testcase 77:
EXPLAIN (VERBOSE, COSTS OFF)
	SELECT * FROM ft2 ORDER BY (ft2.fields->>'C 1')::int, ft2.tags->>'c3' collate "C";

-- user-defined operator/function
--Testcase 78:
CREATE FUNCTION influxdb_fdw_abs(int) RETURNS int AS $$
BEGIN
RETURN abs($1);
END
$$ LANGUAGE plpgsql IMMUTABLE;
--Testcase 79:
CREATE OPERATOR === (
    LEFTARG = int,
    RIGHTARG = int,
    PROCEDURE = int4eq,
    COMMUTATOR = ===
);

-- built-in operators and functions can be shipped for remote execution
--Testcase 80:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = abs((t1.fields->>'c2')::int);
--Testcase 81:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = abs((t1.fields->>'c2')::int);
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = (t1.fields->>'c2')::int;
--Testcase 83:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = (t1.fields->>'c2')::int;

-- by default, user-defined ones cannot
--Testcase 84:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = influxdb_fdw_abs((t1.fields->>'c2')::int);
--Testcase 85:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = influxdb_fdw_abs((t1.fields->>'c2')::int);
--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int;
--Testcase 87:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int;

-- ORDER BY can be shipped, though
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int order by (t1.fields->>'c2')::int limit 1;
--Testcase 89:
SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int order by (t1.fields->>'c2')::int limit 1;

-- but let's put them in an extension ...
ALTER EXTENSION influxdb_fdw ADD FUNCTION influxdb_fdw_abs(int);
ALTER EXTENSION influxdb_fdw ADD OPERATOR === (int, int);
-- ALTER SERVER loopback OPTIONS (ADD extensions 'influxdb_fdw');

-- ... now they can be shipped
--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = influxdb_fdw_abs((t1.fields->>'c2')::int);
--Testcase 91:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = influxdb_fdw_abs((t1.fields->>'c2')::int);
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int;
--Testcase 93:
SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int;

-- and both ORDER BY and LIMIT can be shipped
--Testcase 94:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int order by (t1.fields->>'c2')::int limit 1;
--Testcase 95:
SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int order by (t1.fields->>'c2')::int limit 1;

-- ===================================================================
-- JOIN queries
-- ===================================================================

-- join two tables
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
--Testcase 97:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
-- join three tables
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t3.c1)::int = (t1.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 10 LIMIT 10;
--Testcase 99:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t3.c1)::int = (t1.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 10 LIMIT 10;
-- left outer join
--Testcase 100:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
--Testcase 101:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
-- left outer join three tables
--Testcase 102:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 103:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- left outer join + placement of clauses.
-- clauses within the nullable side are not pulled up, but top level clause on
-- non-nullable side is pushed into non-nullable side
--Testcase 104:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, (t2.fields->>'c1')::int c1, (t2.fields->>'c2')::int c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT * FROM ft5 t2 WHERE (fields->>'c1')::int < 10) t2 ON ((t1.c1)::int = (t2.fields->>'c1')::int) WHERE (t1.c1)::int < 10;
--Testcase 105:
SELECT t1.c1, t1.c2, (t2.fields->>'c1')::int c1, (t2.fields->>'c2')::int c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT * FROM ft5 t2 WHERE (fields->>'c1')::int < 10) t2 ON ((t1.c1)::int = (t2.fields->>'c1')::int) WHERE (t1.c1)::int < 10;
-- clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 106:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2, (t2.fields->>'c1')::int c1, (t2.fields->>'c2')::int c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT * FROM ft5 t2 WHERE (fields->>'c1')::int < 10) t2 ON ((t1.c1)::int = (t2.fields->>'c1')::int)
			WHERE ((t2.fields->>'c1')::int < 10 OR (t2.fields->>'c1')::int IS NULL) AND (t1.c1)::int < 10;
--Testcase 107:
SELECT t1.c1, t1.c2, (t2.fields->>'c1')::int c1, (t2.fields->>'c2')::int c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 LEFT JOIN (SELECT * FROM ft5 t2 WHERE (fields->>'c1')::int < 10) t2 ON ((t1.c1)::int = (t2.fields->>'c1')::int)
			WHERE ((t2.fields->>'c1')::int < 10 OR (t2.fields->>'c1')::int IS NULL) AND (t1.c1)::int < 10;
-- right outer join
--Testcase 108:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t1) t1 RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t2.c1)::int, (t1.c1)::int OFFSET 10 LIMIT 10;
--Testcase 109:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t1) t1 RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t2.c1)::int, (t1.c1)::int OFFSET 10 LIMIT 10;
-- right outer join three tables
--Testcase 110:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 111:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
-- full outer join
--Testcase 112:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 45 LIMIT 10;
--Testcase 113:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 45 LIMIT 10;
-- full outer join with restrictions on the joining relations
-- a. the joining relations are both base relations
--Testcase 114:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int;
--Testcase 115:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int;
--Testcase 116:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT 1 FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
--Testcase 117:
SELECT 1 FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 ON (TRUE) OFFSET 10 LIMIT 10;
-- b. one of the joining relations is a base relation and the other is a join
-- relation
--Testcase 118:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t2) t2 LEFT JOIN (SELECT fields->>'c1' c1, fields->>'c2' c2, tags->>'c3' c3 FROM ft5) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE ((t2.c1)::int between 50 and 60)) ss(a, b) ON ((t1.c1)::int = ss.a) ORDER BY (t1.c1)::int, ss.a, ss.b;
--Testcase 119:
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t2) t2 LEFT JOIN (SELECT fields->>'c1' c1, fields->>'c2' c2, tags->>'c3' c3 FROM ft5) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE ((t2.c1)::int between 50 and 60)) ss(a, b) ON ((t1.c1)::int = ss.a) ORDER BY (t1.c1)::int, ss.a, ss.b;
-- c. test deparsing the remote query as nested subqueries
--Testcase 120:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t3 WHERE (fields->>'c1')::int between 50 and 60) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE (t2.c1)::int IS NULL OR (t2.c1)::int IS NOT NULL) ss(a, b) ON ((t1.c1)::int = ss.a) ORDER BY (t1.c1)::int, ss.a, ss.b;
--Testcase 121:
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 FULL JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t3 WHERE (fields->>'c1')::int between 50 and 60) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE (t2.c1)::int IS NULL OR (t2.c1)::int IS NOT NULL) ss(a, b) ON ((t1.c1)::int = ss.a) ORDER BY (t1.c1)::int, ss.a, ss.b;
-- d. test deparsing rowmarked relations as subqueries
--Testcase 122:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM "S 1"."T 3" t1 WHERE (fields->>'c1')::int = 50) t1 INNER JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t3 WHERE (fields->>'c1')::int between 50 and 60) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE (t2.c1)::int IS NULL OR (t2.c1)::int IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY (t1.c1)::int, ss.a, ss.b FOR UPDATE OF t1;
--Testcase 123:
SELECT t1.c1, ss.a, ss.b FROM (SELECT (fields->>'c1')::int c1 FROM "S 1"."T 3" t1 WHERE (fields->>'c1')::int = 50) t1 INNER JOIN (SELECT (t2.c1)::int, (t3.c1)::int FROM (SELECT (fields->>'c1')::int c1 FROM ft4 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 FULL JOIN (SELECT (fields->>'c1')::int c1 FROM ft5 t3 WHERE (fields->>'c1')::int between 50 and 60) t3 ON ((t2.c1)::int = (t3.c1)::int) WHERE (t2.c1)::int IS NULL OR (t2.c1)::int IS NOT NULL) ss(a, b) ON (TRUE) ORDER BY (t1.c1)::int, ss.a, ss.b FOR UPDATE OF t1;
-- full outer join + inner join
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1, t3.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 INNER JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int + 1 and (t1.c1)::int between 50 and 60) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int, (t3.c1)::int LIMIT 10;
--Testcase 125:
SELECT t1.c1, t2.c1, t3.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 INNER JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int + 1 and (t1.c1)::int between 50 and 60) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int, (t3.c1)::int LIMIT 10;
-- full outer join three tables
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 127:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- full outer join + right outer join
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 129:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
-- right outer join + full outer join
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 131:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- full outer join + left outer join
--Testcase 132:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 133:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- left outer join + full outer join
--Testcase 134:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 135:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- right outer join + left outer join
--Testcase 136:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 137:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 RIGHT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- left outer join + right outer join
--Testcase 138:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) OFFSET 10 LIMIT 10;
--Testcase 139:
SELECT t1.c1, t2.c2, t3.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) RIGHT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t3) t3 ON ((t2.c1)::int = (t3.c1)::int) ORDER BY (t1.c1)::int OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause, only matched rows
--Testcase 140:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE ((t1.c1)::int = (t2.c1)::int OR (t1.c1)::int IS NULL) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
--Testcase 141:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 FULL JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE ((t1.c1)::int = (t2.c1)::int OR (t1.c1)::int IS NULL) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
-- full outer join + WHERE clause with shippable extensions set
--Testcase 142:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t1.c3 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 FULL JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE influxdb_fdw_abs((t1.c1)::int) > 0 OFFSET 10 LIMIT 10;
-- skip, influxdb does not have option 'extensions'
-- ALTER SERVER influxdb_svr OPTIONS (DROP extensions);
-- full outer join + WHERE clause with shippable extensions not set
-- EXPLAIN (VERBOSE, COSTS OFF)
-- SELECT t1.c1, t2.c2, t1.c3 FROM ft1 t1 FULL JOIN ft2 t2 ON (t1.c1 = t2.c1) WHERE influxdb_fdw_abs(t1.c1) > 0 OFFSET 10 LIMIT 10;
-- ALTER SERVER loopback OPTIONS (ADD extensions 'influxdb_fdw');
-- join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
--Testcase 143:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 144:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR UPDATE OF t1;
--Testcase 145:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR UPDATE;
--Testcase 146:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR UPDATE;
-- join two tables with FOR SHARE clause
--Testcase 147:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 148:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR SHARE OF t1;
--Testcase 149:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR SHARE;
--Testcase 150:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10 FOR SHARE;
-- join in CTE
--Testcase 151:
EXPLAIN (VERBOSE, COSTS OFF)
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
--Testcase 152:
WITH t (c1_1, c1_3, c2_1) AS MATERIALIZED (SELECT t1.c1, t1.c3, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int)) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1 OFFSET 100 LIMIT 10;
-- ctid with whole-row reference
--Testcase 153:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.ctid, t1, t2, t1.c1 FROM (SELECT ctid, fields->>'C 1' c1, fields->>'c2' c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
-- SEMI JOIN, not pushed down
--Testcase 154:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT (t1.fields->>'C 1')::int c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE (t1.fields->>'C 1')::int = (t2.fields->>'C 1')::int) ORDER BY (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
--Testcase 155:
SELECT (t1.fields->>'C 1')::int c1 FROM ft1 t1 WHERE EXISTS (SELECT 1 FROM ft2 t2 WHERE (t1.fields->>'C 1')::int = (t2.fields->>'C 1')::int) ORDER BY (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
-- ANTI JOIN, not pushed down
--Testcase 156:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT (t1.fields->>'C 1')::int c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE (t1.fields->>'C 1')::int = (t2.fields->>'c2')::int) ORDER BY (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
--Testcase 157:
SELECT (t1.fields->>'C 1')::int c1 FROM ft1 t1 WHERE NOT EXISTS (SELECT 1 FROM ft2 t2 WHERE (t1.fields->>'C 1')::int = (t2.fields->>'c2')::int) ORDER BY (t1.fields->>'C 1')::int OFFSET 100 LIMIT 10;
-- CROSS JOIN can be pushed down
--Testcase 158:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 CROSS JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
--Testcase 159:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 CROSS JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
-- different server, not pushed down. No result expected.
--Testcase 160:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t1) t1 JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft6 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
--Testcase 161:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t1) t1 JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft6 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
-- unsafe join conditions (c8 has a UDT), not pushed down. Practically a CROSS
-- JOIN since c8 in both tables has same value.
--Testcase 162:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON (t1.c8 = t2.c8) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
--Testcase 163:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON (t1.c8 = t2.c8) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 100 LIMIT 10;
-- unsafe conditions on one side (c8 has a UDT), not pushed down.
--Testcase 164:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE t1.c8 = 'foo' ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
--Testcase 165:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 LEFT JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE t1.c8 = 'foo' ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
-- join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause. In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
--Testcase 166:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
--Testcase 167:
SELECT t1.c1, t2.c1 FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) WHERE t1.c8 = t2.c8 ORDER BY t1.c3, (t1.c1)::int OFFSET 100 LIMIT 10;
-- Aggregate after UNION, for testing setrefs
--Testcase 168:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT (t1.c1)::int, (t2.c1)::int FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) UNION SELECT (t1.c1)::int, (t2.c1)::int FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
--Testcase 169:
SELECT t1c1, avg(t1c1 + t2c1) FROM (SELECT (t1.c1)::int, (t2.c1)::int FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) UNION SELECT (t1.c1)::int, (t2.c1)::int FROM (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 JOIN (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 ON ((t1.c1)::int = (t2.c1)::int)) AS t (t1c1, t2c1) GROUP BY t1c1 ORDER BY t1c1 OFFSET 100 LIMIT 10;
-- join with lateral reference
--Testcase 170:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1."C 1" FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1, LATERAL (SELECT DISTINCT t2.fields->>'C 1', t3.fields->>'C 1' FROM ft1 t2, ft2 t3 WHERE (t2.fields->>'C 1')::int = (t3.fields->>'C 1')::int AND (t2.fields->>'c2')::int = (t1.c2)::int) q ORDER BY (t1."C 1")::int OFFSET 10 LIMIT 10;
--Testcase 171:
SELECT t1."C 1" FROM (SELECT (fields->>'C 1')::int "C 1", (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM "S 1"."T 1" t1) t1, LATERAL (SELECT DISTINCT t2.fields->>'C 1', t3.fields->>'C 1' FROM ft1 t2, ft2 t3 WHERE (t2.fields->>'C 1')::int = (t3.fields->>'C 1')::int AND (t2.fields->>'c2')::int = (t1.c2)::int) q ORDER BY (t1."C 1")::int OFFSET 10 LIMIT 10;

-- non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- unable to push {ft1, ft2}
--Testcase 172:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, (ft2.fields->>'C 1')::int c1 FROM (SELECT 13 FROM ft1 WHERE (fields->>'C 1')::int = 13) q(a) RIGHT JOIN ft2 ON (q.a = (ft2.fields->>'C 1')::int) WHERE (ft2.fields->>'C 1')::int BETWEEN 10 AND 15;
--Testcase 173:
SELECT q.a, (ft2.fields->>'C 1')::int c1 FROM (SELECT 13 FROM ft1 WHERE (fields->>'C 1')::int = 13) q(a) RIGHT JOIN ft2 ON (q.a = (ft2.fields->>'C 1')::int) WHERE (ft2.fields->>'C 1')::int BETWEEN 10 AND 15;

-- ok to push {ft1, ft2} but not {ft1, ft2, ft4}
--Testcase 174:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT (ft4.fields->>'c1')::int c1, q.* FROM ft4 LEFT JOIN (SELECT 13, (ft1.fields->>'C 1')::int, (ft2.fields->>'C 1')::int FROM ft1 RIGHT JOIN ft2 ON ((ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int) WHERE (ft1.fields->>'C 1')::int = 12) q(a, b, c) ON ((ft4.fields->>'c1')::int = q.b) WHERE (ft4.fields->>'c1')::int BETWEEN 10 AND 15;
--Testcase 175:
SELECT (ft4.fields->>'c1')::int c1, q.* FROM ft4 LEFT JOIN (SELECT 13, (ft1.fields->>'C 1')::int, (ft2.fields->>'C 1')::int FROM ft1 RIGHT JOIN ft2 ON ((ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int) WHERE (ft1.fields->>'C 1')::int = 12) q(a, b, c) ON ((ft4.fields->>'c1')::int = q.b) WHERE (ft4.fields->>'c1')::int BETWEEN 10 AND 15 ORDER BY (ft4.fields->>'c1')::int;

-- join with nullable side with some columns with null values
-- influxdb_fdw does not support UPDATE
-- UPDATE ft5 SET c3 = null where c1 % 9 = 0;
--Testcase 176:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ft5, (ft5.fields->>'c1')::int c1, (ft5.fields->>'c2')::int c2, ft5.tags->>'c3' c3, (ft4.fields->>'c1')::int c1, (ft4.fields->>'c2')::int c2 FROM ft5 left join ft4 on (ft5.fields->>'c1')::int = (ft4.fields->>'c1')::int WHERE (ft4.fields->>'c1')::int BETWEEN 10 and 30 ORDER BY (ft5.fields->>'c1')::int, (ft4.fields->>'c1')::int;
--Testcase 177:
SELECT ft5, (ft5.fields->>'c1')::int c1, (ft5.fields->>'c2')::int c2, ft5.tags->>'c3' c3, (ft4.fields->>'c1')::int c1, (ft4.fields->>'c2')::int c2 FROM ft5 left join ft4 on (ft5.fields->>'c1')::int = (ft4.fields->>'c1')::int WHERE (ft4.fields->>'c1')::int BETWEEN 10 and 30 ORDER BY (ft5.fields->>'c1')::int, (ft4.fields->>'c1')::int;

-- multi-way join involving multiple merge joins
-- (this case used to have EPQ-related planning problems)
--Testcase 178:
CREATE FOREIGN TABLE local_tbl (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'local_tbl', schemaless 'true');
CREATE FOREIGN TABLE local_tbl_nsc (c1 int NOT NULL, c2 int NOT NULL, c3 text) SERVER influxdb_svr OPTIONS (table 'local_tbl');
--Testcase 179:
INSERT INTO local_tbl_nsc SELECT id, id % 10, to_char(id, 'FM0000') FROM generate_series(1, 1000) id;
--ANALYZE local_tbl;
SET enable_nestloop TO false;
SET enable_hashjoin TO false;
--Testcase 180:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE (ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int AND (ft1.fields->>'c2')::int = (ft4.fields->>'c1')::int
    AND (ft1.fields->>'c2')::int = (ft5.fields->>'c1')::int AND (ft1.fields->>'c2')::int = (local_tbl.fields->>'c1')::int AND (ft1.fields->>'C 1')::int < 100 AND (ft2.fields->>'C 1')::int < 100 ORDER BY (ft1.fields->>'C 1')::int FOR UPDATE;
--Testcase 181:
SELECT * FROM ft1, ft2, ft4, ft5, local_tbl WHERE (ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int AND (ft1.fields->>'c2')::int = (ft4.fields->>'c1')::int
    AND (ft1.fields->>'c2')::int = (ft5.fields->>'c1')::int AND (ft1.fields->>'c2')::int = (local_tbl.fields->>'c1')::int AND (ft1.fields->>'C 1')::int < 100 AND (ft2.fields->>'C 1')::int < 100 ORDER BY (ft1.fields->>'C 1')::int FOR UPDATE;
RESET enable_nestloop;
RESET enable_hashjoin;
--Testcase 182:
DELETE FROM local_tbl_nsc;
DROP FOREIGN TABLE local_tbl;
DROP FOREIGN TABLE local_tbl_nsc;

-- check join pushdown in situations where multiple userids are involved
--Testcase 183:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 184:
CREATE USER MAPPING FOR regress_view_owner SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);
GRANT SELECT ON ft4 TO regress_view_owner;
GRANT SELECT ON ft5 TO regress_view_owner;

--Testcase 185:
CREATE VIEW v4 AS SELECT * FROM ft4;
--Testcase 186:
CREATE VIEW v5 AS SELECT * FROM ft5;
ALTER VIEW v5 OWNER TO regress_view_owner;
--Testcase 187:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;  -- can't be pushed down, different view owners
--Testcase 188:
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;
--Testcase 189:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 190:
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;

--Testcase 191:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;  -- can't be pushed down, view owner not current user
--Testcase 192:
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO CURRENT_USER;
--Testcase 193:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;  -- can be pushed down
--Testcase 194:
SELECT t1.c1, t2.c2 FROM (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM v4 t1) t1 LEFT JOIN (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 ON ((t1.c1)::int = (t2.c1)::int) ORDER BY (t1.c1)::int, (t2.c1)::int OFFSET 10 LIMIT 10;
ALTER VIEW v4 OWNER TO regress_view_owner;

-- cleanup
--Testcase 195:
DROP OWNED BY regress_view_owner;
--Testcase 196:
DROP ROLE regress_view_owner;


-- ===================================================================
-- Aggregate and grouping queries
-- ===================================================================

-- Simple aggregates
--Testcase 197:
explain (verbose, costs off)
select count(fields->>'c6'), sum((fields->>'C 1')::int), avg((fields->>'C 1')::int), min((fields->>'c2')::int), max((fields->>'C 1')::int), stddev((fields->>'c2')::int), sum((fields->>'C 1')::int) * (random() <= 1)::int as sum2 from ft1 where (fields->>'c2')::int < 5 group by fields->>'c2' order by 1, 2;
--Testcase 198:
select count(fields->>'c6'), sum((fields->>'C 1')::int), avg((fields->>'C 1')::int), min((fields->>'c2')::int), max((fields->>'C 1')::int), stddev((fields->>'c2')::int), sum((fields->>'C 1')::int) * (random() <= 1)::int as sum2 from ft1 where (fields->>'c2')::int < 5 group by fields->>'c2' order by 1, 2;

--Testcase 199:
explain (verbose, costs off)
select count(fields->>'c6'), sum((fields->>'C 1')::int), avg((fields->>'C 1')::int), min((fields->>'c2')::int), max((fields->>'C 1')::int), stddev((fields->>'c2')::int), sum((fields->>'C 1')::int) * (random() <= 1)::int as sum2 from ft1 where (fields->>'c2')::int < 5 group by fields->>'c2' order by 1, 2 limit 1;
--Testcase 200:
select count(fields->>'c6'), sum((fields->>'C 1')::int), avg((fields->>'C 1')::int), min((fields->>'c2')::int), max((fields->>'C 1')::int), stddev((fields->>'c2')::int), sum((fields->>'C 1')::int) * (random() <= 1)::int as sum2 from ft1 where (fields->>'c2')::int < 5 group by fields->>'c2' order by 1, 2 limit 1;

-- Aggregate is not pushed down as aggregation contains random()
--Testcase 201:
explain (verbose, costs off)
select sum((fields->>'C 1')::int * (random() <= 1)::int) as sum, avg((fields->>'C 1')::int) from ft1;

-- Aggregate over join query
--Testcase 202:
explain (verbose, costs off)
select count(*), sum((t1.c1)::int), avg((t2.c1)::int) from (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 inner join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 on ((t1.c2)::int = (t2.c2)::int) where (t1.c2)::int = 6;
--Testcase 203:
select count(*), sum((t1.c1)::int), avg((t2.c1)::int) from (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 inner join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t2) t2 on ((t1.c2)::int = (t2.c2)::int) where (t1.c2)::int = 6;

-- Not pushed down due to local conditions present in underneath input rel
--Testcase 204:
explain (verbose, costs off)
select sum((t1.c1)::int), count((t2.c1)::int) from (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 t1) t1 inner join (SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (((t1.c1)::int * (t2.c1)::int)/((t1.c1)::int * (t2.c1)::int)) * random() <= 1;

-- GROUP BY clause having expressions
--Testcase 205:
explain (verbose, costs off)
select (fields->>'c2')::int/2, sum((fields->>'c2')::int) * ((fields->>'c2')::int/2) from ft1 group by (fields->>'c2')::int/2 order by (fields->>'c2')::int/2;
--Testcase 206:
select (fields->>'c2')::int/2, sum((fields->>'c2')::int) * ((fields->>'c2')::int/2) from ft1 group by (fields->>'c2')::int/2 order by (fields->>'c2')::int/2;

-- Aggregates in subquery are pushed down.
--Testcase 207:
explain (verbose, costs off)
select count(x.a), sum(x.a) from (select (fields->>'c2')::int a, sum((fields->>'C 1')::int) b from ft1 group by fields->>'c2', sqrt((fields->>'C 1')::int) order by 1, 2) x;
--Testcase 208:
select count(x.a), sum(x.a) from (select (fields->>'c2')::int a, sum((fields->>'C 1')::int) b from ft1 group by fields->>'c2', sqrt((fields->>'C 1')::int) order by 1, 2) x;

-- Aggregate is still pushed down by taking unshippable expression out
--Testcase 209:
explain (verbose, costs off)
select (fields->>'c2')::int * (random() <= 1)::int as sum1, sum((fields->>'C 1')::int) * (fields->>'c2')::int as sum2 from ft1 group by fields->>'c2' order by 1, 2;
--Testcase 210:
select (fields->>'c2')::int * (random() <= 1)::int as sum1, sum((fields->>'C 1')::int) * (fields->>'c2')::int as sum2 from ft1 group by fields->>'c2' order by 1, 2;

-- Aggregate with unshippable GROUP BY clause are not pushed
--Testcase 211:
explain (verbose, costs off)
select (fields->>'c2')::int * (random() <= 1)::int as c2 from ft2 group by (fields->>'c2')::int * (random() <= 1)::int order by 1;

-- GROUP BY clause in various forms, cardinal, alias and constant expression
--Testcase 212:
explain (verbose, costs off)
select count(fields->>'c2') w, fields->>'c2' x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;
--Testcase 213:
select count(fields->>'c2') w, fields->>'c2' x, 5 y, 7.0 z from ft1 group by 2, y, 9.0::int order by 2;

-- GROUP BY clause referring to same column multiple times
-- Also, ORDER BY contains an aggregate function
--Testcase 214:
explain (verbose, costs off)
select (fields->>'c2')::int c2, (fields->>'c2')::int c2 from ft1 where (fields->>'c2')::int > 6 group by 1, 2 order by sum((fields->>'C 1')::int);
--Testcase 215:
select (fields->>'c2')::int c2, (fields->>'c2')::int c2 from ft1 where (fields->>'c2')::int > 6 group by 1, 2 order by sum((fields->>'C 1')::int);

-- Testing HAVING clause shippability
--Testcase 216:
explain (verbose, costs off)
select(fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft2 group by fields->>'c2' having avg((fields->>'C 1')::int) < 500 and sum((fields->>'C 1')::int) < 49800 order by (fields->>'c2')::int;
--Testcase 217:
select(fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft2 group by fields->>'c2' having avg((fields->>'C 1')::int) < 500 and sum((fields->>'C 1')::int) < 49800 order by (fields->>'c2')::int;

-- Unshippable HAVING clause will be evaluated locally, and other qual in HAVING clause is pushed down
--Testcase 218:
explain (verbose, costs off)
select count(*) from (select time, count((fields->>'C 1')::int) from ft1 group by time, sqrt((fields->>'c2')::int) having (avg((fields->>'C 1')::int) / avg((fields->>'C 1')::int)) * random() <= 1 and avg((fields->>'C 1')::int) < 500) x;
--Testcase 219:
select count(*) from (select time, count((fields->>'C 1')::int) from ft1 group by time, sqrt((fields->>'c2')::int) having (avg((fields->>'C 1')::int) / avg((fields->>'C 1')::int)) * random() <= 1 and avg((fields->>'C 1')::int) < 500) x;

-- Aggregate in HAVING clause is not pushable, and thus aggregation is not pushed down
--Testcase 220:
explain (verbose, costs off)
select sum((fields->>'C 1')::int) from ft1 group by fields->>'c2' having avg((fields->>'C 1')::int * (random() <= 1)::int) > 100 order by 1;

-- Remote aggregate in combination with a local Param (for the output
-- of an initplan) can be trouble, per bug #15781
--Testcase 221:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum((fields->>'C 1')::int) from ft1;
--Testcase 222:
select exists(select 1 from pg_enum), sum((fields->>'C 1')::int) from ft1;

--Testcase 223:
explain (verbose, costs off)
select exists(select 1 from pg_enum), sum((fields->>'C 1')::int) from ft1 group by 1;
--Testcase 224:
select exists(select 1 from pg_enum), sum((fields->>'C 1')::int) from ft1 group by 1;


-- Testing ORDER BY, DISTINCT, FILTER, Ordered-sets and VARIADIC within aggregates

-- ORDER BY within aggregate, same column used to order
--Testcase 225:
explain (verbose, costs off)
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int) from ft1 where (fields->>'C 1')::int < 100 group by fields->>'c2' order by 1;
--Testcase 226:
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int) from ft1 where (fields->>'C 1')::int < 100 group by fields->>'c2' order by 1;

-- ORDER BY within aggregate, different column used to order also using DESC
--Testcase 227:
explain (verbose, costs off)
select array_agg(time order by (fields->>'C 1')::int desc) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 50;
--Testcase 228:
select array_agg(time order by (fields->>'C 1')::int desc) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 50;

-- DISTINCT within aggregate
--Testcase 229:
explain (verbose, costs off)
select array_agg(distinct ((t1.c1)::int)%5) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;
--Testcase 230:
select array_agg(distinct ((t1.c1)::int)%5) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;

-- DISTINCT combined with ORDER BY within aggregate
--Testcase 231:
explain (verbose, costs off)
select array_agg(distinct ((t1.c1)::int)%5 order by ((t1.c1)::int)%5) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;
--Testcase 232:
select array_agg(distinct ((t1.c1)::int)%5 order by ((t1.c1)::int)%5) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;

--Testcase 233:
explain (verbose, costs off)
select array_agg(distinct ((t1.c1)::int)%5 order by ((t1.c1)::int)%5 desc nulls last) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;
--Testcase 234:
select array_agg(distinct ((t1.c1)::int)%5 order by ((t1.c1)::int)%5 desc nulls last) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) where (t1.c1)::int < 20 or ((t1.c1)::int is null and (t2.c1)::int < 5) group by ((t2.c1)::int)%3 order by 1;

-- FILTER within aggregate
--Testcase 235:
explain (verbose, costs off)
select sum((fields->>'C 1')::int) filter (where (fields->>'C 1')::int < 100 and (fields->>'c2')::int > 5) from ft1 group by fields->>'c2' order by 1 nulls last;
--Testcase 236:
select sum((fields->>'C 1')::int) filter (where (fields->>'C 1')::int < 100 and (fields->>'c2')::int > 5) from ft1 group by fields->>'c2' order by 1 nulls last;

-- DISTINCT, ORDER BY and FILTER within aggregate
--Testcase 237:
explain (verbose, costs off)
select sum((fields->>'C 1')::int%3), sum(distinct (fields->>'C 1')::int%3 order by (fields->>'C 1')::int%3) filter (where (fields->>'C 1')::int%3 < 2), (fields->>'c2')::int c2 from ft1 where (fields->>'c2')::int = 6 group by fields->>'c2';
--Testcase 238:
select sum((fields->>'C 1')::int%3), sum(distinct (fields->>'C 1')::int%3 order by (fields->>'C 1')::int%3) filter (where (fields->>'C 1')::int%3 < 2), (fields->>'c2')::int c2 from ft1 where (fields->>'c2')::int = 6 group by fields->>'c2';

-- Outer query is aggregation query
--Testcase 239:
explain (verbose, costs off)
select distinct (select count(*) filter (where (t2.fields->>'c2')::int = 6 and (t2.fields->>'C 1')::int < 10) from ft1 t1 where (t1.fields->>'C 1')::int = 6) from ft2 t2 where (t2.fields->>'c2')::int % 6 = 0 order by 1;
--Testcase 240:
select distinct (select count(*) filter (where (t2.fields->>'c2')::int = 6 and (t2.fields->>'C 1')::int < 10) from ft1 t1 where (t1.fields->>'C 1')::int = 6) from ft2 t2 where (t2.fields->>'c2')::int % 6 = 0 order by 1;
-- Inner query is aggregation query
--Testcase 241:
explain (verbose, costs off)
select distinct (select count(t1.fields->>'C 1') filter (where (t2.fields->>'c2')::int = 6 and (t2.fields->>'C 1')::int < 10) from ft1 t1 where (t1.fields->>'C 1')::int = 6) from ft2 t2 where (t2.fields->>'c2')::int % 6 = 0 order by 1;
--Testcase 242:
select distinct (select count(t1.fields->>'C 1') filter (where (t2.fields->>'c2')::int = 6 and (t2.fields->>'C 1')::int < 10) from ft1 t1 where (t1.fields->>'C 1')::int = 6) from ft2 t2 where (t2.fields->>'c2')::int % 6 = 0 order by 1;

-- Aggregate not pushed down as FILTER condition is not pushable
--Testcase 243:
explain (verbose, costs off)
select sum((fields->>'C 1')::int) filter (where ((fields->>'C 1')::int / (fields->>'C 1')::int) * random() <= 1) from ft1 group by fields->>'c2' order by 1;
--Testcase 244:
explain (verbose, costs off)
select sum((fields->>'c2')::int) filter (where (fields->>'c2')::int in (select (fields->>'c2')::int from ft1 where (fields->>'c2')::int < 5)) from ft1;

-- Ordered-sets within aggregate
--Testcase 245:
explain (verbose, costs off)
select (fields->>'c2')::int c2, rank('10'::varchar) within group (order by fields->>'c6'), percentile_cont((fields->>'c2')::int/10::numeric) within group (order by (fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' having percentile_cont((fields->>'c2')::int/10::numeric) within group (order by (fields->>'C 1')::int) < 500 order by (fields->>'c2')::int;
--Testcase 246:
select (fields->>'c2')::int c2, rank('10'::varchar) within group (order by fields->>'c6'), percentile_cont((fields->>'c2')::int/10::numeric) within group (order by (fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' having percentile_cont((fields->>'c2')::int/10::numeric) within group (order by (fields->>'C 1')::int) < 500 order by (fields->>'c2')::int;

-- Using multiple arguments within aggregates
--Testcase 247:
explain (verbose, costs off)
select (fields->>'C 1')::int c1, rank(fields->>'C 1', fields->>'c2') within group (order by fields->>'C 1', fields->>'c2') from ft1 group by fields->>'C 1', fields->>'c2' having (fields->>'C 1')::int = 6 order by 1;
--Testcase 248:
select (fields->>'C 1')::int c1, rank(fields->>'C 1', fields->>'c2') within group (order by fields->>'C 1', fields->>'c2') from ft1 group by fields->>'C 1', fields->>'c2' having (fields->>'C 1')::int = 6 order by 1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 249:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 250:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- Disable hash aggregation for plan stability.
set enable_hashagg to false;

-- Not pushed down due to user defined aggregate
--Testcase 251:
explain (verbose, costs off)
select (fields->>'c2')::int c2, least_agg((fields->>'C 1')::int) from ft1 group by fields->>'c2' order by (fields->>'c2')::int;

-- Add function and aggregate into extension
alter extension influxdb_fdw add function least_accum(anyelement, variadic anyarray);
alter extension influxdb_fdw add aggregate least_agg(variadic items anyarray);

-- Now aggregate will be pushed.  Aggregate will display VARIADIC argument.
--Testcase 252:
explain (verbose, costs off)
select (fields->>'c2')::int c2, least_agg((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 100 group by fields->>'c2' order by (fields->>'c2')::int;
--Testcase 253:
select (fields->>'c2')::int c2, least_agg((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 100 group by fields->>'c2' order by (fields->>'c2')::int;

-- Remove function and aggregate from extension
alter extension influxdb_fdw drop function least_accum(anyelement, variadic anyarray);
alter extension influxdb_fdw drop aggregate least_agg(variadic items anyarray);

-- Not pushed down as we have dropped objects from extension.
--Testcase 254:
explain (verbose, costs off)
select (fields->>'c2')::int c2, least_agg((fields->>'C 1')::int) from ft1 group by fields->>'c2' order by (fields->>'c2')::int;

-- Cleanup
reset enable_hashagg;
--Testcase 255:
drop aggregate least_agg(variadic items anyarray);
--Testcase 256:
drop function least_accum(anyelement, variadic anyarray);


-- Testing USING OPERATOR() in ORDER BY within aggregate.
-- For this, we need user defined operators along with operator family and
-- operator class.  Create those and then add them in extension.  Note that
-- user defined objects are considered unshippable unless they are part of
-- the extension.
--Testcase 257:
create operator public.<^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4eq
);

--Testcase 258:
create operator public.=^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4lt
);

--Testcase 259:
create operator public.>^ (
 leftarg = int4,
 rightarg = int4,
 procedure = int4gt
);

--Testcase 260:
create operator family my_op_family using btree;

--Testcase 261:
create function my_op_cmp(a int, b int) returns int as
  $$begin return btint4cmp(a, b); end $$ language plpgsql;

--Testcase 262:
create operator class my_op_class for type int using btree family my_op_family as
 operator 1 public.<^,
 operator 3 public.=^,
 operator 5 public.>^,
 function 1 my_op_cmp(int, int);

-- This will not be pushed as user defined sort operator is not part of the
-- extension yet.
--Testcase 263:
explain (verbose, costs off)
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int using operator(public.<^)) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 100 group by fields->>'c2';

-- Update local stats on ft2
--ANALYZE ft2;

-- Add into extension
alter extension influxdb_fdw add operator class my_op_class using btree;
alter extension influxdb_fdw add function my_op_cmp(a int, b int);
alter extension influxdb_fdw add operator family my_op_family using btree;
alter extension influxdb_fdw add operator public.<^(int, int);
alter extension influxdb_fdw add operator public.=^(int, int);
alter extension influxdb_fdw add operator public.>^(int, int);

-- Now this will be pushed as sort operator is part of the extension.
--Testcase 264:
explain (verbose, costs off)
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int using operator(public.<^)) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 100 group by fields->>'c2';
--Testcase 265:
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int using operator(public.<^)) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 100 group by fields->>'c2';

-- Remove from extension
alter extension influxdb_fdw drop operator class my_op_class using btree;
alter extension influxdb_fdw drop function my_op_cmp(a int, b int);
alter extension influxdb_fdw drop operator family my_op_family using btree;
alter extension influxdb_fdw drop operator public.<^(int, int);
alter extension influxdb_fdw drop operator public.=^(int, int);
alter extension influxdb_fdw drop operator public.>^(int, int);

-- This will not be pushed as sort operator is now removed from the extension.
--Testcase 266:
explain (verbose, costs off)
select array_agg((fields->>'C 1')::int order by (fields->>'C 1')::int using operator(public.<^)) from ft2 where (fields->>'c2')::int = 6 and (fields->>'C 1')::int < 100 group by fields->>'c2';

-- Cleanup
--Testcase 267:
drop operator class my_op_class using btree;
--Testcase 268:
drop function my_op_cmp(a int, b int);
--Testcase 269:
drop operator family my_op_family using btree;
--Testcase 270:
drop operator public.>^(int, int);
--Testcase 271:
drop operator public.=^(int, int);
--Testcase 272:
drop operator public.<^(int, int);

-- Input relation to aggregate push down hook is not safe to pushdown and thus
-- the aggregate cannot be pushed down to foreign server.
--Testcase 273:
explain (verbose, costs off)
select count(t1.c3) from ((SELECT fields->>'C 1' c1, fields->>'c2' c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2)) t1 left join ((SELECT fields->>'C 1' c1, fields->>'c2' c2, tags->>'c3' c3, fields->>'c4' c4, fields->>'c5' c5, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2)) t2 on ((t1.c1)::int = random() * (t2.c2)::int);

-- Subquery in FROM clause having aggregate
--Testcase 274:
explain (verbose, costs off)
select count(*), x.b from ft1, (select (fields->>'c2')::int a, sum((fields->>'C 1')::int) b from ft1 group by fields->>'c2') x where (ft1.fields->>'c2')::int = x.a group by x.b order by 1, 2;
--Testcase 275:
select count(*), x.b from ft1, (select (fields->>'c2')::int a, sum((fields->>'C 1')::int) b from ft1 group by fields->>'c2') x where (ft1.fields->>'c2')::int = x.a group by x.b order by 1, 2;

-- FULL join with IS NULL check in HAVING
--Testcase 276:
explain (verbose, costs off)
select avg((t1.c1)::int), sum((t2.c1)::int) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) group by t2.c1 having (avg((t1.c1)::int) is null and sum((t2.c1)::int) < 10) or sum((t2.c1)::int) is null order by 1 nulls last, 2;
--Testcase 277:
select avg((t1.c1)::int), sum((t2.c1)::int) from (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft4 t1) t1 full join (SELECT (fields->>'c1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft5 t2) t2 on ((t1.c1)::int = (t2.c1)::int) group by t2.c1 having (avg((t1.c1)::int) is null and sum((t2.c1)::int) < 10) or sum((t2.c1)::int) is null order by 1 nulls last, 2;

-- Aggregate over FULL join needing to deparse the joining relations as
-- subqueries.
--Testcase 278:
explain (verbose, costs off)
select count(*), sum((t1.c1)::int), avg((t2.c1)::int) from (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 full join (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 on ((t1.c1)::int = (t2.c1)::int);
--Testcase 279:
select count(*), sum((t1.c1)::int), avg((t2.c1)::int) from (SELECT (fields->>'c1')::int c1 FROM ft4 t1 WHERE (fields->>'c1')::int between 50 and 60) t1 full join (SELECT (fields->>'c1')::int c1 FROM ft5 t2 WHERE (fields->>'c1')::int between 50 and 60) t2 on ((t1.c1)::int = (t2.c1)::int);

-- ORDER BY expression is part of the target list but not pushed down to
-- foreign server.
--Testcase 280:
explain (verbose, costs off)
select sum((fields->>'c2')::int) * (random() <= 1)::int as sum from ft1 order by 1;
--Testcase 281:
select sum((fields->>'c2')::int) * (random() <= 1)::int as sum from ft1 order by 1;

-- LATERAL join, with parameterization
set enable_hashagg to false;
--Testcase 282:
explain (verbose, costs off)
select (fields->>'c2')::int c2, sum from "S 1"."T 1" t1, lateral (select sum((t2.fields->>'C 1')::int + (t1.fields->>'C 1')::int) sum from ft2 t2 group by t2.fields->>'C 1') qry where (t1.fields->>'c2')::int * 2 = qry.sum and (t1.fields->>'c2')::int < 3 and (t1.fields->>'C 1')::int < 100 order by 1;
--Testcase 283:
select (fields->>'c2')::int c2, sum from "S 1"."T 1" t1, lateral (select sum((t2.fields->>'C 1')::int + (t1.fields->>'C 1')::int) sum from ft2 t2 group by t2.fields->>'C 1') qry where (t1.fields->>'c2')::int * 2 = qry.sum and (t1.fields->>'c2')::int < 3 and (t1.fields->>'C 1')::int < 100 order by 1;
reset enable_hashagg;

-- bug #15613: bad plan for foreign table scan with lateral reference
--Testcase 284:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT (ref_0.fields->>'c2')::int c2, subq_1.*
FROM
    "S 1"."T 1" AS ref_0,
    LATERAL (
        SELECT (ref_0.fields->>'C 1')::int c1, subq_0.*
        FROM (SELECT (ref_0.fields->>'c2')::int c2, ref_1.tags->>'c3' c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.tags->>'c3')
    ) AS subq_1
WHERE (ref_0.fields->>'C 1')::int < 10 AND subq_1.c3 = '00001'
ORDER BY (ref_0.fields->>'C 1')::int;

--Testcase 285:
SELECT (ref_0.fields->>'c2')::int c2, subq_1.*
FROM
    "S 1"."T 1" AS ref_0,
    LATERAL (
        SELECT (ref_0.fields->>'C 1')::int c1, subq_0.*
        FROM (SELECT (ref_0.fields->>'c2')::int c2, ref_1.tags->>'c3' c3
              FROM ft1 AS ref_1) AS subq_0
             RIGHT JOIN ft2 AS ref_3 ON (subq_0.c3 = ref_3.tags->>'c3')
    ) AS subq_1
WHERE (ref_0.fields->>'C 1')::int < 10 AND subq_1.c3 = '00001'
ORDER BY (ref_0.fields->>'C 1')::int;

-- Check with placeHolderVars
--Testcase 286:
explain (verbose, costs off)
select sum(q.a), count(q.b) from ft4 left join (select 13, avg((ft1.fields->>'C 1')::int), sum((ft2.fields->>'C 1')::int) from ft1 right join ft2 on ((ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int)) q(a, b, c) on ((ft4.fields->>'c1')::int <= q.b);
--Testcase 287:
select sum(q.a), count(q.b) from ft4 left join (select 13, avg((ft1.fields->>'C 1')::int), sum((ft2.fields->>'C 1')::int) from ft1 right join ft2 on ((ft1.fields->>'C 1')::int = (ft2.fields->>'C 1')::int)) q(a, b, c) on ((ft4.fields->>'c1')::int <= q.b);


-- Not supported cases
-- Grouping sets
--Testcase 288:
explain (verbose, costs off)
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by rollup((fields->>'c2')::int) order by 1 nulls last;
--Testcase 289:
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by rollup((fields->>'c2')::int) order by 1 nulls last;
--Testcase 290:
explain (verbose, costs off)
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by cube((fields->>'c2')::int) order by 1 nulls last;
--Testcase 291:
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by cube((fields->>'c2')::int) order by 1 nulls last;
--Testcase 292:
explain (verbose, costs off)
select (fields->>'c2')::int c2, fields->>'c6' c6, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by grouping sets(fields->>'c2', fields->>'c6') order by 1 nulls last, 2 nulls last;
--Testcase 293:
select (fields->>'c2')::int c2, fields->>'c6' c6, sum((fields->>'C 1')::int) from ft1 where (fields->>'c2')::int < 3 group by grouping sets(fields->>'c2', fields->>'c6') order by 1 nulls last, 2 nulls last;
--Testcase 294:
explain (verbose, costs off)
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int), grouping(fields->>'c2') from ft1 where (fields->>'c2')::int < 3 group by fields->>'c2' order by 1 nulls last;
--Testcase 295:
select (fields->>'c2')::int c2, sum((fields->>'C 1')::int), grouping(fields->>'c2') from ft1 where (fields->>'c2')::int < 3 group by fields->>'c2' order by 1 nulls last;

-- DISTINCT itself is not pushed down, whereas underneath aggregate is pushed
--Testcase 296:
explain (verbose, costs off)
select distinct sum((fields->>'C 1')::int)/1000 s from ft2 where (fields->>'c2')::int < 6 group by fields->>'c2' order by 1;
--Testcase 297:
select distinct sum((fields->>'C 1')::int)/1000 s from ft2 where (fields->>'c2')::int < 6 group by fields->>'c2' order by 1;

-- WindowAgg
--Testcase 298:
explain (verbose, costs off)
select (fields->>'c2')::int c2, sum((fields->>'c2')::int), count((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2) from ft2 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;
--Testcase 299:
select (fields->>'c2')::int c2, sum((fields->>'c2')::int), count((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2) from ft2 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;
--Testcase 300:
explain (verbose, costs off)
select (fields->>'c2')::int c2, array_agg((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2 order by (fields->>'c2')::int desc) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;
--Testcase 301:
select (fields->>'c2')::int c2, array_agg((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2 order by (fields->>'c2')::int desc) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;
--Testcase 302:
explain (verbose, costs off)
select (fields->>'c2')::int c2, array_agg((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2 order by (fields->>'c2')::int range between current row and unbounded following) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;
--Testcase 303:
select (fields->>'c2')::int c2, array_agg((fields->>'c2')::int) over (partition by (fields->>'c2')::int%2 order by (fields->>'c2')::int range between current row and unbounded following) from ft1 where (fields->>'c2')::int < 10 group by fields->>'c2' order by 1;


-- ===================================================================
-- parameterized queries
-- ===================================================================
-- simple join
--Testcase 304:
PREPARE st1(int, int) AS SELECT t1.tags->>'c3' c3, t2.tags->>'c3' c3 FROM ft1 t1, ft2 t2 WHERE (t1.fields->>'C 1')::int = $1 AND (t2.fields->>'C 1')::int = $2;
--Testcase 305:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st1(1, 2);
--Testcase 306:
EXECUTE st1(1, 1);
--Testcase 307:
EXECUTE st1(101, 101);
-- subquery using stable function (can't be sent to remote)
--Testcase 308:
PREPARE st2(int) AS SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int < $2 AND t1.tags->>'c3' IN (SELECT tags->>'c3' FROM ft2 t2 WHERE (fields->>'C 1')::int > $1 AND date(time) = '1970-01-17'::date) ORDER BY (fields->>'C 1')::int;
--Testcase 309:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st2(10, 20);
--Testcase 310:
EXECUTE st2(10, 20);
--Testcase 311:
EXECUTE st2(101, 121);
-- subquery using immutable function (can be sent to remote)
--Testcase 312:
PREPARE st3(int) AS SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int < $2 AND t1.tags->>'c3' IN (SELECT tags->>'c3' FROM ft2 t2 WHERE (fields->>'C 1')::int > $1 AND date(time) = '1970-01-17'::date) ORDER BY (fields->>'C 1')::int;
--Testcase 313:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st3(10, 20);
--Testcase 314:
EXECUTE st3(10, 20);
--Testcase 315:
EXECUTE st3(20, 30);
-- custom plan should be chosen initially
--Testcase 316:
PREPARE st4(int) AS SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = $1;
--Testcase 317:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 318:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 319:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 320:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
--Testcase 321:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- once we try it enough times, should switch to generic plan
--Testcase 322:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st4(1);
-- value of $1 should not be sent to remote
--Testcase 323:
PREPARE st5(text,int) AS SELECT * FROM ft1 t1 WHERE fields->>'c8' = $1 and (fields->>'C 1')::int = $2;
--Testcase 324:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 325:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 326:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 327:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 328:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 329:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st5('foo', 1);
--Testcase 330:
EXECUTE st5('foo', 1);

-- altering FDW options requires replanning
--Testcase 331:
PREPARE st6 AS SELECT * FROM ft1 t1 WHERE (t1.fields->>'C 1')::int = (t1.fields->>'c2')::int;
--Testcase 332:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 333:
PREPARE st7 AS INSERT INTO ft1_nsc (c1,c2,c3) VALUES (1001,101,'foo');
--Testcase 334:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
--Testcase 335:
INSERT INTO "S 1".s1t0 SELECT * FROM "S 1".s1t1;
ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T0');
--Testcase 336:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st6;
--Testcase 337:
EXECUTE st6;
--Testcase 338:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st7;
--Testcase 339:
DELETE FROM "S 1".s1t0;
ALTER FOREIGN TABLE ft1 OPTIONS (SET table 'T1');

--Testcase 340:
PREPARE st8 AS SELECT count(tags->>'c3') FROM ft1 t1 WHERE (t1.fields->>'C 1')::int === (t1.fields->>'c2')::int;
--Testcase 341:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
-- Skip, influxdb_fdw does not support extensions
-- ALTER SERVER loopback OPTIONS (DROP extensions);
--Testcase 342:
EXPLAIN (VERBOSE, COSTS OFF) EXECUTE st8;
--Testcase 343:
EXECUTE st8;
-- ALTER SERVER loopback OPTIONS (ADD extensions 'influxdb_fdw');

-- cleanup
DEALLOCATE st1;
DEALLOCATE st2;
DEALLOCATE st3;
DEALLOCATE st4;
DEALLOCATE st5;
DEALLOCATE st6;
DEALLOCATE st7;
DEALLOCATE st8;

-- System columns, except ctid and oid, should not be sent to remote
--Testcase 344:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'pg_class'::regclass LIMIT 1;
--Testcase 345:
SELECT * FROM ft1 t1 WHERE t1.tableoid = 'ft1'::regclass ORDER BY (fields->>'C 1')::int LIMIT 1;
--Testcase 346:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT tableoid::regclass, * FROM ft1 t1 LIMIT 1;
--Testcase 347:
SELECT tableoid::regclass, * FROM ft1 t1 ORDER BY (fields->>'C 1')::int LIMIT 1;
--Testcase 348:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 349:
SELECT * FROM ft1 t1 WHERE t1.ctid = '(0,2)';
--Testcase 350:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT ctid, * FROM ft1 t1 LIMIT 1;
--Testcase 351:
SELECT ctid, * FROM ft1 t1 ORDER BY (fields->>'C 1')::int LIMIT 1;

-- ===================================================================
-- used in PL/pgSQL function
-- ===================================================================
--Testcase 352:
CREATE OR REPLACE FUNCTION f_test(p_c1 int) RETURNS int AS $$
DECLARE
	v_c1 int;
BEGIN
--Testcase 353:
    SELECT fields->>'C 1' INTO v_c1 FROM ft1 WHERE (fields->>'C 1')::int = p_c1 LIMIT 1;
    PERFORM fields->>'C 1' FROM ft1 WHERE (fields->>'C 1')::int = p_c1 AND p_c1 = v_c1 LIMIT 1;
    RETURN v_c1;
END;
$$ LANGUAGE plpgsql;
--Testcase 354:
SELECT f_test(100);
--Testcase 355:
DROP FUNCTION f_test(int);

-- ===================================================================
-- conversion error
-- ===================================================================
--ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE int;
--Testcase 356:
--SELECT * FROM ft1 WHERE c1 = 1;  -- ERROR
--Testcase 357:
--SELECT  ft1.c1,  ft2.c2, ft1.c8 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
--Testcase 358:
--SELECT  ft1.c1,  ft2.c2, ft1 FROM ft1, ft2 WHERE ft1.c1 = ft2.c1 AND ft1.c1 = 1; -- ERROR
--Testcase 359:
--SELECT sum(c2), array_agg(c8) FROM ft1 GROUP BY c8; -- ERROR
--ALTER FOREIGN TABLE ft1 ALTER COLUMN c8 TYPE text;

/*
-- influxdb_fdw does not support transactions
-- ===================================================================
-- subtransaction
--  + local/remote error doesn't break cursor
-- ===================================================================
BEGIN;
DECLARE c CURSOR FOR SELECT * FROM ft1 ORDER BY c1;
FETCH c;
SAVEPOINT s;
ERROR OUT;          -- ERROR
ROLLBACK TO s;
FETCH c;
SAVEPOINT s;
SELECT * FROM ft1 WHERE 1 / (c1 - 1) > 0;  -- ERROR
ROLLBACK TO s;
FETCH c;
SELECT * FROM ft1 ORDER BY c1 LIMIT 1;
COMMIT;
*/

-- ===================================================================
-- test handling of collations
-- ===================================================================
--Testcase 360:
create foreign table loct3 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loct3', schemaless 'true');
--Testcase 361:
create foreign table ft3 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loct3', schemaless 'true');

-- can be sent to remote
--Testcase 362:
explain (verbose, costs off) select * from ft3 where fields->>'f1' = 'foo';
--Testcase 363:
explain (verbose, costs off) select * from ft3 where fields->>'f1' COLLATE "C" = 'foo';
--Testcase 364:
explain (verbose, costs off) select * from ft3 where fields->>'f2' = 'foo';
--Testcase 365:
explain (verbose, costs off) select * from ft3 where fields->>'f3' = 'foo';
--Testcase 366:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.fields->>'f3' = l.fields->>'f3' and l.fields->>'f1' = 'foo';
-- can't be sent to remote
--Testcase 367:
explain (verbose, costs off) select * from ft3 where fields->>'f1' COLLATE "POSIX" = 'foo';
--Testcase 368:
explain (verbose, costs off) select * from ft3 where fields->>'f1' = 'foo' COLLATE "C";
--Testcase 369:
explain (verbose, costs off) select * from ft3 where fields->>'f2' COLLATE "C" = 'foo';
--Testcase 370:
explain (verbose, costs off) select * from ft3 where fields->>'f2' = 'foo' COLLATE "C";
--Testcase 371:
explain (verbose, costs off) select * from ft3 f, loct3 l
  where f.fields->>'f3' = l.fields->>'f3' COLLATE "POSIX" and l.fields->>'f1' = 'foo';

-- influxdb_fdw does not support UPDATE
-- ===================================================================
-- test writable foreign table stuff
-- ===================================================================
--Testcase 372:
EXPLAIN (verbose, costs off)
INSERT INTO ft2_nsc (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2_nsc ORDER BY c1 LIMIT 20;
--Testcase 373:
INSERT INTO ft2_nsc (c1,c2,c3) SELECT c1+1000,c2+100, c3 || c3 FROM ft2_nsc ORDER BY c1 LIMIT 20;
--Testcase 374:
INSERT INTO ft2_nsc (c1,c2,c3) VALUES (1101,201,'aaa'), (1102,202,'bbb'), (1103,203,'ccc');
--Testcase 375:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 WHERE (fields->>'c2')::int > 200;
--Testcase 376:
INSERT INTO ft2_nsc (c1,c2,c3) VALUES (1104,204,'ddd'), (1105,205,'eee');
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;              -- can be pushed down
--UPDATE ft2 SET c2 = c2 + 300, c3 = c3 || '_update3' WHERE c1 % 10 = 3;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;  -- can be pushed down
--UPDATE ft2 SET c2 = c2 + 400, c3 = c3 || '_update7' WHERE c1 % 10 = 7 RETURNING *;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
--  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;                               -- can be pushed down
--UPDATE ft2 SET c2 = ft2.c2 + 500, c3 = ft2.c3 || '_update9', c7 = DEFAULT
--  FROM ft1 WHERE ft1.c1 = ft2.c2 AND ft1.c1 % 10 = 9;
--Testcase 377:
EXPLAIN (verbose, costs off)
  DELETE FROM ft2_nsc WHERE c1 % 10 = 5;                               -- can be pushed down
--Testcase 378:
SELECT (fields->>'C 1')::int c1 FROM ft2 WHERE (fields->>'C 1')::int % 10 = 5 ORDER BY (fields->>'C 1')::int;
--Testcase 379:
DELETE FROM ft2_nsc WHERE c1 % 10 = 5;
--Testcase 380:
SELECT (fields->>'C 1')::int c1 FROM ft2 WHERE (fields->>'C 1')::int % 10 = 5;
--Testcase 381:
EXPLAIN (verbose, costs off)
DELETE FROM ft2_nsc USING ft1_nsc WHERE ft1_nsc.c1 = ft2_nsc.c2 AND ft1_nsc.c1 % 10 = 2;
--Testcase 382:
DELETE FROM ft2_nsc USING ft1_nsc WHERE ft1_nsc.c1 = ft2_nsc.c2 AND ft1_nsc.c1 % 10 = 2;
--Testcase 383:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3 FROM ft2 ORDER BY (fields->>'C 1')::int;
--Testcase 384:
EXPLAIN (verbose, costs off)
INSERT INTO ft2_nsc (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 385:
INSERT INTO ft2_nsc (c1,c2,c3) VALUES (1200,999,'foo');
--Testcase 386:
SELECT (fields->>'C 1')::int c1 FROM ft2 WHERE (fields->>'C 1')::int = 1200 AND (fields->>'c2')::int = 999;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;             -- can be pushed down
--UPDATE ft2 SET c3 = 'bar' WHERE c1 = 1200 RETURNING tableoid::regclass;
--Testcase 387:
EXPLAIN (verbose, costs off)
DELETE FROM ft2_nsc WHERE c1 = 1200;
--Testcase 388:
SELECT (fields->>'C 1')::int c1 FROM ft2 WHERE (fields->>'C 1')::int = 1200;
--Testcase 389:
DELETE FROM ft2_nsc WHERE c1 = 1200;
--Testcase 390:
SELECT (fields->>'C 1')::int c1 FROM ft2 WHERE (fields->>'C 1')::int = 1200;

-- Test UPDATE/DELETE with RETURNING on a three-table join
--Testcase 391:
INSERT INTO ft2_nsc (c1,c2,c3)
  SELECT id, id - 1200, to_char(id, 'FM00000') FROM generate_series(1201, 1300) id;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c3 = 'foo'
--  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1
--  RETURNING ft2, ft2.*, ft4, ft4.*;       -- can be pushed down
--UPDATE ft2 SET c3 = 'foo'
--  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--  WHERE ft2.c1 > 1200 AND ft2.c2 = ft4.c1
--  RETURNING ft2, ft2.*, ft4, ft4.*;
--Testcase 392:
EXPLAIN (verbose, costs off)
DELETE FROM ft2_nsc
  USING ft4_nsc LEFT JOIN ft5_nsc ON (ft4_nsc.c1 = ft5_nsc.c1)
  WHERE ft2_nsc.c1 > 1200 AND ft2_nsc.c1 % 10 = 0 AND ft2_nsc.c2 = ft4_nsc.c1;                          -- can be pushed down
--Testcase 393:
SELECT 100 FROM ft2,
  ft4 LEFT JOIN ft5 ON ((ft4.fields->>'c1')::int = (ft5.fields->>'c1')::int)
  WHERE (ft2.fields->>'C 1')::int > 1200 AND (ft2.fields->>'C 1')::int % 10 = 0 AND (ft2.fields->>'c2')::int = (ft4.fields->>'c1')::int;
--Testcase 394:
DELETE FROM ft2_nsc
  USING ft4_nsc LEFT JOIN ft5_nsc ON (ft4_nsc.c1 = ft5_nsc.c1)
  WHERE ft2_nsc.c1 > 1200 AND ft2_nsc.c1 % 10 = 0 AND ft2_nsc.c2 = ft4_nsc.c1;
--Testcase 395:
SELECT 100 FROM ft2,
  ft4 LEFT JOIN ft5 ON ((ft4.fields->>'c1')::int = (ft5.fields->>'c1')::int)
  WHERE (ft2.fields->>'C 1')::int > 1200 AND (ft2.fields->>'C 1')::int % 10 = 0 AND (ft2.fields->>'c2')::int = (ft4.fields->>'c1')::int;
--Testcase 396:
DELETE FROM ft2_nsc WHERE ft2_nsc.c1 > 1200;

-- Test UPDATE with a MULTIEXPR sub-select
-- (maybe someday this'll be remotely executable, but not today)
--EXPLAIN (verbose, costs off)
--UPDATE ft2 AS target SET (c2, c7) = (
--    SELECT c2 * 10, c7
--        FROM ft2 AS src
--        WHERE target.c1 = src.c1
--) WHERE c1 > 1100;
--UPDATE ft2 AS target SET (c2, c7) = (
--    SELECT c2 * 10, c7
--        FROM ft2 AS src
--        WHERE targ--et.c1 = src.c1
--) WHERE c1 > 1100;

--UPDATE ft2 AS target SET (c2) = (
--    SELECT c2 / 10
--        FROM ft2 AS src
--        WHERE targ--et.c1 = src.c1
--) WHERE c1 > 1100;

-- Test UPDATE/DELETE with WHERE or JOIN/ON conditions containing
-- user-defined operators/functions
--Testcase 397:
INSERT INTO ft2_nsc (c1,c2,c3)
  SELECT id, id % 10, to_char(id, 'FM00000') FROM generate_series(2001, 2010) id;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c3 = 'bar' WHERE influxdb_fdw_abs(c1) > 2000 RETURNING *;            -- can't be pushed down
--UPDATE ft2 SET c3 = 'bar' WHERE influxdb_fdw_abs(c1) > 2000 RETURNING *;
--EXPLAIN (verbose, costs off)
--UPDATE ft2 SET c3 = 'baz'
--  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1
--  RETURNING ft2.*, ft4.*, ft5.*;                                                    -- can't be pushed down
--UPDATE ft2 SET c3 = 'baz'
--  FROM ft4 INNER JOIN ft5 ON (ft4.c1 = ft5.c1)
--  WHERE ft2.c1 > 2000 AND ft2.c2 === ft4.c1
--  RETURNING ft2.*, ft4.*, ft5.*;
--Testcase 398:
EXPLAIN (verbose, costs off)
DELETE FROM ft2_nsc
  USING ft4_nsc INNER JOIN ft5_nsc ON (ft4_nsc.c1 === ft5_nsc.c1)
  WHERE ft2_nsc.c1 > 2000 AND ft2_nsc.c2 = ft4_nsc.c1;                       -- can't be pushed down
--Testcase 399:
SELECT (ft2.fields->>'C 1')::int c1, (ft2.fields->>'c2')::int c2, ft2.tags->>'c3' c3 
  FROM ft2, ft4 INNER JOIN ft5 ON ((ft4.fields->>'c1')::int === (ft5.fields->>'c1')::int)
  WHERE (ft2.fields->>'C 1')::int > 2000 AND (ft2.fields->>'c2')::int = (ft4.fields->>'c1')::int;
--Testcase 400:
DELETE FROM ft2_nsc
  USING ft4_nsc INNER JOIN ft5_nsc ON (ft4_nsc.c1 === ft5_nsc.c1)
  WHERE ft2_nsc.c1 > 2000 AND ft2_nsc.c2 = ft4_nsc.c1;  
--Testcase 401:
SELECT (ft2.fields->>'C 1')::int c1, (ft2.fields->>'c2')::int c2, ft2.tags->>'c3' c3 
  FROM ft2, ft4 INNER JOIN ft5 ON ((ft4.fields->>'c1')::int === (ft5.fields->>'c1')::int)
  WHERE (ft2.fields->>'C 1')::int > 2000 AND (ft2.fields->>'c2')::int = (ft4.fields->>'c1')::int;
--Testcase 402:
DELETE FROM ft2_nsc WHERE ft2_nsc.c1 > 2000;

-- Test that trigger on remote table works as expected
--Testcase 403:
CREATE OR REPLACE FUNCTION "S 1".F_BRTRIG() RETURNS trigger AS $$
BEGIN
    NEW.c3 = NEW.c3 || '_trig_update';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
--Testcase 404:
CREATE TRIGGER t1_br_insert BEFORE INSERT OR UPDATE
    ON "S 1".s1t1 FOR EACH ROW EXECUTE PROCEDURE "S 1".F_BRTRIG();

--Testcase 405:
INSERT INTO ft2_nsc (c1,c2,c3) VALUES (1208, 818, 'fff');
--Testcase 406:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 WHERE (fields->>'C 1')::int = 1208;
--Testcase 407:
INSERT INTO ft2_nsc (c1,c2,c3,c6) VALUES (1218, 818, 'ggg', '(--;');
--Testcase 408:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft2 WHERE (fields->>'C 1')::int = 1218;
--UPDATE ft2 SET c2 = c2 + 600 WHERE c1 % 10 = 8 AND c1 < 1200 RETURNING *;

-- Test errors thrown on remote side during update
ALTER TABLE "S 1"."T 1" ADD CONSTRAINT c2positive CHECK ((fields->>'c2')::int >= 0);

-- influxdb_fdw does not support key, ON CONFLICT
--INSERT INTO ft1(c1, c2) VALUES(11, 12);  -- duplicate key
--Testcase 409:
INSERT INTO ft1_nsc(c1, c2) VALUES(11, 12) ON CONFLICT DO NOTHING; -- works
--Testcase 410:
INSERT INTO ft1_nsc(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO NOTHING; -- unsupported
--Testcase 411:
INSERT INTO ft1_nsc(c1, c2) VALUES(11, 12) ON CONFLICT (c1, c2) DO UPDATE SET c3 = 'ffg'; -- unsupported
--INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
--UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive

/*
-- influxdb_fdw does not support transactions
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
*/

-- Above DMLs add data with c6 as NULL in ft1, so test ORDER BY NULLS LAST and NULLs
-- FIRST behavior here.
-- ORDER BY DESC NULLS LAST options
--Testcase 412:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY fields->>'c6' DESC NULLS LAST, (fields->>'C 1')::int OFFSET 795 LIMIT 10;
--Testcase 413:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 ORDER BY fields->>'c6' DESC NULLS LAST, (fields->>'C 1')::int OFFSET 795 LIMIT 10;
-- ORDER BY DESC NULLS FIRST options
--Testcase 414:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY fields->>'c6' DESC NULLS FIRST, (fields->>'C 1')::int OFFSET 15 LIMIT 10;
--Testcase 415:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 ORDER BY fields->>'c6' DESC NULLS FIRST, (fields->>'C 1')::int OFFSET 15 LIMIT 10;
-- ORDER BY ASC NULLS FIRST options
--Testcase 416:
EXPLAIN (VERBOSE, COSTS OFF) SELECT * FROM ft1 ORDER BY fields->>'c6' ASC NULLS FIRST, (fields->>'C 1')::int OFFSET 15 LIMIT 10;
--Testcase 417:
SELECT (fields->>'C 1')::int c1, (fields->>'c2')::int c2, tags->>'c3' c3, fields->>'c6' c6, fields->>'c7' c7, fields->>'c8' c8 FROM ft1 ORDER BY fields->>'c6' ASC NULLS FIRST, (fields->>'C 1')::int OFFSET 15 LIMIT 10;

-- ===================================================================
-- test check constraints
-- ===================================================================

-- Consistent check constraints provide consistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2positive CHECK ((fields->>'c2')::int >= 0);
--Testcase 418:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int < 0;
-- InfluxDB return null value because it does not have any record.
--Testcase 419:
SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int < 0;
SET constraint_exclusion = 'on';
--Testcase 420:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int < 0;
--Testcase 421:
SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int < 0;
RESET constraint_exclusion;
-- check constraint is enforced on the remote side, not locally
-- INSERT INTO ft1(c1, c2) VALUES(1111, -2);  -- c2positive
-- UPDATE ft1 SET c2 = -c2 WHERE c1 = 1;  -- c2positive
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2positive;

-- But inconsistent check constraints provide inconsistent results
ALTER FOREIGN TABLE ft1 ADD CONSTRAINT ft1_c2negative CHECK ((fields->>'c2')::int < 0);
--Testcase 422:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int >= 0;
--Testcase 423:
SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int >= 0;
SET constraint_exclusion = 'on';
--Testcase 424:
EXPLAIN (VERBOSE, COSTS OFF) SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int >= 0;
--Testcase 425:
SELECT count(*) FROM ft1 WHERE (fields->>'c2')::int >= 0;
RESET constraint_exclusion;
-- local check constraint is not actually enforced
--Testcase 426:
INSERT INTO ft1_nsc(c1, c2) VALUES(1111, 2);
-- UPDATE ft1 SET c2 = c2 + 1 WHERE c1 = 1;
ALTER FOREIGN TABLE ft1 DROP CONSTRAINT ft1_c2negative;

-- influxdb_fdw does not support this feature
-- ===================================================================
-- test WITH CHECK OPTION constraints
-- ===================================================================

--Testcase 427:
CREATE FUNCTION row_before_insupd_trigfunc() RETURNS trigger AS $$BEGIN NEW.a := NEW.a + 10; RETURN NEW; END$$ LANGUAGE plpgsql;

--Testcase 428:
CREATE FOREIGN TABLE base_tbl (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'base_tbl', schemaless 'true');
--ALTER FOREIGN TABLE base_tbl SET (autovacuum_enabled = 'false');
CREATE FOREIGN TABLE base_tbl_nsc (a int, b int) SERVER influxdb_svr OPTIONS (table 'base_tbl');
--Testcase 429:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON base_tbl_nsc FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
--Testcase 430:
CREATE FOREIGN TABLE foreign_tbl (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'base_tbl', schemaless 'true');
--Testcase 431:
CREATE VIEW rw_view AS SELECT * FROM base_tbl
  WHERE (fields->>'a')::int < (fields->>'b')::int WITH CHECK OPTION;
CREATE VIEW rw_view_nsc AS SELECT * FROM base_tbl_nsc
  WHERE a < b WITH CHECK OPTION;
--Testcase 432:
\d+ rw_view

--Testcase 433:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view_nsc VALUES (0, 5);
--Testcase 434:
INSERT INTO rw_view_nsc VALUES (0, 5); -- should fail
--Testcase 435:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view_nsc VALUES (0, 15);
--Testcase 436:
INSERT INTO rw_view_nsc VALUES (0, 15); -- ok
--Testcase 437:
SELECT * FROM foreign_tbl;

--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 5;
--UPDATE rw_view SET b = b + 5; -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 15;
--UPDATE rw_view SET b = b + 15; -- ok
--SELECT * FROM foreign_tbl;

--Testcase 438:
DELETE FROM foreign_tbl;
DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 439:
DROP TRIGGER row_before_insupd_trigger ON base_tbl_nsc;
--Testcase 440:
DROP FOREIGN TABLE base_tbl CASCADE;
DROP FOREIGN TABLE base_tbl_nsc CASCADE;

-- influxdb_fdw does not support partitions
-- test WCO for partitions

--Testcase 441:
CREATE FOREIGN TABLE child_tbl (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'child_tbl', schemaless 'true');
--ALTER FOREIGN TABLE child_tbl SET (autovacuum_enabled = 'false');
CREATE FOREIGN TABLE child_tbl_nsc (a int, b int) SERVER influxdb_svr OPTIONS (table 'child_tbl');
--Testcase 442:
CREATE TRIGGER row_before_insupd_trigger BEFORE INSERT OR UPDATE ON child_tbl_nsc FOR EACH ROW EXECUTE PROCEDURE row_before_insupd_trigfunc();
--Testcase 443:
CREATE FOREIGN TABLE foreign_tbl (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'child_tbl', schemaless 'true');

--Testcase 444:
CREATE TABLE parent_tbl (a int, b int) PARTITION BY RANGE(a);
ALTER TABLE parent_tbl ATTACH PARTITION child_tbl_nsc FOR VALUES FROM (0) TO (100);

--Testcase 445:
CREATE VIEW rw_view AS SELECT * FROM parent_tbl
  WHERE a < b WITH CHECK OPTION;
--Testcase 446:
\d+ rw_view

--Testcase 447:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 5);
--Testcase 448:
INSERT INTO rw_view VALUES (0, 5); -- should fail
--Testcase 449:
EXPLAIN (VERBOSE, COSTS OFF)
INSERT INTO rw_view VALUES (0, 15);
--Testcase 450:
INSERT INTO rw_view VALUES (0, 15); -- ok
--Testcase 451:
SELECT * FROM foreign_tbl;

--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 5;
--UPDATE rw_view SET b = b + 5; -- should fail
--EXPLAIN (VERBOSE, COSTS OFF)
--UPDATE rw_view SET b = b + 15;
--UPDATE rw_view SET b = b + 15; -- ok
--SELECT * FROM foreign_tbl;

--Testcase 452:
DROP FOREIGN TABLE foreign_tbl CASCADE;
--Testcase 453:
DROP TRIGGER row_before_insupd_trigger ON child_tbl_nsc;
--Testcase 454:
DROP FOREIGN TABLE child_tbl CASCADE;
DROP FOREIGN TABLE child_tbl_nsc CASCADE;
--Testcase 455:
DROP TABLE parent_tbl CASCADE;

--Testcase 456:
DROP FUNCTION row_before_insupd_trigfunc;

-- ===================================================================
-- test serial columns (ie, sequence-based defaults)
-- ===================================================================
--Testcase 457:
create foreign table loc1 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loc1', schemaless 'true');
--alter foreign table loc1 set (autovacuum_enabled = 'false');
create foreign table loc1_nsc (f1 serial, f2 text)
  server influxdb_svr options(table 'loc1');
--Testcase 458:
create foreign table rem1 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loc1', schemaless 'true');
create foreign table rem1_nsc (f1 serial, f2 text)
  server influxdb_svr options(table 'loc1');
--Testcase 459:
select pg_catalog.setval('rem1_nsc_f1_seq', 10, false);
--Testcase 460:
insert into loc1_nsc(f2) values('hi');
--Testcase 461:
insert into rem1_nsc(f2) values('hi remote');
--Testcase 462:
insert into loc1_nsc(f2) values('bye');
--Testcase 463:
insert into rem1_nsc(f2) values('bye remote');
--Testcase 464:
select * from loc1;
--Testcase 465:
select * from rem1;

-- ===================================================================
-- test generated columns
-- ===================================================================
--Testcase 466:
create foreign table gloc1 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'gloc1', schemaless 'true');
--alter foreign table gloc1 set (autovacuum_enabled = 'false');
create foreign table gloc1_nsc (a int, b int generated always as (a * 2) stored)
  server influxdb_svr options(table 'gloc1');
--Testcase 467:
create foreign table grem1 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'gloc1', schemaless 'true');
create foreign table grem1_nsc (
  a int,
  b int generated always as (a * 2) stored)
  server influxdb_svr options(table 'gloc1');
--Testcase 468:
insert into grem1_nsc (a) values (1), (22);
--update grem1 set a = 22 where a = 2;
--Testcase 469:
select * from gloc1;
--Testcase 470:
select * from grem1;

-- Clean up:
delete from grem1_nsc;

-- ===================================================================
-- test local triggers
-- ===================================================================

-- Trigger functions "borrowed" from triggers regress test.
--Testcase 471:
CREATE FUNCTION trigger_func() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
	RAISE NOTICE 'trigger_func(%) called: action = %, when = %, level = %',
		TG_ARGV[0], TG_OP, TG_WHEN, TG_LEVEL;
	RETURN NULL;
END;$$;

--Testcase 472:
CREATE TRIGGER trig_stmt_before BEFORE DELETE OR INSERT OR UPDATE ON rem1_nsc
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--Testcase 473:
CREATE TRIGGER trig_stmt_after AFTER DELETE OR INSERT OR UPDATE ON rem1_nsc
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();

--Testcase 474:
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
--Testcase 475:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 476:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 477:
delete from rem1_nsc;
--Testcase 478:
insert into rem1_nsc values(1,'insert');
--update rem1 set f2 = 'update' where f1 = 1;
--update rem1 set f2 = f2 || f2;


-- cleanup
--Testcase 479:
DROP TRIGGER trig_row_before ON rem1_nsc;
--Testcase 480:
DROP TRIGGER trig_row_after ON rem1_nsc;
--Testcase 481:
DROP TRIGGER trig_stmt_before ON rem1_nsc;
--Testcase 482:
DROP TRIGGER trig_stmt_after ON rem1_nsc;

--Testcase 483:
DELETE from rem1_nsc;

-- Test multiple AFTER ROW triggers on a foreign table
--Testcase 484:
CREATE TRIGGER trig_row_after1
AFTER INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 485:
CREATE TRIGGER trig_row_after2
AFTER INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 486:
insert into rem1_nsc values(1,'insert');
--update rem1 set f2 = 'update' where f1 = 1;
--update rem1 set f2 = f2 || f2;
--Testcase 487:
delete from rem1_nsc;

-- cleanup
--Testcase 488:
DROP TRIGGER trig_row_after1 ON rem1_nsc;
--Testcase 489:
DROP TRIGGER trig_row_after2 ON rem1_nsc;

-- Test WHEN conditions

--Testcase 490:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1_nsc
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 491:
CREATE TRIGGER trig_row_after_insupd
AFTER INSERT OR UPDATE ON rem1_nsc
FOR EACH ROW
WHEN (NEW.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Insert or update not matching: nothing happens
--Testcase 492:
INSERT INTO rem1_nsc values(1, 'insert');
--UPDATE rem1 set f2 = 'test';

-- Insert or update matching: triggers are fired
--Testcase 493:
INSERT INTO rem1_nsc values(2, 'update');
--UPDATE rem1 set f2 = 'update update' where f1 = '2';

--Testcase 494:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1_nsc
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 495:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1_nsc
FOR EACH ROW
WHEN (OLD.f2 like '%update%')
EXECUTE PROCEDURE trigger_data(23,'skidoo');

-- Trigger is fired for f1=2, not for f1=1
--Testcase 496:
DELETE FROM rem1_nsc;

-- cleanup
--Testcase 497:
DROP TRIGGER trig_row_before_insupd ON rem1_nsc;
--Testcase 498:
DROP TRIGGER trig_row_after_insupd ON rem1_nsc;
--Testcase 499:
DROP TRIGGER trig_row_before_delete ON rem1_nsc;
--Testcase 500:
DROP TRIGGER trig_row_after_delete ON rem1_nsc;


-- Test various RETURN statements in BEFORE triggers.

--Testcase 501:
CREATE FUNCTION trig_row_before_insupdate() RETURNS TRIGGER AS $$
  BEGIN
    NEW.f2 := NEW.f2 || ' triggered !';
    RETURN NEW;
  END
$$ language plpgsql;

--Testcase 502:
CREATE TRIGGER trig_row_before_insupd
BEFORE INSERT OR UPDATE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

-- The new values should have 'triggered' appended
--Testcase 503:
INSERT INTO rem1_nsc values(1, 'insert');
--Testcase 504:
SELECT * from loc1;
--Testcase 505:
INSERT INTO rem1_nsc values(2, 'insert');
--Testcase 506:
SELECT fields->>'f2' f2 FROM rem1 WHERE (fields->>'f1')::int = 2;
--Testcase 507:
SELECT * from loc1;
--UPDATE rem1 set f2 = '';
--SELECT * from loc1;
--UPDATE rem1 set f2 = 'skidoo' RETURNING f2;
--SELECT * from loc1;

--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f1 = 10;          -- all columns should be transmitted
--UPDATE rem1 set f1 = 10;
--SELECT * from loc1;

--Testcase 508:
DELETE FROM rem1_nsc;

-- Add a second trigger, to check that the changes are propagated correctly
-- from trigger to trigger
--Testcase 509:
CREATE TRIGGER trig_row_before_insupd2
BEFORE INSERT OR UPDATE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 510:
INSERT INTO rem1_nsc values(1, 'insert');
--Testcase 511:
SELECT * from loc1;
--Testcase 512:
INSERT INTO rem1_nsc values(2, 'insert');
--Testcase 513:
SELECT fields->>'f2' f2 FROM rem1 WHERE (fields->>'f1')::int = 2;
--Testcase 514:
SELECT * from loc1;
--UPDATE rem1 set f2 = '';
--SELECT * from loc1;
--UPDATE rem1 set f2 = 'skidoo' RETURNING f2;
--SELECT * from loc1;

--Testcase 515:
DROP TRIGGER trig_row_before_insupd ON rem1_nsc;
--Testcase 516:
DROP TRIGGER trig_row_before_insupd2 ON rem1_nsc;

--Testcase 517:
DELETE from rem1_nsc;

--Testcase 518:
INSERT INTO rem1_nsc VALUES (1, 'test');

-- Test with a trigger returning NULL
--Testcase 519:
CREATE FUNCTION trig_null() RETURNS TRIGGER AS $$
  BEGIN
    RETURN NULL;
  END
$$ language plpgsql;

--Testcase 520:
CREATE TRIGGER trig_null
BEFORE INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trig_null();

-- Nothing should have changed.
--Testcase 521:
INSERT INTO rem1_nsc VALUES (2, 'test2');

--Testcase 522:
SELECT * from loc1;

--UPDATE rem1 SET f2 = 'test2';

--SELECT * from loc1;

--Testcase 523:
DELETE from rem1_nsc;

--Testcase 524:
SELECT * from loc1;

--Testcase 525:
DROP TRIGGER trig_null ON rem1_nsc;
--Testcase 526:
DELETE from rem1_nsc;

-- Test a combination of local and remote triggers
--Testcase 527:
CREATE TRIGGER trig_row_before
BEFORE INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 528:
CREATE TRIGGER trig_row_after
AFTER INSERT OR UPDATE OR DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');

--Testcase 529:
CREATE TRIGGER trig_local_before BEFORE INSERT OR UPDATE ON loc1_nsc
FOR EACH ROW EXECUTE PROCEDURE trig_row_before_insupdate();

--Testcase 530:
INSERT INTO rem1_nsc(f2) VALUES ('test');
--UPDATE rem1 SET f2 = 'testo';

-- Test returning a system attribute
--Testcase 531:
INSERT INTO rem1_nsc(f2) VALUES ('test');
--Testcase 532:
SELECT * FROM rem1 WHERE fields->>'f2' = 'test';

-- cleanup
--Testcase 533:
DROP TRIGGER trig_row_before ON rem1_nsc;
--Testcase 534:
DROP TRIGGER trig_row_after ON rem1_nsc;
--Testcase 535:
DROP TRIGGER trig_local_before ON loc1_nsc;


-- Test direct foreign table modification functionality

-- Test with statement-level triggers
--Testcase 536:
CREATE TRIGGER trig_stmt_before
	BEFORE DELETE OR INSERT OR UPDATE ON rem1_nsc
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 537:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 538:
DROP TRIGGER trig_stmt_before ON rem1_nsc;

--Testcase 539:
CREATE TRIGGER trig_stmt_after
	AFTER DELETE OR INSERT OR UPDATE ON rem1_nsc
	FOR EACH STATEMENT EXECUTE PROCEDURE trigger_func();
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 540:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 541:
DROP TRIGGER trig_stmt_after ON rem1_nsc;

-- Test with row-level ON INSERT triggers
--Testcase 542:
CREATE TRIGGER trig_row_before_insert
BEFORE INSERT ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 543:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 544:
DROP TRIGGER trig_row_before_insert ON rem1_nsc;

--Testcase 545:
CREATE TRIGGER trig_row_after_insert
AFTER INSERT ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 546:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 547:
DROP TRIGGER trig_row_after_insert ON rem1_nsc;

-- Test with row-level ON UPDATE triggers
--Testcase 548:
CREATE TRIGGER trig_row_before_update
BEFORE UPDATE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 549:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 550:
DROP TRIGGER trig_row_before_update ON rem1_nsc;

--Testcase 551:
CREATE TRIGGER trig_row_after_update
AFTER UPDATE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can't be pushed down
--Testcase 552:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can be pushed down
--Testcase 553:
DROP TRIGGER trig_row_after_update ON rem1_nsc;

-- Test with row-level ON DELETE triggers
--Testcase 554:
CREATE TRIGGER trig_row_before_delete
BEFORE DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 555:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can't be pushed down
--Testcase 556:
DROP TRIGGER trig_row_before_delete ON rem1_nsc;

--Testcase 557:
CREATE TRIGGER trig_row_after_delete
AFTER DELETE ON rem1_nsc
FOR EACH ROW EXECUTE PROCEDURE trigger_data(23,'skidoo');
--EXPLAIN (verbose, costs off)
--UPDATE rem1 set f2 = '';          -- can be pushed down
--Testcase 558:
EXPLAIN (verbose, costs off)
DELETE FROM rem1_nsc;                 -- can't be pushed down
--Testcase 559:
DROP TRIGGER trig_row_after_delete ON rem1_nsc;

-- ===================================================================
-- test inheritance features
-- ===================================================================

--Testcase 560:
CREATE TABLE a (aa TEXT);
--CREATE TABLE loct (aa TEXT, bb TEXT);
ALTER TABLE a SET (autovacuum_enabled = 'false');
--ALTER TABLE loct SET (autovacuum_enabled = 'false');
-- Because influxdb_fdw does not support UPDATE, to test locally 
-- we create local table.
--Testcase 561:
CREATE TABLE b (bb TEXT) INHERITS (a);

--Testcase 562:
INSERT INTO a(aa) VALUES('aaa');
--Testcase 563:
INSERT INTO a(aa) VALUES('aaaa');
--Testcase 564:
INSERT INTO a(aa) VALUES('aaaaa');

--Testcase 565:
INSERT INTO b(aa) VALUES('bbb');
--Testcase 566:
INSERT INTO b(aa) VALUES('bbbb');
--Testcase 567:
INSERT INTO b(aa) VALUES('bbbbb');

--Testcase 568:
SELECT tableoid::regclass, * FROM a;
--Testcase 569:
SELECT tableoid::regclass, * FROM b;
--Testcase 570:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 571:
UPDATE a SET aa = 'zzzzzz' WHERE aa LIKE 'aaaa%';

--Testcase 572:
SELECT tableoid::regclass, * FROM a;
--Testcase 573:
SELECT tableoid::regclass, * FROM b;
--Testcase 574:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 575:
UPDATE b SET aa = 'new';

--Testcase 576:
SELECT tableoid::regclass, * FROM a;
--Testcase 577:
SELECT tableoid::regclass, * FROM b;
--Testcase 578:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 579:
UPDATE a SET aa = 'newtoo';

--Testcase 580:
SELECT tableoid::regclass, * FROM a;
--Testcase 581:
SELECT tableoid::regclass, * FROM b;
--Testcase 582:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 583:
DELETE FROM a;

--Testcase 584:
SELECT tableoid::regclass, * FROM a;
--Testcase 585:
SELECT tableoid::regclass, * FROM b;
--Testcase 586:
SELECT tableoid::regclass, * FROM ONLY a;

--Testcase 587:
DROP TABLE a CASCADE;
--DROP TABLE loct;

-- Check SELECT FOR UPDATE/SHARE with an inherited source table
--Testcase 588:
create foreign table loct1 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loct1', schemaless 'true');
create foreign table loct1_nsc (f1 int, f2 int, f3 int) server influxdb_svr options(table 'loct1');
--Testcase 589:
create foreign table loct2 (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'loct2', schemaless 'true');
create foreign table loct2_nsc (f1 int, f2 int, f3 int) server influxdb_svr options(table 'loct2');
--alter table loct1 set (autovacuum_enabled = 'false');
--alter table loct2 set (autovacuum_enabled = 'false');

--Testcase 590:
create foreign table foo (fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (table 'foo', schemaless 'true');
create foreign table foo_nsc (f1 int, f2 int)
  server influxdb_svr options (table 'foo');
--Testcase 591:
create foreign table foo2 (fields jsonb OPTIONS(fields 'true')) inherits (foo)
  server influxdb_svr options (table 'loct1', schemaless 'true');
create foreign table foo2_nsc (f3 int) inherits (foo_nsc)
  server influxdb_svr options (table 'loct1');
--Testcase 592:
create foreign table bar (fields jsonb OPTIONS(fields 'true'))
  server influxdb_svr options (table 'bar', schemaless 'true');
create foreign table bar_nsc (f1 int, f2 int)
  server influxdb_svr options (table 'bar');
--Testcase 593:
create foreign table bar2 (fields jsonb OPTIONS(fields 'true')) inherits (bar)
  server influxdb_svr options (table 'loct2', schemaless 'true');
create foreign table bar2_nsc (f3 int) inherits (bar_nsc)
  server influxdb_svr options (table 'loct2');

--alter table foo set (autovacuum_enabled = 'false');
--alter table bar set (autovacuum_enabled = 'false');

--Testcase 594:
insert into foo_nsc values(1,1);
--Testcase 595:
insert into foo_nsc values(3,3);
--Testcase 596:
insert into foo2_nsc values(2,2,2);
--Testcase 597:
insert into foo2_nsc values(4,4,4);
--Testcase 598:
insert into bar_nsc values(1,11);
--Testcase 599:
insert into bar_nsc values(2,22);
--Testcase 600:
insert into bar_nsc values(6,66);
--Testcase 601:
insert into bar2_nsc values(3,33,33);
--Testcase 602:
insert into bar2_nsc values(4,44,44);
--Testcase 603:
insert into bar2_nsc values(7,77,77);

--Testcase 604:
explain (verbose, costs off)
select * from bar where fields->>'f1' in (select fields->>'f1' from foo);
--Testcase 605:
select * from bar where fields->>'f1' in (select fields->>'f1' from foo);

--Testcase 606:
explain (verbose, costs off)
select * from bar where fields->>'f1' in (select fields->>'f1' from foo);
--Testcase 607:
select * from bar where fields->>'f1' in (select fields->>'f1' from foo);

/*
-- influxdb_fdw does not support UPDATE
-- Check UPDATE with inherited target and an inherited source table
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

insert into itrtest values (1, 'foo');
insert into itrtest values (1, 'bar') returning *;
insert into itrtest values (2, 'baz');
insert into itrtest values (2, 'qux') returning *;
insert into itrtest values (1, 'test1'), (2, 'test2') returning *;

select tableoid::regclass, * FROM itrtest;
select tableoid::regclass, * FROM remp1;
select tableoid::regclass, * FROM remp2;

delete from itrtest;

create unique index loct1_idx on loct1 (a);

-- DO NOTHING without an inference specification is supported
insert into itrtest values (1, 'foo') on conflict do nothing returning *;
insert into itrtest values (1, 'foo') on conflict do nothing returning *;

-- But other cases are not supported
insert into itrtest values (1, 'bar') on conflict (a) do nothing;
insert into itrtest values (1, 'bar') on conflict (a) do update set b = excluded.b;

select tableoid::regclass, * FROM itrtest;

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
insert into itrtest values (1, 'foo') returning *;
insert into itrtest values (2, 'qux') returning *;
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

insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

select tableoid::regclass, * FROM utrtest;
select tableoid::regclass, * FROM remp;
select tableoid::regclass, * FROM locp;

-- It's not allowed to move a row from a partition that is foreign to another
update utrtest set a = 2 where b = 'foo' returning *;

-- But the reverse is allowed
update utrtest set a = 1 where b = 'qux' returning *;

select tableoid::regclass, * FROM utrtest;
select tableoid::regclass, * FROM remp;
select tableoid::regclass, * FROM locp;

-- The executor should not let unexercised FDWs shut down
update utrtest set a = 1 where b = 'foo';

-- Test that remote triggers work with update tuple routing
create trigger loct_br_insert_trigger before insert on loct
	for each row execute procedure br_insert_trigfunc();

delete from utrtest;
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition is a subplan target rel
explain (verbose, costs off)
update utrtest set a = 1 where a = 1 or a = 2 returning *;
-- The new values are concatenated with ' triggered !'
update utrtest set a = 1 where a = 1 or a = 2 returning *;

delete from utrtest;
insert into utrtest values (2, 'qux');

-- Check case where the foreign partition isn't a subplan target rel
explain (verbose, costs off)
update utrtest set a = 1 where a = 2 returning *;
-- The new values are concatenated with ' triggered !'
update utrtest set a = 1 where a = 2 returning *;

drop trigger loct_br_insert_trigger on loct;

-- We can move rows to a foreign partition that has been updated already,
-- but can't move rows to a foreign partition that hasn't been updated yet

delete from utrtest;
insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

-- Test the former case:
-- with a direct modification plan
explain (verbose, costs off)
update utrtest set a = 1 returning *;
update utrtest set a = 1 returning *;

delete from utrtest;
insert into utrtest values (1, 'foo');
insert into utrtest values (2, 'qux');

-- with a non-direct modification plan
explain (verbose, costs off)
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;
update utrtest set a = 1 from (values (1), (2)) s(x) where a = s.x returning *;

-- Change the definition of utrtest so that the foreign partition get updated
-- after the local partition
delete from utrtest;
alter table utrtest detach partition remp;
drop foreign table remp;
alter table loct drop constraint loct_a_check;
alter table loct add check (a in (3));
create foreign table remp (a int check (a in (3)), b text) server loopback options (table_name 'loct');
alter table utrtest attach partition remp for values in (3);
insert into utrtest values (2, 'qux');
insert into utrtest values (3, 'xyzzy');

-- Test the latter case:
-- with a direct modification plan
explain (verbose, costs off)
update utrtest set a = 3 returning *;
update utrtest set a = 3 returning *; -- ERROR

-- with a non-direct modification plan
explain (verbose, costs off)
update utrtest set a = 3 from (values (2), (3)) s(x) where a = s.x returning *;
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

select tableoid::regclass, * FROM ctrtest;
select tableoid::regclass, * FROM remp1;
select tableoid::regclass, * FROM remp2;

-- Copying into foreign partitions directly should work as well
copy remp1 from stdin;
1	bar
\.

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
select * from rem2;

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
select * from rem2;

alter foreign table rem2 drop constraint rem2_f1positive;
alter table loc2 drop constraint loc2_f1positive;

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
select * from rem2;

drop trigger trig_row_before on rem2;
drop trigger trig_row_after on rem2;
drop trigger trig_stmt_before on rem2;
drop trigger trig_stmt_after on rem2;

delete from rem2;

create trigger trig_row_before_insert before insert on rem2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_row_before_insert on rem2;

delete from rem2;

create trigger trig_null before insert on rem2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_null on rem2;

delete from rem2;

-- Test remote triggers
create trigger trig_row_before_insert before insert on loc2
	for each row execute procedure trig_row_before_insupdate();

-- The new values are concatenated with ' triggered !'
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_row_before_insert on loc2;

delete from rem2;

create trigger trig_null before insert on loc2
	for each row execute procedure trig_null();

-- Nothing happens
copy rem2 from stdin;
1	foo
2	bar
\.
select * from rem2;

drop trigger trig_null on loc2;

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
select * from rem2;

drop trigger rem2_trig_row_before on rem2;
drop trigger rem2_trig_row_after on rem2;
drop trigger loc2_trig_row_before_insert on loc2;

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
select * from rem3;
drop foreign table rem3;
drop table loc3;
*/
-- ===================================================================
-- test IMPORT FOREIGN SCHEMA
-- ===================================================================

--Testcase 608:
CREATE SCHEMA import_influx1;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx1 OPTIONS (schemaless 'true');
--Testcase 609:
\det+ import_influx1.*
--Testcase 610:
\d import_influx1.*

-- Options
--Testcase 611:
CREATE SCHEMA import_influx2;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx2
  OPTIONS (import_default 'true', schemaless 'true');
--Testcase 612:
\det+ import_influx2.*
--Testcase 613:
\d import_influx2.*

--Testcase 614:
CREATE SCHEMA import_influx3;
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx3
  OPTIONS (import_collate 'false', import_not_null 'false', schemaless 'true');
--Testcase 615:
\det+ import_influx3.*
--Testcase 616:
\d import_influx3.*

-- Check LIMIT TO and EXCEPT
--Testcase 617:
CREATE SCHEMA import_influx4;
IMPORT FOREIGN SCHEMA public LIMIT TO ("T1", loct, nonesuch)
  FROM SERVER influxdb_svr INTO import_influx4 OPTIONS (schemaless 'true');
--Testcase 618:
\det+ import_influx4.*
IMPORT FOREIGN SCHEMA public EXCEPT ("T1", loct, nonesuch)
  FROM SERVER influxdb_svr INTO import_influx4 OPTIONS (schemaless 'true');
--Testcase 619:
\det+ import_influx4.*

-- Assorted error cases
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO import_influx4 OPTIONS (schemaless 'true');
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER influxdb_svr INTO import_influx4 OPTIONS (schemaless 'true');
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER influxdb_svr INTO notthere OPTIONS (schemaless 'true');
IMPORT FOREIGN SCHEMA nonesuch FROM SERVER nowhere INTO notthere OPTIONS (schemaless 'true');

/*
-- Skip these test, influxdb_fdw does not support fetch_size option, partition table
-- Check case of a type present only on the remote server.
-- We can fake this by dropping the type locally in our transaction.
CREATE TYPE "Colors" AS ENUM ('red', 'green', 'blue');
CREATE TABLE import_source.t5 (c1 int, c2 text collate "C", "Col" "Colors");

CREATE SCHEMA import_dest5;
BEGIN;
DROP TYPE "Colors" CASCADE;
IMPORT FOREIGN SCHEMA import_source LIMIT TO (t5)
  FROM SERVER loopback INTO import_dest5;  -- ERROR

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

-- ===================================================================
-- test partitionwise joins
-- ===================================================================
SET enable_partitionwise_join=on;

CREATE TABLE fprt1 (a int, b int, c varchar) PARTITION BY RANGE(a);
CREATE TABLE fprt1_p1 (LIKE fprt1);
CREATE TABLE fprt1_p2 (LIKE fprt1);
ALTER TABLE fprt1_p1 SET (autovacuum_enabled = 'false');
ALTER TABLE fprt1_p2 SET (autovacuum_enabled = 'false');
INSERT INTO fprt1_p1 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(0, 249, 2) i;
INSERT INTO fprt1_p2 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(250, 499, 2) i;
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (0) TO (250)
	SERVER loopback OPTIONS (table_name 'fprt1_p1', use_remote_estimate 'true');
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (250) TO (500)
	SERVER loopback OPTIONS (TABLE_NAME 'fprt1_p2');
ANALYZE fprt1;
ANALYZE fprt1_p1;
ANALYZE fprt1_p2;

CREATE TABLE fprt2 (a int, b int, c varchar) PARTITION BY RANGE(b);
CREATE TABLE fprt2_p1 (LIKE fprt2);
CREATE TABLE fprt2_p2 (LIKE fprt2);
ALTER TABLE fprt2_p1 SET (autovacuum_enabled = 'false');
ALTER TABLE fprt2_p2 SET (autovacuum_enabled = 'false');
INSERT INTO fprt2_p1 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(0, 249, 3) i;
INSERT INTO fprt2_p2 SELECT i, i, to_char(i/50, 'FM0000') FROM generate_series(250, 499, 3) i;
CREATE FOREIGN TABLE ftprt2_p1 (b int, c varchar, a int)
	SERVER loopback OPTIONS (table_name 'fprt2_p1', use_remote_estimate 'true');
ALTER TABLE fprt2 ATTACH PARTITION ftprt2_p1 FOR VALUES FROM (0) TO (250);
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (250) TO (500)
	SERVER loopback OPTIONS (table_name 'fprt2_p2', use_remote_estimate 'true');
ANALYZE fprt2;
ANALYZE fprt2_p1;
ANALYZE fprt2_p2;

-- inner join three tables
EXPLAIN (COSTS OFF)
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;
SELECT t1.a,t2.b,t3.c FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) INNER JOIN fprt1 t3 ON (t2.b = t3.a) WHERE t1.a % 25 =0 ORDER BY 1,2,3;

-- left outer join + nullable clause
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;
SELECT t1.a,t2.b,t2.c FROM fprt1 t1 LEFT JOIN (SELECT * FROM fprt2 WHERE a < 10) t2 ON (t1.a = t2.b and t1.b = t2.a) WHERE t1.a < 10 ORDER BY 1,2,3;

-- with whole-row reference; partitionwise join does not apply
EXPLAIN (COSTS OFF)
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;
SELECT t1.wr, t2.wr FROM (SELECT t1 wr, a FROM fprt1 t1 WHERE t1.a % 25 = 0) t1 FULL JOIN (SELECT t2 wr, b FROM fprt2 t2 WHERE t2.b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY 1,2;

-- join with lateral reference
EXPLAIN (COSTS OFF)
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;
SELECT t1.a,t1.b FROM fprt1 t1, LATERAL (SELECT t2.a, t2.b FROM fprt2 t2 WHERE t1.a = t2.b AND t1.b = t2.a) q WHERE t1.a%25 = 0 ORDER BY 1,2;

-- with PHVs, partitionwise join selected but no join pushdown
EXPLAIN (COSTS OFF)
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;
SELECT t1.a, t1.phv, t2.b, t2.phv FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE a % 25 = 0) t1 FULL JOIN (SELECT 't2_phv' phv, * FROM fprt2 WHERE b % 25 = 0) t2 ON (t1.a = t2.b) ORDER BY t1.a, t2.b;

-- test FOR UPDATE; partitionwise join does not apply
EXPLAIN (COSTS OFF)
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;
SELECT t1.a, t2.b FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.a = t2.b) WHERE t1.a % 25 = 0 ORDER BY 1,2 FOR UPDATE OF t1;

RESET enable_partitionwise_join;


-- ===================================================================
-- test partitionwise aggregates
-- ===================================================================

CREATE TABLE pagg_tab (a int, b int, c text) PARTITION BY RANGE(a);

CREATE TABLE pagg_tab_p1 (LIKE pagg_tab);
CREATE TABLE pagg_tab_p2 (LIKE pagg_tab);
CREATE TABLE pagg_tab_p3 (LIKE pagg_tab);

INSERT INTO pagg_tab_p1 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 10;
INSERT INTO pagg_tab_p2 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 20 and (i % 30) >= 10;
INSERT INTO pagg_tab_p3 SELECT i % 30, i % 50, to_char(i/30, 'FM0000') FROM generate_series(1, 3000) i WHERE (i % 30) < 30 and (i % 30) >= 20;

-- Create foreign partitions
CREATE FOREIGN TABLE fpagg_tab_p1 PARTITION OF pagg_tab FOR VALUES FROM (0) TO (10) SERVER loopback OPTIONS (table_name 'pagg_tab_p1');
CREATE FOREIGN TABLE fpagg_tab_p2 PARTITION OF pagg_tab FOR VALUES FROM (10) TO (20) SERVER loopback OPTIONS (table_name 'pagg_tab_p2');
CREATE FOREIGN TABLE fpagg_tab_p3 PARTITION OF pagg_tab FOR VALUES FROM (20) TO (30) SERVER loopback OPTIONS (table_name 'pagg_tab_p3');

ANALYZE pagg_tab;
ANALYZE fpagg_tab_p1;
ANALYZE fpagg_tab_p2;
ANALYZE fpagg_tab_p3;

-- When GROUP BY clause matches with PARTITION KEY.
-- Plan with partitionwise aggregates is disabled
SET enable_partitionwise_aggregate TO false;
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Plan with partitionwise aggregates is enabled
SET enable_partitionwise_aggregate TO true;
EXPLAIN (COSTS OFF)
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
SELECT a, sum(b), min(b), count(*) FROM pagg_tab GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- Check with whole-row reference
-- Should have all the columns in the target list for the given relation
EXPLAIN (VERBOSE, COSTS OFF)
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;
SELECT a, count(t1) FROM pagg_tab t1 GROUP BY a HAVING avg(b) < 22 ORDER BY 1;

-- When GROUP BY clause does not match with PARTITION KEY.
EXPLAIN (COSTS OFF)
SELECT b, avg(a), max(a), count(*) FROM pagg_tab GROUP BY b HAVING sum(a) < 700 ORDER BY 1;
*/

/*
-- Skip test, influxdb_fdw does not support nosuperuser
-- ===================================================================
-- access rights and superuser
-- ===================================================================

-- Non-superuser cannot create a FDW without a password in the connstr
CREATE ROLE regress_nosuper NOSUPERUSER;

GRANT USAGE ON FOREIGN DATA WRAPPER influxdb_fdw TO regress_nosuper;

SET ROLE regress_nosuper;

SHOW is_superuser;

-- This will be OK, we can create the FDW
DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER loopback_nopw FOREIGN DATA WRAPPER influxdb_fdw
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

-- influxdb_fdw does not support transactions
-- Two-phase transactions are not supported.
--BEGIN;
--Testcase 620:
SELECT count(*) FROM ft1;
-- error here
--PREPARE TRANSACTION 'fdw_tpc';
--ROLLBACK;

-- Clean-up
DELETE FROM ft1_nsc;
DELETE FROM ft2_nsc;
DELETE FROM ft4_nsc;
DELETE FROM ft5_nsc;
DELETE FROM foo_nsc;
DELETE FROM bar_nsc;
DELETE FROM loct1_nsc;
DELETE FROM loct2_nsc;
DELETE FROM rem1_nsc;
DROP FOREIGN TABLE foo_nsc cascade;
DROP FOREIGN TABLE bar_nsc cascade;
DROP FOREIGN TABLE loct1_nsc;
DROP FOREIGN TABLE loct2_nsc;
DROP FOREIGN TABLE "S 1".s1t0;
DROP FOREIGN TABLE "S 1".s1t1;
DROP FOREIGN TABLE "S 1".s1t2;
DROP FOREIGN TABLE "S 1".s1t3;
DROP FOREIGN TABLE "S 1".s1t4;
DROP FOREIGN TABLE ft1_nsc;
DROP FOREIGN TABLE ft2_nsc;
DROP FOREIGN TABLE ft4_nsc;
DROP FOREIGN TABLE ft5_nsc;

DROP TYPE IF EXISTS user_enum;
DROP SCHEMA IF EXISTS "S 1" CASCADE;
DROP FUNCTION IF EXISTS trigger_func();
DROP FUNCTION IF EXISTS trig_row_before_insupdate();
DROP FUNCTION IF EXISTS trig_null();
DROP SCHEMA IF EXISTS import_influx1 CASCADE;
DROP SCHEMA IF EXISTS import_influx2 CASCADE;
DROP SCHEMA IF EXISTS import_influx3 CASCADE;
DROP SCHEMA IF EXISTS import_influx4 CASCADE;

--Testcase 621:
DROP USER MAPPING FOR public SERVER testserver1;
--Testcase 622:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 623:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr2;

--Testcase 624:
DROP SERVER testserver1 CASCADE;
--Testcase 625:
DROP SERVER influxdb_svr CASCADE;
--Testcase 626:
DROP SERVER influxdb_svr2 CASCADE;
--Testcase 627:
DROP EXTENSION influxdb_fdw;
