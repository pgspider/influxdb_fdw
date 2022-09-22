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

--
-- LIMIT
-- Check the LIMIT/OFFSET feature of SELECT
--

--Testcase 4:
CREATE FOREIGN TABLE onek (
	fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (schemaless 'true');

--Testcase 5:
CREATE FOREIGN TABLE int8_tbl(fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');

--Testcase 6:
CREATE FOREIGN TABLE tenk1 (
	fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (table 'tenk', schemaless 'true');

--Testcase 7:
SELECT ''::text AS two, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 > 50
		ORDER BY (fields->>'unique1')::int4 LIMIT 2;
--Testcase 8:
SELECT ''::text AS five, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 > 60
		ORDER BY (fields->>'unique1')::int4 LIMIT 5;
--Testcase 9:
SELECT ''::text AS two, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 > 60 AND (fields->>'unique1')::int4 < 63
		ORDER BY (fields->>'unique1')::int4 LIMIT 5;
--Testcase 10:
SELECT ''::text AS three, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 > 100
		ORDER BY (fields->>'unique1')::int4 LIMIT 3 OFFSET 20;
--Testcase 11:
SELECT ''::text AS zero, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 < 50
		ORDER BY (fields->>'unique1')::int4 DESC LIMIT 8 OFFSET 99;
--Testcase 12:
SELECT ''::text AS eleven, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 < 50
		ORDER BY (fields->>'unique1')::int4 DESC LIMIT 20 OFFSET 39;
--Testcase 13:
SELECT ''::text AS ten, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek
		ORDER BY (fields->>'unique1')::int4 OFFSET 990;
--Testcase 14:
SELECT ''::text AS five, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek
		ORDER BY (fields->>'unique1')::int4 OFFSET 990 LIMIT 5;
--Testcase 15:
SELECT ''::text AS five, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek
		ORDER BY (fields->>'unique1')::int4 LIMIT 5 OFFSET 900;

-- Test null limit and offset.  The planner would discard a simple null
-- constant, so to ensure executor is exercised, do this:
--Testcase 16:
select * from int8_tbl limit (case when random() < 0.5 then null::bigint end);
--Testcase 17:
select * from int8_tbl offset (case when random() < 0.5 then null::bigint end);

-- Test assorted cases involving backwards fetch from a LIMIT plan node
begin;

declare c1 scroll cursor for select * from int8_tbl limit 10;
--Testcase 18:
fetch all in c1;
--Testcase 19:
fetch 1 in c1;
--Testcase 20:
fetch backward 1 in c1;
--Testcase 21:
fetch backward all in c1;
--Testcase 22:
fetch backward 1 in c1;
--Testcase 23:
fetch all in c1;

declare c2 scroll cursor for select * from int8_tbl limit 3;
--Testcase 24:
fetch all in c2;
--Testcase 25:
fetch 1 in c2;
--Testcase 26:
fetch backward 1 in c2;
--Testcase 27:
fetch backward all in c2;
--Testcase 28:
fetch backward 1 in c2;
--Testcase 29:
fetch all in c2;

declare c3 scroll cursor for select * from int8_tbl offset 3;
--Testcase 30:
fetch all in c3;
--Testcase 31:
fetch 1 in c3;
--Testcase 32:
fetch backward 1 in c3;
--Testcase 33:
fetch backward all in c3;
--Testcase 34:
fetch backward 1 in c3;
--Testcase 35:
fetch all in c3;

declare c4 scroll cursor for select * from int8_tbl offset 10;
--Testcase 36:
fetch all in c4;
--Testcase 37:
fetch 1 in c4;
--Testcase 38:
fetch backward 1 in c4;
--Testcase 39:
fetch backward all in c4;
--Testcase 40:
fetch backward 1 in c4;
--Testcase 41:
fetch all in c4;

declare c5 scroll cursor for select * from int8_tbl order by (fields->>'q1')::int8 fetch first 2 rows with ties;
--Testcase 42:
fetch all in c5;
--Testcase 43:
fetch 1 in c5;
--Testcase 44:
fetch backward 1 in c5;
--Testcase 45:
fetch backward 1 in c5;
--Testcase 46:
fetch all in c5;
--Testcase 47:
fetch backward all in c5;
--Testcase 48:
fetch all in c5;
--Testcase 49:
fetch backward all in c5;

rollback;

-- Stress test for variable LIMIT in conjunction with bounded-heap sorting
--Testcase 50:
CREATE FOREIGN TABLE generate_series4(fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');
--Testcase 51:
SELECT
  (SELECT (fields->>'a')::int a
     FROM (VALUES (1)) AS x,
          (SELECT (fields->>'a')::int a FROM generate_series4 AS n
             ORDER BY (fields->>'a')::int LIMIT 1 OFFSET (s.fields->>'a')::int - 1) AS y) AS z
  FROM generate_series4 AS s;

--
-- Test behavior of volatile and set-returning functions in conjunction
-- with ORDER BY and LIMIT.
--

--Testcase 52:
create temp sequence testseq;

--Testcase 53:
explain (verbose, costs off)
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, nextval('testseq')
  from tenk1 order by (fields->>'unique2')::int4 limit 10;

--Testcase 54:
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, nextval('testseq')
  from tenk1 order by (fields->>'unique2')::int4 limit 10;

--Testcase 55:
select currval('testseq');

--Testcase 56:
explain (verbose, costs off)
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, nextval('testseq')
  from tenk1 order by (fields->>'tenthous')::int4 limit 10;

--Testcase 57:
select(fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, nextval('testseq')
  from tenk1 order by (fields->>'tenthous')::int4 limit 10;

--Testcase 58:
select currval('testseq');

--Testcase 59:
explain (verbose, costs off)
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, generate_series(1,10)
  from tenk1 order by (fields->>'unique2')::int4 limit 7;

--Testcase 60:
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, generate_series(1,10)
  from tenk1 order by (fields->>'unique2')::int4 limit 7;

--Testcase 61:
explain (verbose, costs off)
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, generate_series(1,10)
  from tenk1 order by (fields->>'tenthous')::int4 limit 7;

--Testcase 62:
select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, generate_series(1,10)
  from tenk1 order by (fields->>'tenthous')::int4 limit 7;

-- use of random() is to keep planner from folding the expressions together
--Testcase 63:
explain (verbose, costs off)
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2;

--Testcase 64:
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2;

--Testcase 65:
explain (verbose, costs off)
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2
order by s2 desc;

--Testcase 66:
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2
order by s2 desc;

-- test for failure to set all aggregates' aggtranstype
--Testcase 67:
explain (verbose, costs off)
select sum((fields->>'tenthous')::int4) as s1, sum((fields->>'tenthous')::int4) + random()*0 as s2
  from tenk1 group by fields->>'thousand' order by (fields->>'thousand')::int4 limit 3;

--Testcase 68:
select sum((fields->>'tenthous')::int4) as s1, sum((fields->>'tenthous')::int4) + random()*0 as s2
  from tenk1 group by fields->>'thousand' order by (fields->>'thousand')::int4 limit 3;

--
-- FETCH FIRST
-- Check the WITH TIES clause
--

--Testcase 69:
SELECT  (fields->>'thousand')::int4 thousand
		FROM onek WHERE (fields->>'thousand')::int4 < 5
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST 2 ROW WITH TIES;

--Testcase 70:
SELECT  (fields->>'thousand')::int4 thousand
		FROM onek WHERE (fields->>'thousand')::int4 < 5
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST ROWS WITH TIES;

--Testcase 71:
SELECT  (fields->>'thousand')::int4 thousand
		FROM onek WHERE (fields->>'thousand')::int4 < 5
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST 1 ROW WITH TIES;

--Testcase 72:
SELECT  (fields->>'thousand')::int4 thousand
		FROM onek WHERE (fields->>'thousand')::int4 < 5
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST 2 ROW ONLY;

-- SKIP LOCKED and WITH TIES are incompatible
--Testcase 90:
SELECT  (fields->>'thousand')::int4 thousand
		FROM onek WHERE (fields->>'thousand')::int4 < 5
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST 1 ROW WITH TIES FOR UPDATE SKIP LOCKED;

-- should fail
--Testcase 73:
SELECT ''::text AS two, (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'stringu1')::name stringu1
		FROM onek WHERE (fields->>'unique1')::int4 > 50
		FETCH FIRST 2 ROW WITH TIES;

-- test ruleutils
--Testcase 74:
CREATE VIEW limit_thousand_v_1 AS SELECT (fields->>'thousand')::int4 thousand FROM onek WHERE (fields->>'thousand')::int4 < 995
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST 5 ROWS WITH TIES OFFSET 10;
--Testcase 75:
\d+ limit_thousand_v_1
--Testcase 76:
CREATE VIEW limit_thousand_v_2 AS SELECT (fields->>'thousand')::int4 thousand FROM onek WHERE (fields->>'thousand')::int4 < 995
		ORDER BY (fields->>'thousand')::int4 OFFSET 10 FETCH FIRST 5 ROWS ONLY;
--Testcase 77:
\d+ limit_thousand_v_2
--Testcase 78:
CREATE VIEW limit_thousand_v_3 AS SELECT (fields->>'thousand')::int4 thousand FROM onek WHERE (fields->>'thousand')::int4 < 995
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST NULL ROWS WITH TIES;		-- fails
--Testcase 79:
CREATE VIEW limit_thousand_v_3 AS SELECT (fields->>'thousand')::int4 thousand FROM onek WHERE (fields->>'thousand')::int4 < 995
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST (NULL+1) ROWS WITH TIES;
--Testcase 80:
\d+ limit_thousand_v_3
--Testcase 81:
CREATE VIEW limit_thousand_v_4 AS SELECT (fields->>'thousand')::int4 thousand FROM onek WHERE (fields->>'thousand')::int4 < 995
		ORDER BY (fields->>'thousand')::int4 FETCH FIRST NULL ROWS ONLY;
--Testcase 82:
\d+ limit_thousand_v_4

-- leave these views
--Testcase 83:
DROP VIEW limit_thousand_v_1;
--Testcase 84:
DROP VIEW limit_thousand_v_2;
--Testcase 85:
DROP VIEW limit_thousand_v_3;
--Testcase 86:
DROP VIEW limit_thousand_v_4;

-- Clean up
DO $d$
declare
  l_rec record;
begin
  for l_rec in (select foreign_table_schema, foreign_table_name 
                from information_schema.foreign_tables) loop
     execute format('drop foreign table %I.%I cascade;', l_rec.foreign_table_schema, l_rec.foreign_table_name);
  end loop;
end;
$d$;

--Testcase 87:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 88:
DROP SERVER influxdb_svr CASCADE;
--Testcase 89:
DROP EXTENSION influxdb_fdw;
