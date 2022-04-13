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

-- import time column as timestamp and text type
-- IMPORT FOREIGN SCHEMA influxdb_schema FROM SERVER influxdb_svr INTO public;

--
-- JOIN
-- Test JOIN clauses
--

--Testcase 4:
CREATE FOREIGN TABLE J1_TBL (
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE j1_tbl_nsc (
  i integer,
  j integer,
  t text
) SERVER influxdb_svr OPTIONS (table 'j1_tbl');
--Testcase 5:
CREATE FOREIGN TABLE J2_TBL (
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE j2_tbl_nsc (
  i integer,
  k integer
) SERVER influxdb_svr OPTIONS (table 'j2_tbl');
--Testcase 6:
INSERT INTO j1_tbl_nsc VALUES (1, 4, 'one');
--Testcase 7:
INSERT INTO j1_tbl_nsc VALUES (2, 3, 'two');
--Testcase 8:
INSERT INTO j1_tbl_nsc VALUES (3, 2, 'three');
--Testcase 9:
INSERT INTO j1_tbl_nsc VALUES (4, 1, 'four');
--Testcase 10:
INSERT INTO j1_tbl_nsc VALUES (5, 0, 'five');
--Testcase 11:
INSERT INTO j1_tbl_nsc VALUES (6, 6, 'six');
--Testcase 12:
INSERT INTO j1_tbl_nsc VALUES (7, 7, 'seven');
--Testcase 13:
INSERT INTO j1_tbl_nsc VALUES (8, 8, 'eight');
--Testcase 14:
INSERT INTO j1_tbl_nsc VALUES (0, NULL, 'zero');
--Testcase 15:
INSERT INTO j1_tbl_nsc VALUES (NULL, NULL, 'null');
--Testcase 16:
INSERT INTO j1_tbl_nsc VALUES (NULL, 0, 'zero');
--Testcase 17:
INSERT INTO j2_tbl_nsc VALUES (1, -1);
--Testcase 18:
INSERT INTO j2_tbl_nsc VALUES (2, 2);
--Testcase 19:
INSERT INTO j2_tbl_nsc VALUES (3, -3);
--Testcase 20:
INSERT INTO j2_tbl_nsc VALUES (2, 4);
--Testcase 21:
INSERT INTO j2_tbl_nsc VALUES (5, -5);
--Testcase 22:
INSERT INTO j2_tbl_nsc VALUES (5, -5);
--Testcase 23:
INSERT INTO j2_tbl_nsc VALUES (0, NULL);
--InfluxDB does not accept NULL value
--INSERT INTO J2_TBL VALUES (NULL, NULL);
--Testcase 24:
INSERT INTO j2_tbl_nsc VALUES (NULL, 0);
--Testcase 25:
CREATE FOREIGN TABLE tenk1 (
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (table 'tenk', schemaless 'true');
--Does not support on Postgres 12
--ALTER TABLE tenk1 SET WITH OIDS;
--Testcase 26:
CREATE FOREIGN TABLE tenk2 (
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS (table 'tenk', schemaless 'true');

--Testcase 27:
CREATE FOREIGN TABLE INT4_TBL(fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
--Testcase 28:
CREATE FOREIGN TABLE FLOAT8_TBL(fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
--Testcase 29:
CREATE FOREIGN TABLE INT8_TBL(
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS(schemaless 'true');
--Testcase 30:
CREATE FOREIGN TABLE INT2_TBL(fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');

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
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) AS t1 (a, b, c);

--Testcase 36:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c);

--Testcase 37:
SELECT *
  FROM (SELECT (fields->>'i')::int, (fields->>'j')::int,fields->>'t' FROM J1_TBL) t1 (a, b, c), (SELECT (fields->>'i')::int ,(fields->>'k')::int FROM J2_TBL) t2 (d, e) ORDER BY t1.a, t1.b, t1.c, t2.d, t2.e;

--Testcase 38:
SELECT t1.a, t2.e
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c), (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (d, e)
  WHERE t1.a = t2.d;


--
-- CROSS JOIN
-- Qualifications are not allowed on cross joins,
-- which degenerate into a standard unqualified inner join.
--

--Testcase 39:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) J1_TBL CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) J2_TBL ORDER BY J1_TBL.i, J1_TBL.j, J1_TBL.t, J2_TBL.i, J2_TBL.k;

-- ambiguous column
--Testcase 40:
SELECT i, k, t
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) J1_TBL CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) J2_TBL ORDER BY J1_TBL.i, J1_TBL.j, J1_TBL.t, J2_TBL.i, J2_TBL.k;

-- resolve previous ambiguity by specifying the table name
--Testcase 41:
SELECT t1.i, k, t
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2  ORDER BY t1.i, t1.j, t1.t, t2.i, t2.k;

--Testcase 42:
SELECT ii, tt, kk
  FROM ((SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) J1_TBL CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) J2_TBL)
    AS tx (ii, jj, tt, ii2, kk) ORDER BY ii, tt, kk;

--Testcase 43:
SELECT tx.ii, tx.jj, tx.kk
  FROM ((SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c) CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (d, e))
    AS tx (ii, jj, tt, ii2, kk) ORDER BY tx.ii, tx.jj, tx.kk;

--Testcase 44:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) J1_TBL CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) a CROSS JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) b ORDER BY J1_TBL.i, J1_TBL.j, J1_TBL.t, a.i, a.k, b.i, b.k;


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
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL INNER JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i);

-- Same as above, slightly different syntax
--Testcase 46:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i);

--Testcase 47:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c) JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (a, d) USING (a)
  ORDER BY a, d;

--Testcase 48:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c) JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (a, b) USING (b)
  ORDER BY b, t1.a;

--
-- NATURAL JOIN
-- Inner equi-join on all columns with the same name
--

--Testcase 49:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL NATURAL JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL;

--Testcase 50:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c) NATURAL JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (a, d);

--Testcase 51:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j, fields->>'t' t FROM J1_TBL) t1 (a, b, c) NATURAL JOIN (SELECT (fields->>'i')::int i, (fields->>'k')::int k FROM J2_TBL) t2 (d, a);

-- mismatch number of columns
-- currently, Postgres will fill in with underlying names
--Testcase 52:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) t1 (a, b) NATURAL JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) t2 (a);


--
-- Inner joins (equi-joins)
--

--Testcase 53:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL JOIN (select (fields->>'i')::int i, (fields->>'k')::int k from J2_TBL) J2_TBL ON ((J1_TBL.i)::bigint = (J2_TBL.i)::bigint);

--Testcase 54:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL JOIN (select (fields->>'i')::int i, (fields->>'k')::int k from J2_TBL) J2_TBL ON ((J1_TBL.i)::bigint = (J2_TBL.k)::bigint);


--
-- Non-equi-joins
--

--Testcase 55:
SELECT *
  FROM (select (fields->>'i')::int i, (fields->>'j')::int j,fields->>'t' t from J1_TBL) J1_TBL JOIN (select (fields->>'i')::int i, (fields->>'k')::int k from J2_TBL) J2_TBL ON ((J1_TBL.i)::bigint <= (J2_TBL.k)::bigint) ORDER BY J1_TBL.i, J1_TBL.j, J1_TBL.t, J2_TBL.i, J2_TBL.k;


--
-- Outer joins
-- Note that OUTER is a noise word
--

--Testcase 56:
SELECT *
  FROM (SELECT (fields->>'i')::int i, (fields->>'j')::int j ,fields->>'t' t FROM J1_TBL) J1_TBL LEFT OUTER JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i)
  ORDER BY i, k, t;

--Testcase 57:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL LEFT JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i)
  ORDER BY i::int, k, t;

--Testcase 58:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL RIGHT OUTER JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i);

--Testcase 59:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL RIGHT JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i);

--Testcase 60:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL FULL OUTER JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i)
  ORDER BY i::int, k, t;

--Testcase 61:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL FULL JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i)
  ORDER BY i::int, k, t;

--Testcase 62:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL LEFT JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i) WHERE (k)::int = 1;

--Testcase 63:
SELECT *
  FROM (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL) J1_TBL LEFT JOIN (SELECT (fields->>'i')::int i,(fields->>'k')::int k FROM J2_TBL) J2_TBL USING (i) WHERE (i)::int = 1;

--
-- semijoin selectivity for <>
--
--Testcase 64:
explain (costs off)
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4, (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a
where exists(select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b
             where (a.twothousand)::int4 = (b.twothousand)::int4 and (a.fivethous)::int4 <> (b.fivethous)::int4)
      and (i4.f1)::int4 = (a.tenthous)::int4;


--
-- More complicated constructs
--

--
-- Multiway full join
--

--Testcase 65:
CREATE FOREIGN TABLE t1 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t1_nsc (name TEXT, n INTEGER) SERVER influxdb_svr OPTIONS (table 't1');
--Testcase 66:
CREATE FOREIGN TABLE t2 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t2_nsc (name TEXT, n INTEGER) SERVER influxdb_svr OPTIONS (table 't2');
--Testcase 67:
CREATE FOREIGN TABLE t3 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t3_nsc (name TEXT, n INTEGER) SERVER influxdb_svr OPTIONS (table 't3');
--Testcase 68:
INSERT INTO t1_nsc VALUES ( 'bb', 11 );
--Testcase 69:
INSERT INTO t2_nsc VALUES ( 'bb', 12 );
--Testcase 70:
INSERT INTO t2_nsc VALUES ( 'cc', 22 );
--Testcase 71:
INSERT INTO t2_nsc VALUES ( 'ee', 42 );
--Testcase 72:
INSERT INTO t3_nsc VALUES ( 'bb', 13 );
--Testcase 73:
INSERT INTO t3_nsc VALUES ( 'cc', 23 );
--Testcase 74:
INSERT INTO t3_nsc VALUES ( 'dd', 33 );
--Testcase 75:
SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t1) t1 FULL JOIN (select fields->>'name' "name", (fields->>'n')::int n from t2) t2 USING (name) FULL JOIN (select fields->>'name' "name", (fields->>'n')::int n from t3) t3 USING (name);

--
-- Test interactions of join syntax and subqueries
--

-- Basic cases (we expect planner to pull up the subquery here)
--Testcase 76:
SELECT * FROM
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t2) t2) as s2
INNER JOIN
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t3) t3) s3
USING (name);

--Testcase 77:
SELECT * FROM
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t2) t2) as s2
LEFT JOIN
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t3) t3) s3
USING (name);

--Testcase 78:
SELECT * FROM
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t2) t2) as s2
FULL JOIN
(SELECT * FROM (select fields->>'name' "name", (fields->>'n')::int n from t3) t3) s3
USING (name);

-- Cases with non-nullable expressions in subquery results;
-- make sure these go to null as expected
--Testcase 79:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL INNER JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 80:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL LEFT JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 81:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL FULL JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 82:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s1_n, 1 as s1_1 FROM t1) as s1
NATURAL INNER JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL INNER JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 83:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s1_n, 1 as s1_1 FROM t1) as s1
NATURAL FULL JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
NATURAL FULL JOIN
(SELECT fields->>'name' "name", (fields->>'n')::int as s3_n, 3 as s3_2 FROM t3) s3;

--Testcase 84:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s1_n FROM t1) as s1
NATURAL FULL JOIN
  (SELECT * FROM
    (SELECT fields->>'name' "name", (fields->>'n')::int as s2_n FROM t2) as s2
    NATURAL FULL JOIN
    (SELECT fields->>'name' "name", (fields->>'n')::int as s3_n FROM t3) as s3
  ) ss2;

--Testcase 85:
SELECT * FROM
(SELECT fields->>'name' "name", (fields->>'n')::int as s1_n FROM t1) as s1
NATURAL FULL JOIN
  (SELECT * FROM
    (SELECT fields->>'name' "name", (fields->>'n')::int as s2_n, 2 as s2_2 FROM t2) as s2
    NATURAL FULL JOIN
    (SELECT fields->>'name' "name", (fields->>'n')::int as s3_n FROM t3) as s3
  ) ss2;

-- Constants as join keys can also be problematic
--Testcase 86:
SELECT * FROM
  (SELECT fields->>'name' "name", (fields->>'n')::int as s1_n FROM t1) as s1
FULL JOIN
  (SELECT fields->>'name' "name", 2 as s2_n FROM t2) as s2
ON ((s1_n)::int = (s2_n)::int);


-- Test for propagation of nullability constraints into sub-joins

--Testcase 87:
create foreign table x (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table x_nsc (x1 int, x2 int) server influxdb_svr OPTIONS (table 'x');
--Testcase 88:
insert into x_nsc values (1,11);
--Testcase 89:
insert into x_nsc values (2,22);
--Testcase 90:
insert into x_nsc values (3,null);
--Testcase 91:
insert into x_nsc values (4,44);
--Testcase 92:
insert into x_nsc values (5,null);
--Testcase 93:
create foreign table y (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table y_nsc (y1 int, y2 int) server influxdb_svr OPTIONS (table 'y');
--Testcase 94:
insert into y_nsc values (1,111);
--Testcase 95:
insert into y_nsc values (2,222);
--Testcase 96:
insert into y_nsc values (3,333);
--Testcase 97:
insert into y_nsc values (4,null);
--Testcase 98:
select * from x;
--Testcase 99:
select * from y;

--Testcase 100:
select * from (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int and x2 is not null);
--Testcase 101:
select * from (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int and y2 is not null);

--Testcase 102:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int);
--Testcase 103:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int and x2 is not null);
--Testcase 104:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int and y2 is not null);
--Testcase 105:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int and xx2 is not null);
-- these should NOT give the same answers as above
--Testcase 106:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int) where (x2 is not null);
--Testcase 107:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int) where (y2 is not null);
--Testcase 108:
select * from ((select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) x left join (select (fields->>'y1')::int y1, (fields->>'y2')::int y2 from y) y on (x1::int = y1::int)) left join (select (fields->>'x1')::int x1, (fields->>'x2')::int x2 from x) xx(xx1,xx2)
on (x1::int = xx1::int) where (xx2 is not null);

--
-- regression test: check for bug with propagation of implied equality
-- to outside an IN
--
--Testcase 109:
select count(*) from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) a where unique1 in
  (select unique1 from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) b join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) c using (unique1)
   where b.unique2::int4 = 42);

--
-- regression test: check for failure to generate a plan with multiple
-- degenerate IN clauses
--
--Testcase 110:
select count(*) from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) x where
  (x.unique1)::int4 in (select (a.fields->>'f1')::int4 from int4_tbl a,float8_tbl b where (a.fields->>'f1')::int4=(b.fields->>'f1')::float8) and
  (x.unique1)::int4 = 0 and
  (x.unique1)::int4 in (select (aa.fields->>'f1')::int4 from int4_tbl aa,float8_tbl bb where (aa.fields->>'f1')::int4=(bb.fields->>'f1')::float8);

-- try that with GEQO too
begin;
--Testcase 111:
set geqo = on;
--Testcase 112:
set geqo_threshold = 2;
--Testcase 113:
select count(*) from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) x where
  (x.unique1)::int4 in (select a.f1 from (select (fields->>'f1')::int4 f1 from INT4_TBL) a,(select (fields->>'f1')::float8 f1 from FLOAT8_TBL) b where a.f1::int4=b.f1::float8) and
  (x.unique1)::int4 = 0 and
  (x.unique1)::int4 in (select aa.f1 from (select (fields->>'f1')::int4 f1 from INT4_TBL) aa,(select (fields->>'f1')::float8 f1 from FLOAT8_TBL) bb where aa.f1::int4=bb.f1::float8);
rollback;

--
-- regression test: be sure we cope with proven-dummy append rels
--
--Testcase 114:
create table b (aa int, bb int);

--Testcase 115:
explain (costs off)
select aa, bb, tenk1.unique1::int, tenk1.unique1::int
  from (select (fields->>'unique1')::int unique1, fields->>'unique2' unique2, fields->>'two' two, fields->>'four' four, fields->>'ten' ten, fields->>'twenty' twenty, fields->>'hundred' hundred, fields->>'thousand' thousand, fields->>'twothousand' twothousand, fields->>'fivethous' fivethous, fields->>'tenthous' tenthous, fields->>'odd' odd, fields->>'even' even, fields->>'stringu1' stringu1, fields->>'stringu2' stringu2, fields->>'string4' string4 from tenk1) tenk1 right join b on aa = tenk1.unique1::int
  where bb < bb and bb is null;

--Testcase 116:
select aa, bb, tenk1.unique1::int, tenk1.unique1::int
  from (select (fields->>'unique1')::int unique1, fields->>'unique2' unique2, fields->>'two' two, fields->>'four' four, fields->>'ten' ten, fields->>'twenty' twenty, fields->>'hundred' hundred, fields->>'thousand' thousand, fields->>'twothousand' twothousand, fields->>'fivethous' fivethous, fields->>'tenthous' tenthous, fields->>'odd' odd, fields->>'even' even, fields->>'stringu1' stringu1, fields->>'stringu2' stringu2, fields->>'string4' string4 from tenk1) tenk1 right join b on aa = tenk1.unique1::int
  where bb < bb and bb is null;

--Testcase 117:
drop table b;
--
-- regression test: check handling of empty-FROM subquery underneath outer join
--
--Testcase 118:
explain (costs off)
select (i1.fields->>'q1')::int8 q1, (i1.fields->>'q2')::int8 q2, (i2.fields->>'q1')::int8 q1, (i2.fields->>'q2')::int8 q2, x from int8_tbl i1 left join (int8_tbl i2 join
  (select 123 as x) ss on (i2.fields->>'q1')::int8 = x) on (i1.fields->>'q2')::int8 = (i2.fields->>'q2')::int8
order by 1, 2;

--Testcase 119:
select (i1.fields->>'q1')::int8 q1, (i1.fields->>'q2')::int8 q2, (i2.fields->>'q1')::int8 q1, (i2.fields->>'q2')::int8 q2, x from int8_tbl i1 left join (int8_tbl i2 join
  (select 123 as x) ss on (i2.fields->>'q1')::int8 = x) on (i1.fields->>'q2')::int8= (i2.fields->>'q2')::int8
order by 1, 2;

--
-- regression test: check a case where join_clause_is_movable_into() gives
-- an imprecise result, causing an assertion failure
--
--Testcase 120:
select count(*)
from
  (select (t3.fields->>'tenthous')::int4 as x1, coalesce((t1.fields->>'stringu1')::name, (t2.fields->>'stringu1')::name) as x2
   from tenk1 t1
   left join tenk1 t2 on (t1.fields->>'unique1')::int4 = (t2.fields->>'unique1')::int4
   join tenk1 t3 on (t1.fields->>'unique2')::int4 = (t3.fields->>'unique2')::int4) ss,
  tenk1 t4,
  tenk1 t5
where (t4.fields->>'thousand')::int4 = (t5.fields->>'unique1')::int4 and ss.x1 = (t4.fields->>'tenthous')::int4 and ss.x2 = (t5.fields->>'stringu1')::name;

--
-- regression test: check a case where we formerly missed including an EC
-- enforcement clause because it was expected to be handled at scan level
--
--Testcase 121:
explain (costs off)
select a.f1, b.f1, (t.fields->>'thousand')::int4 thousand, (t.fields->>'tenhous')::int4 tenthous from
  tenk1 t,
  (select sum((fields->>'f1')::int4)+1 as f1 from int4_tbl i4a) a,
  (select sum((fields->>'f1')::int4) as f1 from int4_tbl i4b) b
where b.f1 = (t.fields->>'thousand')::int4 and a.f1 = b.f1 and (a.f1+b.f1+999) = (t.fields->>'tenthous')::int4;

--Testcase 122:
select a.f1, b.f1, (t.fields->>'thousand')::int4 thousand, (t.fields->>'tenhous')::int4 tenthous from
  tenk1 t,
  (select sum((fields->>'f1')::int4)+1 as f1 from int4_tbl i4a) a,
   (select sum((fields->>'f1')::int4) as f1 from int4_tbl i4b) b
where b.f1 = (t.fields->>'thousand')::int4 and a.f1 = b.f1 and (a.f1+b.f1+999) = (t.fields->>'tenthous')::int4;

--
-- check a case where we formerly got confused by conflicting sort orders
-- in redundant merge join path keys
--
--Testcase 123:
explain (costs off)
select * from
  (SELECT (fields->>'i')::int i,(fields->>'j')::int j,fields->>'t' t FROM J1_TBL j1_tbl) j1_tbl full join
  (select * from (select (fields->>'i')::int i, (fields->>'k')::int k from J2_TBL j2_tbl) j2_tbl order by (j2_tbl.i)::int desc, (j2_tbl.k)::int asc) j2_tbl
  on (j1_tbl.i)::int = (j2_tbl.i)::int and (j1_tbl.i)::int = (j2_tbl.k)::int;

--Testcase 124:
select * from
  (select (fields->>'i')::int i, (fields->>'j')::int j,fields->>'t' t from J1_TBL j1_tbl) j1_tbl full join
  (select * from (select (fields->>'i')::int i, (fields->>'k')::int k from J2_TBL j2_tbl) j2_tbl order by (j2_tbl.i)::int desc, (j2_tbl.k)::int asc) j2_tbl
  on j1_tbl.i = j2_tbl.i and j1_tbl.i = j2_tbl.k;

--
-- a different check for handling of redundant sort keys in merge joins
--
--Testcase 125:
explain (costs off)
select count(*) from
  (select * from tenk1 x order by (x.fields->>'thousand')::int4, (x.fields->>'twothousand')::int4, (x.fields->>'fivethous')::int4) x
  left join
  (select * from tenk1 y order by (y.fields->>'unique2')::int4) y
  on (x.fields->>'thousand')::int4 = (y.fields->>'unique2')::int4 and (x.fields->>'twothousand')::int4 = (y.fields->>'hundred')::int4 and (x.fields->>'fivethous')::int4 = (y.fields->>'unique2')::int4;

--Testcase 126:
select count(*) from
  (select * from tenk1 x order by (x.fields->>'thousand')::int4, (x.fields->>'twothousand')::int4, (x.fields->>'fivethous')::int4) x
  left join
  (select * from tenk1 y order by (y.fields->>'unique2')::int4) y
  on (x.fields->>'thousand')::int4 = (y.fields->>'unique2')::int4 and (x.fields->>'twothousand')::int4 = (y.fields->>'hundred')::int4 and (x.fields->>'fivethous')::int4 = (y.fields->>'unique2')::int4;


--
-- Clean up
--

--Testcase 127:
DELETE FROM t1_nsc;
--Testcase 128:
DELETE FROM t2_nsc;
--Testcase 129:
DELETE FROM t3_nsc;
--Testcase 130:
DROP FOREIGN TABLE t1;
DROP FOREIGN TABLE t1_nsc;
--Testcase 131:
DROP FOREIGN TABLE t2;
DROP FOREIGN TABLE t2_nsc;
--Testcase 132:
DROP FOREIGN TABLE t3;
DROP FOREIGN TABLE t3_nsc;
--Testcase 133:
DELETE FROM j1_tbl_nsc;
DROP FOREIGN TABLE J1_TBL;
DROP FOREIGN TABLE j1_tbl_nsc;
--Testcase 134:
DELETE FROM j2_tbl_nsc;
DROP FOREIGN TABLE J2_TBL;
DROP FOREIGN TABLE j2_tbl_nsc;

DELETE FROM x_nsc;
DELETE FROM y_nsc;
DROP FOREIGN TABLE x_nsc;
DROP FOREIGN TABLE y_nsc;

-- Both DELETE and UPDATE allow the specification of additional tables
-- to "join" against to determine which rows should be modified.

--Testcase 135:
CREATE FOREIGN TABLE t1 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t1_nsc (a int, b int) SERVER influxdb_svr OPTIONS (table 't1');
--Testcase 136:
CREATE FOREIGN TABLE t2 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t2_nsc (a int, b int) SERVER influxdb_svr OPTIONS (table 't2');
--Testcase 137:
CREATE FOREIGN TABLE t3 (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE t3_nsc (x int, y int) SERVER influxdb_svr OPTIONS (table 't3');
--Testcase 138:
INSERT INTO t1_nsc VALUES (5, 10);
--Testcase 139:
INSERT INTO t1_nsc VALUES (15, 20);
--Testcase 140:
INSERT INTO t1_nsc VALUES (100, 100);
--Testcase 141:
INSERT INTO t1_nsc VALUES (200, 1000);
--Testcase 142:
INSERT INTO t2_nsc VALUES (200, 2000);
--Testcase 143:
INSERT INTO t3_nsc VALUES (5, 20);
--Testcase 144:
INSERT INTO t3_nsc VALUES (6, 7);
--Testcase 145:
INSERT INTO t3_nsc VALUES (7, 8);
--Testcase 146:
INSERT INTO t3_nsc VALUES (500, 100);
--Testcase 147:
ALTER TABLE t3 ADD time timestamp;
ALTER TABLE t3_nsc ADD time timestamp;
--Testcase 148:
SELECT (fields->>'x')::int x, (fields->>'y')::int y FROM t3;
--Testcase 149:
DELETE FROM t3_nsc USING t1_nsc table1 WHERE t3_nsc.x = table1.a;
--Testcase 150:
SELECT (fields->>'x')::int x, (fields->>'y')::int y FROM t3;
--Testcase 151:
DELETE FROM t3_nsc USING t1_nsc JOIN t2_nsc USING (a) WHERE t3_nsc.x > t1_nsc.a;
--Testcase 152:
SELECT (fields->>'x')::int x, (fields->>'y')::int y FROM t3;
--Testcase 153:
DELETE FROM t3_nsc USING t3_nsc t3_other WHERE t3_nsc.x = t3_other.x AND t3_nsc.y = t3_other.y;
--Testcase 154:
SELECT (fields->>'x')::int x, (fields->>'y')::int y FROM t3;

-- Test join against inheritance tree

--Testcase 155:
create temp table t2a () inherits (t2);

--Testcase 156:
insert into t2a values ('{"a": "200", "b": "2001"}');

--Testcase 157:
select * from (select (fields->>'a')::int a, (fields->>'b')::int b from t1) t1 left join (select (fields->>'a')::int a, (fields->>'b')::int b from t2) t2 on (t1.a::int = t2.a::int);

-- Test matching of column name with wrong alias

--Testcase 158:
select t1.x from (select (fields->>'a')::int a, (fields->>'b')::int b from t1) t1 join (select (fields->>'x')::int x, (fields->>'y')::int y from t3) t3 on (t1.a::int = t3.x::int);

--
-- regression test for 8.1 merge right join bug
--

--Testcase 159:
CREATE FOREIGN TABLE tt1 ( fields jsonb OPTIONS (fields 'true') ) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE tt1_nsc ( tt1_id int4, joincol int4 ) SERVER influxdb_svr OPTIONS (table 'tt1');
--Testcase 160:
INSERT INTO tt1_nsc VALUES (1, 11);
--Testcase 161:
INSERT INTO tt1_nsc VALUES (2, NULL);
--Testcase 162:
CREATE FOREIGN TABLE tt2 ( fields jsonb OPTIONS (fields 'true') ) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE tt2_nsc ( tt2_id int4, joincol int4 ) SERVER influxdb_svr OPTIONS (table 'tt2');
--Testcase 163:
INSERT INTO tt2_nsc VALUES (21, 11);
--Testcase 164:
INSERT INTO tt2_nsc VALUES (22, 11);
--Testcase 165:
set enable_hashjoin to off;
--Testcase 166:
set enable_nestloop to off;

-- these should give the same results

--Testcase 167:
select tt1.*, tt2.* from (select (fields->>'tt1_id')::int4 tt1_id, (fields->>'joincol')::int4 joincol from tt1) tt1 left join (select (fields->>'tt2_id')::int4 tt2_id, (fields->>'joincol')::int4 joincol from tt2) tt2 on tt1.joincol::int4 = tt2.joincol::int4;

--Testcase 168:
select tt1.*, tt2.* from (select (fields->>'tt2_id')::int4 tt2_id, (fields->>'joincol')::int4 joincol from tt2) tt2 right join (select (fields->>'tt1_id')::int4 tt1_id, (fields->>'joincol')::int4 joincol from tt1) tt1 on tt1.joincol::int4 = tt2.joincol::int4;

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
  where ((a.fields->>'hundred')::int4 = (b.fields->>'thousand')::int4) and ((b.fields->>'fivethous')::int4 % 10) < 10;
--Testcase 174:
select count(*) from tenk1 a, tenk1 b
  where ((a.fields->>'hundred')::int4 = (b.fields->>'thousand')::int4) and ((b.fields->>'fivethous')::int4 % 10) < 10;

--Testcase 175:
reset work_mem;
--Testcase 176:
reset enable_mergejoin;

--
-- regression test for 8.2 bug with improper re-ordering of left joins
--

--Testcase 177:
create foreign table tt3(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table tt3_nsc(f1 int, f2 text) server influxdb_svr OPTIONS (table 'tt3');
--Testcase 178:
insert into tt3_nsc select x, repeat('xyzzy', 100) from generate_series(1,10000) x;
--Testcase 179:
create foreign table tt4(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table tt4_nsc(f1 int) server influxdb_svr OPTIONS (table 'tt4');
--Testcase 180:
insert into tt4_nsc values (0),(1),(9999);
--Testcase 181:
SELECT (a.fields->>'f1')::int f1
FROM tt4 a
LEFT JOIN (
        SELECT (b.fields->>'f1')::int f1
        FROM tt3 b LEFT JOIN tt3 c ON ((b.fields->>'f1')::int = (c.fields->>'f1')::int)
        WHERE c.fields->>'f1' IS NULL
) AS d ON ((a.fields->>'f1')::int = (d.f1)::int)
WHERE d.f1 IS NULL;

--
-- regression test for proper handling of outer joins within antijoins
--

--Testcase 182:
create foreign table tt4x(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');

--Testcase 183:
explain (costs off)
select * from tt4x t1
where not exists (
  select 1 from tt4x t2
    left join tt4x t3 on (t2.fields->>'c3')::int = (t3.fields->>'c1')::int
    left join ( select (t5.fields->>'c1')::int as c1
                from tt4x t4 left join tt4x t5 on (t4.fields->>'c2')::int = (t5.fields->>'c1')::int
              ) a1 on (t3.fields->>'c2')::int = a1.c1
  where (t1.fields->>'c1')::int = (t2.fields->>'c2')::int
);

--
-- regression test for problems of the sort depicted in bug #3494
--

--Testcase 184:
create foreign table tt5(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table tt5_nsc(f1 int, f2 int) server influxdb_svr OPTIONS (table 'tt5');
--Testcase 185:
create foreign table tt6(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table tt6_nsc(f1 int, f2 int) server influxdb_svr OPTIONS (table 'tt6');
--Testcase 186:
insert into tt5_nsc values(1, 10);
--Testcase 187:
insert into tt5_nsc values(1, 11);
--Testcase 188:
insert into tt6_nsc values(1, 9);
--Testcase 189:
insert into tt6_nsc values(1, 2);
--Testcase 190:
insert into tt6_nsc values(2, 9);
--Testcase 191:
select * from (select (fields->>'f1')::int f1, (fields->>'f2')::int f2 from tt5) tt5,(select (fields->>'f1')::int f1, (fields->>'f2')::int f2 from tt6) tt6 where (tt5.f1)::int = (tt6.f1)::int and (tt5.f1)::int = (tt5.f2)::int - (tt6.f2)::int;

--
-- regression test for problems of the sort depicted in bug #3588
--

--Testcase 192:
create foreign table xx (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table xx_nsc (pkxx int) server influxdb_svr OPTIONS (table 'xx');
--Testcase 193:
create foreign table yy (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table yy_nsc (pkyy int, pkxx int) server influxdb_svr OPTIONS (table 'yy');
--Testcase 194:
insert into xx_nsc values (1);
--Testcase 195:
insert into xx_nsc values (2);
--Testcase 196:
insert into xx_nsc values (3);
--Testcase 197:
insert into yy_nsc values (101, 1);
--Testcase 198:
insert into yy_nsc values (201, 2);
--Testcase 199:
insert into yy_nsc values (301, NULL);
--Testcase 200:
select (yy.fields->>'pkyy')::int as yy_pkyy, (yy.fields->>'pkxx')::int as yy_pkxx, (yya.fields->>'pkyy')::int as yya_pkyy,
       (xxa.fields->>'pkxx')::int as xxa_pkxx, (xxb.fields->>'pkxx')::int as xxb_pkxx
from yy
     left join (SELECT * FROM yy where (fields->>'pkyy')::int = 101) as yya ON (yy.fields->>'pkyy')::int = (yya.fields->>'pkyy')::int
     left join xx xxa on (yya.fields->>'pkxx')::int = (xxa.fields->>'pkxx')::int
     left join xx xxb on coalesce ((xxa.fields->>'pkxx')::int, 1) = (xxb.fields->>'pkxx')::int ORDER BY yy_pkyy, yy_pkxx, yya_pkyy, xxa_pkxx, xxb_pkxx;

--
-- regression test for improper pushing of constants across outer-join clauses
-- (as seen in early 8.2.x releases)
--

--Testcase 201:
create foreign table zt1 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table zt1_nsc (f1 int) server influxdb_svr OPTIONS (table 'zt1');
--Testcase 202:
create foreign table zt2 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table zt2_nsc (f2 int) server influxdb_svr OPTIONS (table 'zt2');
--Testcase 203:
create foreign table zt3 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
--Testcase 204:
insert into zt1_nsc values(53);
--Testcase 205:
insert into zt2_nsc values(53);
--Testcase 206:
select * from
  (select (fields->>'f2')::int f2 from zt2) zt2 left join (select (fields->>'f3')::int f3 from zt3) zt3 on (f2::int = f3::int)
      left join (select (fields->>'f1')::int f1 from zt1) zt1 on (f3::int = f1::int)
where (f2)::int = 53;

--Testcase 207:
create temp view zv1 as select *,'dummy'::text AS junk from zt1;

--Testcase 208:
select * from
  (select (fields->>'f2')::int f2 from zt2) zt2 left join (select (fields->>'f3')::int f3 from zt3) zt3 on (f2::int = f3::int)
      left join zv1 on (f3::int = (zv1.fields->>'f1')::int)
where (f2)::int = 53;

--
-- regression test for improper extraction of OR indexqual conditions
-- (as seen in early 8.3.x releases)
--

--Testcase 209:
select a.unique2, a.ten, b.tenthous, b.unique2, b.hundred
from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) b on a.unique2 = b.tenthous
where (a.unique1)::int4 = 42 and
      ((b.unique2 is null and (a.ten)::int4 = 2) or (b.hundred)::int4 = 3);

--
-- test proper positioning of one-time quals in EXISTS (8.4devel bug)
--
--Testcase 210:
prepare foo(bool) as
  select count(*) from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) b
    on ((a.unique2)::int4 = (b.unique1)::int4 and exists
        (select 1 from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) c where (c.thousand)::int4 = (b.unique2)::int4 and $1));
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
create foreign table a (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
--Testcase 217:
create foreign table b (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');

--Testcase 218:
select * from (select (fields->>'i')::int i from a) a left join (select (fields->>'x')::int x, (fields->>'y')::int y from b) b on i::int = x::int and i::int = y::int and x::int = i::int;

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
from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t1 left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t2 on (t1.q2 = t2.q1)
group by t1.q2 order by 1;

--Testcase 229:
select (t1.fields->>'q2')::int8 q2, count(t2.*)
from int8_tbl t1 left join (select * from int8_tbl) t2 on ((t1.fields->>'q2')::int8 = (t2.fields->>'q1')::int8)
group by t1.fields->>'q2' order by 1;

--Testcase 230:
select (t1.fields->>'q2')::int8 q2, count(t2.*)
from int8_tbl t1 left join (select * from int8_tbl offset 0) t2 on ((t1.fields->>'q2')::int8 = (t2.fields->>'q1')::int8)
group by t1.fields->>'q2' order by 1;

--Testcase 231:
select (t1.fields->>'q2')::int8 q2, count(t2.*)
from int8_tbl t1 left join
  (select (fields->>'q1')::int8 q1, case when (fields->>'q2')::int8=1 then 1 else (fields->>'q2')::int8 end as q2 from int8_tbl) t2
  on ((t1.fields->>'q2')::int8 = t2.q1)
group by t1.fields->>'q2' order by 1;

--
-- test incorrect failure to NULL pulled-up subexpressions
--
begin;

--Testcase 232:
create foreign table a (
     fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table a_nsc (
     code char
) server influxdb_svr OPTIONS (table 'a');
--Testcase 233:
create foreign table b (
     fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table b_nsc (
     a char,
     num integer
) server influxdb_svr OPTIONS (table 'b');
--Testcase 234:
create foreign table c (
     fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table c_nsc (
     name char,
     a char
) server influxdb_svr OPTIONS (table 'c');
--Testcase 235:
insert into a_nsc (code) values ('p');
--Testcase 236:
insert into a_nsc (code) values ('q');
--Testcase 237:
insert into b_nsc (a, num) values ('p', 1);
--Testcase 238:
insert into b_nsc (a, num) values ('p', 2);
--Testcase 239:
insert into c_nsc (name, a) values ('A', 'p');
--Testcase 240:
insert into c_nsc (name, a) values ('B', 'q');
--Testcase 241:
insert into c_nsc (name, a) values ('C', null);
--Testcase 242:
select c.name, ss.code, ss.b_cnt, ss.const
from (select fields->>'name' "name", fields->>'a' a from c) c left join
  (select a.code, coalesce(b_grp.cnt, 0) as b_cnt, -1 as const
   from (select fields->>'code' code from a) a left join
     (select count(1) as cnt, b.fields->>'a' a from b group by b.fields->>'a') as b_grp
     on a.code = b_grp.a
  ) as ss
  on (c.a = ss.code)
order by c.name;

--Testcase 243:
DELETE FROM a_nsc;
--Testcase 244:
DELETE FROM b_nsc;
--Testcase 245:
DELETE FROM c_nsc;
--Testcase 246:
DROP FOREIGN TABLE a;
DROP FOREIGN TABLE a_nsc;
--Testcase 247:
DROP FOREIGN TABLE b;
DROP FOREIGN TABLE b_nsc;
--Testcase 248:
DROP FOREIGN TABLE c;
DROP FOREIGN TABLE c_nsc;
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
SELECT qq, (fields->>'unique1')::int4 unique1
  FROM
  ( SELECT COALESCE((fields->>'q1')::int8, 0) AS qq FROM int8_tbl a ) AS ss1
  FULL OUTER JOIN
  ( SELECT COALESCE((fields->>'q2')::int8, -1) AS qq FROM int8_tbl b ) AS ss2
  USING (qq)
  INNER JOIN tenk1 c ON qq = (fields->>'unique2')::int4;

--Testcase 252:
SELECT qq, (fields->>'unique1')::int4 unique1
  FROM
  ( SELECT COALESCE((fields->>'q1')::int8, 0) AS qq FROM int8_tbl a ) AS ss1
  FULL OUTER JOIN
  ( SELECT COALESCE((fields->>'q2')::int8, -1) AS qq FROM int8_tbl b ) AS ss2
  USING (qq)
  INNER JOIN tenk1 c ON qq = (fields->>'unique2')::int4;

--
-- nested nestloops can require nested PlaceHolderVars
--

--Testcase 253:
create foreign table nt1 (
  fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table nt1_nsc (
  id int,
  a1 boolean,
  a2 boolean
) server influxdb_svr OPTIONS (table 'nt1');
--Testcase 254:
create foreign table nt2 (
  fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table nt2_nsc (
  id int,
  nt1_id int,
  b1 boolean,
  b2 boolean
) server influxdb_svr OPTIONS (table 'nt2');
--Testcase 255:
create foreign table nt3 (
  fields jsonb OPTIONS (fields 'true')
) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table nt3_nsc (
  id int,
  nt2_id int,
  c1 boolean
) server influxdb_svr OPTIONS (table 'nt3');
--Testcase 256:
insert into nt1_nsc values (1,true,true);
--Testcase 257:
insert into nt1_nsc values (2,true,false);
--Testcase 258:
insert into nt1_nsc values (3,false,false);
--Testcase 259:
insert into nt2_nsc values (1,1,true,true);
--Testcase 260:
insert into nt2_nsc values (2,2,true,false);
--Testcase 261:
insert into nt2_nsc values (3,3,false,false);
--Testcase 262:
insert into nt3_nsc values (1,1,true);
--Testcase 263:
insert into nt3_nsc values (2,2,false);
--Testcase 264:
insert into nt3_nsc values (3,3,true);
--Testcase 265:
explain (costs off)
select (nt3.fields->>'id')::int id
from nt3 as nt3
  left join
    (select (nt2.fields->>'id')::int id, (nt2.fields->>'nt1_id')::int nt1_id, (nt2.fields->>'b1')::boolean b1, (nt2.fields->>'b2')::boolean b2, ((nt2.fields->>'b1')::boolean and ss1.a3) AS b3
     from nt2 as nt2
       left join
         (select (nt1.fields->>'id')::int id, (nt1.fields->>'a1')::boolean a1, (nt1.fields->>'a2')::boolean a2, ((nt1.fields->>'id')::int is not null) as a3 from nt1) as ss1
         on ss1.id = (nt2.fields->>'nt1_id')::int
    ) as ss2
    on ss2.id = (nt3.fields->>'nt2_id')::int
where (nt3.fields->>'id')::int = 1 and ss2.b3;

--Testcase 266:
select (nt3.fields->>'id')::int id
from nt3 as nt3
  left join
    (select (nt2.fields->>'id')::int id, (nt2.fields->>'nt1_id')::int nt1_id, (nt2.fields->>'b1')::boolean b1, (nt2.fields->>'b2')::boolean b2, ((nt2.fields->>'b1')::boolean and ss1.a3) AS b3
     from nt2 as nt2
       left join
         (select (nt1.fields->>'id')::int id, (nt1.fields->>'a1')::boolean a1, (nt1.fields->>'a2')::boolean a2, ((nt1.fields->>'id')::int is not null) as a3 from nt1) as ss1
         on ss1.id = (nt2.fields->>'nt1_id')::int
    ) as ss2
    on ss2.id = (nt3.fields->>'nt2_id')::int
where (nt3.fields->>'id')::int = 1 and ss2.b3;

--
-- test case where a PlaceHolderVar is propagated into a subquery
--

--Testcase 267:
explain (costs off)
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t1) t1 left join
  (select q1 as x, 42 as y from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t2) t2) ss
  on (t1.q2)::int8 = (ss.x)::int8
where
  1 = (select 1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t3) t3 where ss.y is not null limit 1)
order by 1,2;

--Testcase 268:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t1) t1 left join
  (select q1 as x, 42 as y from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t2) t2) ss
  on (t1.q2)::int8 = (ss.x)::int8
where
  1 = (select 1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL t3) t3 where ss.y is not null limit 1)
order by 1,2;

--
-- variant where a PlaceHolderVar is needed at a join, but not above the join
--

--Testcase 269:
explain (costs off)
select * from
  (select (fields->>'f1')::int4 f1 from INT4_TBL i41) as i41,
  lateral
    (select 1 as x from
      (select i41.f1 as lat,
              i42.f1 as loc from
         (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i81) as i81, (select (fields->>'f1')::int4 f1 from INT4_TBL i42) as i42) as ss1
      right join (select (fields->>'f1')::int4 f1 from INT4_TBL i43) as i43 on (i43.f1 > 1)
      where ss1.loc = ss1.lat) as ss2
where i41.f1 > 0;

--Testcase 270:
select * from
  (select (fields->>'f1')::int4 f1 from INT4_TBL i41) as i41,
  lateral
    (select 1 as x from
      (select i41.f1 as lat,
              i42.f1 as loc from
         (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i81) as i81, (select (fields->>'f1')::int4 f1 from INT4_TBL i42) as i42) as ss1
      right join (select (fields->>'f1')::int4 f1 from INT4_TBL i43) as i43 on (i43.f1 > 1)
      where ss1.loc = ss1.lat) as ss2
where i41.f1 > 0;

--
-- test the corner cases FULL JOIN ON TRUE and FULL JOIN ON FALSE
--
--Testcase 271:
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) a full join (select (fields->>'f1')::int4 f1 from INT4_TBL) b on true;
--Testcase 272:
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) a full join (select (fields->>'f1')::int4 f1 from INT4_TBL) b on false;

--
-- test for ability to use a cartesian join when necessary
--

--Testcase 273:
create foreign table q1 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
--Testcase 274:
create foreign table q2 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');

--Testcase 275:
explain (costs off)
select * from
  (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) tenk1 join (select (fields->>'f1')::int4 f1 from INT4_TBL) INT4_TBL on (f1)::int = (twothousand)::int,
   (select (fields->>'q1')::int q1 from q1) q1, (select (fields->>'q2')::int q2 from q2) q2
where (q1)::int = thousand::int or (q2)::int = thousand::int;

--Testcase 276:
explain (costs off)
select * from
  (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) tenk1 join (select (fields->>'f1')::int4 f1 from INT4_TBL) INT4_TBL on (f1)::int = (twothousand)::int,
  (select (fields->>'q1')::int q1 from q1) q1, (select (fields->>'q2')::int q2 from q2) q2
where (thousand)::int = ((q1)::int + (q2)::int);

--
-- test ability to generate a suitable plan for a star-schema query
--

--Testcase 277:
explain (costs off)
select * from
  (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 tenk1) tenk1, (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a, (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b
where thousand::int4 = a.q1::int8 and tenthous::int4 = b.q1::int8 and a.q2::int8 = 1 and b.q2::int8 = 2;

--
-- test a corner case in which we shouldn't apply the star-schema optimization
--

--Testcase 278:
explain (costs off)
select (t1.fields->>'unique2')::int4 unique2, (t1.fields->>'stringu1')::name stringu1, (t2.fields->>'unique1')::int4 unique1, (t2.fields->>'stringu2')::name stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (select 1,0 from onerow) v1(x1,x2)
               left join (select 3,1 from onerow) v2(y1,y2)
               on (v1.x1)::int4 = (v2.y2)::int4) subq1
    on ((i1.fields->>'f1')::int4 = (subq1.x2)::int4)
  on ((t1.fields->>'unique2')::int4 = (subq1.d1)::int4)
  left join tenk1 t2
  on ((subq1.y1)::int4 = (t2.fields->>'unique1')::int4)
where (t1.fields->>'unique2')::int4 < 42 and (t1.fields->>'stringu1')::name > t2.fields->>'stringu2';

--Testcase 279:
select (t1.fields->>'unique2')::int4 unique2, (t1.fields->>'stringu1')::name stringu1, (t2.fields->>'unique1')::int4 unique1, (t2.fields->>'stringu2')::name stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (select 1,0 from onerow) v1(x1,x2)
               left join (select 3,1 from onerow) v2(y1,y2)
               on (v1.x1)::int4 = (v2.y2)::int4) subq1
    on ((i1.fields->>'f1')::int4 = (subq1.x2)::int4)
  on ((t1.fields->>'unique2')::int4 = (subq1.d1)::int4)
  left join tenk1 t2
  on ((subq1.y1)::int4 = (t2.fields->>'unique1')::int4)
where (t1.fields->>'unique2')::int4 < 42 and (t1.fields->>'stringu1')::name > t2.fields->>'stringu2';

-- variant that isn't quite a star-schema case

--Testcase 280:
select ss1.d1 from
  tenk1 as t1
  inner join tenk1 as t2
  on (t1.fields->>'tenthous')::int4 = (t2.fields->>'ten')::int4
  inner join
    int8_tbl as i8
    left join int4_tbl as i4
      inner join (select 64::information_schema.cardinal_number as d1
                  from tenk1 t3,
                       lateral (select abs((t3.fields->>'unique1')::int4) + random()) ss0(x)
                  where (t3.fields->>'fivethous')::int4 < 0) as ss1
      on (i4.fields->>'f1')::int4 = ss1.d1
    on (i8.fields->>'q1')::int8 = (i4.fields->>'f1')::int4
  on (t1.fields->>'tenthous')::int4 = ss1.d1
where (t1.fields->>'unique1')::int4 < (i4.fields->>'f1')::int4;

-- this variant is foldable by the remove-useless-RESULT-RTEs code

--Testcase 281:
explain (costs off)
select (t1.fields->>'unique2')::int4 unique2, (t1.fields->>'stringu1')::name stringu1, (t2.fields->>'unique1')::int4 unique1, (t2.fields->>'stringu2')::name stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (values(1,0)) v1(x1,x2)
               left join (values(3,1)) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on ((i1.fields->>'f1')::int4 = subq1.x2)
  on ((t1.fields->>'unique2')::int4 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = (t2.fields->>'unique1')::int4)
where (t1.fields->>'unique2')::int4 < 42 and (t1.fields->>'stringu1')::name > (t2.fields->>'stringu2')::name;

--Testcase 282:
select (t1.fields->>'unique2')::int4 unique2, (t1.fields->>'stringu1')::name stringu1, (t2.fields->>'unique1')::int4 unique1, (t2.fields->>'stringu2')::name stringu2 from
  tenk1 t1
  inner join int4_tbl i1
    left join (select v1.x2, v2.y1, 11 AS d1
               from (values(1,0)) v1(x1,x2)
               left join (values(3,1)) v2(y1,y2)
               on v1.x1 = v2.y2) subq1
    on ((i1.fields->>'f1')::int4 = subq1.x2)
  on ((t1.fields->>'unique2')::int4 = subq1.d1)
  left join tenk1 t2
  on (subq1.y1 = (t2.fields->>'unique1')::int4)
where (t1.fields->>'unique2')::int4 < 42 and (t1.fields->>'stringu1')::name > (t2.fields->>'stringu2')::name;

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
select (fields->>'unique1')::int4 unique1 from tenk1, (select * from f_immutable_int4(1) x) x
where x = (fields->>'unique1')::int4;

--Testcase 289:
explain (verbose, costs off)
select (fields->>'unique1')::int4 unique1, x.*
from tenk1, (select *, random() from f_immutable_int4(1) x) x
where x = (fields->>'unique1')::int4;

--Testcase 290:
explain (costs off)
select (fields->>'unique1')::int4 unique1 from tenk1, f_immutable_int4(1) x where x = (fields->>'unique1')::int4;

--Testcase 291:
explain (costs off)
select (fields->>'unique1')::int4 unique1 from tenk1, lateral f_immutable_int4(1) x where x = (fields->>'unique1')::int4;

--Testcase 292:
explain (costs off)
select (fields->>'unique1')::int4 unique1, x from tenk1 join f_immutable_int4(1) x on (fields->>'unique1')::int4 = x;

--Testcase 293:
explain (costs off)
select (fields->>'unique1')::int4 unique1, x from tenk1 left join f_immutable_int4(1) x on (fields->>'unique1')::int4 = x;

--Testcase 294:
explain (costs off)
select (fields->>'unique1')::int4 unique1, x from tenk1 right join f_immutable_int4(1) x on (fields->>'unique1')::int4 = x;

--Testcase 295:
explain (costs off)
select (fields->>'unique1')::int4 unique1, x from tenk1 full join f_immutable_int4(1) x on (fields->>'unique1')::int4 = x;

-- check that pullup of a const function allows further const-folding
--Testcase 296:
explain (costs off)
select (fields->>'unique1')::int4 unique1 from tenk1, f_immutable_int4(1) x where x = 42;

-- test inlining of immutable functions with PlaceHolderVars
--Testcase 297:
explain (costs off)
select (nt3.fields->>'id')::int id
from nt3 as nt3
  left join
    (select nt2.*, ((nt2.fields->>'b1')::boolean or i4 = 42) AS b3
     from nt2 as nt2
       left join
         f_immutable_int4(0) i4
         on i4 = (nt2.fields->>'nt1_id')::int
    ) as ss2
    on (ss2.fields->>'id')::int = (nt3.fields->>'nt2_id')::int
where (nt3.fields->>'id')::int = 1 and (ss2.b3)::boolean;

--Testcase 298:
drop function f_immutable_int4(int);

-- test inlining when function returns composite

--Testcase 299:
create function mki8(bigint, bigint) returns int8_tbl as
$$select row('{"q1" : ' || cast($1 as text) || ', "q2" : ' || cast($2 as text) || '}')::int8_tbl$$ language sql;

--Testcase 300:
create function mki4(int) returns int4_tbl as
$$select row('{"f1" : ' || cast($1 as text) || '}')::int4_tbl$$ language sql;

--Testcase 301:
explain (verbose, costs off)
select * from mki8(1, 2);
--Testcase 302:
select * from mki8(1, 2);

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
select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on
  ((a.unique1)::int4 = 1 and (b.unique1)::int4 = 2) or ((a.unique2)::int4 = 3 and (b.hundred)::int4 = 4);
--Testcase 308:
explain (costs off)
select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on
  ((a.unique1)::int4 = 1 and (b.unique1)::int4 = 2) or ((a.unique2)::int4 = 3 and (b.ten)::int4 = 4);
--Testcase 309:
explain (costs off)
select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on
  ((a.unique1)::int4 = 1 and (b.unique1)::int4 = 2) or
  (((a.unique2)::int4 = 3 or (a.unique2)::int4 = 7) and (b.hundred)::int4 = 4);

--
-- test placement of movable quals in a parameterized join tree
--

--Testcase 310:
explain (costs off)
select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t1) t1 left join
  ((select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t2) t2 join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t3) t3 on (t2.thousand)::int4 = (t3.unique2)::int4)
  on (t1.hundred)::int4 = (t2.hundred)::int4 and (t1.ten)::int4 = (t3.ten)::int4
where (t1.unique1)::int4 = 1;

--Testcase 311:
explain (costs off)
select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t1) t1 left join
  ((select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t2) t2 join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 t3) t3 on (t2.thousand)::int4 = (t3.unique2)::int4)
  on (t1.hundred)::int4 = (t2.hundred)::int4 and (t1.ten)::int4 + (t2.ten)::int4 = (t3.ten)::int4
where (t1.unique1)::int4 = 1;

--Testcase 312:
explain (costs off)
select count(*) from
  (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (a.unique1)::int4 = (b.unique2)::int4
  left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 c) c on (a.unique2)::int4 = (b.unique1)::int4 and (c.thousand)::int4 = (a.thousand)::int4
  join (select (fields->>'f1')::int4 f1 from INT4_TBL) INT4_TBL on (b.thousand)::int4 = (f1)::int4;

--Testcase 313:
select count(*) from
  (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (a.unique1)::int4 = (b.unique2)::int4
  left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 c) c on (a.unique2)::int4 = (b.unique1)::int4 and (c.thousand)::int4 = (a.thousand)::int4
  join int4_tbl on (b.thousand)::int4 = (fields->>'f1')::int4;

--Testcase 314:
explain (costs off)
select (b.fields->>'unique1')::int4 unique1 from
  tenk1 a join tenk1 b on (a.fields->>'unique1')::int4 = (b.fields->>'unique2')::int4
  left join tenk1 c on (b.fields->>'unique1')::int4 = 42 and (c.fields->>'thousand')::int4 = (a.fields->>'thousand')::int4
  join (select (fields->>'f1')::int4 f1 from INT4_TBL i1) i1 on (b.fields->>'thousand')::int4 = (f1)::int4
  right join int4_tbl i2 on (i2.fields->>'f1')::int4 = (b.fields->>'tenthous')::int4
  order by 1;

--Testcase 315:
select (b.fields->>'unique1')::int4 unique1 from
  tenk1 a join tenk1 b on (a.fields->>'unique1')::int4 = (b.fields->>'unique2')::int4
  left join tenk1 c on (b.fields->>'unique1')::int4 = 42 and (c.fields->>'thousand')::int4 = (a.fields->>'thousand')::int4
  join (select (fields->>'f1')::int4 f1 from INT4_TBL i1) i1 on (b.fields->>'thousand')::int4 = (f1)::int4
  right join int4_tbl i2 on (i2.fields->>'f1')::int4 = (b.fields->>'tenthous')::int4
  order by 1;

--Testcase 316:
explain (costs off)
select * from
(
  select unique1, q1, coalesce((unique1)::int4, -1) + (q1)::int8 as fault
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) int8_tbl left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) tenk1 on ((q2)::int8 = (unique2)::int4)
) ss
where fault = 122
order by fault;

--Testcase 317:
select * from
(
  select unique1, q1, coalesce((unique1)::int4, -1) + (q1)::int8 as fault
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) int8_tbl left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) tenk1 on ((q2)::int8 = (unique2)::int4)
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
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (q1)::int8 = (unique2)::int4
  where coalesce((thousand)::int4,123) = (q1)::int8 and (q1)::int8 = coalesce((hundred)::int4,123);

--Testcase 321:
select q1, unique2, thousand, hundred
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (q1)::int8 = (unique2)::int4
  where coalesce((thousand)::int4,123) = (q1)::int8 and (q1)::int8 = coalesce((hundred)::int4,123);

--Testcase 322:
explain (costs off)
select f1, unique2, case when (unique2)::int4 is null then (f1)::int4 else 0 end
  from (select (fields->>'f1')::int4 f1 from INT4_TBL a) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (f1)::int4 = (unique2)::int4
  where (case when (unique2)::int4 is null then (f1)::int4 else 0 end) = 0;

--Testcase 323:
select f1, unique2, case when (unique2)::int4 is null then (f1)::int4 else 0 end
  from (select (fields->>'f1')::int4 f1 from INT4_TBL a) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (f1)::int4 = (unique2)::int4
  where (case when (unique2)::int4 is null then (f1)::int4 else 0 end) = 0;

--
-- another case with equivalence clauses above outer joins (bug #8591)
--

--Testcase 324:
explain (costs off)
select (a.fields->>'unique1')::int4 unique1, (b.fields->>'unique1')::int4 unique1, (c.fields->>'unique1')::int4 unique1, coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4)
  from tenk1 a left join tenk1 b on (b.fields->>'thousand')::int4 = (a.fields->>'unique1')::int4                        left join tenk1 c on (c.fields->>'unique2')::int4 = coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4)
  where (a.fields->>'unique2')::int4 < 10 and coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4) = 44;

--Testcase 325:
select (a.fields->>'unique1')::int4 unique1, (b.fields->>'unique1')::int4 unique1, (c.fields->>'unique1')::int4 unique1, coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4)
  from tenk1 a left join tenk1 b on (b.fields->>'thousand')::int4 = (a.fields->>'unique1')::int4                        left join tenk1 c on (c.fields->>'unique2')::int4 = coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4)
  where (a.fields->>'unique2')::int4 < 10 and coalesce((b.fields->>'twothousand')::int4, (a.fields->>'twothousand')::int4) = 44;

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
      (select (fields->>'f1')::int4 as join_key, 666 as bug_field from int4_tbl i1) ss1
    ) foo2
   left join
    (select (fields->>'unique2')::int4 as join_key from tenk1 i2) ss2
   using (join_key)
  ) foo3
using (join_key);

--Testcase 327:
select foo1.join_key as foo1_id, foo3.join_key AS foo3_id, bug_field from
  (values (0),(1)) foo1(join_key)
left join
  (select join_key, bug_field from
    (select ss1.join_key, ss1.bug_field from
      (select (fields->>'f1')::int4 as join_key, 666 as bug_field from int4_tbl i1) ss1
    ) foo2
   left join
    (select (fields->>'unique2')::int4 as join_key from tenk1 i2) ss2
   using (join_key)
  ) foo3
using (join_key);

--
-- test successful handling of nested outer joins with degenerate join quals
--
--Testcase 328:
create foreign table text_tbl(fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');

--Testcase 329:
explain (verbose, costs off)
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2) b2
      on ((i8.fields->>'q1')::int8 = (b2.fields->>'q1')::int8)
    on ((b2.d2)::int8 = (b1.fields->>'q2')::int8)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on ((i8.fields->>'q2')::int8 = (i4.fields->>'f1')::int4);

--Testcase 330:
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from int8_tbl i8b1) b1
    left join int8_tbl i8
      left join (select *, null::int as d2 from int8_tbl i8b2) b2
      on ((i8.fields->>'q1')::int8 = (b2.fields->>'q1')::int8)
    on ((b2.d2)::int8 = (b1.fields->>'q2')::int8)
  on (t1.f1 = b1.d1)
  left join int4_tbl i4
  on ((i8.fields->>'q2')::int8 = (i4.fields->>'f1')::int4);

--Testcase 331:
explain (verbose, costs off)
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b1) i8b1) b1
    left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
      left join (select *, null::int as d2 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b2) i8b2, (select (fields->>'f1')::int4 f1 from INT4_TBL i4b2) i4b2) b2
      on ((i8.q1)::int8 = (b2.q1)::int8)
    on ((b2.d2)::int8 = (b1.q2)::int8)
  on (t1.f1 = b1.d1)
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on ((i8.q2)::int8 = (i4.f1)::int4);

--Testcase 332:
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b1) i8b1) b1
    left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
      left join (select *, null::int as d2 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b2) i8b2, (select (fields->>'f1')::int4 f1 from INT4_TBL i4b2) i4b2) b2
      on ((i8.q1)::int8 = (b2.q1)::int8)
    on ((b2.d2)::int8 = (b1.q2)::int8)
  on (t1.f1 = b1.d1)
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on ((i8.q2)::int8 = (i4.f1)::int4);

--Testcase 333:
explain (verbose, costs off)
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b1) i8b1) b1
    left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
      left join (select *, null::int as d2 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b2) i8b2, (select (fields->>'f1')::int4 f1 from INT4_TBL i4b2) i4b2
                 where (q1)::int8 = (f1)::int8) b2
      on ((i8.q1)::int8 = (b2.q1)::int8)
    on ((b2.d2)::int8 = (b1.q2)::int8)
  on (t1.f1 = b1.d1)
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on ((i8.q2)::int8 = (i4.f1)::int4);

--Testcase 334:
select t1.* from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select *, '***'::text as d1 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b1) i8b1) b1
    left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
      left join (select *, null::int as d2 from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8b2) i8b2, (select (fields->>'f1')::int4 f1 from INT4_TBL i4b2) i4b2
                 where (q1)::int8 = (f1)::int8) b2
      on ((i8.q1)::int8 = (b2.q1)::int8)
    on ((b2.d2)::int8 = (b1.q2)::int8)
  on (t1.f1 = b1.d1)
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on ((i8.q2)::int8 = (i4.f1)::int4);

--Testcase 335:
explain (verbose, costs off)
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  inner join (select (fields->>'q1')::int8 q1, fields->>'q2' q2 from INT8_TBL i8) i8
  on (i8.q2)::bigint = 456
  right join (select fields->>'f1' f1 from text_tbl t2) t2
  on t1.f1 = 'doh!'
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on i8.q1 = i4.f1;

--Testcase 336:
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  inner join (select (fields->>'q1')::int8 q1, fields->>'q2' q2 from INT8_TBL i8) i8
  on (i8.q2)::bigint = 456
  right join (select fields->>'f1' f1 from text_tbl t2) t2
  on t1.f1 = 'doh!'
  left join (select (fields->>'f1')::int4 f1 from INT4_TBL i4) i4
  on i8.q1 = i4.f1;

--
-- test for appropriate join order in the presence of lateral references
--

--Testcase 337:
explain (verbose, costs off)
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
  on (i8.q2)::int8 = 123,
  lateral (select i8.q1, t2.fields->>'f1' f1 from text_tbl t2 limit 1) as ss
where t1.f1 = ss.f1;

--Testcase 338:
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
  on (i8.q2)::int8 = 123,
  lateral (select i8.q1, t2.fields->>'f1' f1 from text_tbl t2 limit 1) as ss
where t1.f1 = ss.f1;

--Testcase 339:
explain (verbose, costs off)
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
  on (i8.q2)::bigint = 123,
  lateral (select i8.q1, t2.fields->>'f1' f1 from text_tbl t2 limit 1) as ss1,
  lateral (select ss1.* from text_tbl t3 limit 1) as ss2
where t1.f1 = ss2.f1;

--Testcase 340:
select * from
  (select fields->>'f1' f1 from text_tbl t1) t1
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
  on (i8.q2)::bigint = 123,
  lateral (select i8.q1, t2.fields->>'f1' f1 from text_tbl t2 limit 1) as ss1,
  lateral (select ss1.* from text_tbl t3 limit 1) as ss2
where t1.f1 = ss2.f1;

--Testcase 341:
explain (verbose, costs off)
select 1 from
  text_tbl as tt1
  inner join text_tbl as tt2 on (tt1.fields->>'f1' = 'foo')
  left join text_tbl as tt3 on (tt3.fields->>'f1' = 'foo')
  left join text_tbl as tt4 on (tt3.fields->>'f1' = tt4.fields->>'f1'),
  lateral (select tt4.fields->>'f1' as c0 from text_tbl as tt5 limit 1) as ss1
where tt1.fields->>'f1' = ss1.c0;

--Testcase 342:
select 1 from
  text_tbl as tt1
  inner join text_tbl as tt2 on (tt1.fields->>'f1' = 'foo')
  left join text_tbl as tt3 on (tt3.fields->>'f1' = 'foo')
  left join text_tbl as tt4 on (tt3.fields->>'f1' = tt4.fields->>'f1'),
  lateral (select tt4.fields->>'f1' as c0 from text_tbl as tt5 limit 1) as ss1
where tt1.fields->>'f1' = ss1.c0;

--
-- check a case in which a PlaceHolderVar forces join order
--

--Testcase 343:
explain (verbose, costs off)
select ss2.* from
  (select (fields->>'f1')::int4 f1 from INT4_TBL) i41
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) i8
    join (select i42.fields->>'f1' as c1, i43.fields->>'f1' as c2, 42 as c3
          from int4_tbl i42, int4_tbl i43) ss1
    on (i8.q1)::int8 = (ss1.c2)::int8
  on (i41.f1)::int4 = (ss1.c1)::int4,
  lateral (select i41.*, i8.*, ss1.* from text_tbl limit 1) ss2
where (ss1.c2)::int8 = 0;

--Testcase 344:
select ss2.* from
  (select (fields->>'f1')::int4 f1 from INT4_TBL) i41
  left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) i8
    join (select i42.fields->>'f1' as c1, i43.fields->>'f1' as c2, 42 as c3
          from int4_tbl i42, int4_tbl i43) ss1
    on (i8.q1)::int8 = (ss1.c2)::int8
  on (i41.f1)::int4 = (ss1.c1)::int4,
  lateral (select i41.*, i8.*, ss1.* from text_tbl limit 1) ss2
where (ss1.c2)::int8 = 0;

--
-- test successful handling of full join underneath left join (bug #14105)
--

--Testcase 345:
explain (costs off)
select * from
  (select 1 as id) as xx
  left join
    ((select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a1) as a1 full join (select 1 as id) as yy on ((a1.unique1)::int4 = yy.id))
  on (xx.id = coalesce(yy.id));

--Testcase 346:
select * from
  (select 1 as id) as xx
  left join
    ((select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1) as a1 full join (select 1 as id) as yy on ((a1.unique1)::int4 = yy.id))
  on (xx.id = coalesce(yy.id));

--
-- test ability to push constants through outer join clauses
--

--Testcase 347:
explain (costs off)
  select * from (select (fields->>'f1')::int4 f1 from INT4_TBL a) a left join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b on (f1)::int4 = (unique2)::int4 where (f1)::int4 = 0;

--Testcase 348:
explain (costs off)
  select * from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 a) a full join (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, (fields->>'two')::int4 two, (fields->>'four')::int4 four, (fields->>'ten')::int4 ten, (fields->>'twenty')::int4 twenty, (fields->>'hundred')::int4 hundred, (fields->>'thousand')::int4 thousand, (fields->>'twothousand')::int4 twothousand, (fields->>'fivethous')::int4 fivethous, (fields->>'tenthous')::int4 tenthous, (fields->>'odd')::int4 odd, (fields->>'even')::int4 even, (fields->>'stringu1')::name stringu1, (fields->>'stringu2')::name stringu2, (fields->>'string4')::name string4 from tenk1 b) b using(unique2) where (unique2)::int4 = 42;

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
  select (a.fields->>'q2')::int8 q2, (b.fields->>'q1')::int8 q1
    from int8_tbl a left join int8_tbl b on (a.fields->>'q2')::int8 = coalesce((b.fields->>'q1')::int8, 1)
    where coalesce((b.fields->>'q1')::int8, 1) > 0;
--Testcase 352:
select (a.fields->>'q2')::int8 q2, (b.fields->>'q1')::int8 q1
  from int8_tbl a left join int8_tbl b on (a.fields->>'q2')::int8 = coalesce((b.fields->>'q1')::int8, 1)
  where coalesce((b.fields->>'q1')::int8, 1) > 0;

--Testcase 353:
reset enable_hashjoin;
--Testcase 354:
reset enable_nestloop;

--
-- test join removal
--

begin;

--Testcase 355:
CREATE FOREIGN TABLE a (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE a_nsc (id int, b_id int) SERVER influxdb_svr OPTIONS (table 'a');
--Testcase 356:
CREATE FOREIGN TABLE b (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE b_nsc (id int, c_id int) SERVER influxdb_svr OPTIONS (table 'b');
--Testcase 357:
CREATE FOREIGN TABLE c (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE c_nsc (id int) SERVER influxdb_svr OPTIONS (table 'c');
--Testcase 358:
CREATE FOREIGN TABLE d (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE d_nsc (a int, b int) SERVER influxdb_svr OPTIONS (table 'd');
--Testcase 359:
INSERT INTO a_nsc VALUES (0, 0), (1, NULL);
--Testcase 360:
INSERT INTO b_nsc VALUES (0, 0), (1, NULL);
--Testcase 361:
INSERT INTO c_nsc VALUES (0), (1);
--Testcase 362:
INSERT INTO d_nsc VALUES (1,3), (2,2), (3,1);
-- all three cases should be optimizable into a simple seqscan
--Testcase 363:
explain (costs off) SELECT a.* FROM (select (fields->>'id')::int id, (fields->>'b_id')::int b_id from a) a LEFT JOIN (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b ON a.b_id = b.id;
--Testcase 364:
explain (costs off) SELECT b.* FROM (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b LEFT JOIN (select (fields->>'id')::int id from c) c ON b.c_id = c.id;
--Testcase 365:
explain (costs off)
  SELECT a.* FROM (select (fields->>'id')::int id, (fields->>'b_id')::int b_id from a) a LEFT JOIN ((select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b left join (select (fields->>'id')::int id from c) c on b.c_id = c.id)
  ON (a.b_id = b.id);

-- check optimization of outer join within another special join
--Testcase 366:
explain (costs off)
select (fields->>'id')::int id from a where (fields->>'id')::int in (
	select (b.fields->>'id')::int from b left join c on (b.fields->>'id')::int = (c.fields->>'id')::int
);

-- check that join removal works for a left join when joining a subquery
-- that is guaranteed to be unique by its GROUP BY clause
--Testcase 367:
explain (costs off)
select d.* from (select (fields->>'a')::int a, (fields->>'b')::int b from d) d left join (select * from (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b group by b.id, b.c_id) s
  on (d.a)::int = (s.id)::int and (d.b)::int = (s.c_id)::int;

-- similarly, but keying off a DISTINCT clause
--Testcase 368:
explain (costs off)
select d.* from (select (fields->>'a')::int a, (fields->>'b')::int b from d) d left join (select distinct * from (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b) s
  on (d.a)::int = (s.id)::int and (d.b)::int = (s.c_id)::int;

-- join removal is not possible when the GROUP BY contains a column that is
-- not in the join condition.  (Note: as of 9.6, we notice that b.id is a
-- primary key and so drop b.c_id from the GROUP BY of the resulting plan;
-- but this happens too late for join removal in the outer plan level.)
--Testcase 369:
explain (costs off)
select d.* from (select (fields->>'a')::int a, (fields->>'b')::int b from d) d left join (select * from (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b group by b.id, b.c_id) s
  on (d.a)::int = (s.id)::int;

-- similarly, but keying off a DISTINCT clause
--Testcase 370:
explain (costs off)
select d.* from (select (fields->>'a')::int a, (fields->>'b')::int b from d) d left join (select distinct * from (select (fields->>'id')::int id, (fields->>'c_id')::int c_id from b) b) s
  on (d.a)::int = (s.id)::int;

-- check join removal works when uniqueness of the join condition is enforced
-- by a UNION
--Testcase 371:
explain (costs off)
select d.* from (select (fields->>'a')::int a, (fields->>'b')::int b from d) d left join (select (fields->>'id')::int id from a union select (fields->>'id')::int id from b) s
  on (d.a)::int = (s.id)::int;

-- check join removal with a cross-type comparison operator
--Testcase 372:
explain (costs off)
select i8.* from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8 left join (select (fields->>'f1')::int f1 from int4_tbl group by (fields->>'f1')::int) i4
  on (i8.q1)::int8 = (i4.f1)::int4;

-- check join removal with lateral references
--Testcase 373:
explain (costs off)
select 1 from (select (a.fields->>'id')::int id FROM a left join b on (a.fields->>'b_id')::int = (b.fields->>'id')::int) q,
			  lateral generate_series(1, (q.id)::int) gs(i) where (q.id)::int = (gs.i)::int;

--Testcase 374:
DELETE FROM a_nsc;
--Testcase 375:
DELETE FROM b_nsc;
--Testcase 376:
DELETE FROM c_nsc;
--Testcase 377:
DELETE FROM d_nsc;
--Testcase 378:
DROP FOREIGN TABLE a;
DROP FOREIGN TABLE a_nsc;
--Testcase 379:
DROP FOREIGN TABLE b;
DROP FOREIGN TABLE b_nsc;
--Testcase 380:
DROP FOREIGN TABLE c;
DROP FOREIGN TABLE c_nsc;
--Testcase 381:
DROP FOREIGN TABLE d;
DROP FOREIGN TABLE d_nsc;
rollback;

--Testcase 382:
create foreign table parent (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table parent_nsc (k int, pd int) server influxdb_svr OPTIONS (table 'parent');
--Testcase 383:
create foreign table child (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table child_nsc (k int, cd int) server influxdb_svr OPTIONS (table 'child');
--Testcase 384:
insert into parent_nsc values (1, 10), (2, 20), (3, 30);
--Testcase 385:
insert into child_nsc values (1, 100), (4, 400);
-- this case is optimizable
--Testcase 386:
select p.* from (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent p) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child c) c on ((p.k)::int = (c.k)::int);
--Testcase 387:
explain (costs off)
  select p.* from (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent p) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child c) c on ((p.k)::int = (c.k)::int);

-- this case is not
--Testcase 388:
select p.*, linked from (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent p) p
  left join (select c.*, true as linked from (select (fields->>'k')::int k, (fields->>'cd')::int cd from child c) c) as ss
  on (p.k = ss.k);
--Testcase 389:
explain (costs off)
  select p.*, linked from (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent p) p
    left join (select c.*, true as linked from (select (fields->>'k')::int k, (fields->>'cd')::int cd from child c) c) as ss
    on (p.k = ss.k);

-- check for a 9.0rc1 bug: join removal breaks pseudoconstant qual handling
--Testcase 390:
select p.* from
  (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child) c on ((p.k)::int = (c.k)::int)
  where (p.k)::int = 1 and (p.k)::int = 2;
--Testcase 391:
explain (costs off)
select p.* from
  (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child) c on ((p.k)::int = (c.k)::int)
  where (p.k)::int = 1 and (p.k)::int = 2;

--Testcase 392:
select p.* from
  ((select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child) c on ((p.k)::int = (c.k)::int)) join (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) x on (p.k)::int = (x.k)::int
  where (p.k)::int = 1 and (p.k)::int = 2;
--Testcase 393:
explain (costs off)
select p.* from
  ((select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) p left join (select (fields->>'k')::int k, (fields->>'cd')::int cd from child) c on ((p.k)::int = (c.k)::int)) join (select (fields->>'k')::int k, (fields->>'pd')::int pd from parent) x on (p.k)::int = (x.k)::int
  where (p.k)::int = 1 and (p.k)::int = 2;

-- bug 5255: this is not optimizable by join removal
begin;

--Testcase 394:
CREATE FOREIGN TABLE a (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE a_nsc (id int) SERVER influxdb_svr OPTIONS (table 'a');
--Testcase 395:
CREATE FOREIGN TABLE b (fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(schemaless 'true');
CREATE FOREIGN TABLE b_nsc (id int, a_id int) SERVER influxdb_svr OPTIONS (table 'b');
--Testcase 396:
INSERT INTO a_nsc VALUES (0), (1);
--Testcase 397:
INSERT INTO b_nsc VALUES (0, 0), (1, NULL);
--Testcase 398:
SELECT * FROM (select (fields->>'id')::int id, (fields->>'a_id')::int a_id from b) b LEFT JOIN (select (fields->>'id')::int id from a) a ON ((b.a_id)::int = (a.id)::int) WHERE ((a.id)::int IS NULL OR (a.id)::int > 0);
--Testcase 399:
SELECT b.* FROM (select (fields->>'id')::int id, (fields->>'a_id')::int a_id from b) b LEFT JOIN (select (fields->>'id')::int id from a) a ON ((b.a_id)::int = (a.id)::int) WHERE ((a.id)::int IS NULL OR (a.id)::int > 0);

--Testcase 400:
DELETE FROM a_nsc;
--Testcase 401:
DELETE FROM b_nsc;
--Testcase 402:
DROP FOREIGN TABLE a;
DROP FOREIGN TABLE a_nsc;
--Testcase 403:
DROP FOREIGN TABLE b;
DROP FOREIGN TABLE b_nsc;
rollback;

-- another join removal bug: this is not optimizable, either
begin;

--Testcase 404:
create foreign table innertab (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table innertab_nsc (id int8, dat1 int8) server influxdb_svr OPTIONS (table 'innertab');
--Testcase 405:
insert into innertab_nsc values(123, 42);
--Testcase 406:
SELECT * FROM
    (SELECT 1 AS x) ss1
  LEFT JOIN
    (SELECT q1, q2, COALESCE(dat1, q1) AS y
     FROM (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) int8_tbl LEFT JOIN (select (fields->>'id')::int id, (fields->>'dat1')::int dat1 from innertab) innertab ON (q2)::int8 = (id)::int) ss2
  ON true;

-- Clean up
DELETE FROM innertab_nsc;
DROP FOREIGN TABLE innertab;
DROP FOREIGN TABLE innertab_nsc;

rollback;

-- another join removal bug: we must clean up correctly when removing a PHV
begin;

--Testcase 407:
create foreign table uniquetbl (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');

--Testcase 408:
explain (costs off)
select t1.* from
  (select fields->>'f1' f1 from uniquetbl t1) as t1
  left join (select *, '***'::text as d1 from (select fields->>'f1' f1 from uniquetbl uniquetbl) uniquetbl) t2
  on t1.f1 = t2.f1
  left join (select fields->>'f1' f1 from uniquetbl t3) t3
  on t2.d1 = t3.f1;

--Testcase 409:
explain (costs off)
select t0.*
from
 (select fields->>'f1' f1 from text_tbl t0) t0
 left join
   (select case (t1.fields->>'ten')::int4 when 0 then 'doh!'::text else null::text end as case1,
           t1.fields->>'stringu2' stringu2
     from tenk1 t1
     join int4_tbl i4 ON (i4.fields->>'f1')::int4 = (t1.fields->>'unique2')::int4
     left join uniquetbl u1 ON u1.fields->>'f1' = (t1.fields->>'string4')::name) ss
  on t0.f1 = ss.case1
where ss.stringu2 !~* ss.case1;

--Testcase 410:
select t0.*
from
 (select fields->>'f1' f1 from text_tbl t0) t0
 left join
   (select case (t1.fields->>'ten')::int4 when 0 then 'doh!'::text else null::text end as case1,
           t1.fields->>'stringu2' stringu2
     from tenk1 t1
     join int4_tbl i4 ON (i4.fields->>'f1')::int4 = (t1.fields->>'unique2')::int4
     left join uniquetbl u1 ON u1.fields->>'f1' = (t1.fields->>'string4')::name) ss
  on t0.f1 = ss.case1
where ss.stringu2 !~* ss.case1;

rollback;

-- test case to expose miscomputation of required relid set for a PHV
--Testcase 411:
explain (verbose, costs off)
select i8.*, ss.v, (t.fields->>'unique2')::int4 unique2
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
    left join int4_tbl i4 on (i4.fields->>'f1')::int4 = 1
    left join lateral (select (i4.fields->>'f1')::int4 + 1 as v) as ss on true
    left join tenk1 t on (t.fields->>'unique2')::int4 = (ss.v)::int4
where q2::int8 = 456;

--Testcase 412:
select i8.*, ss.v, (t.fields->>'unique2')::int4 unique2
  from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8
    left join int4_tbl i4 on (i4.fields->>'f1')::int4 = 1
    left join lateral (select (i4.fields->>'f1')::int4 + 1 as v) as ss on true
    left join tenk1 t on (t.fields->>'unique2')::int4 = (ss.v)::int4
where q2::int8 = 456;

-- bug #8444: we've historically allowed duplicate aliases within aliased JOINs

--Testcase 413:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x join ((select (fields->>'f1')::int4 f1 from INT4_TBL) x cross join (select (fields->>'f1')::int4 f1 from INT4_TBL) y) j on  q1 = f1; -- error
--Testcase 414:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x join ((select (fields->>'f1')::int4 f1 from INT4_TBL) x cross join (select (fields->>'f1')::int4 f1 from INT4_TBL) y) j on q1 = y.f1; -- error
--Testcase 415:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x join ((select (fields->>'f1')::int4 f1 from INT4_TBL) x cross join (select (fields->>'f1')::int4 f1 from INT4_TBL) y(ff)) j on q1 = f1; -- ok

--
-- Test hints given on incorrect column references are useful
--

--Testcase 416:
select( t1.ffields->>'unique1')::int4 unique1 from
  tenk1 t1 join tenk2 t2 on (t1.fields->>'two')::int4 = (t2.fields->>'two')::int4; -- error, prefer "t1" suggestion
--Testcase 417:
select (t2.ffields->>'unique1')::int4 unique1 from
  tenk1 t1 join tenk2 t2 on (t1.fields->>'two')::int4 = (t2.fields->>'two')::int4; -- error, prefer "t2" suggestion
--Testcase 418:
select (ffields->>'unique1')::int4 unique1 from
  tenk1 t1 join tenk2 t2 on (t1.fields->>'two')::int4 = (t2.fields->>'two')::int4; -- error, suggest both at once

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
from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, fields->>'two' two, fields->>'four' four, fields->>'ten' ten, fields->>'twenty' twenty, fields->>'hundred' hundred, fields->>'thousand' thousand, fields->>'twothousand' twothousand, fields->>'fivethous' fivethous, fields->>'tenthous' tenthous, fields->>'odd' odd, fields->>'even' even, fields->>'stringu1' stringu1, fields->>'stringu2' stringu2, fields->>'string4' string4 from tenk1 a) a, lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL b) b where f1 = a.unique1) x;
--Testcase 420:
explain (costs off)
  select unique2, x.*
  from (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2, fields->>'two' two, fields->>'four' four, fields->>'ten' ten, fields->>'twenty' twenty, fields->>'hundred' hundred, fields->>'thousand' thousand, fields->>'twothousand' twothousand, fields->>'fivethous' fivethous, fields->>'tenthous' tenthous, fields->>'odd' odd, fields->>'even' even, fields->>'stringu1' stringu1, fields->>'stringu2' stringu2, fields->>'string4' string4 from tenk1 a) a, lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL b) b where f1 = a.unique1) x;
--Testcase 421:
select unique2, x.*
from (select (fields->>'f1')::int4 f1 from INT4_TBL x) x, lateral (select (fields->>'unique2')::int4 unique2 from tenk1 where f1 = (fields->>'unique1')::int4) ss;
--Testcase 422:
explain (costs off)
  select unique2, x.*
  from (select (fields->>'f1')::int4 f1 from INT4_TBL x) x, lateral (select (fields->>'unique2')::int4 unique2 from tenk1 where f1 = (fields->>'unique1')::int4) ss;
--Testcase 423:
explain (costs off)
  select unique2, x.*
  from (select (fields->>'f1')::int4 f1 from INT4_TBL x) x cross join lateral (select (fields->>'unique2')::int4 unique2 from tenk1 where f1 = (fields->>'unique1')::int4) ss;
--Testcase 424:
select unique2, x.*
from (select (fields->>'f1')::int4 f1 from INT4_TBL x) x left join lateral (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2 from tenk1 where f1 = (fields->>'unique1')::int4) ss on true;
--Testcase 425:
explain (costs off)
  select unique2, x.*
  from (select (fields->>'f1')::int4 f1 from INT4_TBL x) x left join lateral (select (fields->>'unique1')::int4 unique1, (fields->>'unique2')::int4 unique2 from tenk1 where f1 = (fields->>'unique1')::int4) ss on true;

-- check scoping of lateral versus parent references
-- the first of these should return int8_tbl.q2, the second int8_tbl.q1
--Testcase 426:
select *, (select r from (select q1 as q2) x, (select q2 as r) y) from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) int8_tbl;
--Testcase 427:
select *, (select r from (select q1 as q2) x, lateral (select q2 as r) y) from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) int8_tbl;

-- lateral with function in FROM
--Testcase 428:
select count(*) from tenk1 a, lateral generate_series(1, (fields->>'two')::int4) g;
--Testcase 429:
explain (costs off)
  select count(*) from tenk1 a, lateral generate_series(1, (fields->>'two')::int4) g;
--Testcase 430:
explain (costs off)
  select count(*) from tenk1 a cross join lateral generate_series(1,(fields->>'two')::int4) g;
-- don't need the explicit LATERAL keyword for functions
--Testcase 431:
explain (costs off)
  select count(*) from tenk1 a, generate_series(1,(fields->>'two')::int4) g;

-- lateral with UNION ALL subselect
--Testcase 432:
explain (costs off)
  select * from generate_series(100,200) g,
    lateral (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a where g = (q1)::int8 union all
             select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b where g = (q2)::int8) ss;
--Testcase 433:
select * from generate_series(100,200) g,
  lateral (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a where g = (q1)::int8 union all
           select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b where g = (q2)::int8) ss;

-- lateral with VALUES
--Testcase 434:
explain (costs off)
  select count(*) from tenk1 a,
    tenk1 b join lateral (values(a.fields->>'unique1')) ss(x) on b.fields->>'unique2' = ss.x;
--Testcase 435:
select count(*) from tenk1 a,
  tenk1 b join lateral (values(a.fields->>'unique1')) ss(x) on b.fields->>'unique2' = ss.x;

-- lateral with VALUES, no flattening possible
--Testcase 436:
explain (costs off)
  select count(*) from tenk1 a,
    tenk1 b join lateral (values((a.fields->>'unique1')::int4),(-1)) ss(x) on (b.fields->>'unique2')::int4 = (ss.x)::int;
--Testcase 437:
select count(*) from tenk1 a,
  tenk1 b join lateral (values((a.fields->>'unique1')::int4),(-1)) ss(x) on (b.fields->>'unique2')::int4 = (ss.x)::int;

-- lateral injecting a strange outer join condition
--Testcase 438:
explain (costs off)
  select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a,
    (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL x) x left join lateral (select a.q1 from (select (fields->>'f1')::int4 f1 from INT4_TBL y) y) ss(z)
      on x.q2 = ss.z
  order by (a.q1)::int8, (a.q2)::int8, (x.q1)::int8, (x.q2)::int8, (ss.z)::int8;
--Testcase 439:
select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a,
    (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL x) x left join lateral (select a.q1 from (select (fields->>'f1')::int4 f1 from INT4_TBL y) y) ss(z)
      on x.q2 = ss.z
  order by (a.q1)::int8, (a.q2)::int8, (x.q1)::int8, (x.q2)::int8, (ss.z)::int8;

-- lateral reference to a join alias variable
--Testcase 440:
select * from (select (fields->>'f1')::int4/2 as x from int4_tbl) ss1 join (select (fields->>'f1')::int4 f1 from INT4_TBL) i4 on x::int4 = (f1)::int4,
  lateral (select x) ss2(y);
--Testcase 441:
select * from (select (fields->>'f1')::int4 as x from int4_tbl) ss1 join (select (fields->>'f1')::int4 f1 from INT4_TBL) i4 on x::int4 = (f1)::int4,
  lateral (values(x)) ss2(y);
--Testcase 442:
select * from ((select (fields->>'f1')::int4/2 as x from int4_tbl) ss1 join (select (fields->>'f1')::int4 f1 from INT4_TBL) i4 on x::int4 = (f1)::int4) j,
  lateral (select x) ss2(y);

-- lateral references requiring pullup
--Testcase 443:
select * from (values(1)) x(lb),
  lateral generate_series(lb,4) x4;
--Testcase 444:
select * from (select (fields->>'f1')::int4/1000000000 from int4_tbl) x(lb),
  lateral generate_series(lb,4) x4;
--Testcase 445:
select * from (values(1)) x(lb),
  lateral (values(lb)) y(lbcopy);
--Testcase 446:
select * from (values(1)) x(lb),
  lateral (select lb from int4_tbl) y(lbcopy);
--Testcase 447:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x left join (select (fields->>'q1')::int8 q1,coalesce((fields->>'q2')::int8,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (values(x.q1,y.q1,y.q2)) v(xq1,yq1,yq2) ORDER BY xq1, yq1, yq2;
--Testcase 448:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x left join (select (fields->>'q1')::int8 q1,coalesce((fields->>'q2')::int8,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (select x.q1,y.q1,y.q2) v(xq1,yq1,yq2) ORDER BY xq1, yq1, yq2;
--Testcase 449:
select x.* from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x left join (select (fields->>'q1')::int8 q1,coalesce((fields->>'q2')::int8,0) q2 from int8_tbl) y on x.q2 = y.q1,
  lateral (select x.q1,y.q1,y.q2) v(xq1,yq1,yq2) ORDER BY xq1, yq1, yq2;
--Testcase 450:
select v.* from
  (int8_tbl x left join (select (fields->>'q1')::int8 q1,coalesce((fields->>'q2')::int8,0) q2 from int8_tbl) y on (x.fields->>'q2')::int8 = y.q1)
  left join int4_tbl z on (z.fields->>'f1')::int8 = (x.fields->>'q2')::int8,
  lateral (select (x.fields->>'q1')::int8,(y.q1)::int8 union all select (x.fields->>'q2')::int8,(y.q2)::int8) v(vx,vy);
--Testcase 451:
select v.* from
  (int8_tbl x left join (select (fields->>'q1')::int8 q1,(select coalesce((fields->>'q2')::int8,0)) q2 from int8_tbl) y on (x.fields->>'q2')::int8 = y.q1)
  left join int4_tbl z on (z.fields->>'f1')::int8 = (x.fields->>'q2')::int8,
  lateral (select (x.fields->>'q1')::int8,(y.q1)::int8 union all select (x.fields->>'q2')::int8,(y.q2)::int8) v(vx,vy);
--Testcase 452:
select v.* from
  (int8_tbl x left join (select (fields->>'q1')::int8 q1,(select coalesce((fields->>'q2')::int8,0)) q2 from int8_tbl) y on (x.fields->>'q2')::int8 = y.q1)
  left join int4_tbl z on (z.fields->>'f1')::int8 = (x.fields->>'q2')::int8,
  lateral (select (x.fields->>'q1')::int8,(y.q1)::int8 from onerow union all select (x.fields->>'q2')::int8,(y.q2)::int8 from onerow) v(vx,vy);

--Testcase 453:
explain (verbose, costs off)
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join
  lateral (select *, a.q2 as x from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b) ss on a.q2 = ss.q1;
--Testcase 454:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join
  lateral (select *, a.q2 as x from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b) ss on a.q2 = ss.q1;
--Testcase 455:
explain (verbose, costs off)
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join
  lateral (select *, coalesce((a.q2)::int8, 42) as x from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b) ss on a.q2 = ss.q1;
--Testcase 456:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join
  lateral (select *, coalesce((a.q2)::int8, 42) as x from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b) ss on a.q2 = ss.q1;

-- lateral can result in join conditions appearing below their
-- real semantic level
--Testcase 457:
explain (verbose, costs off)
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i) i left join
  lateral (select * from (select (fields->>'f1')::int2 f1 from INT2_TBL j) j where i.f1 = j.f1) k on true;
--Testcase 458:
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i) i left join
  lateral (select * from (select (fields->>'f1')::int2 f1 from INT2_TBL j) j where i.f1 = j.f1) k on true;
--Testcase 459:
explain (verbose, costs off)
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i) i left join
  lateral (select coalesce(i) from (select (fields->>'f1')::int2 f1 from INT2_TBL j) j where i.f1 = j.f1) k on true;
--Testcase 460:
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i) i left join
  lateral (select coalesce(i) from (select (fields->>'f1')::int2 f1 from INT2_TBL j) j where i.f1 = j.f1) k on true;
--Testcase 461:
explain (verbose, costs off)
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL a) a,
  lateral (
    select * from (select (fields->>'f1')::int4 f1 from INT4_TBL b) b left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL c) c on (b.f1 = q1 and a.f1 = q2)
  ) ss;
--Testcase 462:
select * from (select (fields->>'f1')::int4 f1 from INT4_TBL a) a,
  lateral (
    select * from (select (fields->>'f1')::int4 f1 from INT4_TBL b) b left join (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL c) c on (b.f1 = q1 and a.f1 = q2)
  ) ss;

-- lateral reference in a PlaceHolderVar evaluated at join level
--Testcase 463:
explain (verbose, costs off)
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join lateral
  (select (b.fields->>'q1')::int8 as bq1, (c.fields->>'q1')::int8 as cq1, least(a.q1,(b.fields->>'q1')::int8,(c.fields->>'q1')::int8) from
   int8_tbl b cross join int8_tbl c) ss
  on a.q2 = ss.bq1;
--Testcase 464:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join lateral
  (select (b.fields->>'q1')::int8 as bq1, (c.fields->>'q1')::int8 as cq1, least(a.q1,(b.fields->>'q1')::int8,(c.fields->>'q1')::int8) from
   int8_tbl b cross join int8_tbl c) ss
  on a.q2 = ss.bq1;

-- case requiring nested PlaceHolderVars
--Testcase 465:
explain (verbose, costs off)
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL c) c left join (
    (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join (select (fields->>'q1')::int8 q1, coalesce((fields->>'q2')::int8,42) as x from int8_tbl b) ss1
      on a.q2 = ss1.q1
    cross join
    lateral (select (fields->>'q1')::int8 q1, coalesce(ss1.x,(fields->>'q2')::int8) as y from int8_tbl d) ss2
  ) on c.q2 = ss2.q1,
  lateral (select ss2.y offset 0) ss3;

-- case that breaks the old ph_may_need optimization
--Testcase 466:
explain (verbose, costs off)
select c.*,a.*,ss1.q1,ss2.q1,ss3.* from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL c) c left join (
    (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL a) a left join
      (select q1, coalesce(q2,f1) as x from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL b) b, (select (fields->>'f1')::int4 f1 from INT4_TBL b2) b2
       where (q1)::int8 < (f1)::int4) ss1
      on a.q2 = ss1.q1
    cross join
    lateral (select (fields->>'q1')::int8 q1, coalesce(ss1.x,(fields->>'q2')::int8) as y from int8_tbl d) ss2
  ) on c.q2 = ss2.q1,
  lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL i) i where (ss2.y)::int8 > (f1)::int4) ss3;

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
select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8 left join lateral
  (select *, i8.q2 from (select (fields->>'f1')::int4 f1 from INT4_TBL int4_tbl) int4_tbl where false) ss on true;
--Testcase 469:
explain (verbose, costs off)
select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL i8) i8 left join lateral
  (select *, i8.q2 from (select (fields->>'f1')::int4 f1 from INT4_TBL i1) i1, (select (fields->>'f1')::int4 f1 from INT4_TBL i2) i2 where false) ss on true;

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

-- check we don't try to do a unique-ified semijoin with LATERAL
--Testcase 471:
explain (verbose, costs off)
select * from
  (values (0,9998), (1,1000)) v(id,x),
  lateral (select (fields->>'f1')::int4 f1 from INT4_TBL
           where (fields->>'f1')::int4 = any (select (fields->>'unique1')::int4 from tenk1
                           where (fields->>'unique2')::int4 = v.x offset 0)) ss;
--Testcase 472:
select * from
  (values (0,9998), (1,1000)) v(id,x),
  lateral (select (fields->>'f1')::int4 f1 from INT4_TBL
           where (fields->>'f1')::int4 = any (select (fields->>'unique1')::int4 from tenk1
                           where (fields->>'unique2')::int4 = v.x offset 0)) ss;

-- check proper extParam/allParam handling (this isn't exactly a LATERAL issue,
-- but we can make the test case much more compact with LATERAL)
--Testcase 473:
explain (verbose, costs off)
select * from (values (0), (1)) v(id),
lateral (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t1,
         lateral (select * from
                    (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t2
                     where q1 = any (select (fields->>'q2')::int8 from int8_tbl t3
                                     where (fields->>'q2')::int8 = (select greatest(t1.q1,t2.q2))
                                       and (select v.id=0)) offset 0) ss2) ss
         where (t1.q1)::int8 = (ss.q2)::int8) ss0;

--Testcase 474:
select * from (values (0), (1)) v(id),
lateral (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t1,
         lateral (select * from
                    (select * from (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) t2
                     where q1 = any (select (fields->>'q2')::int8 from int8_tbl t3
                                     where (fields->>'q2')::int8 = (select greatest(t1.q1,t2.q2))
                                       and (select v.id=0)) offset 0) ss2) ss
         where t1.q1 = ss.q2) ss0;

-- test some error cases where LATERAL should have been used but wasn't
--Testcase 475:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a, (select fields->>'f1' as g) ss;
--Testcase 476:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a, (select a.fields->>'f1' as g) ss;
--Testcase 477:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a cross join (select fields->>'f1' as g) ss;
--Testcase 478:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a cross join (select a.fields->>'f1' as g) ss;
-- SQL:2008 says the left table is in scope but illegal to access here
--Testcase 479:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a right join lateral generate_series(0, (a.fields->>'f1')::int4) g on true;
--Testcase 480:
select (fields->>'f1')::int4 f1,(fields->>'g')::int4 g from int4_tbl a full join lateral generate_series(0, (a.fields->>'f1')::int4) g on true;
-- check we complain about ambiguous table references
--Testcase 481:
select * from
  (select (fields->>'q1')::int8 q1, (fields->>'q2')::int8 q2 from INT8_TBL) x cross join ((select (fields->>'f1')::int4 f1 from INT4_TBL) x cross join lateral (select x.f1) ss);
-- LATERAL can be used to put an aggregate into the FROM clause of its query
--Testcase 482:
select 1 from tenk1 a, lateral (select max((a.fields->>'unique1')::int4) from int4_tbl b) ss;

-- check behavior of LATERAL in UPDATE/DELETE

--Testcase 483:
create temp table xx1 as select fields->>'f1' as x1, -(fields->>'f1')::int4 as x2 from int4_tbl;

-- error, can't do this:
--Testcase 484:
update xx1 set x2 = f1 from (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = x1) ss;
--Testcase 485:
update xx1 set x2 = f1 from (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = xx1.x1) ss;
-- can't do it even with LATERAL:
--Testcase 486:
update xx1 set x2 = f1 from lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = x1) ss;
-- we might in future allow something like this, but for now it's an error:
--Testcase 487:
update xx1 set x2 = f1 from xx1, lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = x1) ss;

-- also errors:
--Testcase 488:
delete from xx1 using (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = x1) ss;
--Testcase 489:
delete from xx1 using (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = xx1.x1) ss;
--Testcase 490:
delete from xx1 using lateral (select * from (select (fields->>'f1')::int4 f1 from INT4_TBL) int4_tbl where f1 = x1) ss;

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
create foreign table fkest (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table fkest_nsc (a int, b int, c int) server influxdb_svr OPTIONS (table 'fkest');
--Testcase 492:
create foreign table fkest1 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table fkest1_nsc (a int, b int) server influxdb_svr OPTIONS (table 'fkest1');
--Testcase 493:
insert into fkest_nsc select x/10, x%10, x from generate_series(1,1000) x;
--Testcase 494:
insert into fkest1_nsc select x/10, x%10 from generate_series(1,1000) x;
--Testcase 495:
explain (costs off)
select *
from (select (fields->>'a')::int a, (fields->>'b')::int b, (fields->>'c')::int c from fkest f) f
  left join (select (fields->>'a')::int a, (fields->>'b')::int b from fkest1 f1) f1 on (f.a)::int = (f1.a)::int and (f.b)::int = (f1.b)::int
  left join (select (fields->>'a')::int a, (fields->>'b')::int b from fkest1 f2) f2 on (f.a)::int = (f2.a)::int and (f.b)::int = (f2.b)::int
  left join (select (fields->>'a')::int a, (fields->>'b')::int b from fkest1 f3) f3 on (f.a)::int = (f3.a)::int and (f.b)::int = (f3.b)::int
where (f.c)::bigint = 1;

rollback;

--
-- test planner's ability to mark joins as unique
--

--Testcase 496:
create foreign table j1 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j1_nsc (id int) server influxdb_svr OPTIONS (table 'j1');
--Testcase 497:
create foreign table j2 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j2_nsc (id int) server influxdb_svr OPTIONS (table 'j2');
--Testcase 498:
create foreign table j3 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j3_nsc (id int) server influxdb_svr OPTIONS (table 'j3');
--Testcase 499:
insert into j1_nsc values(1),(2),(3);
--Testcase 500:
insert into j2_nsc values(1),(2),(3);
--Testcase 501:
insert into j3_nsc values(1),(1);
-- ensure join is properly marked as unique
--Testcase 502:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 inner join (select (fields->>'id')::int id from j2) j2 on (j1.id)::int = (j2.id)::int;

-- ensure join is not unique when not an equi-join
--Testcase 503:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 inner join (select (fields->>'id')::int id from j2) j2 on (j1.id)::int > (j2.id)::int;

-- ensure non-unique rel is not chosen as inner
--Testcase 504:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 inner join (select (fields->>'id')::int id from j3) j3 on (j1.id)::int = (j3.id)::int;

-- ensure left join is marked as unique
--Testcase 505:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 left join (select (fields->>'id')::int id from j2) j2 on (j1.id)::int = (j2.id)::int;

-- ensure right join is marked as unique
--Testcase 506:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 right join (select (fields->>'id')::int id from j2) j2 on (j1.id)::int = (j2.id)::int;

-- ensure full join is marked as unique
--Testcase 507:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 full join (select (fields->>'id')::int id from j2) j2 on (j1.id)::int = (j2.id)::int;

-- a clauseless (cross) join can't be unique
--Testcase 508:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 cross join (select (fields->>'id')::int id from j2) j2;

-- ensure a natural join is marked as unique
--Testcase 509:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1) j1 natural join (select (fields->>'id')::int id from j2) j2;

-- ensure a distinct clause allows the inner to become unique
--Testcase 510:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1 j1) j1
inner join (select distinct (fields->>'id')::int id from j3 j3) j3 on (j1.id)::int = (j3.id)::int;

-- ensure group by clause allows the inner to become unique
--Testcase 511:
explain (verbose, costs off)
select * from (select (fields->>'id')::int id from j1 j1) j1
inner join (select (fields->>'id')::int id from j3 j3 group by fields->>'id') j3 on (j1.id)::int = (j3.id)::int;

--Testcase 512:
delete from j1_nsc;
--Testcase 513:
delete from j2_nsc;
--Testcase 514:
delete from j3_nsc;
--Testcase 515:
drop foreign table j1;
drop foreign table j1_nsc;
--Testcase 516:
drop foreign table j2;
drop foreign table j2_nsc;
--Testcase 517:
drop foreign table j3;
drop foreign table j3_nsc;

-- test more complex permutations of unique joins

--Testcase 518:
create foreign table j1 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j1_nsc (id1 int, id2 int) server influxdb_svr OPTIONS (table 'j1');
--Testcase 519:
create foreign table j2 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j2_nsc (id1 int, id2 int) server influxdb_svr OPTIONS (table 'j2');
--Testcase 520:
create foreign table j3 (fields jsonb OPTIONS (fields 'true')) server influxdb_svr OPTIONS(schemaless 'true');
create foreign table j3_nsc (id1 int, id2 int) server influxdb_svr OPTIONS (table 'j3');
--Testcase 521:
insert into j1_nsc values(1,1),(1,2);
--Testcase 522:
insert into j2_nsc values(1,1);
--Testcase 523:
insert into j3_nsc values(1,1);
-- ensure there's no unique join when not all columns which are part of the
-- unique index are seen in the join clause
--Testcase 524:
explain (verbose, costs off)
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on (j1.id1)::int = (j2.id1)::int;

-- ensure proper unique detection with multiple join quals
--Testcase 525:
explain (verbose, costs off)
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on (j1.id1)::int = (j2.id1)::int and (j1.id2)::int = (j2.id2)::int;

-- ensure we don't detect the join to be unique when quals are not part of the
-- join condition
--Testcase 526:
explain (verbose, costs off)
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on (j1.id1)::int = (j2.id1)::int where (j1.id2)::int = 1;

-- as above, but for left joins.
--Testcase 527:
explain (verbose, costs off)
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
left join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on (j1.id1)::int = (j2.id1)::int where (j1.id2)::int = 1;

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
insert into j2_nsc values(1,2);
--analyze j2;

--Testcase 532:
explain (costs off) select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1;

--Testcase 533:
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1;

-- Exercise array keys mark/restore B-Tree code
--Testcase 534:
explain (costs off) select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1 and (j2.id1)::int = any (array[1]);

--Testcase 535:
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1 and (j2.id1)::int = any (array[1]);

-- Exercise array keys "find extreme element" B-Tree code
--Testcase 536:
explain (costs off) select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1 and (j2.id1)::int >= any (array[1,5]);

--Testcase 537:
select * from (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j1) j1
inner join (select (fields->>'id1')::int id1, (fields->>'id2')::int id2 from j2) j2 on j1.id1 = j2.id1 and j1.id2 = j2.id2
where (j1.id1)::int % 1000 = 1 and (j2.id1)::int % 1000 = 1 and (j2.id1)::int >= any (array[1,5]);

--Testcase 538:
reset enable_nestloop;
--Testcase 539:
reset enable_hashjoin;
--Testcase 540:
reset enable_sort;

--Testcase 541:
delete from j1_nsc;
--Testcase 542:
delete from j2_nsc;
--Testcase 543:
delete from j3_nsc;
--Testcase 544:
drop foreign table j1;
drop foreign table j1_nsc;
--Testcase 545:
drop foreign table j2;
drop foreign table j2_nsc;
--Testcase 546:
drop foreign table j3;
drop foreign table j3_nsc;

-- check that semijoin inner is not seen as unique for a portion of the outerrel
--Testcase 547:
CREATE FOREIGN TABLE onek (
  fields jsonb OPTIONS (fields 'true')
) SERVER influxdb_svr OPTIONS(schemaless 'true');

-- check that semijoin inner is not seen as unique for a portion of the outerrel
--Testcase 548:
explain (verbose, costs off)
select (t1.fields->>'unique1')::int4 unique1, (t2.fields->>'hundred')::int4 hundred
from onek t1, tenk1 t2
where exists (select 1 from tenk1 t3
              where (t3.fields->>'thousand')::int4 = (t1.fields->>'unique1')::int4 and (t3.fields->>'tenthous')::int4 = (t2.fields->>'hundred')::int4)
      and (t1.fields->>'unique1')::int4 < 1;

-- ... unless it actually is unique
--Testcase 549:
create table j3 as select (fields->>'unique1')::int4 unique1, (fields->>'tenthous')::int4 tenthous from onek;
vacuum analyze j3;
--Testcase 550:
create unique index on j3(unique1, tenthous);

--Testcase 551:
explain (verbose, costs off)
select (t1.fields->>'unique1')::int4 unique1, (t2.fields->>'hundred')::int4 hundred
from onek t1, tenk1 t2
where exists (select 1 from j3
              where j3.unique1 = (t1.fields->>'unique1')::int4 and j3.tenthous = (t2.fields->>'hundred')::int4)
      and (t1.fields->>'unique1')::int4 < 1;

--Testcase 552:
drop table j3;

-- Clean up
DELETE FROM t1_nsc;
DELETE FROM t2_nsc;
DELETE FROM t3_nsc;
DELETE FROM tt1_nsc;
DELETE FROM tt2_nsc;
DELETE FROM tt3_nsc;
DELETE FROM tt4_nsc;
DELETE FROM tt5_nsc;
DELETE FROM tt6_nsc;
DELETE FROM xx_nsc;
DELETE FROM yy_nsc;
DELETE FROM zt1_nsc;
DELETE FROM zt2_nsc;
DELETE FROM nt1_nsc;
DELETE FROM nt2_nsc;
DELETE FROM nt3_nsc;
DELETE FROM parent_nsc;
DELETE FROM child_nsc;

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
DROP EXTENSION influxdb_fdw;
