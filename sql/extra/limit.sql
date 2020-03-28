CREATE EXTENSION influxdb_fdw;

CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', host 'http://localhost', port '8086');
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password 'pass');

-- import time column as timestamp and text type
-- IMPORT FOREIGN SCHEMA influxdb_schema FROM SERVER influxdb_svr INTO public;

--
-- LIMIT
-- Check the LIMIT/OFFSET feature of SELECT
--

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

CREATE FOREIGN TABLE int8_tbl(q1 int8, q2 int8) SERVER influxdb_svr;

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

SELECT ''::text AS two, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 50
		ORDER BY unique1 LIMIT 2;
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 60
		ORDER BY unique1 LIMIT 5;
SELECT ''::text AS two, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 60 AND unique1 < 63
		ORDER BY unique1 LIMIT 5;
SELECT ''::text AS three, unique1, unique2, stringu1
		FROM onek WHERE unique1 > 100
		ORDER BY unique1 LIMIT 3 OFFSET 20;
SELECT ''::text AS zero, unique1, unique2, stringu1
		FROM onek WHERE unique1 < 50
		ORDER BY unique1 DESC LIMIT 8 OFFSET 99;
SELECT ''::text AS eleven, unique1, unique2, stringu1
		FROM onek WHERE unique1 < 50
		ORDER BY unique1 DESC LIMIT 20 OFFSET 39;
SELECT ''::text AS ten, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 OFFSET 990;
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 OFFSET 990 LIMIT 5;
SELECT ''::text AS five, unique1, unique2, stringu1
		FROM onek
		ORDER BY unique1 LIMIT 5 OFFSET 900;

-- Test null limit and offset.  The planner would discard a simple null
-- constant, so to ensure executor is exercised, do this:
select * from int8_tbl limit (case when random() < 0.5 then null::bigint end);
select * from int8_tbl offset (case when random() < 0.5 then null::bigint end);

-- Test assorted cases involving backwards fetch from a LIMIT plan node
begin;

declare c1 scroll cursor for select * from int8_tbl limit 10;
fetch all in c1;
fetch 1 in c1;
fetch backward 1 in c1;
fetch backward all in c1;
fetch backward 1 in c1;
fetch all in c1;

declare c2 scroll cursor for select * from int8_tbl limit 3;
fetch all in c2;
fetch 1 in c2;
fetch backward 1 in c2;
fetch backward all in c2;
fetch backward 1 in c2;
fetch all in c2;

declare c3 scroll cursor for select * from int8_tbl offset 3;
fetch all in c3;
fetch 1 in c3;
fetch backward 1 in c3;
fetch backward all in c3;
fetch backward 1 in c3;
fetch all in c3;

declare c4 scroll cursor for select * from int8_tbl offset 10;
fetch all in c4;
fetch 1 in c4;
fetch backward 1 in c4;
fetch backward all in c4;
fetch backward 1 in c4;
fetch all in c4;

rollback;

-- Stress test for variable LIMIT in conjunction with bounded-heap sorting

SELECT
  (SELECT n
     FROM (VALUES (1)) AS x,
          (SELECT n FROM generate_series(1,10) AS n
             ORDER BY n LIMIT 1 OFFSET s-1) AS y) AS z
  FROM generate_series(1,10) AS s;

--
-- Test behavior of volatile and set-returning functions in conjunction
-- with ORDER BY and LIMIT.
--

create temp sequence testseq;

explain (verbose, costs off)
select unique1, unique2, nextval('testseq')
  from tenk1 order by unique2 limit 10;

select unique1, unique2, nextval('testseq')
  from tenk1 order by unique2 limit 10;

select currval('testseq');

explain (verbose, costs off)
select unique1, unique2, nextval('testseq')
  from tenk1 order by tenthous limit 10;

select unique1, unique2, nextval('testseq')
  from tenk1 order by tenthous limit 10;

select currval('testseq');

explain (verbose, costs off)
select unique1, unique2, generate_series(1,10)
  from tenk1 order by unique2 limit 7;

select unique1, unique2, generate_series(1,10)
  from tenk1 order by unique2 limit 7;

explain (verbose, costs off)
select unique1, unique2, generate_series(1,10)
  from tenk1 order by tenthous limit 7;

select unique1, unique2, generate_series(1,10)
  from tenk1 order by tenthous limit 7;

-- use of random() is to keep planner from folding the expressions together
explain (verbose, costs off)
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2;

select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2;

explain (verbose, costs off)
select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2
order by s2 desc;

select generate_series(0,2) as s1, generate_series((random()*.1)::int,2) as s2
order by s2 desc;

-- test for failure to set all aggregates' aggtranstype
-- influxdb does not support group by clause.
-- explain (verbose, costs off)
-- select sum(tenthous) as s1, sum(tenthous) + random()*0 as s2
--   from tenk1 group by thousand order by thousand limit 3;

-- select sum(tenthous) as s1, sum(tenthous) + random()*0 as s2
--   from tenk1 group by thousand order by thousand limit 3;

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

DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
DROP SERVER influxdb_svr CASCADE;
DROP EXTENSION influxdb_fdw CASCADE;
