-- Regression tests for prepareable statements. We query the content
-- of the pg_prepared_statements view as prepared statements are
-- created and removed.
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 1:
CREATE EXTENSION influxdb_fdw;

--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', :SERVER);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (:AUTHENTICATION);

--Testcase 4:
CREATE FOREIGN TABLE tenk1 (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	name,
	stringu2	name,
	string4		name
) SERVER influxdb_svr OPTIONS (table 'tenk');

-- Does not support this command
-- ALTER TABLE tenk1 SET WITH OIDS;

--Testcase 5:
CREATE FOREIGN TABLE road (
	name		text,
	thepath 	path
) SERVER influxdb_svr;

--Testcase 6:
CREATE FOREIGN TABLE road_tmp (a int, b int) SERVER influxdb_svr;

--Testcase 7:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

--Testcase 8:
PREPARE q1 AS SELECT a AS a FROM road_tmp;
--Testcase 9:
EXECUTE q1;

--Testcase 10:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- should fail
--Testcase 11:
PREPARE q1 AS SELECT b FROM road_tmp;

-- should succeed
DEALLOCATE q1;
--Testcase 12:
PREPARE q1 AS SELECT b FROM road_tmp;
--Testcase 13:
EXECUTE q1;

--Testcase 14:
PREPARE q2 AS SELECT b AS b FROM road_tmp;
--Testcase 15:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- sql92 syntax
DEALLOCATE PREPARE q1;

--Testcase 16:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

DEALLOCATE PREPARE q2;
-- the view should return the empty set again
--Testcase 17:
SELECT name, statement, parameter_types FROM pg_prepared_statements;

-- parameterized queries
--Testcase 18:
PREPARE q2(text) AS
	SELECT datname, datistemplate, datallowconn
	FROM pg_database WHERE datname = $1;

--Testcase 19:
EXECUTE q2('postgres');

--Testcase 20:
PREPARE q3(text, int, float, boolean, smallint) AS
	SELECT * FROM tenk1 WHERE string4 = $1 AND (four = $2 OR
	ten = $3::bigint OR true = $4 OR odd = $5::int)
	ORDER BY unique1;

--Testcase 21:
EXECUTE q3('AAAAxx', 5::smallint, 10.5::float, false, 4::bigint);

-- too few params
--Testcase 22:
EXECUTE q3('bool');

-- too many params
--Testcase 23:
EXECUTE q3('bytea', 5::smallint, 10.5::float, false, 4::bigint, true);

-- wrong param types
--Testcase 24:
EXECUTE q3(5::smallint, 10.5::float, false, 4::bigint, 'bytea');

-- invalid type
--Testcase 25:
PREPARE q4(nonexistenttype) AS SELECT $1;

-- create table as execute
--Testcase 26:
PREPARE q5(int, text) AS
	SELECT * FROM tenk1 WHERE unique1 = $1 OR stringu1 = $2
	ORDER BY unique1;
--Testcase 27:
CREATE TEMPORARY TABLE q5_prep_results AS EXECUTE q5(200, 'DTAAAA');
--Testcase 28:
SELECT * FROM q5_prep_results;
--Testcase 29:
CREATE TEMPORARY TABLE q5_prep_nodata AS EXECUTE q5(200, 'DTAAAA')
    WITH NO DATA;
--Testcase 30:
SELECT * FROM q5_prep_nodata;

-- unknown or unspecified parameter types: should succeed
--Testcase 31:
PREPARE q6 AS
    SELECT * FROM tenk1 WHERE unique1 = $1 AND stringu1 = $2;
--Testcase 32:
PREPARE q7(unknown) AS
    SELECT * FROM road WHERE thepath = $1;

--Testcase 33:
SELECT name, statement, parameter_types FROM pg_prepared_statements
    ORDER BY name;

-- test DEALLOCATE ALL;
DEALLOCATE ALL;
--Testcase 34:
SELECT name, statement, parameter_types FROM pg_prepared_statements
    ORDER BY name;

--Testcase 35:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 36:
DROP SERVER influxdb_svr CASCADE;
--Testcase 37:
DROP EXTENSION influxdb_fdw CASCADE;
