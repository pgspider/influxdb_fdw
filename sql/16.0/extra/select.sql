--
-- SELECT
--
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
CREATE FOREIGN TABLE onek (
  unique1   int4,
  unique2   int4,
  two     int4,
  four    int4,
  ten     int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd     int4,
  even    int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER influxdb_svr;

--Testcase 5:
CREATE FOREIGN TABLE onek2 (
  unique1   int4,
  unique2   int4,
  two     int4,
  four    int4,
  ten     int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd     int4,
  even    int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER influxdb_svr OPTIONS (table 'onek');

--Testcase 6:
CREATE FOREIGN TABLE INT8_TBL (
  q1 int8,
  q2 int8
) SERVER influxdb_svr;

--Testcase 7:
CREATE FOREIGN TABLE person (
  name    text,
  age     int4,
  location  point
) SERVER influxdb_svr;


--Testcase 8:
CREATE FOREIGN TABLE emp (
	salary 		int4,
	manager 	text
) INHERITS (person) SERVER influxdb_svr;


--Testcase 9:
CREATE FOREIGN TABLE student (
	gpa 		float8
) INHERITS (person) SERVER influxdb_svr;


--Testcase 10:
CREATE FOREIGN TABLE stud_emp (
	percent 	int4
) INHERITS (emp, student) SERVER influxdb_svr;

-- btree index
-- awk '{if($1<10){print;}else{next;}}' onek.data | sort +0n -1
--
--Testcase 11:
SELECT * FROM onek
   WHERE onek.unique1 < 10
   ORDER BY onek.unique1;

--
-- awk '{if($1<20){print $1,$14;}else{next;}}' onek.data | sort +0nr -1
--
--Testcase 12:
SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >;

--
-- awk '{if($1>980){print $1,$14;}else{next;}}' onek.data | sort +1d -2
--
--Testcase 13:
SELECT onek.unique1, onek.stringu1 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY stringu1 using <;

--
-- awk '{if($1>980){print $1,$16;}else{next;}}' onek.data |
-- sort +1d -2 +0nr -1
--
--Testcase 14:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using <, unique1 using >;

--
-- awk '{if($1>980){print $1,$16;}else{next;}}' onek.data |
-- sort +1dr -2 +0n -1
--
--Testcase 15:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 > 980
   ORDER BY string4 using >, unique1 using <;

--
-- awk '{if($1<20){print $1,$16;}else{next;}}' onek.data |
-- sort +0nr -1 +1d -2
--
--Testcase 16:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using >, string4 using <;

--
-- awk '{if($1<20){print $1,$16;}else{next;}}' onek.data |
-- sort +0n -1 +1dr -2
--
--Testcase 17:
SELECT onek.unique1, onek.string4 FROM onek
   WHERE onek.unique1 < 20
   ORDER BY unique1 using <, string4 using >;

--
-- test partial btree indexes
--
-- As of 7.2, planner probably won't pick an indexscan without stats,
-- so ANALYZE first.  Also, we want to prevent it from picking a bitmapscan
-- followed by sort, because that could hide index ordering problems.
--
-- ANALYZE onek2;

--Testcase 18:
SET enable_seqscan TO off;
--Testcase 19:
SET enable_bitmapscan TO off;
--Testcase 20:
SET enable_sort TO off;

--
-- awk '{if($1<10){print $0;}else{next;}}' onek.data | sort +0n -1
--
--Testcase 21:
SELECT onek2.* FROM onek2 WHERE onek2.unique1 < 10 order by 1;

--
-- awk '{if($1<20){print $1,$14;}else{next;}}' onek.data | sort +0nr -1
--
--Testcase 22:
SELECT onek2.unique1, onek2.stringu1 FROM onek2
    WHERE onek2.unique1 < 20
    ORDER BY unique1 using >;

--
-- awk '{if($1>980){print $1,$14;}else{next;}}' onek.data | sort +1d -2
--
--Testcase 23:
SELECT onek2.unique1, onek2.stringu1 FROM onek2
   WHERE onek2.unique1 > 980 order by 1;

--Testcase 24:
RESET enable_seqscan;
--Testcase 25:
RESET enable_bitmapscan;
--Testcase 26:
RESET enable_sort;


--Testcase 27:
--SELECT two, stringu1, ten, string4
--   INTO TABLE tmp
--   FROM onek;

--
-- awk '{print $1,$2;}' person.data |
-- awk '{if(NF!=2){print $3,$2;}else{print;}}' - emp.data |
-- awk '{if(NF!=2){print $3,$2;}else{print;}}' - student.data |
-- awk 'BEGIN{FS="      ";}{if(NF!=2){print $4,$5;}else{print;}}' - stud_emp.data
--
-- SELECT name, age FROM person*; ??? check if different
--Testcase 28:
SELECT p.name, p.age FROM person* p;

--
-- awk '{print $1,$2;}' person.data |
-- awk '{if(NF!=2){print $3,$2;}else{print;}}' - emp.data |
-- awk '{if(NF!=2){print $3,$2;}else{print;}}' - student.data |
-- awk 'BEGIN{FS="      ";}{if(NF!=1){print $4,$5;}else{print;}}' - stud_emp.data |
-- sort +1nr -2
--
--Testcase 29:
SELECT p.name, p.age FROM person* p ORDER BY age using >, name;

--
-- Test some cases involving whole-row Var referencing a subquery
--
--Testcase 30:
select foo from (select 1 offset 0) as foo;
--Testcase 31:
select foo from (select null offset 0) as foo;
--Testcase 32:
select foo from (select 'xyzzy',1,null offset 0) as foo;

--
-- Test VALUES lists
--
--Testcase 33:
select * from onek, (values(147, 'RFAAAA'), (931, 'VJAAAA')) as v (i, j)
    WHERE onek.unique1 = v.i and onek.stringu1 = v.j;

-- a more complex case
-- looks like we're coding lisp :-)
--Testcase 34:
select * from onek,
  (values ((select i from
    (values(10000), (2), (389), (1000), (2000), ((select 10029))) as foo(i)
    order by i asc limit 1))) bar (i)
  where onek.unique1 = bar.i;

-- try VALUES in a subquery
--Testcase 35:
select * from onek
    where (unique1,ten) in (values (1,1), (20,0), (99,9), (17,99))
    order by unique1;

-- VALUES is also legal as a standalone query or a set-operation member
--Testcase 36:
VALUES (1,2), (3,4+4), (7,77.7);

--Testcase 37:
VALUES (1,2), (3,4+4), (7,77.7)
UNION ALL
SELECT 2+2, 57
UNION ALL
TABLE int8_tbl;

-- -- corner case: VALUES with no columns
-- InfluxDB not support table with no columns.
-- --Testcase 79:
-- CREATE FOREIGN TABLE nocols() SERVER influxdb_svr;
-- --Testcase 80:
-- INSERT INTO nocols DEFAULT VALUES;
-- --Testcase 81:
-- SELECT * FROM nocols n, LATERAL (VALUES(n.*)) v;

--
-- Test ORDER BY options
--

--Testcase 38:
CREATE FOREIGN TABLE foo (f1 int) SERVER influxdb_svr;

--Testcase 39:
SELECT * FROM foo ORDER BY f1;
--Testcase 40:
SELECT * FROM foo ORDER BY f1 ASC;	-- same thing
--Testcase 41:
SELECT * FROM foo ORDER BY f1 NULLS FIRST;
--Testcase 42:
SELECT * FROM foo ORDER BY f1 DESC;
--Testcase 43:
SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;

-- check if indexscans do the right things
-- CREATE INDEX fooi ON foo (f1);
-- SET enable_sort = false;

-- SELECT * FROM foo ORDER BY f1;
-- SELECT * FROM foo ORDER BY f1 NULLS FIRST;
-- SELECT * FROM foo ORDER BY f1 DESC;
-- SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;

-- DROP INDEX fooi;
-- CREATE INDEX fooi ON foo (f1 DESC);

-- SELECT * FROM foo ORDER BY f1;
-- SELECT * FROM foo ORDER BY f1 NULLS FIRST;
-- SELECT * FROM foo ORDER BY f1 DESC;
-- SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;

-- DROP INDEX fooi;
-- CREATE INDEX fooi ON foo (f1 DESC NULLS LAST);

-- SELECT * FROM foo ORDER BY f1;
-- SELECT * FROM foo ORDER BY f1 NULLS FIRST;
-- SELECT * FROM foo ORDER BY f1 DESC;
-- SELECT * FROM foo ORDER BY f1 DESC NULLS LAST;

--
-- Test planning of some cases with partial indexes
--

-- partial index is usable
--Testcase 44:
explain (costs off)
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 45:
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
-- actually run the query with an analyze to use the partial index
--Testcase 46:
explain (costs off, analyze on, timing off, summary off)
select * from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 47:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
--Testcase 48:
select unique2 from onek2 where unique2 = 11 and stringu1 = 'ATAAAA';
-- partial index predicate implies clause, so no need for retest
--Testcase 49:
explain (costs off)
select * from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 50:
select * from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 51:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 52:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
-- but if it's an update target, must retest anyway
--Testcase 53:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B' for update;
--Testcase 54:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B' for update;
-- partial index is not applicable
--Testcase 55:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'C';
--Testcase 56:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'C';
-- partial index implies clause, but bitmap scan must recheck predicate anyway
--Testcase 57:
SET enable_indexscan TO off;
--Testcase 58:
explain (costs off)
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 59:
select unique2 from onek2 where unique2 = 11 and stringu1 < 'B';
--Testcase 60:
RESET enable_indexscan;
-- check multi-index cases too
--Testcase 61:
explain (costs off)
select unique1, unique2 from onek2
  where (unique2 = 11 or unique1 = 0) and stringu1 < 'B';
--Testcase 62:
select unique1, unique2 from onek2
  where (unique2 = 11 or unique1 = 0) and stringu1 < 'B';
--Testcase 63:
explain (costs off)
select unique1, unique2 from onek2
  where (unique2 = 11 and stringu1 < 'B') or unique1 = 0;
--Testcase 64:
select unique1, unique2 from onek2
  where (unique2 = 11 and stringu1 < 'B') or unique1 = 0;

--
-- Test some corner cases that have been known to confuse the planner
--

-- ORDER BY on a constant doesn't really need any sorting
--Testcase 65:
SELECT 1 AS x ORDER BY x;

-- But ORDER BY on a set-valued expression does
--Testcase 66:
create function sillysrf(int) returns setof int as
  'values (1),(10),(2),($1)' language sql immutable;

--Testcase 67:
select sillysrf(42);
--Testcase 68:
select sillysrf(-1) order by 1;

--Testcase 69:
drop function sillysrf(int);

-- X = X isn't a no-op, it's effectively X IS NOT NULL assuming = is strict
-- (see bug #5084)
--Testcase 70:
select * from (values (2),(null),(1)) v(k) where k = k order by k;
--Testcase 71:
select * from (values (2),(null),(1)) v(k) where k = k;

-- Test partitioned tables with no partitions, which should be handled the
-- same as the non-inheritance case when expanding its RTE.
--Testcase 72:
create table list_parted_tbl (a int,b int) partition by list (a);
--Testcase 73:
create table list_parted_tbl1 partition of list_parted_tbl
  for values in (1) partition by list(b);
--Testcase 74:
explain (costs off) select * from list_parted_tbl;
--Testcase 75:
drop table list_parted_tbl;

-- Clean up:
--DROP TABLE IF EXISTS tmp;

--Testcase 76:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 77:
DROP SERVER influxdb_svr CASCADE;
--Testcase 78:
DROP EXTENSION influxdb_fdw CASCADE;
