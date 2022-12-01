-- Regression tests for prepareable statements. We query the content
-- of the pg_prepared_statements view as prepared statements are
-- created and removed.
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 27:
CREATE EXTENSION influxdb_fdw;

--Testcase 28:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', :SERVER);
--Testcase 29:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (:AUTHENTICATION);

--Testcase 30:
CREATE FOREIGN TABLE tenk1 (
	fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (table 'tenk', schemaless 'true');

-- Does not support this command
-- ALTER TABLE tenk1 SET WITH OIDS;

--Testcase 31:
CREATE FOREIGN TABLE road (
	fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (schemaless 'true');

--Testcase 32:
CREATE FOREIGN TABLE road_tmp (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');

--Testcase 1:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

--Testcase 2:
PREPARE q1 AS SELECT (fields->>'a')::int AS a FROM road_tmp;
--Testcase 3:
EXECUTE q1;

--Testcase 4:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- should fail
--Testcase 5:
PREPARE q1 AS SELECT (fields->>'b')::int b FROM road_tmp;

-- should succeed
DEALLOCATE q1;
--Testcase 6:
PREPARE q1 AS SELECT (fields->>'b')::int b FROM road_tmp;
--Testcase 7:
EXECUTE q1;

--Testcase 8:
PREPARE q2 AS SELECT (fields->>'b')::int AS b FROM road_tmp;
--Testcase 9:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- sql92 syntax
DEALLOCATE PREPARE q1;

--Testcase 10:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

DEALLOCATE PREPARE q2;
-- the view should return the empty set again
--Testcase 11:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- parameterized queries
--Testcase 12:
PREPARE q2(text) AS
	SELECT datname, datistemplate, datallowconn
	FROM pg_database WHERE datname = $1;

--Testcase 13:
EXECUTE q2('postgres');

--Testcase 14:
PREPARE q3(text, int, float, boolean, smallint) AS
	SELECT * FROM tenk1 WHERE fields->>'string4' = $1 AND ((fields->>'four')::int = $2 OR
	(fields->>'ten')::int = $3::bigint OR true = $4 OR (fields->>'odd')::int = $5::int)
	ORDER BY (fields->>'unique1')::int;

--Testcase 15:
EXECUTE q3('AAAAxx', 5::smallint, 10.5::float, false, 4::bigint);

-- too few params
--Testcase 16:
EXECUTE q3('bool');

-- too many params
--Testcase 17:
EXECUTE q3('bytea', 5::smallint, 10.5::float, false, 4::bigint, true);

-- wrong param types
--Testcase 18:
EXECUTE q3(5::smallint, 10.5::float, false, 4::bigint, 'bytea');

-- invalid type
--Testcase 19:
PREPARE q4(nonexistenttype) AS SELECT $1;

-- create table as execute
--Testcase 20:
PREPARE q5(int, text) AS
	SELECT * FROM tenk1 WHERE (fields->>'unique1')::int = $1 OR fields->>'stringu1' = $2
	ORDER BY (fields->>'unique1')::int;
--Testcase 33:
CREATE TEMPORARY TABLE q5_prep_results AS EXECUTE q5(200, 'DTAAAA');
--Testcase 21:
SELECT * FROM q5_prep_results;
--Testcase 34:
CREATE TEMPORARY TABLE q5_prep_nodata AS EXECUTE q5(200, 'DTAAAA')
    WITH NO DATA;
--Testcase 22:
SELECT * FROM q5_prep_nodata;

-- unknown or unspecified parameter types: should succeed
--Testcase 23:
PREPARE q6 AS
    SELECT * FROM tenk1 WHERE (fields->>'unique1')::int = $1 AND fields->>'stringu1' = $2;
--Testcase 24:
PREPARE q7(unknown) AS
    SELECT * FROM road WHERE fields->>'thepath' = $1;

--Testcase 25:
SELECT name, statement, parameter_types FROM pg_prepared_statements
    ORDER BY name;

-- test DEALLOCATE ALL;
DEALLOCATE ALL;
--Testcase 26:
SELECT name, statement, parameter_types FROM pg_prepared_statements
    ORDER BY name;

--Testcase 35:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 36:
DROP SERVER influxdb_svr CASCADE;
--Testcase 37:
DROP EXTENSION influxdb_fdw;
