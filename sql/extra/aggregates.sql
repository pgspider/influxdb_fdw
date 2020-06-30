CREATE EXTENSION influxdb_fdw;

CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw
  OPTIONS (dbname 'coredb', host 'http://localhost', port '8086');
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password 'pass');

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

CREATE FOREIGN TABLE aggtest (
  a         int2,
  b         float4
) SERVER influxdb_svr OPTIONS (table 'agg');

CREATE FOREIGN TABLE student (
  name      text,
  age       int4,
  location  point,
  gpa       float8
) SERVER influxdb_svr;

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

CREATE FOREIGN TABLE INT8_TBL (
  q1        int8,
  q2        int8
) SERVER influxdb_svr;

CREATE FOREIGN TABLE INT8_TBL2 (
  q1        int8,
  q2        int8
) SERVER influxdb_svr;

CREATE FOREIGN TABLE INT4_TBL (f1 int4) SERVER influxdb_svr;
CREATE FOREIGN TABLE INT4_TBL2 (f1 int4) SERVER influxdb_svr;
CREATE FOREIGN TABLE INT4_TBL3 (f1 int4) SERVER influxdb_svr;
CREATE FOREIGN TABLE INT4_TBL4 (f1 int4) SERVER influxdb_svr;

CREATE FOREIGN TABLE multi_arg_agg (a int, b int, c text) SERVER influxdb_svr;
CREATE FOREIGN TABLE multi_arg_agg2 (a int, b int, c text) SERVER influxdb_svr;
CREATE FOREIGN TABLE multi_arg_agg3 (a int, b int, c text) SERVER influxdb_svr;

CREATE FOREIGN TABLE VARCHAR_TBL (f1 varchar(4)) SERVER influxdb_svr;
CREATE FOREIGN TABLE FLOAT8_TBL (f1 float8) SERVER influxdb_svr;

--
-- AGGREGATES
--

-- avoid bit-exact output here because operations may not be bit-exact.
SET extra_float_digits = 0;

--Testcase 1:
SELECT avg(four) AS avg_1 FROM onek;

--Testcase 2:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

-- In 7.1, avg(float4) is computed using float8 arithmetic.
-- Round the result to 3 digits to avoid platform-specific results.

--Testcase 3:
SELECT avg(b)::numeric(10,3) AS avg_107_943 FROM aggtest;

--Testcase 4:
SELECT avg(gpa) AS avg_3_4 FROM ONLY student;


--Testcase 5:
SELECT sum(four) AS sum_1500 FROM onek;
--Testcase 6:
SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 7:
SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 8:
SELECT sum(gpa) AS avg_6_8 FROM ONLY student;

--Testcase 9:
SELECT max(four) AS max_3 FROM onek;
--Testcase 10:
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 11:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 12:
SELECT max(student.gpa) AS max_3_7 FROM student;

--Testcase 13:
SELECT stddev_pop(b) FROM aggtest;
--Testcase 14:
SELECT stddev_samp(b) FROM aggtest;
--Testcase 15:
SELECT var_pop(b) FROM aggtest;
--Testcase 16:
SELECT var_samp(b) FROM aggtest;

--Testcase 17:
SELECT stddev_pop(b::numeric) FROM aggtest;
--Testcase 18:
SELECT stddev_samp(b::numeric) FROM aggtest;
--Testcase 19:
SELECT var_pop(b::numeric) FROM aggtest;
--Testcase 20:
SELECT var_samp(b::numeric) FROM aggtest;

-- population variance is defined for a single tuple, sample variance
-- is not
--Testcase 21:
SELECT var_pop(1.0), var_samp(2.0);
--Testcase 22:
SELECT stddev_pop(3.0::numeric), stddev_samp(4.0::numeric);

-- verify correct results for null and NaN inputs
create foreign table generate_series1(a int) server influxdb_svr;
--Testcase 23:
select sum(null::int4) from generate_series1;
--Testcase 24:
select sum(null::int8) from generate_series1;
--Testcase 25:
select sum(null::numeric) from generate_series1;
--Testcase 26:
select sum(null::float8) from generate_series1;
--Testcase 27:
select avg(null::int4) from generate_series1;
--Testcase 28:
select avg(null::int8) from generate_series1;
--Testcase 29:
select avg(null::numeric) from generate_series1;
--Testcase 30:
select avg(null::float8) from generate_series1;
--Testcase 31:
select sum('NaN'::numeric) from generate_series1;
--Testcase 32:
select avg('NaN'::numeric) from generate_series1;

-- verify correct results for infinite inputs
create foreign table infinite1(id int, a text) server influxdb_svr;
--Testcase 33:
SELECT avg(a::float8), var_pop(a::float8) 
FROM infinite1 WHERE id = 1;

--Testcase 34:
SELECT avg(a::float8), var_pop(a::float8) 
FROM infinite1 WHERE id = 2;

--Testcase 35:
SELECT avg(a::float8), var_pop(a::float8) 
FROM infinite1 WHERE id = 3;

--Testcase 36:
SELECT avg(a::float8), var_pop(a::float8)
FROM infinite1 WHERE id = 4;

-- test accuracy with a large input offset
create foreign table large_input1(id int, a int) server influxdb_svr;
--Testcase 37:
SELECT avg(a::float8), var_pop(a::float8)
FROM large_input1 WHERE id=1;

--Testcase 38:
SELECT avg(a::float8), var_pop(a::float8)
FROM large_input1 WHERE id=2;

-- SQL2003 binary aggregates
--Testcase 39:
SELECT regr_count(b, a) FROM aggtest;
--Testcase 40:
SELECT regr_sxx(b, a) FROM aggtest;
--Testcase 41:
SELECT regr_syy(b, a) FROM aggtest;
--Testcase 42:
SELECT regr_sxy(b, a) FROM aggtest;
--Testcase 43:
SELECT regr_avgx(b, a), regr_avgy(b, a) FROM aggtest;
--Testcase 44:
SELECT regr_r2(b, a) FROM aggtest;
--Testcase 45:
SELECT regr_slope(b, a), regr_intercept(b, a) FROM aggtest;
--Testcase 46:
SELECT covar_pop(b, a), covar_samp(b, a) FROM aggtest;
--Testcase 47:
SELECT corr(b, a) FROM aggtest;

-- test accum and combine functions directly
CREATE FOREIGN TABLE regr_test1 (x float8, y float8) server influxdb_svr;
--Testcase 48:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test1 WHERE x IN (10,20,30,80);
--Testcase 49:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test1;

CREATE FOREIGN TABLE float8_arr1 (id int, x text, y text) server influxdb_svr;
--Testcase 50:
SELECT float8_accum(x::float8[], 100) FROM float8_arr1 WHERE id=1;
--Testcase 51:
SELECT float8_regr_accum(x::float8[], 200, 100) FROM float8_arr1 WHERE id=2;
--Testcase 52:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test1 WHERE x IN (10,20,30);
--Testcase 53:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test1 WHERE x IN (80,100);
--Testcase 54:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr1 WHERE id=3;
--Testcase 55:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr1 WHERE id=4;
--Testcase 56:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr1 WHERE id=5;
--Testcase 57:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr1 WHERE id=6;
--Testcase 58:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr1 WHERE id=7;
--Testcase 59:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr1 WHERE id=8;

-- test count, distinct
--Testcase 60:
SELECT count(four) AS cnt_1000 FROM onek;
--Testcase 61:
SELECT count(DISTINCT four) AS cnt_4 FROM onek;

--Testcase 62:
select ten, count(*), sum(four) from onek
group by ten order by ten;

--Testcase 63:
select ten, count(four), sum(DISTINCT four) from onek
group by ten order by ten;

-- user-defined aggregates
CREATE AGGREGATE newavg (
  sfunc = int4_avg_accum, basetype = int4, stype = _int8,
  finalfunc = int8_avg,
  initcond1 = '{0,0}'
);

-- without finalfunc; test obsolete spellings 'sfunc1' etc
CREATE AGGREGATE newsum (
  sfunc1 = int4pl, basetype = int4, stype1 = int4,
  initcond1 = '0'
);

-- zero-argument aggregate
CREATE AGGREGATE newcnt (*) (
  sfunc = int8inc, stype = int8,
  initcond = '0', parallel = safe
);

-- old-style spelling of same (except without parallel-safe; that's too new)
CREATE AGGREGATE oldcnt (
  sfunc = int8inc, basetype = 'ANY', stype = int8,
  initcond = '0'
);

-- aggregate that only cares about null/nonnull input
CREATE AGGREGATE newcnt ("any") (
  sfunc = int8inc_any, stype = int8,
  initcond = '0'
);

-- multi-argument aggregate
create function sum3(int8,int8,int8) returns int8 as
'select $1 + $2 + $3' language sql strict immutable;

create aggregate sum2(int8,int8) (
  sfunc = sum3, stype = int8,
  initcond = '0'
);

--Testcase 64:
SELECT newavg(four) AS avg_1 FROM onek;
--Testcase 65:
SELECT newsum(four) AS sum_1500 FROM onek;
--Testcase 66:
SELECT newcnt(four) AS cnt_1000 FROM onek;
--Testcase 67:
SELECT newcnt(*) AS cnt_1000 FROM onek;
--Testcase 68:
SELECT oldcnt(*) AS cnt_1000 FROM onek;
--Testcase 69:
SELECT sum2(q1,q2) FROM int8_tbl;

-- test for outer-level aggregates

-- this should work
--Testcase 70:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

-- this should fail because subquery has an agg of its own in WHERE
--Testcase 71:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b
               where sum(distinct a.four + b.four) = b.four);

-- Test handling of sublinks within outer-level aggregates.
-- Per bug report from Daniel Grace.
-- this test 
--select
--  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1)))
--from tenk1 o;

-- Test handling of Params within aggregate arguments in hashed aggregation.
-- Per bug report from Jeevan Chalke.
--Testcase 72:
explain (verbose, costs off)
select s1.a, ss.a, sm
from generate_series1 s1,
     lateral (select s2.a, sum(s1.a + s2.a) sm
              from generate_series1 s2 group by s2.a) ss
order by 1, 2;
--Testcase 73:
select s1.a, ss.a, sm
from generate_series1 s1,
     lateral (select s2.a, sum(s1.a + s2.a) sm
              from generate_series1 s2 group by s2.a) ss
order by 1, 2;

--Testcase 74:
explain (verbose, costs off)
select array(select sum(x.a+y.a) s
            from generate_series1 y group by y.a order by s)
  from generate_series1 x;
--Testcase 75:
select array(select sum(x.a+y.a) s
            from generate_series1 y group by y.a order by s)
  from generate_series1 x;

--
-- test for bitwise integer aggregates
--
CREATE FOREIGN TABLE bitwise_test_empty (
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2,
  y BIT(4)
) SERVER influxdb_svr;

-- empty case
--Testcase 76:
SELECT
  BIT_AND(i2) AS "?",
  BIT_OR(i4)  AS "?"
FROM bitwise_test_empty;

CREATE FOREIGN TABLE bitwise_test (
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2,
  y BIT(4)
) SERVER influxdb_svr;

--Testcase 77:
SELECT
  BIT_AND(i2) AS "1",
  BIT_AND(i4) AS "1",
  BIT_AND(i8) AS "1",
  BIT_AND(i)  AS "?",
  BIT_AND(x)  AS "0",
  BIT_AND(y)  AS "0100",

  BIT_OR(i2)  AS "7",
  BIT_OR(i4)  AS "7",
  BIT_OR(i8)  AS "7",
  BIT_OR(i)   AS "?",
  BIT_OR(x)   AS "7",
  BIT_OR(y)   AS "1101"
FROM bitwise_test;

--
-- test boolean aggregates
--
-- first test all possible transition and final states
CREATE FOREIGN TABLE boolean1 (x1 BOOL, y1 BOOL , x2 BOOL, y2 BOOL,
			x3 BOOL, y3 BOOL, x4 BOOL, y4 BOOL,
			x5 BOOL, y5 BOOL, x6 BOOL, y6 BOOL,
			x7 BOOL, y7 BOOL, x8 BOOL, y8 BOOL,
			x9 BOOL, y9 BOOL) SERVER influxdb_svr;

--Testcase 78:
SELECT
  -- boolean and transitions
  -- null because strict
  booland_statefunc(x1, y1)  IS NULL AS "t",
  booland_statefunc(x2, y2)  IS NULL AS "t",
  booland_statefunc(x3, y3) IS NULL AS "t",
  booland_statefunc(x4, y4)  IS NULL AS "t",
  booland_statefunc(x5, y5) IS NULL AS "t",
  -- and actual computations
  booland_statefunc(x6, y6) AS "t",
  NOT booland_statefunc(x7, y7) AS "t",
  NOT booland_statefunc(x8, y8) AS "t",
  NOT booland_statefunc(x9, y9) AS "t" FROM boolean1;

--Testcase 79:
SELECT
  -- boolean or transitions
  -- null because strict
  boolor_statefunc(x1, y1)  IS NULL AS "t",
  boolor_statefunc(x2, y2)  IS NULL AS "t",
  boolor_statefunc(x3, y3) IS NULL AS "t",
  boolor_statefunc(x4, y4)  IS NULL AS "t",
  boolor_statefunc(x5, y5) IS NULL AS "t",
  -- actual computations
  boolor_statefunc(x6, y6) AS "t",
  boolor_statefunc(x7, y7) AS "t",
  boolor_statefunc(x8, y8) AS "t",
  NOT boolor_statefunc(x9, y9) AS "t" FROM boolean1;

CREATE FOREIGN TABLE bool_test_empty (
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL
) SERVER influxdb_svr;

-- empty case
--Testcase 80:
SELECT
  BOOL_AND(b1)   AS "n",
  BOOL_OR(b3)    AS "n"
FROM bool_test_empty;

CREATE FOREIGN TABLE bool_test (
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL
) SERVER influxdb_svr;

--Testcase 81:
SELECT
  BOOL_AND(b1)     AS "f",
  BOOL_AND(b2)     AS "t",
  BOOL_AND(b3)     AS "f",
  BOOL_AND(b4)     AS "n",
  BOOL_AND(NOT b2) AS "f",
  BOOL_AND(NOT b3) AS "t"
FROM bool_test;

--Testcase 82:
SELECT
  EVERY(b1)     AS "f",
  EVERY(b2)     AS "t",
  EVERY(b3)     AS "f",
  EVERY(b4)     AS "n",
  EVERY(NOT b2) AS "f",
  EVERY(NOT b3) AS "t"
FROM bool_test;

--Testcase 83:
SELECT
  BOOL_OR(b1)      AS "t",
  BOOL_OR(b2)      AS "t",
  BOOL_OR(b3)      AS "f",
  BOOL_OR(b4)      AS "n",
  BOOL_OR(NOT b2)  AS "f",
  BOOL_OR(NOT b3)  AS "t"
FROM bool_test;

--
-- Test cases that should be optimized into indexscans instead of
-- the generic aggregate implementation.
--

-- Basic cases
--Testcase 84:
explain (costs off)
  select min(unique1) from tenk1;
--Testcase 85:
select min(unique1) from tenk1;
--Testcase 86:
explain (costs off)
  select max(unique1) from tenk1;
--Testcase 87:
select max(unique1) from tenk1;
--Testcase 88:
explain (costs off)
  select max(unique1) from tenk1 where unique1 < 42;
--Testcase 89:
select max(unique1) from tenk1 where unique1 < 42;
--Testcase 90:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42;
--Testcase 91:
select max(unique1) from tenk1 where unique1 > 42;

-- the planner may choose a generic aggregate here if parallel query is
-- enabled, since that plan will be parallel safe and the "optimized"
-- plan, which has almost identical cost, will not be.  we want to test
-- the optimized plan, so temporarily disable parallel query.
begin;
set local max_parallel_workers_per_gather = 0;
--Testcase 92:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42000;
--Testcase 93:
select max(unique1) from tenk1 where unique1 > 42000;
rollback;

-- multi-column index (uses tenk1_thous_tenthous)
--Testcase 94:
explain (costs off)
  select max(tenthous) from tenk1 where thousand = 33;
--Testcase 95:
select max(tenthous) from tenk1 where thousand = 33;
--Testcase 96:
explain (costs off)
  select min(tenthous) from tenk1 where thousand = 33;
--Testcase 97:
select min(tenthous) from tenk1 where thousand = 33;

-- check parameter propagation into an indexscan subquery
--Testcase 98:
explain (costs off)
  select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
    from int4_tbl;
--Testcase 99:
select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
  from int4_tbl;

-- check some cases that were handled incorrectly in 8.3.0
--Testcase 100:
explain (costs off)
  select distinct max(unique2) from tenk1;
--Testcase 101:
select distinct max(unique2) from tenk1;
--Testcase 102:
explain (costs off)
  select max(unique2) from tenk1 order by 1;
--Testcase 103:
select max(unique2) from tenk1 order by 1;
--Testcase 104:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2);
--Testcase 105:
select max(unique2) from tenk1 order by max(unique2);
--Testcase 106:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 107:
select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 108:
explain (costs off)
  select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;
--Testcase 109:
select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;

-- interesting corner case: constant gets optimized into a seqscan
--Testcase 110:
explain (costs off)
  select max(100) from tenk1;
--Testcase 111:
select max(100) from tenk1;

-- try it on an inheritance tree
create foreign table minmaxtest(f1 int) server influxdb_svr;;
create table minmaxtest1() inherits (minmaxtest);
create table minmaxtest2() inherits (minmaxtest);
create table minmaxtest3() inherits (minmaxtest);
-- create index minmaxtesti on minmaxtest(f1);
create index minmaxtest1i on minmaxtest1(f1);
create index minmaxtest2i on minmaxtest2(f1 desc);
create index minmaxtest3i on minmaxtest3(f1) where f1 is not null;

-- insert into minmaxtest values(11), (12);
--Testcase 112:
insert into minmaxtest1 values(13), (14);
--Testcase 113:
insert into minmaxtest2 values(15), (16);
--Testcase 114:
insert into minmaxtest3 values(17), (18);

--Testcase 115:
explain (costs off)
  select min(f1), max(f1) from minmaxtest;
--Testcase 116:
select min(f1), max(f1) from minmaxtest;

-- DISTINCT doesn't do anything useful here, but it shouldn't fail
--Testcase 117:
explain (costs off)
  select distinct min(f1), max(f1) from minmaxtest;
--Testcase 118:
select distinct min(f1), max(f1) from minmaxtest;

drop foreign table minmaxtest cascade;

-- check for correct detection of nested-aggregate errors
--Testcase 119:
select max(min(unique1)) from tenk1;
--Testcase 120:
select (select max(min(unique1)) from int8_tbl) from tenk1;

--
-- Test removal of redundant GROUP BY columns
--

create foreign table agg_t1 (a int, b int, c int, d int) server influxdb_svr;
create foreign table agg_t2 (x int, y int, z int) server influxdb_svr;

-- Non-primary-key columns can be removed from GROUP BY
--Testcase 121:
explain (costs off) select * from agg_t1 group by a,b,c,d;

-- No removal can happen if the complete PK is not present in GROUP BY
--Testcase 122:
explain (costs off) select a,c from agg_t1 group by a,c,d;

-- Test removal across multiple relations
--Testcase 123:
explain (costs off) select *
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.y,agg_t2.z;

-- Test case where agg_t1 can be optimized but not agg_t2
--Testcase 124:
explain (costs off) select agg_t1.*,agg_t2.x,agg_t2.z
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.z;

--
-- Test combinations of DISTINCT and/or ORDER BY
--
begin;
--Testcase 125:
select array_agg(q1 order by q2)
  from INT8_TBL2;
--Testcase 126:
select array_agg(q1 order by q1)
  from INT8_TBL2;
--Testcase 127:
select array_agg(q1 order by q1 desc)
  from INT8_TBL2;
--Testcase 128:
select array_agg(q2 order by q1 desc)
  from INT8_TBL2;

--Testcase 129:
select array_agg(distinct f1)
  from INT4_TBL2;
--Testcase 130:
select array_agg(distinct f1 order by f1)
  from INT4_TBL2;
--Testcase 131:
select array_agg(distinct f1 order by f1 desc)
  from INT4_TBL2;
--Testcase 132:
select array_agg(distinct f1 order by f1 desc nulls last)
  from INT4_TBL2;
rollback;

-- multi-arg aggs, strict/nonstrict, distinct/order by
create type aggtype as (a integer, b integer, c text);

create function aggf_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql strict immutable;

create function aggfns_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql immutable;

create aggregate aggfstr(integer,integer,text) (
   sfunc = aggf_trans, stype = aggtype[],
   initcond = '{}'
);

create aggregate aggfns(integer,integer,text) (
   sfunc = aggfns_trans, stype = aggtype[], sspace = 10000,
   initcond = '{}'
);

begin;
--Testcase 133:
select aggfstr(a,b,c) from multi_arg_agg;
--Testcase 134:
select aggfns(a,b,c) from multi_arg_agg;

--Testcase 135:
select aggfstr(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;
--Testcase 136:
select aggfns(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;

--Testcase 137:
select aggfstr(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;
--Testcase 138:
select aggfns(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;

-- test specific code paths

--Testcase 139:
select aggfns(distinct a,a,c order by c using ~<~,a) from multi_arg_agg, generate_series(1,2) i;
--Testcase 140:
select aggfns(distinct a,a,c order by c using ~<~) from multi_arg_agg, generate_series(1,2) i;
--Testcase 141:
select aggfns(distinct a,a,c order by a) from multi_arg_agg, generate_series(1,2) i;
--Testcase 142:
select aggfns(distinct a,b,c order by a,c using ~<~,b) from multi_arg_agg, generate_series(1,2) i;

-- check node I/O via view creation and usage, also deparsing logic

create view agg_view1 as
  select aggfns(a,b,c) from multi_arg_agg;

--Testcase 143:
select * from agg_view1;
--Testcase 144:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;

--Testcase 145:
select * from agg_view1;
--Testcase 146:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;

--Testcase 147:
select * from agg_view1;
--Testcase 148:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(a,b,c order by b+1) from multi_arg_agg;

--Testcase 149:
select * from agg_view1;
--Testcase 150:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(a,a,c order by b) from multi_arg_agg;

--Testcase 151:
select * from agg_view1;
--Testcase 152:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(a,b,c order by c using ~<~) from multi_arg_agg;

--Testcase 153:
select * from agg_view1;
--Testcase 154:
select pg_get_viewdef('agg_view1'::regclass);

create or replace view agg_view1 as
  select aggfns(distinct a,b,c order by a,c using ~<~,b) from multi_arg_agg, generate_series(1,2) i;

--Testcase 155:
select * from agg_view1;
--Testcase 156:
select pg_get_viewdef('agg_view1'::regclass);

drop view agg_view1;
rollback;

-- incorrect DISTINCT usage errors
--Testcase 157:
select aggfns(distinct a,b,c order by i) from multi_arg_agg2, generate_series(1,2) i;
--Testcase 158:
select aggfns(distinct a,b,c order by a,b+1) from multi_arg_agg2, generate_series(1,2) i;
--Testcase 159:
select aggfns(distinct a,b,c order by a,b,i,c) from multi_arg_agg2, generate_series(1,2) i;
--Testcase 160:
select aggfns(distinct a,a,c order by a,b) from multi_arg_agg2, generate_series(1,2) i;

-- string_agg tests
create foreign table string_agg1(a1 text, a2 text) server influxdb_svr;
create foreign table string_agg2(a1 text, a2 text) server influxdb_svr;
create foreign table string_agg3(a1 text, a2 text) server influxdb_svr;
create foreign table string_agg4(a1 text, a2 text) server influxdb_svr;

--Testcase 161:
select string_agg(a1,',') from string_agg1;
--Testcase 162:
select string_agg(a1,',') from string_agg2;
--Testcase 163:
select string_agg(a1,'AB') from string_agg3;
--Testcase 164:
select string_agg(a1,',') from string_agg4;

-- check some implicit casting cases, as per bug #5564
--Testcase 165:
select string_agg(distinct f1, ',' order by f1) from varchar_tbl;  -- ok
--Testcase 166:
select string_agg(distinct f1::text, ',' order by f1) from varchar_tbl;  -- not ok
--Testcase 167:
select string_agg(distinct f1, ',' order by f1::text) from varchar_tbl;  -- not ok
--Testcase 168:
select string_agg(distinct f1::text, ',' order by f1::text) from varchar_tbl;  -- ok

-- InfluxDB does not support binary data
-- string_agg bytea tests
-- create foreign table bytea_test_table(v bytea) server influxdb_svr;

-- select string_agg(v, '') from bytea_test_table;

-- insert into bytea_test_table values(decode('ff','hex'));

-- select string_agg(v, '') from bytea_test_table;

-- insert into bytea_test_table values(decode('aa','hex'));

-- select string_agg(v, '') from bytea_test_table;
-- select string_agg(v, NULL) from bytea_test_table;
-- select string_agg(v, decode('ee', 'hex')) from bytea_test_table;

-- drop foreign table bytea_test_table;

-- FILTER tests

--Testcase 169:
select min(unique1) filter (where unique1 > 100) from tenk1;

--Testcase 170:
select sum(1/ten) filter (where ten > 0) from tenk1;

--Testcase 171:
select ten, sum(distinct four) filter (where four::text ~ '123') from onek a
group by ten;

--Testcase 172:
select ten, sum(distinct four) filter (where four > 10) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

--Testcase 173:
select max(foo COLLATE "C") filter (where (bar collate "POSIX") > '0')
from (values ('a', 'b')) AS v(foo,bar);

-- outer reference in FILTER (PostgreSQL extension)
--Testcase 174:
select (select count(*)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- inner query is aggregation query
--Testcase 175:
select (select count(*) filter (where outer_c <> 0)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- outer query is aggregation query
--Testcase 176:
select (select count(inner_c) filter (where outer_c <> 0)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- inner query is aggregation query
--Testcase 177:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1))
     filter (where o.unique1 < 10))
from tenk1 o;                   -- outer query is aggregation query

-- subquery in FILTER clause (PostgreSQL extension)
--Testcase 178:
select sum(unique1) FILTER (WHERE
  unique1 IN (SELECT unique1 FROM onek where unique1 < 100)) FROM tenk1;

-- exercise lots of aggregate parts with FILTER
begin;
--Testcase 179:
select aggfns(distinct a,b,c order by a,c using ~<~,b) filter (where a > 1) from multi_arg_agg3, generate_series(1,2) i;
rollback;

-- ordered-set aggregates

begin;
--Testcase 180:
select f1, percentile_cont(f1) within group (order by x::float8)
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 181:
select f1, percentile_cont(f1 order by f1) within group (order by x)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 182:
select f1, sum() within group (order by x::float8)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 183:
select f1, percentile_cont(f1,f1)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

--Testcase 184:
select percentile_cont(0.5) within group (order by b) from aggtest;
--Testcase 185:
select percentile_cont(0.5) within group (order by b), sum(b) from aggtest;
--Testcase 186:
select percentile_cont(0.5) within group (order by thousand) from tenk1;
--Testcase 187:
select percentile_disc(0.5) within group (order by thousand) from tenk1;

begin;
--Testcase 188:
select rank(3) within group (order by f1) from INT4_TBL3;
--Testcase 189:
select cume_dist(3) within group (order by f1) from INT4_TBL3;
--Testcase 190:
select percent_rank(3) within group (order by f1) from INT4_TBL4;
--Testcase 191:
select dense_rank(3) within group (order by f1) from INT4_TBL3;
rollback;

--Testcase 192:
select percentile_disc(array[0,0.1,0.25,0.5,0.75,0.9,1]) within group (order by thousand)
from tenk1;
--Testcase 193:
select percentile_cont(array[0,0.25,0.5,0.75,1]) within group (order by thousand)
from tenk1;
--Testcase 194:
select percentile_disc(array[[null,1,0.5],[0.75,0.25,null]]) within group (order by thousand)
from tenk1;
create foreign table generate_series2 (a int) server influxdb_svr;
--Testcase 195:
select percentile_cont(array[0,1,0.25,0.75,0.5,1,0.3,0.32,0.35,0.38,0.4]) within group (order by a)
from generate_series2;

--Testcase 196:
select ten, mode() within group (order by string4) from tenk1 group by ten;

create foreign table percentile_disc1(x text) server influxdb_svr;
--Testcase 197:
select percentile_disc(array[0.25,0.5,0.75]) within group (order by unnest)
from (select unnest(x::text[]) from percentile_disc1) y;

-- check collation propagates up in suitable cases:
create foreign table pg_collation1 (x text) server influxdb_svr;
--Testcase 198:
select pg_collation_for(percentile_disc(1) within group (order by x collate "POSIX"))
  from pg_collation1;

-- test ordered-set aggs using built-in support functions
create aggregate test_percentile_disc(float8 ORDER BY anyelement) (
  stype = internal,
  sfunc = ordered_set_transition,
  finalfunc = percentile_disc_final,
  finalfunc_extra = true,
  finalfunc_modify = read_write
);

create aggregate test_rank(VARIADIC "any" ORDER BY VARIADIC "any") (
  stype = internal,
  sfunc = ordered_set_transition_multi,
  finalfunc = rank_final,
  finalfunc_extra = true,
  hypothetical
);

-- ordered-set aggs created with CREATE AGGREGATE
create foreign table test_rank1 (x int) server influxdb_svr;
--Testcase 199:
select test_rank(3) within group (order by x) from test_rank1;
--Testcase 200:
select test_percentile_disc(0.5) within group (order by thousand) from tenk1;

-- ordered-set aggs can't use ungrouped vars in direct args:
create foreign table generate_series3 (x int) server influxdb_svr;
--Testcase 201:
select rank(x) within group (order by x) from generate_series3 x;

-- outer-level agg can't use a grouped arg of a lower level, either:
--Testcase 202:
select array(select percentile_disc(a) within group (order by x)
               from (values (0.3),(0.7)) v(a) group by a)
  from generate_series3;

-- agg in the direct args is a grouping violation, too:
--Testcase 203:
select rank(sum(x)) within group (order by x) from generate_series3 x;

-- hypothetical-set type unification and argument-count failures:
--Testcase 204:
select rank(3) within group (order by x) from pg_collation1;
--Testcase 205:
select rank(3) within group (order by stringu1,stringu2) from tenk1;
--Testcase 206:
select rank('fred') within group (order by x) from generate_series3 x;
--Testcase 207:
select rank('adam'::text collate "C") within group (order by x collate "POSIX")
  from pg_collation1;
-- hypothetical-set type unification successes:
--Testcase 208:
select rank('adam'::varchar) within group (order by x) from pg_collation1;
--Testcase 209:
select rank('3') within group (order by x) from generate_series3 x;

-- divide by zero check
--Testcase 210:
select percent_rank(0) within group (order by x) from generate_series(1,0) x;

-- deparse and multiple features:
create view aggordview1 as
--Testcase 211:
select ten,
       percentile_disc(0.5) within group (order by thousand) as p50,
       percentile_disc(0.5) within group (order by thousand) filter (where hundred=1) as px,
       rank(5,'AZZZZ',50) within group (order by hundred, string4 desc, hundred)
  from tenk1
 group by ten order by ten;

--Testcase 212:
select pg_get_viewdef('aggordview1');
--Testcase 213:
select * from aggordview1 order by ten;
drop view aggordview1;

-- User defined function for user defined aggregate, VARIADIC
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

-- variadic aggregates
--Testcase 214:
select least_agg(q1,q2) from int8_tbl;
--Testcase 215:
select least_agg(variadic array[q1,q2]) from int8_tbl;


-- test aggregates with common transition functions share the same states
begin work;

create type avg_state as (total bigint, count bigint);

create or replace function avg_transfn(state avg_state, n int) returns avg_state as
$$
declare new_state avg_state;
begin
 raise notice 'avg_transfn called with %', n;
 if state is null then
     if n is not null then
         new_state.total := n;
         new_state.count := 1;
         return new_state;
     end if;
     return null;
 elsif n is not null then
     state.total := state.total + n;
     state.count := state.count + 1;
     return state;
 end if;

 return null;
end
$$ language plpgsql;

create function avg_finalfn(state avg_state) returns int4 as
$$
begin
 if state is null then
     return NULL;
 else
     return state.total / state.count;
 end if;
end
$$ language plpgsql;

create function sum_finalfn(state avg_state) returns int4 as
$$
begin
 if state is null then
     return NULL;
 else
     return state.total;
 end if;
end
$$ language plpgsql;

create aggregate my_avg(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn
);

create aggregate my_sum(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = sum_finalfn
);

-- aggregate state should be shared as aggs are the same.
create foreign table my_avg1 (one int) server influxdb_svr;
--Testcase 216:
select my_avg(one),my_avg(one) from my_avg1;

-- aggregate state should be shared as transfn is the same for both aggs.
--Testcase 217:
select my_avg(one),my_sum(one) from my_avg1;

-- same as previous one, but with DISTINCT, which requires sorting the input.
--Testcase 218:
select my_avg(distinct one),my_sum(distinct one) from my_avg1;

-- shouldn't share states due to the distinctness not matching.
--Testcase 219:
select my_avg(distinct one),my_sum(one) from my_avg1;

-- shouldn't share states due to the filter clause not matching.
--Testcase 220:
select my_avg(one) filter (where one > 1),my_sum(one) from my_avg1;

-- this should not share the state due to different input columns.
create foreign table my_avg2(one int, two int) server influxdb_svr;
--Testcase 221:
select my_avg(one),my_sum(two) from my_avg2;

-- exercise cases where OSAs share state
create foreign table percentile_cont1( a int) server influxdb_svr;
--Testcase 222:
select
  percentile_cont(0.5) within group (order by a),
  percentile_disc(0.5) within group (order by a)
from percentile_cont1;

--Testcase 223:
select
  percentile_cont(0.25) within group (order by a),
  percentile_disc(0.5) within group (order by a)
from percentile_cont1;

-- these can't share state currently
--Testcase 224:
select
  rank(4) within group (order by a),
  dense_rank(4) within group (order by a)
from percentile_cont1;

-- test that aggs with the same sfunc and initcond share the same agg state
create aggregate my_sum_init(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = sum_finalfn,
   initcond = '(10,0)'
);

create aggregate my_avg_init(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn,
   initcond = '(10,0)'
);

create aggregate my_avg_init2(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn,
   initcond = '(4,0)'
);

-- state should be shared if INITCONDs are matching
--Testcase 225:
select my_sum_init(one),my_avg_init(one) from my_avg1;

-- Varying INITCONDs should cause the states not to be shared.
--Testcase 226:
select my_sum_init(one),my_avg_init2(one) from my_avg1;

rollback;

-- test aggregate state sharing to ensure it works if one aggregate has a
-- finalfn and the other one has none.
begin work;

create or replace function sum_transfn(state int4, n int4) returns int4 as
$$
declare new_state int4;
begin
 raise notice 'sum_transfn called with %', n;
 if state is null then
     if n is not null then
         new_state := n;
         return new_state;
     end if;
     return null;
 elsif n is not null then
     state := state + n;
     return state;
 end if;

 return null;
end
$$ language plpgsql;

create function halfsum_finalfn(state int4) returns int4 as
$$
begin
 if state is null then
     return NULL;
 else
     return state / 2;
 end if;
end
$$ language plpgsql;

create aggregate my_sum(int4)
(
   stype = int4,
   sfunc = sum_transfn
);

create aggregate my_half_sum(int4)
(
   stype = int4,
   sfunc = sum_transfn,
   finalfunc = halfsum_finalfn
);

-- Agg state should be shared even though my_sum has no finalfn
create foreign table my_sum1(one int) server influxdb_svr;
--Testcase 227:
select my_sum(one),my_half_sum(one) from my_sum1;

rollback;


-- test that the aggregate transition logic correctly handles
-- transition / combine functions returning NULL

-- First test the case of a normal transition function returning NULL
BEGIN;
CREATE FUNCTION balkifnull(int8, int4)
RETURNS int8
STRICT
LANGUAGE plpgsql AS $$
BEGIN
    IF $1 IS NULL THEN
       RAISE 'erroneously called with NULL argument';
    END IF;
    RETURN NULL;
END$$;

CREATE AGGREGATE balk(int4)
(
    SFUNC = balkifnull(int8, int4),
    STYPE = int8,
    PARALLEL = SAFE,
    INITCOND = '0'
);

--Testcase 228:
SELECT balk(hundred) FROM tenk1;

ROLLBACK;

-- Secondly test the case of a parallel aggregate combiner function
-- returning NULL. For that use normal transition function, but a
-- combiner function returning NULL.
BEGIN ISOLATION LEVEL REPEATABLE READ;
CREATE FUNCTION balkifnull(int8, int8)
RETURNS int8
PARALLEL SAFE
STRICT
LANGUAGE plpgsql AS $$
BEGIN
    IF $1 IS NULL THEN
       RAISE 'erroneously called with NULL argument';
    END IF;
    RETURN NULL;
END$$;

CREATE AGGREGATE balk(int4)
(
    SFUNC = int4_sum(int8, int4),
    STYPE = int8,
    COMBINEFUNC = balkifnull(int8, int8),
    PARALLEL = SAFE,
    INITCOND = '0'
);

-- force use of parallelism
-- ALTER TABLE tenk1 set (parallel_workers = 4);
-- SET LOCAL parallel_setup_cost=0;
-- SET LOCAL max_parallel_workers_per_gather=4;

-- EXPLAIN (COSTS OFF) SELECT balk(hundred) FROM tenk1;
-- SELECT balk(hundred) FROM tenk1;

ROLLBACK;

-- test coverage for aggregate combine/serial/deserial functions
BEGIN ISOLATION LEVEL REPEATABLE READ;

SET parallel_setup_cost = 0;
SET parallel_tuple_cost = 0;
SET min_parallel_table_scan_size = 0;
SET max_parallel_workers_per_gather = 4;
SET enable_indexonlyscan = off;

-- variance(int4) covers numeric_poly_combine
-- sum(int8) covers int8_avg_combine
-- regr_count(float8, float8) covers int8inc_float8_float8 and aggregates with > 1 arg
--Testcase 229:
EXPLAIN (COSTS OFF, VERBOSE)
  SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8) FROM tenk1;

--Testcase 230:
SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8) FROM tenk1;

ROLLBACK;

-- test coverage for dense_rank
create foreign table dense_rank1 (x int) server influxdb_svr;
--Testcase 231:
SELECT dense_rank(x) WITHIN GROUP (ORDER BY x) FROM dense_rank1 GROUP BY (x) ORDER BY 1;


-- Ensure that the STRICT checks for aggregates does not take NULLness
-- of ORDER BY columns into account. See bug report around
-- 2a505161-2727-2473-7c46-591ed108ac52@email.cz
--Testcase 232:
SELECT min(x ORDER BY y) FROM (VALUES(1, NULL)) AS d(x,y);
--Testcase 233:
SELECT min(x ORDER BY y) FROM (VALUES(1, 2)) AS d(x,y);

-- check collation-sensitive matching between grouping expressions
--Testcase 234:
select v||'a', case v||'a' when 'aa' then 1 else 0 end, count(*)
  from unnest(array['a','b']) u(v)
 group by v||'a' order by 1;
--Testcase 235:
select v||'a', case when v||'a' = 'aa' then 1 else 0 end, count(*)
  from unnest(array['a','b']) u(v)
 group by v||'a' order by 1;

-- Make sure that generation of HashAggregate for uniqification purposes
-- does not lead to array overflow due to unexpected duplicate hash keys
-- see CAFeeJoKKu0u+A_A9R9316djW-YW3-+Gtgvy3ju655qRHR3jtdA@mail.gmail.com
--Testcase 236:
explain (costs off)
  select 1 from tenk1
   where (hundred, thousand) in (select twothousand, twothousand from onek);

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
