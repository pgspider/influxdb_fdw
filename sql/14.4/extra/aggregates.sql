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

--Testcase 4:
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

--Testcase 5:
CREATE FOREIGN TABLE aggtest (
  a         int2,
  b         float4
) SERVER influxdb_svr OPTIONS (table 'agg');

--Testcase 6:
CREATE FOREIGN TABLE student (
  name      text,
  age       int4,
  location  point,
  gpa       float8
) SERVER influxdb_svr;

--Testcase 7:
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

--Testcase 8:
CREATE FOREIGN TABLE INT8_TBL (
  q1        int8,
  q2        int8
) SERVER influxdb_svr;

--Testcase 9:
CREATE FOREIGN TABLE INT8_TBL2 (
  q1        int8,
  q2        int8
) SERVER influxdb_svr;

--Testcase 10:
CREATE FOREIGN TABLE INT4_TBL (f1 int4) SERVER influxdb_svr;
--Testcase 11:
CREATE FOREIGN TABLE INT4_TBL2 (f1 int4) SERVER influxdb_svr;
--Testcase 12:
CREATE FOREIGN TABLE INT4_TBL3 (f1 int4) SERVER influxdb_svr;
--Testcase 13:
CREATE FOREIGN TABLE INT4_TBL4 (f1 int4) SERVER influxdb_svr;

--Testcase 14:
CREATE FOREIGN TABLE multi_arg_agg (a int, b int, c text) SERVER influxdb_svr;
--Testcase 15:
CREATE FOREIGN TABLE multi_arg_agg2 (a int, b int, c text) SERVER influxdb_svr;
--Testcase 16:
CREATE FOREIGN TABLE multi_arg_agg3 (a int, b int, c text) SERVER influxdb_svr;

--Testcase 17:
CREATE FOREIGN TABLE VARCHAR_TBL (f1 varchar(4)) SERVER influxdb_svr;
--Testcase 18:
CREATE FOREIGN TABLE FLOAT8_TBL (f1 float8) SERVER influxdb_svr;

--
-- AGGREGATES
--

-- avoid bit-exact output here because operations may not be bit-exact.
--Testcase 19:
SET extra_float_digits = 0;

--Testcase 20:
SELECT avg(four) AS avg_1 FROM onek;

--Testcase 21:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

-- In 7.1, avg(float4) is computed using float8 arithmetic.
-- Round the result to 3 digits to avoid platform-specific results.

--Testcase 22:
SELECT avg(b)::numeric(10,3) AS avg_107_943 FROM aggtest;

--Testcase 23:
SELECT avg(gpa) AS avg_3_4 FROM ONLY student;


--Testcase 24:
SELECT sum(four) AS sum_1500 FROM onek;
--Testcase 25:
SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 26:
SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 27:
SELECT sum(gpa) AS avg_6_8 FROM ONLY student;

--Testcase 28:
SELECT max(four) AS max_3 FROM onek;
--Testcase 29:
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 30:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 31:
SELECT max(student.gpa) AS max_3_7 FROM student;

--Testcase 32:
SELECT stddev_pop(b) FROM aggtest;
--Testcase 33:
SELECT stddev_samp(b) FROM aggtest;
--Testcase 34:
SELECT var_pop(b) FROM aggtest;
--Testcase 35:
SELECT var_samp(b) FROM aggtest;

--Testcase 36:
SELECT stddev_pop(b::numeric) FROM aggtest;
--Testcase 37:
SELECT stddev_samp(b::numeric) FROM aggtest;
--Testcase 38:
SELECT var_pop(b::numeric) FROM aggtest;
--Testcase 39:
SELECT var_samp(b::numeric) FROM aggtest;

-- population variance is defined for a single tuple, sample variance
-- is not
--Testcase 40:
CREATE FOREIGN TABLE agg_t5 (id int, a text, b text) SERVER influxdb_svr;
--Testcase 41:
SELECT var_pop(a::float8), var_samp(b::float8) FROM agg_t5 WHERE id = 1;
--Testcase 42:
SELECT stddev_pop(a::float8), stddev_samp(b::float8) FROM agg_t5 WHERE id = 2;
--Testcase 43:
SELECT var_pop(a::float8), var_samp(b::float8) FROM agg_t5 WHERE id = 3;
--Testcase 44:
SELECT stddev_pop(a::float8), stddev_samp(b::float8) FROM agg_t5 WHERE id = 3;
--Testcase 45:
SELECT var_pop(a::float8), var_samp(b::float8) FROM agg_t5 WHERE id = 4;
--Testcase 46:
SELECT stddev_pop(a::float8), stddev_samp(b::float8) FROM agg_t5 WHERE id = 4;
--Testcase 47:
SELECT var_pop(a::float4), var_samp(b::float4) FROM agg_t5 WHERE id = 1;
--Testcase 48:
SELECT stddev_pop(a::float4), stddev_samp(b::float4) FROM agg_t5 WHERE id = 2;
--Testcase 49:
SELECT var_pop(a::float4), var_samp(b::float4) FROM agg_t5 WHERE id = 3;
--Testcase 50:
SELECT stddev_pop(a::float4), stddev_samp(b::float4) FROM agg_t5 WHERE id = 3;
--Testcase 51:
SELECT var_pop(a::float4), var_samp(b::float4) FROM agg_t5 WHERE id = 4;
--Testcase 52:
SELECT stddev_pop(a::float4), stddev_samp(b::float4) FROM agg_t5 WHERE id = 4;
--Testcase 53:
SELECT var_pop(a::numeric), var_samp(b::numeric) FROM agg_t5 WHERE id = 1;
--Testcase 54:
SELECT stddev_pop(a::numeric), stddev_samp(b::numeric) FROM agg_t5 WHERE id = 2;
--Testcase 55:
SELECT var_pop(a::numeric), var_samp(b::numeric) FROM agg_t5 WHERE id = 3;
--Testcase 56:
SELECT stddev_pop(a::numeric), stddev_samp(b::numeric) FROM agg_t5 WHERE id = 3;
--Testcase 57:
SELECT var_pop(a::numeric), var_samp(b::numeric) FROM agg_t5 WHERE id = 4;
--Testcase 58:
SELECT stddev_pop(a::numeric), stddev_samp(b::numeric) FROM agg_t5 WHERE id = 4;

-- verify correct results for null and NaN inputs
--Testcase 59:
create foreign table generate_series1(a int) server influxdb_svr;
--Testcase 60:
select sum(null::int4) from generate_series1;
--Testcase 61:
select sum(null::int8) from generate_series1;
--Testcase 62:
select sum(null::numeric) from generate_series1;
--Testcase 63:
select sum(null::float8) from generate_series1;
--Testcase 64:
select avg(null::int4) from generate_series1;
--Testcase 65:
select avg(null::int8) from generate_series1;
--Testcase 66:
select avg(null::numeric) from generate_series1;
--Testcase 67:
select avg(null::float8) from generate_series1;
--Testcase 68:
select sum('NaN'::numeric) from generate_series1;
--Testcase 69:
select avg('NaN'::numeric) from generate_series1;

-- verify correct results for infinite inputs
--Testcase 70:
create foreign table infinite1(id int, x text) server influxdb_svr;
--Testcase 71:
SELECT sum(x::float8), avg(x::float8), var_pop(x::float8)
FROM infinite1 WHERE id = 1;
--Testcase 72:
SELECT sum(x::float8), avg(x::float8), var_pop(x::float8)
FROM infinite1 WHERE id = 2;
--Testcase 73:
SELECT sum(x::float8), avg(x::float8), var_pop(x::float8)
FROM infinite1 WHERE id = 3;
--Testcase 74:
SELECT sum(x::float8), avg(x::float8), var_pop(x::float8)
FROM infinite1 WHERE id = 4;
--Testcase 75:
SELECT sum(x::float8), avg(x::float8), var_pop(x::float8)
FROM infinite1 WHERE id = 5;
--Testcase 76:
SELECT sum(x::numeric), avg(x::numeric), var_pop(x::numeric)
FROM infinite1 WHERE id = 1;
--Testcase 77:
SELECT sum(x::numeric), avg(x::numeric), var_pop(x::numeric)
FROM infinite1 WHERE id = 2;
--Testcase 78:
SELECT sum(x::numeric), avg(x::numeric), var_pop(x::numeric)
FROM infinite1 WHERE id = 3;
--Testcase 79:
SELECT sum(x::numeric), avg(x::numeric), var_pop(x::numeric)
FROM infinite1 WHERE id = 4;
--Testcase 80:
SELECT sum(x::numeric), avg(x::numeric), var_pop(x::numeric)
FROM infinite1 WHERE id = 5;

-- test accuracy with a large input offset
--Testcase 81:
create foreign table large_input1(id int, x float8) server influxdb_svr;
--Testcase 82:
SELECT avg(x::float8), var_pop(x::float8)
FROM large_input1 WHERE id=1;
--Testcase 83:
SELECT avg(x::float8), var_pop(x::float8)
FROM large_input1 WHERE id=2;

-- SQL2003 binary aggregates
--Testcase 84:
SELECT regr_count(b, a) FROM aggtest;
--Testcase 85:
SELECT regr_sxx(b, a) FROM aggtest;
--Testcase 86:
SELECT regr_syy(b, a) FROM aggtest;
--Testcase 87:
SELECT regr_sxy(b, a) FROM aggtest;
--Testcase 88:
SELECT regr_avgx(b, a), regr_avgy(b, a) FROM aggtest;
--Testcase 89:
SELECT regr_r2(b, a) FROM aggtest;
--Testcase 90:
SELECT regr_slope(b, a), regr_intercept(b, a) FROM aggtest;
--Testcase 91:
SELECT covar_pop(b, a), covar_samp(b, a) FROM aggtest;
--Testcase 92:
SELECT corr(b, a) FROM aggtest;

-- check single-tuple behavior
--Testcase 93:
create foreign table agg_t4(id int, a text, b text, c text, d text) server influxdb_svr;
--Testcase 94:
SELECT covar_pop(a::float8,b::float8), covar_samp(c::float8,d::float8) FROM agg_t4 WHERE id = 1;
--Testcase 95:
SELECT covar_pop(a::float8,b::float8), covar_samp(c::float8,d::float8) FROM agg_t4 WHERE id = 2;
--Testcase 96:
SELECT covar_pop(a::float8,b::float8), covar_samp(c::float8,d::float8) FROM agg_t4 WHERE id = 3;

-- test accum and combine functions directly
--Testcase 97:
CREATE FOREIGN TABLE regr_test (x float8, y float8) server influxdb_svr;
--Testcase 98:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30,80);
--Testcase 99:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test;

--Testcase 100:
CREATE FOREIGN TABLE float8_arr (id int, x text, y text) server influxdb_svr;
--Testcase 101:
SELECT float8_accum(x::float8[], 100) FROM float8_arr WHERE id=1;
--Testcase 102:
SELECT float8_regr_accum(x::float8[], 200, 100) FROM float8_arr WHERE id=2;
--Testcase 103:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30);
--Testcase 104:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (80,100);
--Testcase 105:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr WHERE id=3;
--Testcase 106:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr WHERE id=4;
--Testcase 107:
SELECT float8_combine(x::float8[], y::float8[]) FROM float8_arr WHERE id=5;
--Testcase 108:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr WHERE id=6;
--Testcase 109:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr WHERE id=7;
--Testcase 110:
SELECT float8_regr_combine(x::float8[],y::float8[]) FROM float8_arr WHERE id=8;
--Testcase 111:
DROP FOREIGN TABLE regr_test;

-- test count, distinct
--Testcase 112:
SELECT count(four) AS cnt_1000 FROM onek;
--Testcase 113:
SELECT count(DISTINCT four) AS cnt_4 FROM onek;

--Testcase 114:
select ten, count(*), sum(four) from onek
group by ten order by ten;

--Testcase 115:
select ten, count(four), sum(DISTINCT four) from onek
group by ten order by ten;

-- user-defined aggregates
--Testcase 116:
CREATE AGGREGATE newavg (
  sfunc = int4_avg_accum, basetype = int4, stype = _int8,
  finalfunc = int8_avg,
  initcond1 = '{0,0}'
);

-- without finalfunc; test obsolete spellings 'sfunc1' etc
--Testcase 117:
CREATE AGGREGATE newsum (
  sfunc1 = int4pl, basetype = int4, stype1 = int4,
  initcond1 = '0'
);

-- zero-argument aggregate
--Testcase 118:
CREATE AGGREGATE newcnt (*) (
  sfunc = int8inc, stype = int8,
  initcond = '0', parallel = safe
);

-- old-style spelling of same (except without parallel-safe; that's too new)
--Testcase 119:
CREATE AGGREGATE oldcnt (
  sfunc = int8inc, basetype = 'ANY', stype = int8,
  initcond = '0'
);

-- aggregate that only cares about null/nonnull input
--Testcase 120:
CREATE AGGREGATE newcnt ("any") (
  sfunc = int8inc_any, stype = int8,
  initcond = '0'
);

-- multi-argument aggregate
--Testcase 121:
create function sum3(int8,int8,int8) returns int8 as
'select $1 + $2 + $3' language sql strict immutable;

--Testcase 122:
create aggregate sum2(int8,int8) (
  sfunc = sum3, stype = int8,
  initcond = '0'
);

--Testcase 123:
SELECT newavg(four) AS avg_1 FROM onek;
--Testcase 124:
SELECT newsum(four) AS sum_1500 FROM onek;
--Testcase 125:
SELECT newcnt(four) AS cnt_1000 FROM onek;
--Testcase 126:
SELECT newcnt(*) AS cnt_1000 FROM onek;
--Testcase 127:
SELECT oldcnt(*) AS cnt_1000 FROM onek;
--Testcase 128:
SELECT sum2(q1,q2) FROM int8_tbl;

-- test for outer-level aggregates

-- this should work
--Testcase 129:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

-- this should fail because subquery has an agg of its own in WHERE
--Testcase 130:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b
               where sum(distinct a.four + b.four) = b.four);

-- Test handling of sublinks within outer-level aggregates.
-- Per bug report from Daniel Grace.
--Testcase 131:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1)))
from tenk1 o;

-- Test handling of Params within aggregate arguments in hashed aggregation.
-- Per bug report from Jeevan Chalke.
--Testcase 132:
explain (verbose, costs off)
select s1.a, ss.a, sm
from generate_series1 s1,
     lateral (select s2.a, sum(s1.a + s2.a) sm
              from generate_series1 s2 group by s2.a) ss
order by 1, 2;
--Testcase 133:
select s1.a as s1, ss.a as s2, sm
from generate_series1 s1,
     lateral (select s2.a, sum(s1.a + s2.a) sm
              from generate_series1 s2 group by s2.a) ss
order by 1, 2;

--Testcase 134:
explain (verbose, costs off)
select array(select sum(x.a+y.a) s
            from generate_series1 y group by y.a order by s)
  from generate_series1 x;
--Testcase 135:
select array(select sum(x.a+y.a) s
            from generate_series1 y group by y.a order by s)
  from generate_series1 x;

--
-- test for bitwise integer aggregates
--
--Testcase 136:
CREATE FOREIGN TABLE bitwise_test_empty (
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2,
  y BIT(4)
) SERVER influxdb_svr;

-- empty case
--Testcase 137:
SELECT
  BIT_AND(i2) AS "?",
  BIT_OR(i4)  AS "?",
  BIT_XOR(i8) AS "?"
FROM bitwise_test_empty;

--Testcase 138:
CREATE FOREIGN TABLE bitwise_test (
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2,
  y BIT(4)
) SERVER influxdb_svr;

--Testcase 139:
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
  BIT_OR(y)   AS "1101",

  BIT_XOR(i2) AS "5",
  BIT_XOR(i4) AS "5",
  BIT_XOR(i8) AS "5",
  BIT_XOR(i)  AS "?",
  BIT_XOR(x)  AS "7",
  BIT_XOR(y)  AS "1101"
FROM bitwise_test;

--
-- test boolean aggregates
--
-- first test all possible transition and final states
--Testcase 140:
CREATE FOREIGN TABLE boolean1 (x1 BOOL, y1 BOOL , x2 BOOL, y2 BOOL,
			x3 BOOL, y3 BOOL, x4 BOOL, y4 BOOL,
			x5 BOOL, y5 BOOL, x6 BOOL, y6 BOOL,
			x7 BOOL, y7 BOOL, x8 BOOL, y8 BOOL,
			x9 BOOL, y9 BOOL) SERVER influxdb_svr;

--Testcase 141:
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

--Testcase 142:
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

--Testcase 143:
CREATE FOREIGN TABLE bool_test_empty (
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL
) SERVER influxdb_svr;

-- empty case
--Testcase 144:
SELECT
  BOOL_AND(b1)   AS "n",
  BOOL_OR(b3)    AS "n"
FROM bool_test_empty;

--Testcase 145:
CREATE FOREIGN TABLE bool_test (
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL
) SERVER influxdb_svr;

--Testcase 146:
SELECT
  BOOL_AND(b1)     AS "f",
  BOOL_AND(b2)     AS "t",
  BOOL_AND(b3)     AS "f",
  BOOL_AND(b4)     AS "n",
  BOOL_AND(NOT b2) AS "f",
  BOOL_AND(NOT b3) AS "t"
FROM bool_test;

--Testcase 147:
SELECT
  EVERY(b1)     AS "f",
  EVERY(b2)     AS "t",
  EVERY(b3)     AS "f",
  EVERY(b4)     AS "n",
  EVERY(NOT b2) AS "f",
  EVERY(NOT b3) AS "t"
FROM bool_test;

--Testcase 148:
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
--Testcase 149:
explain (costs off)
  select min(unique1) from tenk1;
--Testcase 150:
select min(unique1) from tenk1;
--Testcase 151:
explain (costs off)
  select max(unique1) from tenk1;
--Testcase 152:
select max(unique1) from tenk1;
--Testcase 153:
explain (costs off)
  select max(unique1) from tenk1 where unique1 < 42;
--Testcase 154:
select max(unique1) from tenk1 where unique1 < 42;
--Testcase 155:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42;
--Testcase 156:
select max(unique1) from tenk1 where unique1 > 42;

-- the planner may choose a generic aggregate here if parallel query is
-- enabled, since that plan will be parallel safe and the "optimized"
-- plan, which has almost identical cost, will not be.  we want to test
-- the optimized plan, so temporarily disable parallel query.
begin;
--Testcase 157:
set local max_parallel_workers_per_gather = 0;
--Testcase 158:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42000;
--Testcase 159:
select max(unique1) from tenk1 where unique1 > 42000;
rollback;

-- multi-column index (uses tenk1_thous_tenthous)
--Testcase 160:
explain (costs off)
  select max(tenthous) from tenk1 where thousand = 33;
--Testcase 161:
select max(tenthous) from tenk1 where thousand = 33;
--Testcase 162:
explain (costs off)
  select min(tenthous) from tenk1 where thousand = 33;
--Testcase 163:
select min(tenthous) from tenk1 where thousand = 33;

-- check parameter propagation into an indexscan subquery
--Testcase 164:
explain (costs off)
  select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
    from int4_tbl;
--Testcase 165:
select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
  from int4_tbl;

-- check some cases that were handled incorrectly in 8.3.0
--Testcase 166:
explain (costs off)
  select distinct max(unique2) from tenk1;
--Testcase 167:
select distinct max(unique2) from tenk1;
--Testcase 168:
explain (costs off)
  select max(unique2) from tenk1 order by 1;
--Testcase 169:
select max(unique2) from tenk1 order by 1;
--Testcase 170:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2);
--Testcase 171:
select max(unique2) from tenk1 order by max(unique2);
--Testcase 172:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 173:
select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 174:
explain (costs off)
  select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;
--Testcase 175:
select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;

-- interesting corner case: constant gets optimized into a seqscan
--Testcase 176:
explain (costs off)
  select max(100) from tenk1;
--Testcase 177:
select max(100) from tenk1;

-- try it on an inheritance tree
--Testcase 178:
create foreign table minmaxtest(f1 int) server influxdb_svr;;
--Testcase 179:
create table minmaxtest1() inherits (minmaxtest);
--Testcase 180:
create table minmaxtest2() inherits (minmaxtest);
--Testcase 181:
create table minmaxtest3() inherits (minmaxtest);
--create index minmaxtesti on minmaxtest(f1);
--Testcase 182:
create index minmaxtest1i on minmaxtest1(f1);
--Testcase 183:
create index minmaxtest2i on minmaxtest2(f1 desc);
--Testcase 184:
create index minmaxtest3i on minmaxtest3(f1) where f1 is not null;

--Testcase 185:
insert into minmaxtest values(11), (12);
--Testcase 186:
insert into minmaxtest1 values(13), (14);
--Testcase 187:
insert into minmaxtest2 values(15), (16);
--Testcase 188:
insert into minmaxtest3 values(17), (18);

--Testcase 189:
explain (costs off)
  select min(f1), max(f1) from minmaxtest;
--Testcase 190:
select min(f1), max(f1) from minmaxtest;

-- DISTINCT doesn't do anything useful here, but it shouldn't fail
--Testcase 191:
explain (costs off)
  select distinct min(f1), max(f1) from minmaxtest;
--Testcase 192:
select distinct min(f1), max(f1) from minmaxtest;

--Testcase 193:
drop foreign table minmaxtest cascade;

-- check for correct detection of nested-aggregate errors
--Testcase 194:
select max(min(unique1)) from tenk1;
--Testcase 195:
select (select max(min(unique1)) from int8_tbl) from tenk1;

--
-- Test removal of redundant GROUP BY columns
--

--Testcase 196:
create foreign table agg_t1 (a int, b int, c int, d int) server influxdb_svr;
--Testcase 197:
create foreign table agg_t2 (x int, y int, z int) server influxdb_svr;
--Testcase 198:
create foreign table agg_t3 (a int, b int, c int) server influxdb_svr;

-- Non-primary-key columns can be removed from GROUP BY
--Testcase 199:
explain (costs off) select * from agg_t1 group by a,b,c,d;

-- No removal can happen if the complete PK is not present in GROUP BY
--Testcase 200:
explain (costs off) select a,c from agg_t1 group by a,c,d;

-- Test removal across multiple relations
--Testcase 201:
explain (costs off) select *
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.y,agg_t2.z;

-- Test case where agg_t1 can be optimized but not agg_t2
--Testcase 202:
explain (costs off) select agg_t1.*,agg_t2.x,agg_t2.z
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.z;

-- Cannot optimize when PK is deferrable
--Testcase 203:
explain (costs off) select * from agg_t3 group by a,b,c;

--Testcase 204:
create temp table agg_t1c () inherits (agg_t1);

-- Ensure we don't remove any columns when agg_t1 has a child table
--Testcase 205:
explain (costs off) select * from agg_t1 group by a,b,c,d;

-- Okay to remove columns if we're only querying the parent.
--Testcase 206:
explain (costs off) select * from only agg_t1 group by a,b,c,d;

--Testcase 207:
create temp table p_agg_t1 (
  a int,
  b int,
  c int,
  d int,
  primary key(a,b)
) partition by list(a);
--Testcase 208:
create temp table p_agg_t1_1 partition of p_agg_t1 for values in(1);
--Testcase 209:
create temp table p_agg_t1_2 partition of p_agg_t1 for values in(2);

-- Ensure we can remove non-PK columns for partitioned tables.
--Testcase 210:
explain (costs off) select * from p_agg_t1 group by a,b,c,d;

--Testcase 211:
drop foreign table agg_t1 cascade;
--Testcase 212:
drop foreign table agg_t2 cascade;
--Testcase 213:
drop foreign table agg_t3 cascade;
--Testcase 214:
drop table p_agg_t1;

--
-- Test GROUP BY matching of join columns that are type-coerced due to USING
--

--Testcase 215:
create foreign table agg_t1(f1 int, f2 bigint) server influxdb_svr;
--Testcase 216:
create foreign table agg_t2(f1 bigint, f22 bigint) server influxdb_svr;

--Testcase 217:
select f1 from agg_t1 left join agg_t2 using (f1) group by f1;
--Testcase 218:
select f1 from agg_t1 left join agg_t2 using (f1) group by agg_t1.f1;
--Testcase 219:
select agg_t1.f1 from agg_t1 left join agg_t2 using (f1) group by agg_t1.f1;
-- only this one should fail:
--Testcase 220:
select agg_t1.f1 from agg_t1 left join agg_t2 using (f1) group by f1;

--Testcase 221:
drop foreign table agg_t1 cascade;
--Testcase 222:
drop foreign table agg_t2 cascade;
--
-- Test combinations of DISTINCT and/or ORDER BY
--
begin;
--Testcase 223:
select array_agg(q1 order by q2)
  from INT8_TBL2;
--Testcase 224:
select array_agg(q1 order by q1)
  from INT8_TBL2;
--Testcase 225:
select array_agg(q1 order by q1 desc)
  from INT8_TBL2;
--Testcase 226:
select array_agg(q2 order by q1 desc)
  from INT8_TBL2;

--Testcase 227:
select array_agg(distinct f1)
  from INT4_TBL2;
--Testcase 228:
select array_agg(distinct f1 order by f1)
  from INT4_TBL2;
--Testcase 229:
select array_agg(distinct f1 order by f1 desc)
  from INT4_TBL2;
--Testcase 230:
select array_agg(distinct f1 order by f1 desc nulls last)
  from INT4_TBL2;
rollback;

-- multi-arg aggs, strict/nonstrict, distinct/order by
--Testcase 231:
create type aggtype as (a integer, b integer, c text);

--Testcase 232:
create function aggf_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql strict immutable;

--Testcase 233:
create function aggfns_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql immutable;

--Testcase 234:
create aggregate aggfstr(integer,integer,text) (
   sfunc = aggf_trans, stype = aggtype[],
   initcond = '{}'
);

--Testcase 235:
create aggregate aggfns(integer,integer,text) (
   sfunc = aggfns_trans, stype = aggtype[], sspace = 10000,
   initcond = '{}'
);

begin;
--Testcase 236:
select aggfstr(a,b,c)
  from multi_arg_agg;
--Testcase 237:
select aggfns(a,b,c)
  from multi_arg_agg;

--Testcase 238:
select aggfstr(distinct a,b,c)
  from multi_arg_agg,
       generate_series(1,3) i;
--Testcase 239:
select aggfns(distinct a,b,c)
  from multi_arg_agg,
       generate_series(1,3) i;

--Testcase 240:
select aggfstr(distinct a,b,c order by b)
  from multi_arg_agg, 
       generate_series(1,3) i;
--Testcase 241:
select aggfns(distinct a,b,c order by b)
  from multi_arg_agg,
       generate_series(1,3) i;

-- test specific code paths

--Testcase 242:
select aggfns(distinct a,a,c order by c using ~<~,a)
  from multi_arg_agg,
       generate_series(1,2) i;
--Testcase 243:
select aggfns(distinct a,a,c order by c using ~<~)
  from multi_arg_agg,
       generate_series(1,2) i;
--Testcase 244:
select aggfns(distinct a,a,c order by a)
  from multi_arg_agg,
       generate_series(1,2) i;
--Testcase 245:
select aggfns(distinct a,b,c order by a,c using ~<~,b)
  from multi_arg_agg,
       generate_series(1,2) i;

-- check node I/O via view creation and usage, also deparsing logic

--Testcase 246:
create view agg_view1 as
  select aggfns(a,b,c)
    from multi_arg_agg;

--Testcase 247:
select * from agg_view1;
--Testcase 248:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 249:
create or replace view agg_view1 as
  select aggfns(distinct a,b,c)
    from multi_arg_agg,
         generate_series(1,3) i;

--Testcase 250:
select * from agg_view1;
--Testcase 251:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 252:
create or replace view agg_view1 as
  select aggfns(distinct a,b,c order by b)
    from multi_arg_agg,
         generate_series(1,3) i;

--Testcase 253:
select * from agg_view1;
--Testcase 254:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 255:
create or replace view agg_view1 as
  select aggfns(a,b,c order by b+1)
    from multi_arg_agg;

--Testcase 256:
select * from agg_view1;
--Testcase 257:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 258:
create or replace view agg_view1 as
  select aggfns(a,a,c order by b)
    from multi_arg_agg;

--Testcase 259:
select * from agg_view1;
--Testcase 260:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 261:
create or replace view agg_view1 as
  select aggfns(a,b,c order by c using ~<~)
    from multi_arg_agg;

--Testcase 262:
select * from agg_view1;
--Testcase 263:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 264:
create or replace view agg_view1 as
  select aggfns(distinct a,b,c order by a,c using ~<~,b)
    from multi_arg_agg,
         generate_series(1,2) i;

--Testcase 265:
select * from agg_view1;
--Testcase 266:
select pg_get_viewdef('agg_view1'::regclass);

--Testcase 267:
drop view agg_view1;
rollback;

-- incorrect DISTINCT usage errors
--Testcase 268:
select aggfns(distinct a,b,c order by i)
  from multi_arg_agg2, generate_series(1,2) i;
--Testcase 269:
select aggfns(distinct a,b,c order by a,b+1)
  from multi_arg_agg2, generate_series(1,2) i;
--Testcase 270:
select aggfns(distinct a,b,c order by a,b,i,c)
  from multi_arg_agg2, generate_series(1,2) i;
--Testcase 271:
select aggfns(distinct a,a,c order by a,b)
  from multi_arg_agg2, generate_series(1,2) i;

-- string_agg tests
--Testcase 272:
create foreign table string_agg1(a1 text, a2 text) server influxdb_svr;
--Testcase 273:
create foreign table string_agg2(a1 text, a2 text) server influxdb_svr;
--Testcase 274:
create foreign table string_agg3(a1 text, a2 text) server influxdb_svr;
--Testcase 275:
create foreign table string_agg4(a1 text, a2 text) server influxdb_svr;

--Testcase 276:
select string_agg(a1,',') from string_agg1;
--Testcase 277:
select string_agg(a1,',') from string_agg2;
--Testcase 278:
select string_agg(a1,'AB') from string_agg3;
--Testcase 279:
select string_agg(a1,',') from string_agg4;

-- check some implicit casting cases, as per bug #5564
--Testcase 280:
select string_agg(distinct f1, ',' order by f1) from varchar_tbl;  -- ok
--Testcase 281:
select string_agg(distinct f1::text, ',' order by f1) from varchar_tbl;  -- not ok
--Testcase 282:
select string_agg(distinct f1, ',' order by f1::text) from varchar_tbl;  -- not ok
--Testcase 283:
select string_agg(distinct f1::text, ',' order by f1::text) from varchar_tbl;  -- ok

-- InfluxDB does not support binary data
-- string_agg bytea tests
/*
create table bytea_test_table(v bytea);

select string_agg(v, '') from bytea_test_table;

insert into bytea_test_table values(decode('ff','hex'));

select string_agg(v, '') from bytea_test_table;

insert into bytea_test_table values(decode('aa','hex'));

select string_agg(v, '') from bytea_test_table;
select string_agg(v, NULL) from bytea_test_table;
select string_agg(v, decode('ee', 'hex')) from bytea_test_table;

drop table bytea_test_table;
*/
-- FILTER tests

--Testcase 284:
select min(unique1) filter (where unique1 > 100) from tenk1;

--Testcase 285:
select sum(1/ten) filter (where ten > 0) from tenk1;

--Testcase 286:
select ten, sum(distinct four) filter (where four::text ~ '123') from onek a
group by ten;

--Testcase 287:
select ten, sum(distinct four) filter (where four > 10) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

--Testcase 288:
select max(foo COLLATE "C") filter (where (bar collate "POSIX") > '0')
from (values ('a', 'b')) AS v(foo,bar);

-- outer reference in FILTER (PostgreSQL extension)
--Testcase 289:
select (select count(*)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- inner query is aggregation query
--Testcase 290:
select (select count(*) filter (where outer_c <> 0)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- outer query is aggregation query
--Testcase 291:
select (select count(inner_c) filter (where outer_c <> 0)
        from (values (1)) t0(inner_c))
from (values (2),(3)) t1(outer_c); -- inner query is aggregation query
--Testcase 292:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1))
     filter (where o.unique1 < 10))
from tenk1 o;					-- outer query is aggregation query

-- subquery in FILTER clause (PostgreSQL extension)
--Testcase 293:
select sum(unique1) FILTER (WHERE
  unique1 IN (SELECT unique1 FROM onek where unique1 < 100)) FROM tenk1;

-- exercise lots of aggregate parts with FILTER
begin;
--Testcase 294:
select aggfns(distinct a,b,c order by a,c using ~<~,b) filter (where a > 1)
    from multi_arg_agg3,
    generate_series(1,2) i;
rollback;

-- check handling of bare boolean Var in FILTER
--Testcase 454:
select max(0) filter (where b1) from bool_test;
--Testcase 455:
select (select max(0) filter (where b1)) from bool_test;

-- check for correct detection of nested-aggregate errors in FILTER
--Testcase 456:
select max(unique1) filter (where sum(ten) > 0) from tenk1;
--Testcase 457:
select (select max(unique1) filter (where sum(ten) > 0) from int8_tbl) from tenk1;
--Testcase 458:
select max(unique1) filter (where bool_or(ten > 0)) from tenk1;
--Testcase 459:
select (select max(unique1) filter (where bool_or(ten > 0)) from int8_tbl) from tenk1;

-- ordered-set aggregates

begin;
--Testcase 295:
select f1, percentile_cont(f1) within group (order by x::float8)
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 296:
select f1, percentile_cont(f1 order by f1) within group (order by x)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 297:
select f1, sum() within group (order by x::float8)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

begin;
--Testcase 298:
select f1, percentile_cont(f1,f1)  -- error
from generate_series(1,5) x,
     FLOAT8_TBL
group by f1 order by f1;
rollback;

--Testcase 299:
select percentile_cont(0.5) within group (order by b) from aggtest;
--Testcase 300:
select percentile_cont(0.5) within group (order by b), sum(b) from aggtest;
--Testcase 301:
select percentile_cont(0.5) within group (order by thousand) from tenk1;
--Testcase 302:
select percentile_disc(0.5) within group (order by thousand) from tenk1;

begin;
--Testcase 303:
select rank(3) within group (order by f1) from INT4_TBL3;
--Testcase 304:
select cume_dist(3) within group (order by f1) from INT4_TBL3;
--Testcase 305:
select percent_rank(3) within group (order by f1) from INT4_TBL4;
--Testcase 306:
select dense_rank(3) within group (order by f1) from INT4_TBL3;
rollback;

--Testcase 307:
select percentile_disc(array[0,0.1,0.25,0.5,0.75,0.9,1]) within group (order by thousand)
from tenk1;
--Testcase 308:
select percentile_cont(array[0,0.25,0.5,0.75,1]) within group (order by thousand)
from tenk1;
--Testcase 309:
select percentile_disc(array[[null,1,0.5],[0.75,0.25,null]]) within group (order by thousand)
from tenk1;
--Testcase 310:
create foreign table generate_series2 (a int) server influxdb_svr;
--Testcase 311:
select percentile_cont(array[0,1,0.25,0.75,0.5,1,0.3,0.32,0.35,0.38,0.4]) within group (order by a)
from generate_series2;

--Testcase 312:
select ten, mode() within group (order by string4) from tenk1 group by ten;

--Testcase 313:
create foreign table percentile_disc1(x text) server influxdb_svr;
--Testcase 314:
select percentile_disc(array[0.25,0.5,0.75]) within group (order by unnest)
from (select unnest(x::text[]) from percentile_disc1) y;

-- check collation propagates up in suitable cases:
--Testcase 315:
create foreign table pg_collation1 (x text) server influxdb_svr;
--Testcase 316:
select pg_collation_for(percentile_disc(1) within group (order by x collate "POSIX"))
  from pg_collation1;

-- test ordered-set aggs using built-in support functions
--Testcase 317:
create aggregate test_percentile_disc(float8 ORDER BY anyelement) (
  stype = internal,
  sfunc = ordered_set_transition,
  finalfunc = percentile_disc_final,
  finalfunc_extra = true,
  finalfunc_modify = read_write
);

--Testcase 318:
create aggregate test_rank(VARIADIC "any" ORDER BY VARIADIC "any") (
  stype = internal,
  sfunc = ordered_set_transition_multi,
  finalfunc = rank_final,
  finalfunc_extra = true,
  hypothetical
);

-- ordered-set aggs created with CREATE AGGREGATE
--Testcase 319:
create foreign table test_rank1 (x int) server influxdb_svr;
--Testcase 320:
select test_rank(3) within group (order by x) from test_rank1;
--Testcase 321:
select test_percentile_disc(0.5) within group (order by thousand) from tenk1;

-- ordered-set aggs can't use ungrouped vars in direct args:
--Testcase 322:
create foreign table generate_series3 (x int) server influxdb_svr;
--Testcase 323:
select rank(x) within group (order by x) from generate_series3 x;

-- outer-level agg can't use a grouped arg of a lower level, either:
--Testcase 324:
select array(select percentile_disc(a) within group (order by x)
               from (values (0.3),(0.7)) v(a) group by a)
  from generate_series3;

-- agg in the direct args is a grouping violation, too:
--Testcase 325:
select rank(sum(x)) within group (order by x) from generate_series3 x;

-- hypothetical-set type unification and argument-count failures:
--Testcase 326:
select rank(3) within group (order by x) from pg_collation1;
--Testcase 327:
select rank(3) within group (order by stringu1,stringu2) from tenk1;
--Testcase 328:
select rank('fred') within group (order by x) from generate_series3 x;
--Testcase 329:
select rank('adam'::text collate "C") within group (order by x collate "POSIX")
  from pg_collation1;
-- hypothetical-set type unification successes:
--Testcase 330:
select rank('adam'::varchar) within group (order by x) from pg_collation1;
--Testcase 331:
select rank('3') within group (order by x) from generate_series3 x;

-- divide by zero check
--Testcase 332:
select percent_rank(0) within group (order by x) from generate_series(1,0) x;

-- deparse and multiple features:
--Testcase 333:
create view aggordview1 as
select ten,
       percentile_disc(0.5) within group (order by thousand) as p50,
       percentile_disc(0.5) within group (order by thousand) filter (where hundred=1) as px,
       rank(5,'AZZZZ',50) within group (order by hundred, string4 desc, hundred)
  from tenk1
 group by ten order by ten;

--Testcase 334:
select pg_get_viewdef('aggordview1');
--Testcase 335:
select * from aggordview1 order by ten;
--Testcase 336:
drop view aggordview1;

-- User defined function for user defined aggregate, VARIADIC
--Testcase 337:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';
--Testcase 338:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

--Testcase 339:
create function cleast_accum(anycompatible, variadic anycompatiblearray)
returns anycompatible language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';

--Testcase 340:
create aggregate cleast_agg(variadic items anycompatiblearray) (
  stype = anycompatible, sfunc = cleast_accum
);

-- variadic aggregates
--Testcase 341:
select least_agg(q1,q2) from int8_tbl;
--Testcase 342:
select least_agg(variadic array[q1,q2]) from int8_tbl;

--Testcase 343:
select cleast_agg(q1,q2) from int8_tbl;
--Testcase 344:
select cleast_agg(4.5,f1) from int4_tbl;
--Testcase 345:
select cleast_agg(variadic array[4.5,f1]) from int4_tbl;
--Testcase 346:
select pg_typeof(cleast_agg(variadic array[4.5,f1])) from int4_tbl;

--Testcase 347:
drop aggregate least_agg(variadic items anyarray);
--Testcase 348:
drop function least_accum(anyelement, variadic anyarray);
-- test aggregates with common transition functions share the same states
begin work;

--Testcase 349:
create type avg_state as (total bigint, count bigint);

--Testcase 350:
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

--Testcase 351:
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

--Testcase 352:
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

--Testcase 353:
create aggregate my_avg(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn
);

--Testcase 354:
create aggregate my_sum(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = sum_finalfn
);

-- aggregate state should be shared as aggs are the same.
--Testcase 355:
create foreign table my_avg1 (one int) server influxdb_svr;
--Testcase 356:
select my_avg(one),my_avg(one) from my_avg1;

-- aggregate state should be shared as transfn is the same for both aggs.
--Testcase 357:
select my_avg(one),my_sum(one) from my_avg1;

-- same as previous one, but with DISTINCT, which requires sorting the input.
--Testcase 358:
select my_avg(distinct one),my_sum(distinct one) from my_avg1;

-- shouldn't share states due to the distinctness not matching.
--Testcase 359:
select my_avg(distinct one),my_sum(one) from my_avg1;

-- shouldn't share states due to the filter clause not matching.
--Testcase 360:
select my_avg(one) filter (where one > 1),my_sum(one) from my_avg1;

-- this should not share the state due to different input columns.
--Testcase 361:
create foreign table my_avg2(one int, two int) server influxdb_svr;
--Testcase 362:
select my_avg(one),my_sum(two) from my_avg2;

-- exercise cases where OSAs share state
--Testcase 363:
create foreign table percentile_cont1( a int) server influxdb_svr;
--Testcase 364:
select
  percentile_cont(0.5) within group (order by a),
  percentile_disc(0.5) within group (order by a)
from percentile_cont1;

--Testcase 365:
select
  percentile_cont(0.25) within group (order by a),
  percentile_disc(0.5) within group (order by a)
from percentile_cont1;

-- these can't share state currently
--Testcase 366:
select
  rank(4) within group (order by a),
  dense_rank(4) within group (order by a)
from percentile_cont1;

-- test that aggs with the same sfunc and initcond share the same agg state
--Testcase 367:
create aggregate my_sum_init(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = sum_finalfn,
   initcond = '(10,0)'
);

--Testcase 368:
create aggregate my_avg_init(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn,
   initcond = '(10,0)'
);

--Testcase 369:
create aggregate my_avg_init2(int4)
(
   stype = avg_state,
   sfunc = avg_transfn,
   finalfunc = avg_finalfn,
   initcond = '(4,0)'
);

-- state should be shared if INITCONDs are matching
--Testcase 370:
select my_sum_init(one),my_avg_init(one) from my_avg1;

-- Varying INITCONDs should cause the states not to be shared.
--Testcase 371:
select my_sum_init(one),my_avg_init2(one) from my_avg1;

rollback;

-- test aggregate state sharing to ensure it works if one aggregate has a
-- finalfn and the other one has none.
begin work;

--Testcase 372:
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

--Testcase 373:
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

--Testcase 374:
create aggregate my_sum(int4)
(
   stype = int4,
   sfunc = sum_transfn
);

--Testcase 375:
create aggregate my_half_sum(int4)
(
   stype = int4,
   sfunc = sum_transfn,
   finalfunc = halfsum_finalfn
);

-- Agg state should be shared even though my_sum has no finalfn
--Testcase 376:
create foreign table my_sum1(one int) server influxdb_svr;
--Testcase 377:
select my_sum(one),my_half_sum(one) from my_sum1;

rollback;


-- test that the aggregate transition logic correctly handles
-- transition / combine functions returning NULL

-- First test the case of a normal transition function returning NULL
BEGIN;
--Testcase 378:
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

--Testcase 379:
CREATE AGGREGATE balk(int4)
(
    SFUNC = balkifnull(int8, int4),
    STYPE = int8,
    PARALLEL = SAFE,
    INITCOND = '0'
);

--Testcase 380:
SELECT balk(hundred) FROM tenk1;

ROLLBACK;

-- Secondly test the case of a parallel aggregate combiner function
-- returning NULL. For that use normal transition function, but a
-- combiner function returning NULL.
BEGIN;
--Testcase 381:
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

--Testcase 382:
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
BEGIN;

--Testcase 383:
SET parallel_setup_cost = 0;
--Testcase 384:
SET parallel_tuple_cost = 0;
--Testcase 385:
SET min_parallel_table_scan_size = 0;
--Testcase 386:
SET max_parallel_workers_per_gather = 4;
--Testcase 387:
SET parallel_leader_participation = off;
--Testcase 388:
SET enable_indexonlyscan = off;

-- variance(int4) covers numeric_poly_combine
-- sum(int8) covers int8_avg_combine
-- regr_count(float8, float8) covers int8inc_float8_float8 and aggregates with > 1 arg
--Testcase 389:
EXPLAIN (COSTS OFF, VERBOSE)
SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8)
FROM (SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1) u;

--Testcase 390:
SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8)
FROM (SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1) u;

-- variance(int8) covers numeric_combine
-- avg(numeric) covers numeric_avg_combine
--Testcase 391:
EXPLAIN (COSTS OFF, VERBOSE)
SELECT variance(unique1::int8), avg(unique1::numeric)
FROM (SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1) u;

--Testcase 392:
SELECT variance(unique1::int8), avg(unique1::numeric)
FROM (SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1
      UNION ALL SELECT * FROM tenk1) u;

ROLLBACK;

-- test coverage for dense_rank
--Testcase 393:
create foreign table dense_rank1 (x int) server influxdb_svr;
--Testcase 394:
SELECT dense_rank(x) WITHIN GROUP (ORDER BY x) FROM dense_rank1 GROUP BY (x) ORDER BY 1;


-- Ensure that the STRICT checks for aggregates does not take NULLness
-- of ORDER BY columns into account. See bug report around
-- 2a505161-2727-2473-7c46-591ed108ac52@email.cz
--Testcase 395:
SELECT min(x ORDER BY y) FROM (VALUES(1, NULL)) AS d(x,y);
--Testcase 396:
SELECT min(x ORDER BY y) FROM (VALUES(1, 2)) AS d(x,y);

-- check collation-sensitive matching between grouping expressions
--Testcase 397:
select v||'a', case v||'a' when 'aa' then 1 else 0 end, count(*)
  from unnest(array['a','b']) u(v)
 group by v||'a' order by 1;
--Testcase 398:
select v||'a', case when v||'a' = 'aa' then 1 else 0 end, count(*)
  from unnest(array['a','b']) u(v)
 group by v||'a' order by 1;

-- Make sure that generation of HashAggregate for uniqification purposes
-- does not lead to array overflow due to unexpected duplicate hash keys
-- see CAFeeJoKKu0u+A_A9R9316djW-YW3-+Gtgvy3ju655qRHR3jtdA@mail.gmail.com
--Testcase 399:
set enable_memoize to off;
--Testcase 400:
explain (costs off)
  select 1 from tenk1
   where (hundred, thousand) in (select twothousand, twothousand from onek);
--Testcase 401:
reset enable_memoize;

--
-- Hash Aggregation Spill tests
--

--Testcase 402:
set enable_sort=false;
--Testcase 403:
set work_mem='64kB';

--Testcase 404:
select unique1, count(*), sum(twothousand) from tenk1
group by unique1
having sum(fivethous) > 4975
order by sum(twothousand);

--Testcase 405:
set work_mem to default;
--Testcase 406:
set enable_sort to default;

--
-- Compare results between plans using sorting and plans using hash
-- aggregation. Force spilling in both cases by setting work_mem low.
--

--Testcase 407:
set work_mem='64kB';

--Testcase 408:
create foreign table agg_data_2k(g int) server influxdb_svr;
--Testcase 409:
create foreign table agg_data_20k(g int) server influxdb_svr;

--Testcase 410:
create foreign table agg_group_1(c1 int, c2 numeric, c3 int) server influxdb_svr;
--Testcase 411:
create foreign table agg_group_2(a int, c1 numeric, c2 text, c3 int) server influxdb_svr;
--Testcase 412:
create foreign table agg_group_3(c1 numeric, c2 int4, c3 int) server influxdb_svr;
--Testcase 413:
create foreign table agg_group_4(c1 numeric, c2 text, c3 int) server influxdb_svr;

--Testcase 414:
create foreign table agg_hash_1(c1 int, c2 numeric, c3 int) server influxdb_svr;
--Testcase 415:
create foreign table agg_hash_2(a int, c1 numeric, c2 text, c3 int) server influxdb_svr;
--Testcase 416:
create foreign table agg_hash_3(c1 numeric, c2 int4, c3 int) server influxdb_svr;
--Testcase 417:
create foreign table agg_hash_4(c1 numeric, c2 text, c3 int) server influxdb_svr;

--Testcase 418:
insert into agg_data_2k select g from generate_series(0, 1999) g;
--analyze agg_data_2k;

--Testcase 419:
insert into agg_data_20k select g from generate_series(0, 19999) g;
--analyze agg_data_20k;

-- Produce results with sorting.

--Testcase 420:
set enable_hashagg = false;

--Testcase 421:
set jit_above_cost = 0;

--Testcase 422:
explain (costs off)
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 423:
insert into agg_group_1
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 424:
insert into agg_group_2
select * from
  (values (100), (300), (500)) as r(a),
  lateral (
    select (g/2)::numeric as c1,
           array_agg(g::numeric) as c2,
	   count(*) as c3
    from agg_data_2k
    where g < r.a
    group by g/2) as s;

--Testcase 425:
set jit_above_cost to default;

--Testcase 426:
insert into agg_group_3
select (g/2)::numeric as c1, sum(7::int4) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 427:
insert into agg_group_4
select (g/2)::numeric as c1, array_agg(g::numeric) as c2, count(*) as c3
  from agg_data_2k group by g/2;

-- Produce results with hash aggregation

--Testcase 428:
set enable_hashagg = true;
--Testcase 429:
set enable_sort = false;

--Testcase 430:
set jit_above_cost = 0;

--Testcase 431:
explain (costs off)
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 432:
insert into agg_hash_1
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 433:
insert into agg_hash_2
select * from
  (values (100), (300), (500)) as r(a),
  lateral (
    select (g/2)::numeric as c1,
           array_agg(g::numeric) as c2,
	   count(*) as c3
    from agg_data_2k
    where g < r.a
    group by g/2) as s;

--Testcase 434:
set jit_above_cost to default;

--Testcase 435:
insert into agg_hash_3
select (g/2)::numeric as c1, sum(7::int4) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 436:
insert into agg_hash_4
select (g/2)::numeric as c1, array_agg(g::numeric) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 437:
set enable_sort = true;
--Testcase 438:
set work_mem to default;

-- Compare group aggregation results to hash aggregation results

--Testcase 439:
(select * from agg_hash_1 except select * from agg_group_1)
  union all
(select * from agg_group_1 except select * from agg_hash_1);

--Testcase 440:
(select * from agg_hash_2 except select * from agg_group_2)
  union all
(select * from agg_group_2 except select * from agg_hash_2);

--Testcase 441:
(select * from agg_hash_3 except select * from agg_group_3)
  union all
(select * from agg_group_3 except select * from agg_hash_3);

--Testcase 442:
(select * from agg_hash_4 except select * from agg_group_4)
  union all
(select * from agg_group_4 except select * from agg_hash_4);

--Testcase 443:
-- Clean up:
delete from agg_data_2k;
delete from agg_data_20k;
delete from agg_group_1;
delete from agg_group_2;
delete from agg_group_3;
delete from agg_group_4;
delete from agg_hash_1;
delete from agg_hash_2;
delete from agg_hash_3;
delete from agg_hash_4;
drop foreign table agg_data_2k;
drop foreign table agg_data_20k;
drop foreign table agg_group_1;
--Testcase 444:
drop foreign table agg_group_2;
--Testcase 445:
drop foreign table agg_group_3;
--Testcase 446:
drop foreign table agg_group_4;
--Testcase 447:
drop foreign table agg_hash_1;
--Testcase 448:
drop foreign table agg_hash_2;
--Testcase 449:
drop foreign table agg_hash_3;
--Testcase 450:
drop foreign table agg_hash_4;

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

-- Clean up:
DROP AGGREGATE IF EXISTS newavg (int4);
DROP AGGREGATE IF EXISTS newsum (int4);
DROP AGGREGATE IF EXISTS newcnt (*);
DROP AGGREGATE IF EXISTS oldcnt (*);
DROP AGGREGATE IF EXISTS newcnt ("any");
DROP AGGREGATE IF EXISTS sum2(int8,int8);
DROP FUNCTION IF EXISTS sum3(int8,int8,int8);

DROP AGGREGATE IF EXISTS aggfns(integer,integer,text);
DROP AGGREGATE IF EXISTS aggfstr(integer,integer,text);
DROP FUNCTION IF EXISTS aggfns_trans(aggtype[],integer,integer,text);
DROP FUNCTION IF EXISTS aggf_trans(aggtype[],integer,integer,text);
DROP TYPE IF EXISTS aggtype;

DROP AGGREGATE IF EXISTS test_percentile_disc(float8 ORDER BY anyelement);
DROP AGGREGATE IF EXISTS test_rank(VARIADIC "any" ORDER BY VARIADIC "any");

DROP AGGREGATE IF EXISTS cleast_agg(variadic items anycompatiblearray);
DROP FUNCTION IF EXISTS cleast_accum(anycompatible, variadic anycompatiblearray);

--Testcase 451:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 452:
DROP SERVER influxdb_svr CASCADE;
--Testcase 453:
DROP EXTENSION influxdb_fdw CASCADE;
