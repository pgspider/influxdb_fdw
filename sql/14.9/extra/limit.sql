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

--
-- LIMIT
-- Check the LIMIT/OFFSET feature of SELECT
--

--Testcase 4:
CREATE FOREIGN TABLE onek (
	unique1	 	int4,
	unique2	 	int4,
	two 			int4,
	four 		int4,
	ten 			int4,
	twenty 		int4,
	hundred	 	int4,
	thousand 	int4,
	twothousand 	int4,
	fivethous 	int4,
	tenthous 	int4,
	odd 			int4,
	even 		int4,
	stringu1 	name,
	stringu2 	name,
	string4	 	name
) SERVER influxdb_svr;

--Testcase 5:
CREATE FOREIGN TABLE int8_tbl(q1 int8, q2 int8) SERVER influxdb_svr;

--Testcase 6:
CREATE FOREIGN TABLE tenk1 (
	unique1	 	int4,
	unique2	 	int4,
	two 			int4,
	four 		int4,
	ten 			int4,
	twenty 		int4,
	hundred	 	int4,
	thousand 	int4,
	twothousand 	int4,
	fivethous 	int4,
	tenthous 	int4,
	odd 			int4,
	even 		int4,
	stringu1 	name,
	stringu2 	name,
	string4	 	name
) SERVER influxdb_svr OPTIONS (table 'tenk');

--Testcase 7:
SELECT ''::text AS two, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 50
		ORDER BY unique1 LIMIT 2;
--Testcase 8:
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 60
		ORDER BY unique1 LIMIT 5;
--Testcase 9:
SELECT ''::text AS two, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 60 AND unique1 < 63
		ORDER BY unique1 LIMIT 5;
--Testcase 10:
SELECT ''::text AS three, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 100
		ORDER BY unique1 LIMIT 3 OFFSET 20;
--Testcase 11:
SELECT ''::text AS zero, unique1, unique2, stringu1
		FROM onek WHERE unique1 < 50
		ORDER BY unique1 DESC LIMIT 8 OFFSET 99;
--Testcase 12:
SELECT ''::text AS eleven, unique1, unique2, stringu1
		FROM onek WHERE unique1 < 50
		ORDER BY unique1 DESC LIMIT 20 OFFSET 39;
--Testcase 13:
SELECT ''::text AS ten, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 OFFSET 990;
--Testcase 14:
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 OFFSET 990 LIMIT 5;
--Testcase 15:
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 LIMIT 5 OFFSET 900;

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

declare c5 scroll cursor for select * from int8_tbl order by q1 fetch first 2 rows with ties;
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
CREATE FOREIGN TABLE generate_series4(a int) SERVER influxdb_svr;
--Testcase 51:
SELECT
  (SELECT a
     FROM (VALUES (1)) AS x,
          (SELECT a FROM generate_series4 AS n
             ORDER BY a LIMIT 1 OFFSET s.a-1) AS y) AS z
  FROM generate_series4 AS s;

--
-- Test behavior of volatile and set-returning functions in conjunction
-- with ORDER BY and LIMIT.
--

--Testcase 52:
create temp sequence testseq;

--Testcase 53:
explain (verbose, costs off)
select unique1, unique2, nextval('testseq')
  from tenk1 order by unique2 limit 10;

--Testcase 54:
select unique1, unique2, nextval('testseq')
  from tenk1 order by unique2 limit 10;

--Testcase 55:
select currval('testseq');

--Testcase 56:
explain (verbose, costs off)
select unique1, unique2, nextval('testseq')
  from tenk1 order by tenthous limit 10;

--Testcase 57:
select unique1, unique2, nextval('testseq')
  from tenk1 order by tenthous limit 10;

--Testcase 58:
select currval('testseq');

--Testcase 59:
explain (verbose, costs off)
select unique1, unique2, generate_series(1,10)
  from tenk1 order by unique2 limit 7;

--Testcase 60:
select unique1, unique2, generate_series(1,10)
  from tenk1 order by unique2 limit 7;

--Testcase 61:
explain (verbose, costs off)
select unique1, unique2, generate_series(1,10)
  from tenk1 order by tenthous limit 7;

--Testcase 62:
select unique1, unique2, generate_series(1,10)
  from tenk1 order by tenthous limit 7;

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
select sum(tenthous) as s1, sum(tenthous) + random()*0 as s2
  from tenk1 group by thousand order by thousand limit 3;

--Testcase 68:
select sum(tenthous) as s1, sum(tenthous) + random()*0 as s2
  from tenk1 group by thousand order by thousand limit 3;

--
-- FETCH FIRST
-- Check the WITH TIES clause
--

--Testcase 69:
SELECT  thousand
		FROM onek WHERE thousand < 5
		ORDER BY thousand FETCH FIRST 2 ROW WITH TIES;

--Testcase 70:
SELECT  thousand
		FROM onek WHERE thousand < 5
		ORDER BY thousand FETCH FIRST ROWS WITH TIES;

--Testcase 71:
SELECT  thousand
		FROM onek WHERE thousand < 5
		ORDER BY thousand FETCH FIRST 1 ROW WITH TIES;

--Testcase 72:
SELECT  thousand
		FROM onek WHERE thousand < 5
		ORDER BY thousand FETCH FIRST 2 ROW ONLY;

-- should fail
--Testcase 73:
SELECT ''::text AS two, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 50
		FETCH FIRST 2 ROW WITH TIES;

-- test ruleutils
--Testcase 74:
CREATE VIEW limit_thousand_v_1 AS SELECT thousand FROM onek WHERE thousand < 995
		ORDER BY thousand FETCH FIRST 5 ROWS WITH TIES OFFSET 10;
--Testcase 75:
\d+ limit_thousand_v_1
--Testcase 76:
CREATE VIEW limit_thousand_v_2 AS SELECT thousand FROM onek WHERE thousand < 995
		ORDER BY thousand OFFSET 10 FETCH FIRST 5 ROWS ONLY;
--Testcase 77:
\d+ limit_thousand_v_2
--Testcase 78:
CREATE VIEW limit_thousand_v_3 AS SELECT thousand FROM onek WHERE thousand < 995
		ORDER BY thousand FETCH FIRST NULL ROWS WITH TIES;		-- fails
--Testcase 79:
CREATE VIEW limit_thousand_v_3 AS SELECT thousand FROM onek WHERE thousand < 995
		ORDER BY thousand FETCH FIRST (NULL+1) ROWS WITH TIES;
--Testcase 80:
\d+ limit_thousand_v_3
--Testcase 81:
CREATE VIEW limit_thousand_v_4 AS SELECT thousand FROM onek WHERE thousand < 995
		ORDER BY thousand FETCH FIRST NULL ROWS ONLY;
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
DROP EXTENSION influxdb_fdw CASCADE;
