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

-- import time column as timestamp and text type
-- IMPORT FOREIGN SCHEMA influxdb_schema FROM SERVER influxdb_svr INTO public;

--
-- JOIN
-- Test JOIN clauses
--

--Testcase 4:
CREATE FOREIGN TABLE J1_TBL (
  i integer,
  j integer,
  t text
) SERVER influxdb_svr;

--Testcase 5:
CREATE FOREIGN TABLE J2_TBL (
  i integer,
  k integer
) SERVER influxdb_svr;

--Testcase 6:
INSERT INTO J1_TBL VALUES (1, 4, 'one');
--Testcase 7:
INSERT INTO J1_TBL VALUES (2, 3, 'two');
--Testcase 8:
INSERT INTO J1_TBL VALUES (3, 2, 'three');
--Testcase 9:
INSERT INTO J1_TBL VALUES (4, 1, 'four');
--Testcase 10:
INSERT INTO J1_TBL VALUES (5, 0, 'five');
--Testcase 11:
INSERT INTO J1_TBL VALUES (6, 6, 'six');
--Testcase 12:
INSERT INTO J1_TBL VALUES (7, 7, 'seven');
--Testcase 13:
INSERT INTO J1_TBL VALUES (8, 8, 'eight');
--Testcase 14:
INSERT INTO J1_TBL VALUES (0, NULL, 'zero');
--Testcase 15:
INSERT INTO J1_TBL VALUES (NULL, NULL, 'null');
--Testcase 16:
INSERT INTO J1_TBL VALUES (NULL, 0, 'zero');

--Testcase 17:
INSERT INTO J2_TBL VALUES (1, -1);
--Testcase 18:
INSERT INTO J2_TBL VALUES (2, 2);
--Testcase 19:
INSERT INTO J2_TBL VALUES (3, -3);
--Testcase 20:
INSERT INTO J2_TBL VALUES (2, 4);
--Testcase 21:
INSERT INTO J2_TBL VALUES (5, -5);
--Testcase 22:
INSERT INTO J2_TBL VALUES (5, -5);
--Testcase 23:
INSERT INTO J2_TBL VALUES (0, NULL);
--InfluxDB does not accept NULL value
--INSERT INTO J2_TBL VALUES (NULL, NULL);
--Testcase 24:
INSERT INTO J2_TBL VALUES (NULL, 0);

--Testcase 25:
CREATE FOREIGN TABLE tenk1 (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER influxdb_svr OPTIONS (table 'tenk');

--Does not support on Postgres 12
--ALTER TABLE tenk1 SET WITH OIDS;

--Testcase 26:
CREATE FOREIGN TABLE tenk2 (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER influxdb_svr OPTIONS (table 'tenk');

--Testcase 27:
CREATE FOREIGN TABLE INT4_TBL(f1 int4) SERVER influxdb_svr;
--Testcase 28:
CREATE FOREIGN TABLE FLOAT8_TBL(f1 float8) SERVER influxdb_svr;
--Testcase 29:
CREATE FOREIGN TABLE INT8_TBL(
  q1 int8,
  q2 int8
) SERVER influxdb_svr;
--Testcase 30:
CREATE FOREIGN TABLE INT2_TBL(f1 int2) SERVER influxdb_svr;

-- useful in some tests below
--Testcase 31:
create temp table onerow();
--Testcase 32:
insert into onerow default values;
analyze onerow;


--
-- CORRELATION NAMES
-- Make sure that table/column aliases are supported
-- before diving into more complex join syntax.
--

--Testcase 33:
SELECT *
  FROM J1_TBL AS tx;

--Testcase 34:
SELECT *
  FROM J1_TBL tx;

--Testcase 35:
SELECT *
  FROM J1_TBL AS t1 (a, b, c);

--Testcase 36:
SELECT *
  FROM J1_TBL t1 (a, b, c);

--Testcase 37:
SELECT *
  FROM J1_TBL t1 (a, b, c), J2_TBL t2 (d, e);

--Testcase 38:
SELECT t1.a, t2.e
  FROM J1_TBL t1 (a, b, c), J2_TBL t2 (d, e)
  WHERE t1.a = t2.d;


--
-- CROSS JOIN
-- Qualifications are not allowed on cross joins,
-- which degenerate into a standard unqualified inner join.
--

--Testcase 39:
SELECT *
  FROM J1_TBL CROSS JOIN J2_TBL;

-- ambiguous column
--Testcase 40:
SELECT i, k, t
  FROM J1_TBL CROSS JOIN J2_TBL;

-- resolve previous ambiguity by specifying the table name
--Testcase 41:
SELECT t1.i, k, t
  FROM J1_TBL t1 CROSS JOIN J2_TBL t2;

--Testcase 42:
SELECT ii, tt, kk
  FROM (J1_TBL CROSS JOIN J2_TBL)
    AS tx (ii, jj, tt, ii2, kk);

--Testcase 43:
SELECT tx.ii, tx.jj, tx.kk
  FROM (J1_TBL t1 (a, b, c) CROSS JOIN J2_TBL t2 (d, e))
    AS tx (ii, jj, tt, ii2, kk);

--Testcase 44:
SELECT *
  FROM J1_TBL CROSS JOIN J2_TBL a CROSS JOIN J2_TBL b;


--
--
-- Inner joins (equi-joins)
--
--

--
-- Inner joins (equi-joins) with USING clause
-- The USING syntax changes the shape of the resulting table
-- by including a column in the USING clause only once in the result.
--

-- Inner equi-join on specified column
--Testcase 45:
SELECT *
  FROM J1_TBL INNER JOIN J2_TBL USING (i);

-- Same as above, slightly different syntax
--Testcase 46:
SELECT *
  FROM J1_TBL JOIN J2_TBL USING (i);

--Testcase 47:
SELECT *
  FROM J1_TBL t1 (a, b, c) JOIN J2_TBL t2 (a, d) USING (a)
  ORDER BY a, d;

--Testcase 48:
SELECT *
  FROM J1_TBL t1 (a, b, c) JOIN J2_TBL t2 (a, b) USING (b)
  ORDER BY b, t1.a;

--
-- NATURAL JOIN
-- Inner equi-join on all columns with the same name
--

--Testcase 49:
SELECT *
  FROM J1_TBL NATURAL JOIN J2_TBL;

--Testcase 50:
SELECT *
  FROM J1_TBL t1 (a, b, c) NATURAL JOIN J2_TBL t2 (a, d);

--Testcase 51:
SELECT *
  FROM J1_TBL t1 (a, b, c) NATURAL JOIN J2_TBL t2 (d, a);

-- mismatch number of columns
-- currently, Postgres will fill in with underlying names
--Testcase 52:
SELECT *
  FROM J1_TBL t1 (a, b) NATURAL JOIN J2_TBL t2 (a);


--
-- Inner joins (equi-joins)
--

--Testcase 53:
SELECT *
  FROM J1_TBL JOIN J2_TBL ON (J1_TBL.i = J2_TBL.i);

--Testcase 54:
SELECT *
  FROM J1_TBL JOIN J2_TBL ON (J1_TBL.i = J2_TBL.k);


--
-- Non-equi-joins
--

--Testcase 55:
SELECT *
  FROM J1_TBL JOIN J2_TBL ON (J1_TBL.i <= J2_TBL.k);


--
-- Outer joins
-- Note that OUTER is a noise word
--

--Testcase 56:
SELECT *
  FROM J1_TBL LEFT OUTER JOIN J2_TBL USING (i)
  ORDER BY i, k, t;

--Testcase 57:
SELECT *
  FROM J1_TBL LEFT JOIN J2_TBL USING (i)
  ORDER BY i, k, t;

--Testcase 58:
SELECT *
  FROM J1_TBL RIGHT OUTER JOIN J2_TBL USING (i);

--Testcase 59:
SELECT *
  FROM J1_TBL RIGHT JOIN J2_TBL USING (i);

--Testcase 60:
SELECT *
  FROM J1_TBL FULL OUTER JOIN J2_TBL USING (i)
  ORDER BY i, k, t;

--Testcase 61:
SELECT *
  FROM J1_TBL FULL JOIN J2_TBL USING (i)
  ORDER BY i, k, t;

--Testcase 62:
SELECT *
  FROM J1_TBL LEFT JOIN J2_TBL USING (i) WHERE (k = 1);

--Testcase 63:
SELECT *
  FROM J1_TBL LEFT JOIN J2_TBL USING (i) WHERE (i = 1);

--
-- semijoin selectivity for <>
--
--Testcase 64:
explain (costs off)
select * from int4_tbl i4, tenk1 a
where exists(select * from tenk1 b
             where a.twothousand = b.twothousand and a.fivethous <> b.fivethous)
      and i4.f1 = a.tenthous;


--
-- More complicated constructs
--

--
-- Multiway full join
--

--Testcase 65:
CREATE FOREIGN TABLE t1 (name TEXT, n INTEGER) SERVER influxdb_svr;
--Testcase 66:
CREATE FOREIGN TABLE t2 (name TEXT, n INTEGER) SERVER influxdb_svr;
--Testcase 67:
CREATE FOREIGN TABLE t3 (name TEXT, n INTEGER) SERVER influxdb_svr;

--Testcase 68:
INSERT INTO t1 VALUES ( 'bb', 11 );
--Testcase 69:
INSERT INTO t2 VALUES ( 'bb', 12 );
--Testcase 70:
INSERT INTO t2 VALUES ( 'cc', 22 );
--Testcase 71:
INSERT INTO t2 VALUES ( 'ee', 42 );
--Testcase 72:
INSERT INTO t3 VALUES ( 'bb', 13 );
--Testcase 73:
INSERT INTO t3 VALUES ( 'cc', 23 );
--Testcase 74:
INSERT INTO t3 VALUES ( 'dd', 33 );

--Testcase 75:
SELECT * FROM t1 FULL JOIN t2 USING (name) FULL JOIN t3 USING (name);

--
-- Test interactions of join syntax and subqueries
--

-- Basic cases (we expect planner to pull up the subquery here)
--Testcase 76:
SELECT * FROM
(SELECT * FROM t2) as s2
INNER JOIN
(SELECT * FROM t3) s3
USING (name);

--Testcase 77:
SELECT * FROM
(SELECT * FROM t2) as s2
LEFT JOIN
(SELECT * FROM t3) s3
USING (name);

--Testcase 78:
SELECT * FROM
(SELECT * FROM t2) as s2
FULL JOIN
(SELECT * FROM t3) s3
USING (name);

-- Cases with non-nullable expressions in subquery results;
-- make sure these go to null as expected
--Testcase 79:
SELECT * FROM
(SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL INNER JOIN
(SELECT name, n as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 80:
SELECT * FROM
(SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL LEFT JOIN
(SELECT name, n as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 81:
SELECT * FROM
(SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL FULL JOIN
(SELECT name, n as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 82:
SELECT * FROM
(SELECT name, n as s1_n, 1 as s1_1 FROM t1) as s1
NATURAL INNER JOIN
(SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL INNER JOIN
(SELECT name, n as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 83:
SELECT * FROM
(SELECT name, n as s1_n, 1 as s1_1 FROM t1) as s1
NATURAL FULL JOIN
(SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL FULL JOIN
(SELECT name, n as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 84:
SELECT * FROM
(SELECT name, n as s1_n FROM t1) as s1
NATURAL FULL JOIN
  (SELECT * FROM
    (SELECT name, n as s2_n FROM t2) as s2
    NATURAL FULL JOIN
    (SELECT name, n as s3_n FROM t3) as s3
  ) ss2;

--Testcase 85:
SELECT * FROM
(SELECT name, n as s1_n FROM t1) as s1
NATURAL FULL JOIN
  (SELECT * FROM
    (SELECT name, n as s2_n, 2 as s2_2 FROM t2) as s2
    NATURAL FULL JOIN
    (SELECT name, n as s3_n FROM t3) as s3
  ) ss2;

-- Constants as join keys can also be problematic
--Testcase 86:
SELECT * FROM
  (SELECT name, n as s1_n FROM t1) as s1
FULL JOIN
  (SELECT name, 2 as s2_n FROM t2) as s2
ON (s1_n = s2_n);


-- Test for propagation of nullability constraints into sub-joins

--Testcase 87:
create foreign table x (x1 int, x2 int) server influxdb_svr;
--Testcase 88:
insert into x values (1,11);
--Testcase 89:
insert into x values (2,22);
--Testcase 90:
insert into x values (3,null);
--Testcase 91:
insert into x values (4,44);
--Testcase 92:
insert into x values (5,null);

--Testcase 93:
create foreign table y (y1 int, y2 int) server influxdb_svr;
--Testcase 94:
insert into y values (1,111);
--Testcase 95:
insert into y values (2,222);
--Testcase 96:
insert into y values (3,333);
--Testcase 97:
insert into y values (4,null);

--Testcase 98:
select * from x;
--Testcase 99:
select * from y;

--Testcase 100:
select * from x left join y on (x1 = y1 and x2 is not null);
--Testcase 101:
select * from x left join y on (x1 = y1 and y2 is not null);

--Testcase 102:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1);
--Testcase 103:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1 and x2 is not null);
--Testcase 104:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1 and y2 is not null);
--Testcase 105:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1 and xx2 is not null);
-- these should NOT give the same answers as above
--Testcase 106:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1) where (x2 is not null);
--Testcase 107:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1) where (y2 is not null);
--Testcase 108:
select * from (x left join y on (x1 = y1)) left join x xx(xx1,xx2)
on (x1 = xx1) where (xx2 is not null);

--
-- regression test: check for bug with propagation of implied equality
-- to outside an IN
--
--Testcase 109:
select count(*) from tenk1 a where unique1 in
  (select unique1 from tenk1 b join tenk1 c using (unique1)
   where b.unique2 = 42);

--
-- regression test: check for failure to generate a plan with multiple
-- degenerate IN clauses
--
--Testcase 110:
select count(*) from tenk1 x where
  x.unique1 in (select a.f1 from int4_tbl a,float8_tbl b where a.f1=b.f1) and
  x.unique1 = 0 and
  x.unique1 in (select aa.f1 from int4_tbl aa,float8_tbl bb where aa.f1=bb.f1);

-- try that with GEQO too
begin;
--Testcase 111:
set geqo = on;
--Testcase 112:
set geqo_threshold = 2;
--Testcase 113:
select count(*) from tenk1 x where
  x.unique1 in (select a.f1 from int4_tbl a,float8_tbl b where a.f1=b.f1) and
  x.unique1 = 0 and
  x.unique1 in (select aa.f1 from int4_tbl aa,float8_tbl bb where aa.f1=bb.f1);
rollback;

--
-- regression test: be sure we cope with proven-dummy append rels
--
--Testcase 114:
create table b (aa int, bb int);

--Testcase 115:
explain (costs off)
select aa, bb, unique1, unique1
  from tenk1 right join b on aa = unique1
  where bb < bb and bb is null;

--Testcase 116:
select aa, bb, unique1, unique1
  from tenk1 right join b on aa = unique1
  where bb < bb and bb is null;

--Testcase 117:
drop table b;
--
-- regression test: check handling of empty-FROM subquery underneath outer join
--
--Testcase 118:
explain (costs off)
select * from int8_tbl i1 left join (int8_tbl i2 join
  (select 123 as x) ss on i2.q1 = x) on i1.q2 = i2.q2
order by 1, 2;

--Testcase 119:
select * from int8_tbl i1 left join (int8_tbl i2 join
  (select 123 as x) ss on i2.q1 = x) on i1.q2 = i2.q2
order by 1, 2;

--
-- regression test: check a case where join_clause_is_movable_into() gives
-- an imprecise result, causing an assertion failure
--
--Testcase 120:
select count(*)
from
  (select t3.tenthous as x1, coalesce(t1.stringu1, t2.stringu1) as x2
   from tenk1 t1
   left join tenk1 t2 on t1.unique1 = t2.unique1
   join tenk1 t3 on t1.unique2 = t3.unique2) ss,
  tenk1 t4,
  tenk1 t5
where t4.thousand = t5.unique1 and ss.x1 = t4.tenthous and ss.x2 = t5.stringu1;

--
-- regression test: check a case where we formerly missed including an EC
-- enforcement clause because it was expected to be handled at scan level
--
--Testcase 121:
explain (costs off)
select a.f1, b.f1, t.thousand, t.tenthous from
  tenk1 t,
  (select sum(f1)+1 as f1 from int4_tbl i4a) a,
  (select sum(f1) as f1 from int4_tbl i4b) b
where b.f1 = t.thousand and a.f1 = b.f1 and (a.f1+b.f1+999) = t.tenthous;

--Testcase 122:
select a.f1, b.f1, t.thousand, t.tenthous from
  tenk1 t,
  (select sum(f1)+1 as f1 from int4_tbl i4a) a,
  (select sum(f1) as f1 from int4_tbl i4b) b
where b.f1 = t.thousand and a.f1 = b.f1 and (a.f1+b.f1+999) = t.tenthous;

--
-- check a case where we formerly got confused by conflicting sort orders
-- in redundant merge join path keys
--
--Testcase 123:
explain (costs off)
select * from
  j1_tbl full join
  (select * from j2_tbl order by j2_tbl.i desc, j2_tbl.k asc) j2_tbl
  on j1_tbl.i = j2_tbl.i and j1_tbl.i = j2_tbl.k;

--Testcase 124:
select * from
  j1_tbl full join
  (select * from j2_tbl order by j2_tbl.i desc, j2_tbl.k asc) j2_tbl
  on j1_tbl.i = j2_tbl.i and j1_tbl.i = j2_tbl.k;

--
-- a different check for handling of redundant sort keys in merge joins
--
--Testcase 125:
explain (costs off)
select count(*) from
  (select * from tenk1 x order by x.thousand, x.twothousand, x.fivethous) x
  left join
  (select * from tenk1 y order by y.unique2) y
  on x.thousand = y.unique2 and x.twothousand = y.hundred and x.fivethous = y.unique2;

--Testcase 126:
select count(*) from
  (select * from tenk1 x order by x.thousand, x.twothousand, x.fivethous) x
  left join
  (select * from tenk1 y order by y.unique2) y
  on x.thousand = y.unique2 and x.twothousand = y.hundred and x.fivethous = y.unique2;


--
-- Clean up
--

--Testcase 127:
DELETE FROM t1;
--Testcase 128:
DELETE FROM t2;
--Testcase 129:
DELETE FROM t3;
--Testcase 130:
DROP FOREIGN TABLE t1;
--Testcase 131:
DROP FOREIGN TABLE t2;
--Testcase 132:
DROP FOREIGN TABLE t3;

--Testcase 133:
DELETE FROM J1_TBL;
DROP FOREIGN TABLE J1_TBL;
--Testcase 134:
DELETE FROM J2_TBL;
DROP FOREIGN TABLE J2_TBL;

DELETE FROM x;
DELETE FROM y;
DROP FOREIGN TABLE x;
DROP FOREIGN TABLE y;

-- Both DELETE and UPDATE allow the specification of additional tables
-- to "join" against to determine which rows should be modified.

--Testcase 135:
CREATE FOREIGN TABLE t1 (a int, b int) SERVER influxdb_svr;
--Testcase 136:
CREATE FOREIGN TABLE t2 (a int, b int) SERVER influxdb_svr;
--Testcase 137:
CREATE FOREIGN TABLE t3 (x int, y int) SERVER influxdb_svr;

--Testcase 138:
INSERT INTO t1 VALUES (5, 10);
--Testcase 139:
INSERT INTO t1 VALUES (15, 20);
--Testcase 140:
INSERT INTO t1 VALUES (100, 100);
--Testcase 141:
INSERT INTO t1 VALUES (200, 1000);
--Testcase 142:
INSERT INTO t2 VALUES (200, 2000);
--Testcase 143:
INSERT INTO t3 VALUES (5, 20);
--Testcase 144:
INSERT INTO t3 VALUES (6, 7);
--Testcase 145:
INSERT INTO t3 VALUES (7, 8);
--Testcase 146:
INSERT INTO t3 VALUES (500, 100);

--Testcase 147:
ALTER TABLE t3 ADD time timestamp;

--Testcase 148:
SELECT x, y FROM t3;
--Testcase 149:
DELETE FROM t3 USING t1 table1 WHERE t3.x = table1.a;
--Testcase 150:
SELECT x, y FROM t3;
--Testcase 151:
DELETE FROM t3 USING t1 JOIN t2 USING (a) WHERE t3.x > t1.a;
--Testcase 152:
SELECT x, y FROM t3;
--Testcase 153:
DELETE FROM t3 USING t3 t3_other WHERE t3.x = t3_other.x AND t3.y = t3_other.y;
--Testcase 154:
SELECT x, y FROM t3;

-- Test join against inheritance tree

--Testcase 155:
create temp table t2a () inherits (t2);

--Testcase 156:
insert into t2a values (200, 2001);

--Testcase 157:
select * from t1 left join t2 on (t1.a = t2.a);

-- Test matching of column name with wrong alias

--Testcase 158:
select t1.x from t1 join t3 on (t1.a = t3.x);

--
-- regression test for 8.1 merge right join bug
--

--Testcase 159:
CREATE FOREIGN TABLE tt1 ( tt1_id int4, joincol int4 ) SERVER influxdb_svr;
--Testcase 160:
INSERT INTO tt1 VALUES (1, 11);
--Testcase 161:
INSERT INTO tt1 VALUES (2, NULL);

--Testcase 162:
CREATE FOREIGN TABLE tt2 ( tt2_id int4, joincol int4 ) SERVER influxdb_svr;
--Testcase 163:
INSERT INTO tt2 VALUES (21, 11);
--Testcase 164:
INSERT INTO tt2 VALUES (22, 11);

--Testcase 165:
set enable_hashjoin to off;
--Testcase 166:
set enable_nestloop to off;

-- these should give the same results

--Testcase 167:
select tt1.*, tt2.* from tt1 left join tt2 on tt1.joincol = tt2.joincol;

--Testcase 168:
select tt1.*, tt2.* from tt2 right join tt1 on tt1.joincol = tt2.joincol;

--Testcase 169:
reset enable_hashjoin;
--Testcase 170:
reset enable_nestloop;

--
-- regression test for bug #13908 (hash join with skew tuples & nbatch increase)
--

--Testcase 171:
set work_mem to '64kB';
--Testcase 172:
set enable_mergejoin to off;

--Testcase 173:
explain (costs off)
select count(*) from tenk1 a, tenk1 b
  where a.hundred = b.thousand and (b.fivethous % 10) < 10;
--Testcase 174:
select count(*) from tenk1 a, tenk1 b
  where a.hundred = b.thousand and (b.fivethous % 10) < 10;

--Testcase 175:
reset work_mem;
--Testcase 176:
reset enable_mergejoin;

--
-- regression test for 8.2 bug with improper re-ordering of left joins
--

--Testcase 177:
create foreign table tt3(f1 int, f2 text) server influxdb_svr;
--Testcase 178:
insert into tt3 select x, repeat('xyzzy', 100) from generate_series(1,10000) x;

--Testcase 179:
create foreign table tt4(f1 int) server influxdb_svr;
--Testcase 180:
insert into tt4 values (0),(1),(9999);

--Testcase 181:
SELECT a.f1
FROM tt4 a
LEFT JOIN (
        SELECT b.f1
        FROM tt3 b LEFT JOIN tt3 c ON (b.f1 = c.f1)
        WHERE c.f1 IS NULL
) AS d ON (a.f1 = d.f1)
WHERE d.f1 IS NULL;

--
-- regression test for proper handling of outer joins within antijoins
--

--Testcase 182:
create foreign table tt4x(c1 int, c2 int, c3 int) server influxdb_svr;

--Testcase 183:
explain (costs off)
select * from tt4x t1
where not exists (
  select 1 from tt4x t2
    left join tt4x t3 on t2.c3 = t3.c1
    left join ( select t5.c1 as c1
                from tt4x t4 left join tt4x t5 on t4.c2 = t5.c1
              ) a1 on t3.c2 = a1.c1
  where t1.c1 = t2.c2
);

--
-- regression test for problems of the sort depicted in bug #3494
--

--Testcase 184:
create foreign table tt5(f1 int, f2 int) server influxdb_svr;
--Testcase 185:
create foreign table tt6(f1 int, f2 int) server influxdb_svr;

--Testcase 186:
insert into tt5 values(1, 10);
--Testcase 187:
insert into tt5 values(1, 11);

--Testcase 188:
insert into tt6 values(1, 9);
--Testcase 189:
insert into tt6 values(1, 2);
--Testcase 190:
insert into tt6 values(2, 9);

--Testcase 191:
select * from tt5,tt6 where tt5.f1 = tt6.f1 and tt5.f1 = tt5.f2 - tt6.f2;

--
-- regression test for problems of the sort depicted in bug #3588
--

--Testcase 192:
create foreign table xx (pkxx int) server influxdb_svr;
--Testcase 193:
create foreign table yy (pkyy int, pkxx int) server influxdb_svr;

--Testcase 194:
insert into xx values (1);
--Testcase 195:
insert into xx values (2);
--Testcase 196:
insert into xx values (3);

--Testcase 197:
insert into yy values (101, 1);
--Testcase 198:
insert into yy values (201, 2);
--Testcase 199:
insert into yy values (301, NULL);

--Testcase 200:
select yy.pkyy as yy_pkyy, yy.pkxx as yy_pkxx, yya.pkyy as yya_pkyy,
       xxa.pkxx as xxa_pkxx, xxb.pkxx as xxb_pkxx
from yy
     left join (SELECT * FROM yy where pkyy = 101) as yya ON yy.pkyy = yya.pkyy
     left join xx xxa on yya.pkxx = xxa.pkxx
     left join xx xxb on coalesce (xxa.pkxx, 1) = xxb.pkxx;

--
-- regression test for improper pushing of constants across outer-join clauses
-- (as seen in early 8.2.x releases)
--

--Testcase 201:
create foreign table zt1 (f1 int) server influxdb_svr;
--Testcase 202:
create foreign table zt2 (f2 int) server influxdb_svr;
--Testcase 203:
create foreign table zt3 (f3 int) server influxdb_svr;
--Testcase 204:
insert into zt1 values(53);
--Testcase 205:
insert into zt2 values(53);

--Testcase 206:
select * from
  zt2 left join zt3 on (f2 = f3)
      left join zt1 on (f3 = f1)
where f2 = 53;

--Testcase 207:
create temp view zv1 as select *,'dummy'::text AS junk from zt1;

--Testcase 208:
select * from
  zt2 left join zt3 on (f2 = f3)
      left join zv1 on (f3 = f1)
where f2 = 53;

--
-- regression test for improper extraction of OR indexqual conditions
-- (as seen in early 8.3.x releases)
--

--Testcase 209:
select a.unique2, a.ten, b.tenthous, b.unique2, b.hundred
from tenk1 a left join tenk1 b on a.unique2 = b.tenthous
where a.unique1 = 42 and
      ((b.unique2 is null and a.ten = 2) or b.hundred = 3);

--
-- test proper positioning of one-time quals in EXISTS (8.4devel bug)
--
--Testcase 210:
prepare foo(bool) as
  select count(*) from tenk1 a left join tenk1 b
    on (a.unique2 = b.unique1 and exists
        (select 1 from tenk1 c where c.thousand = b.unique2 and $1));
--Testcase 211:
execute foo(true);
--Testcase 212:
execute foo(false);

--
-- test for sane behavior with noncanonical merge clauses, per bug #4926
--

begin;

--Testcase 213:
set enable_mergejoin = 1;
--Testcase 214:
set enable_hashjoin = 0;
--Testcase 215:
set enable_nestloop = 0;

--Testcase 216:
create foreign table a (i integer) server influxdb_svr;
--Testcase 217:
create foreign table b (x integer, y integer) server influxdb_svr;

--Testcase 218:
select * from a left join b on i = x and i = y and x = i;

--Testcase 219:
DROP FOREIGN TABLE a;
--Testcase 220:
DROP FOREIGN TABLE b;
rollback;

--
-- test handling of merge clauses using record_ops
--
begin;

--Testcase 221:
create type mycomptype as (id int, v bigint);

--Testcase 222:
create temp table tidv (idv mycomptype);
--Testcase 223:
create index on tidv (idv);

--Testcase 224:
explain (costs off)
select a.idv, b.idv from tidv a, tidv b where a.idv = b.idv;

--Testcase 225:
set enable_mergejoin = 0;
--Testcase 226:
set enable_hashjoin = 0;

--Testcase 227:
explain (costs off)
select a.idv, b.idv from tidv a, tidv b where a.idv = b.idv;

rollback;

--
-- test NULL behavior of whole-row Vars, per bug #5025
--
--Testcase 228:
select t1.q2, count(t2.*)
from int8_tbl t1 left join int8_tbl t2 on (t1.q2 = t2.q1)
group by t1.q2 order by 1;

--Testcase 229:
select t1.q2, count(t2.*)
from int8_tbl t1 left join (select * from int8_tbl) t2 on (t1.q2 = t2.q1)
group by t1.q2 order by 1;

--Testcase 230:
select t1.q2, count(t2.*)
from int8_tbl t1 left join (select * from int8_tbl offset 0) t2 on (t1.q2 = t2.q1)
group by t1.q2 order by 1;

--Testcase 231:
select t1.q2, count(t2.*)
from int8_tbl t1 left join
  (select q1, case when q2=1 then 1 else q2 end as q2 from int8_tbl) t2
  on (t1.q2 = t2.q1)
group by t1.q2 order by 1;

--
-- test incorrect failure to NULL pulled-up subexpressions
--
begin;

--Testcase 232:
create foreign table a (
     code char
) server influxdb_svr;
--Testcase 233:
create foreign table b (
     a char,
     num integer
) server influxdb_svr;
--Testcase 234:
create foreign table c (
     name char,
     a char
) server influxdb_svr;

--Testcase 235:
insert into a (code) values ('p');
--Testcase 236:
insert into a (code) values ('q');
--Testcase 237:
insert into b (a, num) values ('p', 1);
--Testcase 238:
insert into b (a, num) values ('p', 2);
--Testcase 239:
insert into c (name, a) values ('A', 'p');
--Testcase 240:
insert into c (name, a) values ('B', 'q');
--Testcase 241:
insert into c (name, a) values ('C', null);

--Testcase 242:
select c.name, ss.code, ss.b_cnt, ss.const
from c left join
  (select a.code, coalesce(b_grp.cnt, 0) as b_cnt, -1 as const
   from a left join
     (select count(1) as cnt, b.a from b group by b.a) as b_grp
     on a.code = b_grp.a
  ) as ss
  on (c.a = ss.code)
order by c.name;

--Testcase 243:
DELETE FROM a;
--Testcase 244:
DELETE FROM b;
--Testcase 245:
DELETE FROM c;
--Testcase 246:
DROP FOREIGN TABLE a;
--Testcase 247:
DROP FOREIGN TABLE b;
--Testcase 248:
DROP FOREIGN TABLE c;
rollback;

--
-- test incorrect handling of placeholders that only appear in targetlists,
-- per bug #6154
--
--Testcase 249:
SELECT * FROM
( SELECT 1 as key1 ) sub1
LEFT JOIN
( SELECT sub3.key3, sub4.value2, COALESCE(sub4.value2, 66) as value3 FROM
    ( SELECT 1 as key3 ) sub3
    LEFT JOIN
    ( SELECT sub5.key5, COALESCE(sub6.value1, 1) as value2 FROM
        ( SELECT 1 as key5 ) sub5
        LEFT JOIN
        ( SELECT 2 as key6, 42 as value1 ) sub6
        ON sub5.key5 = sub6.key6
    ) sub4
    ON sub4.key5 = sub3.key3
) sub2
ON sub1.key1 = sub2.key3;

-- test the path using join aliases, too
--Testcase 250:
SELECT * FROM
( SELECT 1 as key1 ) sub1
LEFT JOIN
( SELECT sub3.key3, value2, COALESCE(value2, 66) as value3 FROM
    ( SELECT 1 as key3 ) sub3
    LEFT JOIN
    ( SELECT sub5.key5, COALESCE(sub6.value1, 1) as value2 FROM
        ( SELECT 1 as key5 ) sub5
        LEFT JOIN
        ( SELECT 2 as key6, 42 as value1 ) sub6
        ON sub5.key5 = sub6.key6
    ) sub4
    ON sub4.key5 = sub3.key3
) sub2
ON sub1.key1 = sub2.key3;

--
-- test case where a PlaceHolderVar is used as a nestloop parameter
--

--Testcase 251:
EXPLAIN (COSTS OFF)
SELECT qq, unique1
  FROM
  ( SELECT COALESCE(q1, 0) AS qq FROM int8_tbl a ) AS ss1
  FULL OUTER JOIN
  ( SELECT COALESCE(q2, -1) AS qq FROM int8_tbl b ) AS ss2
  USING (qq)
  INNER JOIN tenk1 c ON qq = unique2;

--Testcase 252:
SELECT qq, unique1
  FROM
  ( SELECT COALESCE(q1, 0) AS qq FROM int8_tbl a ) AS ss1
  FULL OUTER JOIN
  ( SELECT COALESCE(q2, -1) AS qq FROM int8_tbl b ) AS ss2
  USING (qq)
  INNER JOIN tenk1 c ON qq = unique2;

--
-- nested nestloops can require nested PlaceHolderVars
--

--Testcase 253:
create foreign table nt1 (
  id int,
  a1 boolean,
  a2 boolean
) server influxdb_svr;
--Testcase 254:
create foreign table nt2 (
  id int,
  nt1_id int,
  b1 boolean,
  b2 boolean
) server influxdb_svr;
--Testcase 255:
create foreign table nt3 (
  id int,
  nt2_id int,
  c1 boolean
) server influxdb_svr;

--Testcase 256:
insert into nt1 values (1,true,true);
--Testcase 257:
insert into nt1 values (2,true,false);
--Testcase 258:
insert into nt1 values (3,false,false);
--Testcase 259:
insert into nt2 values (1,1,true,true);
--Testcase 260:
insert into nt2 values (2,2,true,false);
--Testcase 261:
insert into nt2 values (3,3,false,false);
--Testcase 262:
insert into nt3 values (1,1,true);
--Testcase 263:
insert into nt3 values (2,2,false);
--Testcase 264:
insert into nt3 values (3,3,true);

--Testcase 265:
explain (costs off)
select nt3.id
from nt3 as nt3
  left join
    (select nt2.*, (nt2.b1 and ss1.a3) AS b3
     from nt2 as nt2
       left join
         (select nt1.*, (nt1.id is not null) as a3 from nt1) as ss1
         on ss1.id = nt2.nt1_id
    ) as ss2
    on ss2.id = nt3.nt2_id
where nt3.id = 1 and ss2.b3;

--Testcase 266:
select nt3.id
from nt3 as nt3
  left join
    (select nt2.*, (nt2.b1 and ss1.a3) AS b3
     from nt2 as nt2
       left join
         (select nt1.*, (nt1.id is not null) as a3 from nt1) as ss1
         on ss1.id = nt2.nt1_id
    ) as ss2
    on ss2.id = nt3.nt2_id
where nt3.id = 1 and ss2.b3;

--
-- test case where a PlaceHolderVar is propagated into a subquery
--

--Testcase 267:
explain (costs off)
select * from
  int8_tbl t1 left join
  (select q1 as x, 42 as y from int8_tbl t2) ss
  on t1.q2 = ss.x
where
  1 = (select 1 from int8_tbl t3 where ss.y is not null limit 1)
order by 1,2;

--Testcase 268:
select * from
  int8_tbl t1 left join
  (select q1 as x, 42 as y from int8_tbl t2) ss
  on t1.q2 = ss.x
where
  1 = (select 1 from int8_tbl t3 where ss.y is not null limit 1)
order by 1,2;

--
-- variant where a PlaceHolderVar is needed at a join, but not above the join
--

--Testcase 269:
explain (costs off)
select * from
  int4_tbl as i41,
  lateral
    (select 1 as x from
      (select i41.f1 as lat,
              i42.f1 as loc from
         int8_tbl as i81, int4_tbl as i42) as ss1
      right join int4_tbl as i43 on (i43.f1 > 1)
      where ss1.loc = ss1.lat) as ss2
where i41.f1 > 0;

--Testcase 270:
select * from
  int4_tbl as i41,
  lateral
    (select 1 as x from
      (select i41.f1 as lat,
              i42.f1 as loc from
         int8_tbl as i81, int4_tbl as i42) as ss1
      right join int4_tbl as i43 on (i43.f1 > 1)
      where ss1.loc = ss1.lat) as ss2
where i41.f1 > 0;

--
-- test the corner cases FULL JOIN ON TRUE and FULL JOIN ON FALSE
--
--Testcase 271:
select * from int4_tbl a full join int4_tbl b on true;
--Testcase 272:
select * from int4_tbl a full join int4_tbl b on false;

--
-- test for ability to use a cartesian join when necessary
--

--Testcase 273:
create foreign table q1 (q1 int) server influxdb_svr;
--Testcase 274:
create foreign table q2 (q2 int) server influxdb_svr;

--Testcase 275:
explain (costs off)
select * from
  tenk1 join int4_tbl on f1 = twothousand,
  q1, q2
where q1 = thousand or q2 = thousand;

--Testcase 276:
explain (costs off)
select * from
  tenk1 join int4_tbl on f1 = twothousand,
  q1, q2
where thousand = (q1 + q2);

--
-- test ability to generate a suitable plan for a star-schema query
--

--Testcase 277:
explain (costs off)
select * from
  tenk1, int8_tbl a, int8_tbl b
where thousand = a.q1 and tenthous = b.q1 and a.q2 = 1 and b.q2 = 2;

--
-- test a corner case in which we shouldn't apply the star-schema optimization
--

--Testcase 278:
explain (costs off)
select t1.unique2, t1.stringu1, t2.unique1, t2.stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (select 1,0 from onerow) v1(x1,x2)
               left join (select 3,1 from onerow) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on (i1.f1 = subq1.x2)
  on (t1.unique2 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = t2.unique1)
where t1.unique2 < 42 and t1.stringu1 > t2.stringu2;

--Testcase 279:
select t1.unique2, t1.stringu1, t2.unique1, t2.stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (select 1,0 from onerow) v1(x1,x2)
               left join (select 3,1 from onerow) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on (i1.f1 = subq1.x2)
  on (t1.unique2 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = t2.unique1)
where t1.unique2 < 42 and t1.stringu1 > t2.stringu2;

-- variant that isn't quite a star-schema case

--Testcase 280:
select ss1.d1 from
  tenk1 as t1
  inner join tenk1 as t2
  on t1.tenthous = t2.ten
  inner join
    int8_tbl as i8
    left join int4_tbl as i4
      inner join (select 64::information_schema.cardinal_number as d1
                  from tenk1 t3,
                       lateral (select abs(t3.unique1) + random()) ss0(x)
                  where t3.fivethous < 0) as ss1
      on i4.f1 = ss1.d1
    on i8.q1 = i4.f1
  on t1.tenthous = ss1.d1
where t1.unique1 < i4.f1;

-- this variant is foldable by the remove-useless-RESULT-RTEs code

--Testcase 281:
explain (costs off)
select t1.unique2, t1.stringu1, t2.unique1, t2.stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (values(1,0)) v1(x1,x2)
               left join (values(3,1)) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on (i1.f1 = subq1.x2)
  on (t1.unique2 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = t2.unique1)
where t1.unique2 < 42 and t1.stringu1 > t2.stringu2;

--Testcase 282:
select t1.unique2, t1.stringu1, t2.unique1, t2.stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (values(1,0)) v1(x1,x2)
               left join (values(3,1)) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on (i1.f1 = subq1.x2)
  on (t1.unique2 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = t2.unique1)
where t1.unique2 < 42 and t1.stringu1 > t2.stringu2;

-- Here's a variant that we can't fold too aggressively, though,
-- or we end up with noplace to evaluate the lateral PHV
--Testcase 283:
explain (verbose, costs off)
select * from
  (select 1 as x) ss1 left join (select 2 as y) ss2 on (true),
  lateral (select ss2.y as z limit 1) ss3;
--Testcase 284:
select * from
  (select 1 as x) ss1 left join (select 2 as y) ss2 on (true),
  lateral (select ss2.y as z limit 1) ss3;

-- Test proper handling of appendrel PHVs during useless-RTE removal
--Testcase 285:
explain (costs off)
select * from
  (select 0 as z) as t1
  left join
  (select true as a) as t2
  on true,
  lateral (select true as b
           union all
           select a as b) as t3
where b;

--Testcase 286:
select * from
  (select 0 as z) as t1
  left join
  (select true as a) as t2
  on true,
  lateral (select true as b
           union all
           select a as b) as t3
where b;

--
-- test inlining of immutable functions
--
--Testcase 287:
create function f_immutable_int4(i integer) returns integer as
$$ begin return i; end; $$ language plpgsql immutable;

-- check optimization of function scan with join
--Testcase 288:
explain (costs off)
select unique1 from tenk1, (select * from f_immutable_int4(1) x) x
where x = unique1;

--Testcase 289:
explain (verbose, costs off)
select unique1, x.*
from tenk1, (select *, random() from f_immutable_int4(1) x) x
where x = unique1;

--Testcase 290:
explain (costs off)
select unique1 from tenk1, f_immutable_int4(1) x where x = unique1;

--Testcase 291:
explain (costs off)
select unique1 from tenk1, lateral f_immutable_int4(1) x where x = unique1;

--Testcase 292:
explain (costs off)
select unique1, x from tenk1 join f_immutable_int4(1) x on unique1 = x;

--Testcase 293:
explain (costs off)
select unique1, x from tenk1 left join f_immutable_int4(1) x on unique1 = x;

--Testcase 294:
explain (costs off)
select unique1, x from tenk1 right join f_immutable_int4(1) x on unique1 = x;

--Testcase 295:
explain (costs off)
select unique1, x from tenk1 full join f_immutable_int4(1) x on unique1 = x;

-- check that pullup of a const function allows further const-folding
--Testcase 296:
explain (costs off)
select unique1 from tenk1, f_immutable_int4(1) x where x = 42;

-- test inlining of immutable functions with PlaceHolderVars
--Testcase 297:
explain (costs off)
select nt3.id
from nt3 as nt3
  left join
    (select nt2.*, (nt2.b1 or i4 = 42) AS b3
     from nt2 as nt2
       left join
         f_immutable_int4(0) i4
         on i4 = nt2.nt1_id
    ) as ss2
    on ss2.id = nt3.nt2_id
where nt3.id = 1 and ss2.b3;

--Testcase 298:
drop function f_immutable_int4(int);

-- test inlining when function returns composite

--Testcase 299:
create function mki8(bigint, bigint) returns int8_tbl as
$$select row($1,$2)::int8_tbl$$ language sql;

--Testcase 300:
create function mki4(int) returns int4_tbl as
$$select row($1)::int4_tbl$$ language sql;

--Testcase 301:
explain (verbose, costs off)
select * from mki8(1,2);
--Testcase 302:
select * from mki8(1,2);

--Testcase 303:
explain (verbose, costs off)
select * from mki4(42);
--Testcase 304:
select * from mki4(42);

--Testcase 305:
drop function mki8(bigint, bigint);
--Testcase 306:
drop function mki4(int);

--
-- test extraction of restriction OR clauses from join OR clause
-- (we used to only do this for indexable clauses)
--

--Testcase 307:
explain (costs off)
select * from tenk1 a join tenk1 b on
  (a.unique1 = 1 and b.unique1 = 2) or (a.unique2 = 3 and b.hundred = 4);
--Testcase 308:
explain (costs off)
select * from tenk1 a join tenk1 b on
  (a.unique1 = 1 and b.unique1 = 2) or (a.unique2 = 3 and b.ten = 4);
--Testcase 309:
explain (costs off)
select * from tenk1 a join tenk1 b on
  (a.unique1 = 1 and b.unique1 = 2) or
  ((a.unique2 = 3 or a.unique2 = 7) and b.hundred = 4);

--
-- test placement of movable quals in a parameterized join tree
--

--Testcase 310:
explain (costs off)
select * from tenk1 t1 left join
  (tenk1 t2 join tenk1 t3 on t2.thousand = t3.unique2)
  on t1.hundred = t2.hundred and t1.ten = t3.ten
where t1.unique1 = 1;

--Testcase 311:
explain (costs off)
select * from tenk1 t1 left join
  (tenk1 t2 join tenk1 t3 on t2.thousand = t3.unique2)
  on t1.hundred = t2.hundred and t1.ten + t2.ten = t3.ten
where t1.unique1 = 1;

--Testcase 312:
explain (costs off)
select count(*) from
  tenk1 a join tenk1 b on a.unique1 = b.unique2
  left join tenk1 c on a.unique2 = b.unique1 and c.thousand = a.thousand
  join int4_tbl on b.thousand = f1;

--Testcase 313:
select count(*) from
  tenk1 a join tenk1 b on a.unique1 = b.unique2
  left join tenk1 c on a.unique2 = b.unique1 and c.thousand = a.thousand
  join int4_tbl on b.thousand = f1;

--Testcase 314:
explain (costs off)
select b.unique1 from
  tenk1 a join tenk1 b on a.unique1 = b.unique2
  left join tenk1 c on b.unique1 = 42 and c.thousand = a.thousand
  join int4_tbl i1 on b.thousand = f1
  right join int4_tbl i2 on i2.f1 = b.tenthous
  order by 1;

--Testcase 315:
select b.unique1 from
  tenk1 a join tenk1 b on a.unique1 = b.unique2
  left join tenk1 c on b.unique1 = 42 and c.thousand = a.thousand
  join int4_tbl i1 on b.thousand = f1
  right join int4_tbl i2 on i2.f1 = b.tenthous
  order by 1;

--Testcase 316:
explain (costs off)
select * from
(
  select unique1, q1, coalesce(unique1, -1) + q1 as fault
  from int8_tbl left join tenk1 on (q2 = unique2)
) ss
where fault = 122
order by fault;

--Testcase 317:
select * from
(
  select unique1, q1, coalesce(unique1, -1) + q1 as fault
  from int8_tbl left join tenk1 on (q2 = unique2)
) ss
where fault = 122
order by fault;

--Testcase 318:
explain (costs off)
select * from
(values (1, array[10,20]), (2, array[20,30])) as v1(v1x,v1ys)
left join (values (1, 10), (2, 20)) as v2(v2x,v2y) on v2x = v1x
left join unnest(v1ys) as u1(u1y) on u1y = v2y;

--Testcase 319:
select * from
(values (1, array[10,20]), (2, array[20,30])) as v1(v1x,v1ys)
left join (values (1, 10), (2, 20)) as v2(v2x,v2y) on v2x = v1x
left join unnest(v1ys) as u1(u1y) on u1y = v2y;

--
-- test handling of potential equivalence clauses above outer joins
--

--Testcase 320:
explain (costs off)
select q1, unique2, thousand, hundred
  from int8_tbl a left join tenk1 b on q1 = unique2
  where coalesce(thousand,123) = q1 and q1 = coalesce(hundred,123);

--Testcase 321:
select q1, unique2, thousand, hundred
  from int8_tbl a left join tenk1 b on q1 = unique2
  where coalesce(thousand,123) = q1 and q1 = coalesce(hundred,123);

--Testcase 322:
explain (costs off)
select f1, unique2, case when unique2 is null then f1 else 0 end
  from int4_tbl a left join tenk1 b on f1 = unique2
  where (case when unique2 is null then f1 else 0 end) = 0;

--Testcase 323:
select f1, unique2, case when unique2 is null then f1 else 0 end
  from int4_tbl a left join tenk1 b on f1 = unique2
  where (case when unique2 is null then f1 else 0 end) = 0;

--
-- another case with equivalence clauses above outer joins (bug #8591)
--

--Testcase 324:
explain (costs off)
select a.unique1, b.unique1, c.unique1, coalesce(b.twothousand, a.twothousand)
  from tenk1 a left join tenk1 b on b.thousand = a.unique1                        left join tenk1 c on c.unique2 = coalesce(b.twothousand, a.twothousand)
  where a.unique2 < 10 and coalesce(b.twothousand, a.twothousand) = 44;

--Testcase 325:
select a.unique1, b.unique1, c.unique1, coalesce(b.twothousand, a.twothousand)
  from tenk1 a left join tenk1 b on b.thousand = a.unique1                        left join tenk1 c on c.unique2 = coalesce(b.twothousand, a.twothousand)
  where a.unique2 < 10 and coalesce(b.twothousand, a.twothousand) = 44;

--
-- check handling of join aliases when flattening multiple levels of subquery
--

--Testcase 326:
explain (verbose, costs off)
select foo1.join_key as foo1_id, foo3.join_key AS foo3_id, bug_field from
  (values (0),(1)) foo1(join_key)
left join
  (select join_key, bug_field from
    (select ss1.join_key, ss1.bug_field from
      (select f1 as join_key, 666 as bug_field from int4_tbl i1) ss1
    ) foo2
   left join
    (select unique2 as join_key from tenk1 i2) ss2
   using (join_key)
  ) foo3
using (join_key);

--Testcase 327:
select foo1.join_key as foo1_id, foo3.join_key AS foo3_id, bug_field from
  (values (0),(1)) foo1(join_key)
left join
  (select join_key, bug_field from
    (select ss1.join_key, ss1.bug_field from
      (select f1 as join_key, 666 as bug_field from int4_tbl i1) ss1
    ) foo2
   left join
    (select unique2 as join_key from tenk1 i2) ss2
   using (join_key)
  ) foo3
using (join_key);

--
-- test successful handling of nested outer joins with degenerate join quals
--
--Testcase 328:
create foreign table text_tbl(f1 text) server influxdb_svr;

--Testcase 329:
explain (verbose, costs off)
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 330:
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 331:
explain (verbose, costs off)
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2, int4_tbl i4b2) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 332:
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2, int4_tbl i4b2) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 333:
explain (verbose, costs off)
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2, int4_tbl i4b2
                 where q1 = f1) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 334:
select t1.* from
  text_tbl t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2, int4_tbl i4b2
                 where q1 = f1) b2
      on (i8.q1 = b2.q1)
    on (b2.d2 = b1.q2)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on (i8.q2 = i4.f1);

--Testcase 335:
explain (verbose, costs off)
select * from
  text_tbl t1
  inner join int8_tbl i8
  on i8.q2 = 456
  right join text_tbl t2
  on t1.f1 = 'doh!'
  left join int4_tbl i4
  on i8.q1 = i4.f1;

--Testcase 336:
select * from
  text_tbl t1
  inner join int8_tbl i8
  on i8.q2 = 456
  right join text_tbl t2
  on t1.f1 = 'doh!'
  left join int4_tbl i4
  on i8.q1 = i4.f1;

--
-- test for appropriate join order in the presence of lateral references
--

--Testcase 337:
explain (verbose, costs off)
select * from
  text_tbl t1
  left join int8_tbl i8
  on i8.q2 = 123,
  lateral (select i8.q1, t2.f1 from text_tbl t2 limit 1) as ss
where t1.f1 = ss.f1;

--Testcase 338:
select * from
  text_tbl t1
  left join int8_tbl i8
  on i8.q2 = 123,
  lateral (select i8.q1, t2.f1 from text_tbl t2 limit 1) as ss
where t1.f1 = ss.f1;

--Testcase 339:
explain (verbose, costs off)
select * from
  text_tbl t1
  left join int8_tbl i8
  on i8.q2 = 123,
  lateral (select i8.q1, t2.f1 from text_tbl t2 limit 1) as ss1,
  lateral (select ss1.* from text_tbl t3 limit 1) as ss2
where t1.f1 = ss2.f1;

--Testcase 340:
select * from
  text_tbl t1
  left join int8_tbl i8
  on i8.q2 = 123,
  lateral (select i8.q1, t2.f1 from text_tbl t2 limit 1) as ss1,
  lateral (select ss1.* from text_tbl t3 limit 1) as ss2
where t1.f1 = ss2.f1;

--Testcase 341:
explain (verbose, costs off)
select 1 from
  text_tbl as tt1
  inner join text_tbl as tt2 on (tt1.f1 = 'foo')
  left join text_tbl as tt3 on (tt3.f1 = 'foo')
  left join text_tbl as tt4 on (tt3.f1 = tt4.f1),
  lateral (select tt4.f1 as c0 from text_tbl as tt5 limit 1) as ss1
where tt1.f1 = ss1.c0;

--Testcase 342:
select 1 from
  text_tbl as tt1
  inner join text_tbl as tt2 on (tt1.f1 = 'foo')
  left join text_tbl as tt3 on (tt3.f1 = 'foo')
  left join text_tbl as tt4 on (tt3.f1 = tt4.f1),
  lateral (select tt4.f1 as c0 from text_tbl as tt5 limit 1) as ss1
where tt1.f1 = ss1.c0;

--
-- check a case in which a PlaceHolderVar forces join order
--

--Testcase 343:
explain (verbose, costs off)
select ss2.* from
  int4_tbl i41
  left join int8_tbl i8
    join (select i42.f1 as c1, i43.f1 as c2, 42 as c3
          from int4_tbl i42, int4_tbl i43) ss1
    on i8.q1 = ss1.c2
  on i41.f1 = ss1.c1,
  lateral (select i41.*, i8.*, ss1.* from text_tbl limit 1) ss2
where ss1.c2 = 0;

--Testcase 344:
select ss2.* from
  int4_tbl i41
  left join int8_tbl i8
    join (select i42.f1 as c1, i43.f1 as c2, 42 as c3
          from int4_tbl i42, int4_tbl i43) ss1
    on i8.q1 = ss1.c2
  on i41.f1 = ss1.c1,
  lateral (select i41.*, i8.*, ss1.* from text_tbl limit 1) ss2
where ss1.c2 = 0;

--
-- test successful handling of full join underneath left join (bug #14105)
--

--Testcase 345:
explain (costs off)
select * from
  (select 1 as id) as xx
  left join
    (tenk1 as a1 full join (select 1 as id) as yy on (a1.unique1 = yy.id))
  on (xx.id = coalesce(yy.id));

--Testcase 346:
select * from
  (select 1 as id) as xx
  left join
    (tenk1 as a1 full join (select 1 as id) as yy on (a1.unique1 = yy.id))
  on (xx.id = coalesce(yy.id));

--
-- test ability to push constants through outer join clauses
--

--Testcase 347:
explain (costs off)
  select * from int4_tbl a left join tenk1 b on f1 = unique2 where f1 = 0;

--Testcase 348:
explain (costs off)
  select * from tenk1 a full join tenk1 b using(unique2) where unique2 = 42;

--
-- test that quals attached to an outer join have correct semantics,
-- specifically that they don't re-use expressions computed below the join;
-- we force a mergejoin so that coalesce(b.q1, 1) appears as a join input
--

--Testcase 349:
set enable_hashjoin to off;
--Testcase 350:
set enable_nestloop to off;

--Testcase 351:
explain (verbose, costs off)
  select a.q2, b.q1
    from int8_tbl a left join int8_tbl b on a.q2 = coalesce(b.q1, 1)
    where coalesce(b.q1, 1) > 0;
--Testcase 352:
select a.q2, b.q1
  from int8_tbl a left join int8_tbl b on a.q2 = coalesce(b.q1, 1)
  where coalesce(b.q1, 1) > 0;

--Testcase 353:
reset enable_hashjoin;
--Testcase 354:
reset enable_nestloop;

--
-- test join removal
--

begin;

--Testcase 355:
CREATE FOREIGN TABLE a (id int, b_id int) SERVER influxdb_svr;
--Testcase 356:
CREATE FOREIGN TABLE b (id int, c_id int) SERVER influxdb_svr;
--Testcase 357:
CREATE FOREIGN TABLE c (id int) SERVER influxdb_svr;
--Testcase 358:
CREATE FOREIGN TABLE d (a int, b int) SERVER influxdb_svr;
--Testcase 359:
INSERT INTO a VALUES (0, 0), (1, NULL);
--Testcase 360:
INSERT INTO b VALUES (0, 0), (1, NULL);
--Testcase 361:
INSERT INTO c VALUES (0), (1);
--Testcase 362:
INSERT INTO d VALUES (1,3), (2,2), (3,1);

-- all three cases should be optimizable into a simple seqscan
--Testcase 363:
explain (costs off) SELECT a.* FROM a LEFT JOIN b ON a.b_id = b.id;
--Testcase 364:
explain (costs off) SELECT b.* FROM b LEFT JOIN c ON b.c_id = c.id;
--Testcase 365:
explain (costs off)
  SELECT a.* FROM a LEFT JOIN (b left join c on b.c_id = c.id)
  ON (a.b_id = b.id);

-- check optimization of outer join within another special join
--Testcase 366:
explain (costs off)
select id from a where id in (
	select b.id from b left join c on b.id = c.id
);

-- check that join removal works for a left join when joining a subquery
-- that is guaranteed to be unique by its GROUP BY clause
--Testcase 367:
explain (costs off)
select d.* from d left join (select * from b group by b.id, b.c_id) s
  on d.a = s.id and d.b = s.c_id;

-- similarly, but keying off a DISTINCT clause
--Testcase 368:
explain (costs off)
select d.* from d left join (select distinct * from b) s
  on d.a = s.id and d.b = s.c_id;

-- join removal is not possible when the GROUP BY contains a column that is
-- not in the join condition.  (Note: as of 9.6, we notice that b.id is a
-- primary key and so drop b.c_id from the GROUP BY of the resulting plan;
-- but this happens too late for join removal in the outer plan level.)
--Testcase 369:
explain (costs off)
select d.* from d left join (select * from b group by b.id, b.c_id) s
  on d.a = s.id;

-- similarly, but keying off a DISTINCT clause
--Testcase 370:
explain (costs off)
select d.* from d left join (select distinct * from b) s
  on d.a = s.id;

-- check join removal works when uniqueness of the join condition is enforced
-- by a UNION
--Testcase 371:
explain (costs off)
select d.* from d left join (select id from a union select id from b) s
  on d.a = s.id;

-- check join removal with a cross-type comparison operator
--Testcase 372:
explain (costs off)
select i8.* from int8_tbl i8 left join (select f1 from int4_tbl group by f1) i4
  on i8.q1 = i4.f1;

-- check join removal with lateral references
--Testcase 373:
explain (costs off)
select 1 from (select a.id FROM a left join b on a.b_id = b.id) q,
			  lateral generate_series(1, q.id) gs(i) where q.id = gs.i;

--Testcase 374:
DELETE FROM a;
--Testcase 375:
DELETE FROM b;
--Testcase 376:
DELETE FROM c;
--Testcase 377:
DELETE FROM d;
--Testcase 378:
DROP FOREIGN TABLE a;
--Testcase 379:
DROP FOREIGN TABLE b;
--Testcase 380:
DROP FOREIGN TABLE c;
--Testcase 381:
DROP FOREIGN TABLE d;
rollback;

--Testcase 382:
create foreign table parent (k int, pd int) server influxdb_svr;
--Testcase 383:
create foreign table child (k int, cd int) server influxdb_svr;
--Testcase 384:
insert into parent values (1, 10), (2, 20), (3, 30);
--Testcase 385:
insert into child values (1, 100), (4, 400);

-- this case is optimizable
--Testcase 386:
select p.* from parent p left join child c on (p.k = c.k);
--Testcase 387:
explain (costs off)
  select p.* from parent p left join child c on (p.k = c.k);

-- this case is not
--Testcase 388:
select p.*, linked from parent p
  left join (select c.*, true as linked from child c) as ss
  on (p.k = ss.k);
--Testcase 389:
explain (costs off)
  select p.*, linked from parent p
    left join (select c.*, true as linked from child c) as ss
    on (p.k = ss.k);

-- check for a 9.0rc1 bug: join removal breaks pseudoconstant qual handling
--Testcase 390:
select p.* from
  parent p left join child c on (p.k = c.k)
  where p.k = 1 and p.k = 2;
--Testcase 391:
explain (costs off)
select p.* from
  parent p left join child c on (p.k = c.k)
  where p.k = 1 and p.k = 2;

--Testcase 392:
select p.* from
  (parent p left join child c on (p.k = c.k)) join parent x on p.k = x.k
  where p.k = 1 and p.k = 2;
--Testcase 393:
explain (costs off)
select p.* from
  (parent p left join child c on (p.k = c.k)) join parent x on p.k = x.k
  where p.k = 1 and p.k = 2;

-- bug 5255: this is not optimizable by join removal
begin;

--Testcase 394:
CREATE FOREIGN TABLE a (id int) SERVER influxdb_svr;
--Testcase 395:
CREATE FOREIGN TABLE b (id int, a_id int) SERVER influxdb_svr;
--Testcase 396:
INSERT INTO a VALUES (0), (1);
--Testcase 397:
INSERT INTO b VALUES (0, 0), (1, NULL);

--Testcase 398:
SELECT * FROM b LEFT JOIN a ON (b.a_id = a.id) WHERE (a.id IS NULL OR a.id > 0);
--Testcase 399:
SELECT b.* FROM b LEFT JOIN a ON (b.a_id = a.id) WHERE (a.id IS NULL OR a.id > 0);

--Testcase 400:
DELETE FROM a;
--Testcase 401:
DELETE FROM b;
--Testcase 402:
DROP FOREIGN TABLE a;
--Testcase 403:
DROP FOREIGN TABLE b;
rollback;

-- another join removal bug: this is not optimizable, either
begin;

--Testcase 404:
create foreign table innertab (id int8, dat1 int8) server influxdb_svr;
--Testcase 405:
insert into innertab values(123, 42);

--Testcase 406:
SELECT * FROM
    (SELECT 1 AS x) ss1
  LEFT JOIN
    (SELECT q1, q2, COALESCE(dat1, q1) AS y
     FROM int8_tbl LEFT JOIN innertab ON q2 = id) ss2
  ON true;

-- Clean up
DELETE FROM innertab;
DROP FOREIGN TABLE innertab;

rollback;

-- another join removal bug: we must clean up correctly when removing a PHV
begin;

--Testcase 407:
create foreign table uniquetbl (f1 text) server influxdb_svr;

--Testcase 408:
explain (costs off)
select t1.* from
  uniquetbl as t1
  left join (select *, '***'::text as d1 from uniquetbl) t2
  on t1.f1 = t2.f1
  left join uniquetbl t3
  on t2.d1 = t3.f1;

--Testcase 409:
explain (costs off)
select t0.*
from
 text_tbl t0
 left join
   (select case t1.ten when 0 then 'doh!'::text else null::text end as case1,
           t1.stringu2
     from tenk1 t1
     join int4_tbl i4 ON i4.f1 = t1.unique2
     left join uniquetbl u1 ON u1.f1 = t1.string4) ss
  on t0.f1 = ss.case1
where ss.stringu2 !~* ss.case1;

--Testcase 410:
select t0.*
from
 text_tbl t0
 left join
   (select case t1.ten when 0 then 'doh!'::text else null::text end as case1,
           t1.stringu2
     from tenk1 t1
     join int4_tbl i4 ON i4.f1 = t1.unique2
     left join uniquetbl u1 ON u1.f1 = t1.string4) ss
  on t0.f1 = ss.case1
where ss.stringu2 !~* ss.case1;

rollback;

-- test case to expose miscomputation of required relid set for a PHV
--Testcase 411:
explain (verbose, costs off)
select i8.*, ss.v, t.unique2
  from int8_tbl i8
    left join int4_tbl i4 on i4.f1 = 1
    left join lateral (select i4.f1 + 1 as v) as ss on true
    left join tenk1 t on t.unique2 = ss.v
where q2 = 456;

--Testcase 412:
select i8.*, ss.v, t.unique2
  from int8_tbl i8
    left join int4_tbl i4 on i4.f1 = 1
    left join lateral (select i4.f1 + 1 as v) as ss on true
    left join tenk1 t on t.unique2 = ss.v
where q2 = 456;

-- bug #8444: we've historically allowed duplicate aliases within aliased JOINs

--Testcase 413:
select * from
  int8_tbl x join (int4_tbl x cross join int4_tbl y) j on q1 = f1; -- error
--Testcase 414:
select * from
  int8_tbl x join (int4_tbl x cross join int4_tbl y) j on q1 = y.f1; -- error
--Testcase 415:
select * from
  int8_tbl x join (int4_tbl x cross join int4_tbl y(ff)) j on q1 = f1; -- ok

--
-- Test hints given on incorrect column references are useful
--

--Testcase 416:
select t1.uunique1 from
  tenk1 t1 join tenk2 t2 on t1.two = t2.two; -- error, prefer "t1" suggestion
--Testcase 417:
select t2.uunique1 from
  tenk1 t1 join tenk2 t2 on t1.two = t2.two; -- error, prefer "t2" suggestion
--Testcase 418:
select uunique1 from
  tenk1 t1 join tenk2 t2 on t1.two = t2.two; -- error, suggest both at once

--
-- Take care to reference the correct RTE
--

--Testcase 556:
select atts.relid::regclass, s.* from pg_stats s join
    pg_attribute a on s.attname = a.attname and s.tablename =
    a.attrelid::regclass::text join (select unnest(indkey) attnum,
    indexrelid from pg_index i) atts on atts.attnum = a.attnum where
    schemaname != 'pg_catalog';

--
-- Test LATERAL
--

--Testcase 419:
select unique2, x.*
from tenk1 a, lateral (select * from int4_tbl b where f1 = a.unique1) x;
--Testcase 420:
explain (costs off)
  select unique2, x.*
  from tenk1 a, lateral (select * from int4_tbl b where f1 = a.unique1) x;
--Testcase 421:
select unique2, x.*
from int4_tbl x, lateral (select unique2 from tenk1 where f1 = unique1) ss;
--Testcase 422:
explain (costs off)
  select unique2, x.*
  from int4_tbl x, lateral (select unique2 from tenk1 where f1 = unique1) ss;
--Testcase 423:
explain (costs off)
  select unique2, x.*
  from int4_tbl x cross join lateral (select unique2 from tenk1 where f1 = unique1) ss;
--Testcase 424:
select unique2, x.*
from int4_tbl x left join lateral (select unique1, unique2 from tenk1 where f1 = unique1) ss on true;
--Testcase 425:
explain (costs off)
  select unique2, x.*
  from int4_tbl x left join lateral (select unique1, unique2 from tenk1 where f1 = unique1) ss on true;

-- check scoping of lateral versus parent references
-- the first of these should return int8_tbl.q2, the second int8_tbl.q1
--Testcase 426:
select *, (select r from (select q1 as q2) x, (select q2 as r) y) from int8_tbl;
--Testcase 427:
select *, (select r from (select q1 as q2) x, lateral (select q2 as r) y) from int8_tbl;

-- lateral with function in FROM
--Testcase 428:
select count(*) from tenk1 a, lateral generate_series(1,two) g;
--Testcase 429:
explain (costs off)
  select count(*) from tenk1 a, lateral generate_series(1,two) g;
--Testcase 430:
explain (costs off)
  select count(*) from tenk1 a cross join lateral generate_series(1,two) g;
-- don't need the explicit LATERAL keyword for functions
--Testcase 431:
explain (costs off)
  select count(*) from tenk1 a, generate_series(1,two) g;

-- lateral with UNION ALL subselect
--Testcase 432:
explain (costs off)
  select * from generate_series(100,200) g,
    lateral (select * from int8_tbl a where g = q1 union all
             select * from int8_tbl b where g = q2) ss;
--Testcase 433:
select * from generate_series(100,200) g,
  lateral (select * from int8_tbl a where g = q1 union all
           select * from int8_tbl b where g = q2) ss;

-- lateral with VALUES
--Testcase 434:
explain (costs off)
  select count(*) from tenk1 a,
    tenk1 b join lateral (values(a.unique1)) ss(x) on b.unique2 = ss.x;
--Testcase 435:
select count(*) from tenk1 a,
  tenk1 b join lateral (values(a.unique1)) ss(x) on b.unique2 = ss.x;

-- lateral with VALUES, no flattening possible
--Testcase 436:
explain (costs off)
  select count(*) from tenk1 a,
    tenk1 b join lateral (values(a.unique1),(-1)) ss(x) on b.unique2 = ss.x;
--Testcase 437:
select count(*) from tenk1 a,
  tenk1 b join lateral (values(a.unique1),(-1)) ss(x) on b.unique2 = ss.x;

-- lateral injecting a strange outer join condition
--Testcase 438:
explain (costs off)
  select * from int8_tbl a,
    int8_tbl x left join lateral (select a.q1 from int4_tbl y) ss(z)
      on x.q2 = ss.z
  order by a.q1, a.q2, x.q1, x.q2, ss.z;
--Testcase 439:
select * from int8_tbl a,
  int8_tbl x left join lateral (select a.q1 from int4_tbl y) ss(z)
    on x.q2 = ss.z
  order by a.q1, a.q2, x.q1, x.q2, ss.z;

-- lateral reference to a join alias variable
--Testcase 440:
select * from (select f1/2 as x from int4_tbl) ss1 join int4_tbl i4 on x = f1,
  lateral (select x) ss2(y);
--Testcase 441:
select * from (select f1 as x from int4_tbl) ss1 join int4_tbl i4 on x = f1,
  lateral (values(x)) ss2(y);
--Testcase 442:
select * from ((select f1/2 as x from int4_tbl) ss1 join int4_tbl i4 on x = f1) j,
  lateral (select x) ss2(y);

-- lateral references requiring pullup
--Testcase 443:
select * from (values(1)) x(lb),
  lateral generate_series(lb,4) x4;
--Testcase 444:
select * from (select f1/1000000000 from int4_tbl) x(lb),
  lateral generate_series(lb,4) x4;
--Testcase 445:
select * from (values(1)) x(lb),
  lateral (values(lb)) y(lbcopy);
--Testcase 446:
select * from (values(1)) x(lb),
  lateral (select lb from int4_tbl) y(lbcopy);
--Testcase 447:
select * from
  int8_tbl x left join (select q1,coalesce(q2,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (values(x.q1,y.q1,y.q2)) v(xq1,yq1,yq2);
--Testcase 448:
select * from
  int8_tbl x left join (select q1,coalesce(q2,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (select x.q1,y.q1,y.q2) v(xq1,yq1,yq2);
--Testcase 449:
select x.* from
  int8_tbl x left join (select q1,coalesce(q2,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (select x.q1,y.q1,y.q2) v(xq1,yq1,yq2);
--Testcase 450:
select v.* from
  (int8_tbl x left join (select q1,coalesce(q2,0) q2 from int8_tbl) y on x.q2 = y.q1)
  left join int4_tbl z on z.f1 = x.q2,
  lateral (select x.q1,y.q1 union all select x.q2,y.q2) v(vx,vy);
--Testcase 451:
select v.* from
  (int8_tbl x left join (select q1,(select coalesce(q2,0)) q2 from int8_tbl) y on x.q2 = y.q1)
  left join int4_tbl z on z.f1 = x.q2,
  lateral (select x.q1,y.q1 union all select x.q2,y.q2) v(vx,vy);
--Testcase 452:
select v.* from
  (int8_tbl x left join (select q1,(select coalesce(q2,0)) q2 from int8_tbl) y on x.q2 = y.q1)
  left join int4_tbl z on z.f1 = x.q2,
  lateral (select x.q1,y.q1 from onerow union all select x.q2,y.q2 from onerow) v(vx,vy);

--Testcase 453:
explain (verbose, costs off)
select * from
  int8_tbl a left join
  lateral (select *, a.q2 as x from int8_tbl b) ss on a.q2 = ss.q1;
--Testcase 454:
select * from
  int8_tbl a left join
  lateral (select *, a.q2 as x from int8_tbl b) ss on a.q2 = ss.q1;
--Testcase 455:
explain (verbose, costs off)
select * from
  int8_tbl a left join
  lateral (select *, coalesce(a.q2, 42) as x from int8_tbl b) ss on a.q2 = ss.q1;
--Testcase 456:
select * from
  int8_tbl a left join
  lateral (select *, coalesce(a.q2, 42) as x from int8_tbl b) ss on a.q2 = ss.q1;

-- lateral can result in join conditions appearing below their
-- real semantic level
--Testcase 457:
explain (verbose, costs off)
select * from int4_tbl i left join
  lateral (select * from int2_tbl j where i.f1 = j.f1) k on true;
--Testcase 458:
select * from int4_tbl i left join
  lateral (select * from int2_tbl j where i.f1 = j.f1) k on true;
--Testcase 459:
explain (verbose, costs off)
select * from int4_tbl i left join
  lateral (select coalesce(i) from int2_tbl j where i.f1 = j.f1) k on true;
--Testcase 460:
select * from int4_tbl i left join
  lateral (select coalesce(i) from int2_tbl j where i.f1 = j.f1) k on true;
--Testcase 461:
explain (verbose, costs off)
select * from int4_tbl a,
  lateral (
    select * from int4_tbl b left join int8_tbl c on (b.f1 = q1 and a.f1 = q2)
  ) ss;
--Testcase 462:
select * from int4_tbl a,
  lateral (
    select * from int4_tbl b left join int8_tbl c on (b.f1 = q1 and a.f1 = q2)
  ) ss;

-- lateral reference in a PlaceHolderVar evaluated at join level
--Testcase 463:
explain (verbose, costs off)
select * from
  int8_tbl a left join lateral
  (select b.q1 as bq1, c.q1 as cq1, least(a.q1,b.q1,c.q1) from
   int8_tbl b cross join int8_tbl c) ss
  on a.q2 = ss.bq1;
--Testcase 464:
select * from
  int8_tbl a left join lateral
  (select b.q1 as bq1, c.q1 as cq1, least(a.q1,b.q1,c.q1) from
   int8_tbl b cross join int8_tbl c) ss
  on a.q2 = ss.bq1;

-- case requiring nested PlaceHolderVars
--Testcase 465:
explain (verbose, costs off)
select * from
  int8_tbl c left join (
    int8_tbl a left join (select q1, coalesce(q2,42) as x from int8_tbl b) ss1
      on a.q2 = ss1.q1
    cross join
    lateral (select q1, coalesce(ss1.x,q2) as y from int8_tbl d) ss2
  ) on c.q2 = ss2.q1,
  lateral (select ss2.y offset 0) ss3;

-- case that breaks the old ph_may_need optimization
--Testcase 466:
explain (verbose, costs off)
select c.*,a.*,ss1.q1,ss2.q1,ss3.* from
  int8_tbl c left join (
    int8_tbl a left join
      (select q1, coalesce(q2,f1) as x from int8_tbl b, int4_tbl b2
       where q1 < f1) ss1
      on a.q2 = ss1.q1
    cross join
    lateral (select q1, coalesce(ss1.x,q2) as y from int8_tbl d) ss2
  ) on c.q2 = ss2.q1,
  lateral (select * from int4_tbl i where ss2.y > f1) ss3;

-- check processing of postponed quals (bug #9041)
--Testcase 467:
explain (verbose, costs off)
select * from
  (select 1 as x offset 0) x cross join (select 2 as y offset 0) y
  left join lateral (
    select * from (select 3 as z offset 0) z where z.z = x.x
  ) zz on zz.z = y.y;

-- check dummy rels with lateral references (bug #15694)
--Testcase 468:
explain (verbose, costs off)
select * from int8_tbl i8 left join lateral
  (select *, i8.q2 from int4_tbl where false) ss on true;
--Testcase 469:
explain (verbose, costs off)
select * from int8_tbl i8 left join lateral
  (select *, i8.q2 from int4_tbl i1, int4_tbl i2 where false) ss on true;

-- check handling of nested appendrels inside LATERAL
--Testcase 470:
select * from
  ((select 2 as v) union all (select 3 as v)) as q1
  cross join lateral
  ((select * from
      ((select 4 as v) union all (select 5 as v)) as q3)
   union all
   (select q1.v)
  ) as q2;

-- check the number of columns specified
SELECT * FROM (int8_tbl i cross join int4_tbl j) ss(a,b,c,d);

-- check we don't try to do a unique-ified semijoin with LATERAL
--Testcase 471:
explain (verbose, costs off)
select * from
  (values (0,9998), (1,1000)) v(id,x),
  lateral (select f1 from int4_tbl
           where f1 = any (select unique1 from tenk1
                           where unique2 = v.x offset 0)) ss;
--Testcase 472:
select * from
  (values (0,9998), (1,1000)) v(id,x),
  lateral (select f1 from int4_tbl
           where f1 = any (select unique1 from tenk1
                           where unique2 = v.x offset 0)) ss;

-- check proper extParam/allParam handling (this isn't exactly a LATERAL issue,
-- but we can make the test case much more compact with LATERAL)
--Testcase 473:
explain (verbose, costs off)
select * from (values (0), (1)) v(id),
lateral (select * from int8_tbl t1,
         lateral (select * from
                    (select * from int8_tbl t2
                     where q1 = any (select q2 from int8_tbl t3
                                     where q2 = (select greatest(t1.q1,t2.q2))
                                       and (select v.id=0)) offset 0) ss2) ss
         where t1.q1 = ss.q2) ss0;

--Testcase 474:
select * from (values (0), (1)) v(id),
lateral (select * from int8_tbl t1,
         lateral (select * from
                    (select * from int8_tbl t2
                     where q1 = any (select q2 from int8_tbl t3
                                     where q2 = (select greatest(t1.q1,t2.q2))
                                       and (select v.id=0)) offset 0) ss2) ss
         where t1.q1 = ss.q2) ss0;

-- test some error cases where LATERAL should have been used but wasn't
--Testcase 475:
select f1,g from int4_tbl a, (select f1 as g) ss;
--Testcase 476:
select f1,g from int4_tbl a, (select a.f1 as g) ss;
--Testcase 477:
select f1,g from int4_tbl a cross join (select f1 as g) ss;
--Testcase 478:
select f1,g from int4_tbl a cross join (select a.f1 as g) ss;
-- SQL:2008 says the left table is in scope but illegal to access here
--Testcase 479:
select f1,g from int4_tbl a right join lateral generate_series(0, a.f1) g on true;
--Testcase 480:
select f1,g from int4_tbl a full join lateral generate_series(0, a.f1) g on true;
-- check we complain about ambiguous table references
--Testcase 481:
select * from
  int8_tbl x cross join (int4_tbl x cross join lateral (select x.f1) ss);
-- LATERAL can be used to put an aggregate into the FROM clause of its query
--Testcase 482:
select 1 from tenk1 a, lateral (select max(a.unique1) from int4_tbl b) ss;

-- check behavior of LATERAL in UPDATE/DELETE

--Testcase 483:
create temp table xx1 as select f1 as x1, -f1 as x2 from int4_tbl;

-- error, can't do this:
--Testcase 484:
update xx1 set x2 = f1 from (select * from int4_tbl where f1 = x1) ss;
--Testcase 485:
update xx1 set x2 = f1 from (select * from int4_tbl where f1 = xx1.x1) ss;
-- can't do it even with LATERAL:
--Testcase 486:
update xx1 set x2 = f1 from lateral (select * from int4_tbl where f1 = x1) ss;
-- we might in future allow something like this, but for now it's an error:
--Testcase 487:
update xx1 set x2 = f1 from xx1, lateral (select * from int4_tbl where f1 = x1) ss;

-- also errors:
--Testcase 488:
delete from xx1 using (select * from int4_tbl where f1 = x1) ss;
--Testcase 489:
delete from xx1 using (select * from int4_tbl where f1 = xx1.x1) ss;
--Testcase 490:
delete from xx1 using lateral (select * from int4_tbl where f1 = x1) ss;

/*
-- Influx does not support partition table
--
-- test LATERAL reference propagation down a multi-level inheritance hierarchy
-- produced for a multi-level partitioned table hierarchy.
--
create table join_pt1 (a int, b int, c varchar) partition by range(a);
create table join_pt1p1 partition of join_pt1 for values from (0) to (100) partition by range(b);
create table join_pt1p2 partition of join_pt1 for values from (100) to (200);
create table join_pt1p1p1 partition of join_pt1p1 for values from (0) to (100);
insert into join_pt1 values (1, 1, 'x'), (101, 101, 'y');
create table join_ut1 (a int, b int, c varchar);
insert into join_ut1 values (101, 101, 'y'), (2, 2, 'z');
explain (verbose, costs off)
select t1.b, ss.phv from join_ut1 t1 left join lateral
              (select t2.a as t2a, t3.a t3a, least(t1.a, t2.a, t3.a) phv
					  from join_pt1 t2 join join_ut1 t3 on t2.a = t3.b) ss
              on t1.a = ss.t2a order by t1.a;
select t1.b, ss.phv from join_ut1 t1 left join lateral
              (select t2.a as t2a, t3.a t3a, least(t1.a, t2.a, t3.a) phv
					  from join_pt1 t2 join join_ut1 t3 on t2.a = t3.b) ss
              on t1.a = ss.t2a order by t1.a;

drop table join_pt1;
drop table join_ut1;

--
-- test estimation behavior with multi-column foreign key and constant qual
--

begin;

create table fkest (x integer, x10 integer, x10b integer, x100 integer);
insert into fkest select x, x/10, x/10, x/100 from generate_series(1,1000) x;
create unique index on fkest(x, x10, x100);
analyze fkest;

explain (costs off)
select * from fkest f1
  join fkest f2 on (f1.x = f2.x and f1.x10 = f2.x10b and f1.x100 = f2.x100)
  join fkest f3 on f1.x = f3.x
  where f1.x100 = 2;

alter table fkest add constraint fk
  foreign key (x, x10b, x100) references fkest (x, x10, x100);

explain (costs off)
select * from fkest f1
  join fkest f2 on (f1.x = f2.x and f1.x10 = f2.x10b and f1.x100 = f2.x100)
  join fkest f3 on f1.x = f3.x
  where f1.x100 = 2;

rollback;
*/

--
-- test that foreign key join estimation performs sanely for outer joins
--

begin;

--Testcase 491:
create foreign table fkest (a int, b int, c int) server influxdb_svr;
--Testcase 492:
create foreign table fkest1 (a int, b int) server influxdb_svr;

--Testcase 493:
insert into fkest select x/10, x%10, x from generate_series(1,1000) x;
--Testcase 494:
insert into fkest1 select x/10, x%10 from generate_series(1,1000) x;

--Testcase 495:
explain (costs off)
select *
from fkest f
  left join fkest1 f1 on f.a = f1.a and f.b = f1.b
  left join fkest1 f2 on f.a = f2.a and f.b = f2.b
  left join fkest1 f3 on f.a = f3.a and f.b = f3.b
where f.c = 1;

rollback;

--
-- test planner's ability to mark joins as unique
--

--Testcase 496:
create foreign table j1 (id int) server influxdb_svr;
--Testcase 497:
create foreign table j2 (id int) server influxdb_svr;
--Testcase 498:
create foreign table j3 (id int) server influxdb_svr;

--Testcase 499:
insert into j1 values(1),(2),(3);
--Testcase 500:
insert into j2 values(1),(2),(3);
--Testcase 501:
insert into j3 values(1),(1);

-- ensure join is properly marked as unique
--Testcase 502:
explain (verbose, costs off)
select * from j1 inner join j2 on j1.id = j2.id;

-- ensure join is not unique when not an equi-join
--Testcase 503:
explain (verbose, costs off)
select * from j1 inner join j2 on j1.id > j2.id;

-- ensure non-unique rel is not chosen as inner
--Testcase 504:
explain (verbose, costs off)
select * from j1 inner join j3 on j1.id = j3.id;

-- ensure left join is marked as unique
--Testcase 505:
explain (verbose, costs off)
select * from j1 left join j2 on j1.id = j2.id;

-- ensure right join is marked as unique
--Testcase 506:
explain (verbose, costs off)
select * from j1 right join j2 on j1.id = j2.id;

-- ensure full join is marked as unique
--Testcase 507:
explain (verbose, costs off)
select * from j1 full join j2 on j1.id = j2.id;

-- a clauseless (cross) join can't be unique
--Testcase 508:
explain (verbose, costs off)
select * from j1 cross join j2;

-- ensure a natural join is marked as unique
--Testcase 509:
explain (verbose, costs off)
select * from j1 natural join j2;

-- ensure a distinct clause allows the inner to become unique
--Testcase 510:
explain (verbose, costs off)
select * from j1
inner join (select distinct id from j3) j3 on j1.id = j3.id;

-- ensure group by clause allows the inner to become unique
--Testcase 511:
explain (verbose, costs off)
select * from j1
inner join (select id from j3 group by id) j3 on j1.id = j3.id;

--Testcase 512:
delete from j1;
--Testcase 513:
delete from j2;
--Testcase 514:
delete from j3;
--Testcase 515:
drop foreign table j1;
--Testcase 516:
drop foreign table j2;
--Testcase 517:
drop foreign table j3;

-- test more complex permutations of unique joins

--Testcase 518:
create foreign table j1 (id1 int, id2 int) server influxdb_svr;
--Testcase 519:
create foreign table j2 (id1 int, id2 int) server influxdb_svr;
--Testcase 520:
create foreign table j3 (id1 int, id2 int) server influxdb_svr;

--Testcase 521:
insert into j1 values(1,1),(1,2);
--Testcase 522:
insert into j2 values(1,1);
--Testcase 523:
insert into j3 values(1,1);

-- ensure there's no unique join when not all columns which are part of the
-- unique index are seen in the join clause
--Testcase 524:
explain (verbose, costs off)
select * from j1
inner join j2 on j1.id1 = j2.id1;

-- ensure proper unique detection with multiple join quals
--Testcase 525:
explain (verbose, costs off)
select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2;

-- ensure we don't detect the join to be unique when quals are not part of the
-- join condition
--Testcase 526:
explain (verbose, costs off)
select * from j1
inner join j2 on j1.id1 = j2.id1 where j1.id2 = 1;

-- as above, but for left joins.
--Testcase 527:
explain (verbose, costs off)
select * from j1
left join j2 on j1.id1 = j2.id1 where j1.id2 = 1;

-- validate logic in merge joins which skips mark and restore.
-- it should only do this if all quals which were used to detect the unique
-- are present as join quals, and not plain quals.
--Testcase 528:
set enable_nestloop to 0;
--Testcase 529:
set enable_hashjoin to 0;
--Testcase 530:
set enable_sort to 0;

-- create indexes that will be preferred over the PKs to perform the join
--create index j1_id1_idx on j1 (id1) where id1 % 1000 = 1;
--create index j2_id1_idx on j2 (id1) where id1 % 1000 = 1;

-- need an additional row in j2, if we want j2_id1_idx to be preferred
--Testcase 531:
insert into j2 values(1,2);
--analyze j2;

--Testcase 532:
explain (costs off) select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1;

--Testcase 533:
select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1;

-- Exercise array keys mark/restore B-Tree code
--Testcase 534:
explain (costs off) select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1 and j2.id1 = any (array[1]);

--Testcase 535:
select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1 and j2.id1 = any (array[1]);

-- Exercise array keys "find extreme element" B-Tree code
--Testcase 536:
explain (costs off) select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1 and j2.id1 >= any (array[1,5]);

--Testcase 537:
select * from j1
inner join j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where j1.id1 % 1000 = 1 and j2.id1 % 1000 = 1 and j2.id1 >= any (array[1,5]);

--Testcase 538:
reset enable_nestloop;
--Testcase 539:
reset enable_hashjoin;
--Testcase 540:
reset enable_sort;

--Testcase 541:
delete from j1;
--Testcase 542:
delete from j2;
--Testcase 543:
delete from j3;
--Testcase 544:
drop foreign table j1;
--Testcase 545:
drop foreign table j2;
--Testcase 546:
drop foreign table j3;

-- check that semijoin inner is not seen as unique for a portion of the outerrel
--Testcase 547:
CREATE FOREIGN TABLE onek (
  unique1   int4,
  unique2   int4,
  two       int4,
  four      int4,
  ten       int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd       int4,
  even      int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER influxdb_svr;

-- check that semijoin inner is not seen as unique for a portion of the outerrel
--Testcase 548:
explain (verbose, costs off)
select t1.unique1, t2.hundred
from onek t1, tenk1 t2
where exists (select 1 from tenk1 t3
              where t3.thousand = t1.unique1 and t3.tenthous = t2.hundred)
      and t1.unique1 < 1;

-- ... unless it actually is unique
--Testcase 549:
create table j3 as select unique1, tenthous from onek;
vacuum analyze j3;
--Testcase 550:
create unique index on j3(unique1, tenthous);

--Testcase 551:
explain (verbose, costs off)
select t1.unique1, t2.hundred
from onek t1, tenk1 t2
where exists (select 1 from j3
              where j3.unique1 = t1.unique1 and j3.tenthous = t2.hundred)
      and t1.unique1 < 1;

--Testcase 552:
drop table j3;

-- Clean up
DELETE FROM t1;
DELETE FROM t2;
DELETE FROM t3;
DELETE FROM tt1;
DELETE FROM tt2;
DELETE FROM tt3;
DELETE FROM tt4;
DELETE FROM tt5;
DELETE FROM tt6;
DELETE FROM xx;
DELETE FROM yy;
DELETE FROM zt1;
DELETE FROM zt2;
DELETE FROM nt1;
DELETE FROM nt2;
DELETE FROM nt3;
DELETE FROM parent;
DELETE FROM child;

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

--Testcase 553:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 554:
DROP SERVER influxdb_svr CASCADE;
--Testcase 555:
DROP EXTENSION influxdb_fdw CASCADE;
