--Testcase 1:
SET datestyle=ISO;
--Testcase 2:
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 3:
CREATE EXTENSION influxdb_fdw;
--Testcase 4:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb2', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');
--Testcase 6:
CREATE FOREIGN TABLE s3(time timestamp with time zone, tags jsonb OPTIONS (tags 'true'), fields jsonb OPTIONS (fields 'true')) SERVER server1 OPTIONS(table 's3', tags 'tag1', schemaless 'true');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 7:
\d s3;
--Testcase 8:
SELECT * FROM s3;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 9:
EXPLAIN VERBOSE
SELECT float8(fields->>'value1'), float8(fields->>'value2'), float8(fields->>'value3'), float8(fields->>'value4') FROM s3;

-- select float8() (not pushdown, remove float8, result)
--Testcase 10:
SELECT float8(fields->>'value1'), float8(fields->>'value2'), float8(fields->>'value3'), float8(fields->>'value4') FROM s3;

-- select sqrt (builtin function, explain)
--Testcase 11:
EXPLAIN VERBOSE
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3;

-- select sqrt (builtin function, result)
--Testcase 12:
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3;

-- select sqrt (builtin function, not pushdown constraints, explain)
--Testcase 13:
EXPLAIN VERBOSE
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 14:
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 15:
EXPLAIN VERBOSE
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 16:
SELECT sqrt((fields->>'value1')::float), sqrt((fields->>'value2')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select sqrt(*) (stub agg function, explain)
--Testcase 17:
EXPLAIN VERBOSE
SELECT sqrt_all() from s3;

-- select sqrt(*) (stub agg function, result)
--Testcase 18:
SELECT sqrt_all() from s3;

-- select sqrt(*) (stub agg function and group by tag only) (explain)
--Testcase 19:
EXPLAIN VERBOSE
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sqrt(*) (stub agg function and group by tag only) (result)
--Testcase 20:
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select abs (builtin function, explain)
--Testcase 21:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3;

-- ABS() returns negative values if integer (https://github.com/influxdata/influxdb/issues/10261)
-- select abs (builtin function, result)
--Testcase 22:
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 23:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 24:
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 25:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 26:
SELECT abs((fields->>'value1')::float), abs((fields->>'value2')::bigint), abs((fields->>'value3')::float), abs((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select log (builtin function, need to swap arguments, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), influxdb (v, base)
--Testcase 27:
EXPLAIN VERBOSE
SELECT log((fields->>'value1')::numeric, (fields->>'value2')::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, numeric cast, result)
--Testcase 28:
SELECT log((fields->>'value1')::numeric, (fields->>'value2')::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, float8, explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT log((fields->>'value1')::numeric, 0.1) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, float8, result)
--Testcase 30:
SELECT log((fields->>'value1')::numeric, 0.1) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, bigint, explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT log((fields->>'value2')::numeric, 3::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, bigint, result)
--Testcase 32:
SELECT log((fields->>'value2')::numeric, 3::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, mix type, explain)
--Testcase 33:
EXPLAIN VERBOSE
SELECT log((fields->>'value1')::numeric, (fields->>'value2')::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log (builtin function, need to swap arguments, mix type, result)
--Testcase 34:
SELECT log((fields->>'value1')::numeric, (fields->>'value2')::numeric) FROM s3 WHERE (fields->>'value1')::float != 1;

-- select log(*) (stub agg function, explain)
--Testcase 35:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3;

-- select log(*) (stub agg function, result)
--Testcase 36:
SELECT log_all(50) FROM s3;

-- select log(*) (stub agg function, explain)
--Testcase 37:
EXPLAIN VERBOSE
SELECT log_all(70.5) FROM s3;

-- select log(*) (stub agg function, result)
--Testcase 38:
SELECT log_all(70.5) FROM s3;

-- select log(*) (stub agg function and group by tag only) (explain)
--Testcase 39:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select log(*) (stub agg function and group by tag only) (result)
--Testcase 40:
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 41:
SELECT ln_all(),log10_all(),log_all(50) FROM s3;

-- select log2 (stub function, explain)
--Testcase 42:
EXPLAIN VERBOSE
SELECT log2((fields->>'value1')::float),log2((fields->>'value2')::bigint) FROM s3;

-- select log2 (stub function, result)
--Testcase 43:
SELECT log2((fields->>'value1')::float),log2((fields->>'value2')::bigint) FROM s3;

-- select log2(*) (stub agg function, explain)
--Testcase 44:
EXPLAIN VERBOSE
SELECT log2_all() from s3;

-- select log2(*) (stub agg function, result)
--Testcase 45:
SELECT log2_all() from s3;

-- select log2(*) (stub agg function and group by tag only) (explain)
--Testcase 46:
EXPLAIN VERBOSE
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select log2(*) (stub agg function and group by tag only) (result)
--Testcase 47:
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select log10 (stub function, explain)
--Testcase 48:
EXPLAIN VERBOSE
SELECT log10((fields->>'value1')::float),log10((fields->>'value2')::bigint) FROM s3;

-- select log10 (stub function, result)
--Testcase 49:
SELECT log10((fields->>'value1')::float),log10((fields->>'value2')::bigint) FROM s3;

-- select log10(*) (stub agg function, explain)
--Testcase 50:
EXPLAIN VERBOSE
SELECT log10_all() from s3;

-- select log10(*) (stub agg function, result)
--Testcase 51:
SELECT log10_all() from s3;

-- select log10(*) (stub agg function and group by tag only) (explain)
--Testcase 52:
EXPLAIN VERBOSE
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select log10(*) (stub agg function and group by tag only) (result)
--Testcase 53:
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 54:
SELECT log2_all(), log10_all() FROM s3;

-- select spread (stub agg function, explain)
--Testcase 55:
EXPLAIN VERBOSE
SELECT spread((fields->>'value1')::float),spread((fields->>'value2')::bigint),spread((fields->>'value3')::float),spread((fields->>'value4')::bigint) FROM s3;

-- select spread (stub agg function, result)
--Testcase 56:
SELECT spread((fields->>'value1')::float),spread((fields->>'value2')::bigint),spread((fields->>'value3')::float),spread((fields->>'value4')::bigint) FROM s3;

-- select spread (stub agg function, raise exception if not expected type)
--Testcase 57:
SELECT spread((fields->>'value1')::numeric),spread((fields->>'value2')::numeric),spread((fields->>'value3')::numeric),spread((fields->>'value4')::numeric) FROM s3;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 58:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),abs(sum((fields->>'value3')::float)) FROM s3;

-- select abs as nest function with agg (pushdown, result)
--Testcase 59:
SELECT sum((fields->>'value3')::float),abs(sum((fields->>'value3')::float)) FROM s3;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 60:
EXPLAIN VERBOSE
SELECT abs(log2((fields->>'value1')::float)),abs(log2(1/(fields->>'value1')::float)) FROM s3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 61:
SELECT abs(log2((fields->>'value1')::float)),abs(log2(1/(fields->>'value1')::float)) FROM s3;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 62:
EXPLAIN VERBOSE
SELECT abs((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 63:
SELECT abs((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 64:
EXPLAIN VERBOSE
SELECT sqrt(count((fields->>'value1')::float)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 65:
SELECT sqrt(count((fields->>'value1')::float)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 66:
EXPLAIN VERBOSE
SELECT sqrt(count((fields->>'value1')::float)), pi(), 4.1, tags->>'tag1' tag1 FROM s3;

-- select spread (stub agg function and group by influx_time() and tag) (explain)
--Testcase 67:
EXPLAIN VERBOSE
SELECT spread((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread (stub agg function and group by influx_time() and tag) (result)
--Testcase 68:
SELECT spread((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread (stub agg function and group by tag only) (result)
--Testcase 69:
SELECT tags->>'tag1' tag1,spread((fields->>'value1')::float) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select spread (stub agg function and other aggs) (result)
--Testcase 70:
SELECT sum((fields->>'value1')::float),spread((fields->>'value1')::float),count((fields->>'value1')::float) FROM s3;

-- select abs with order by (explain)
--Testcase 71:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, abs(1-(fields->>'value1')::float) FROM s3 order by abs(1-(fields->>'value1')::float);

-- select abs with order by (result)
--Testcase 72:
SELECT (fields->>'value1')::float value1, abs(1-(fields->>'value1')::float) FROM s3 order by abs(1-(fields->>'value1')::float);

-- select abs with order by index (result)
--Testcase 73:
SELECT (fields->>'value1')::float value1, abs(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select abs with order by index (result)
--Testcase 74:
SELECT (fields->>'value1')::float value1, abs(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select abs and as
--Testcase 75:
SELECT abs((fields->>'value3')::float) as abs1 FROM s3;

-- select abs(*) (stub agg function, explain)
--Testcase 76:
EXPLAIN VERBOSE
SELECT abs_all() from s3;

-- select abs(*) (stub agg function, result)
--Testcase 77:
SELECT abs_all() from s3;

-- select abs(*) (stub agg function and group by tag only) (explain)
--Testcase 78:
EXPLAIN VERBOSE
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select abs(*) (stub agg function and group by tag only) (result)
--Testcase 79:
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select abs(*) (stub agg function, expose data, explain)
--Testcase 80:
EXPLAIN VERBOSE
SELECT (abs_all()::s3).* from s3;

-- select abs(*) (stub agg function, expose data, result)
--Testcase 81:
SELECT (abs_all()::s3).* from s3;

-- select spread over join query (explain)
--Testcase 82:
EXPLAIN VERBOSE
SELECT spread((t1.fields->>'value1')::float), spread((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select spread over join query (result, stub call error)
--Testcase 83:
SELECT spread((t1.fields->>'value1')::float), spread((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select spread with having (explain)
--Testcase 84:
EXPLAIN VERBOSE
SELECT spread((fields->>'value1')::float) FROM s3 HAVING spread((fields->>'value1')::float) > 100;

-- select spread with having (result, not pushdown, stub call error)
--Testcase 85:
SELECT spread((fields->>'value1')::float) FROM s3 HAVING spread((fields->>'value1')::float) > 100;

-- select spread(*) (stub agg function, explain)
--Testcase 86:
EXPLAIN VERBOSE
SELECT spread_all(*) from s3;

-- select spread(*) (stub agg function, result)
--Testcase 87:
SELECT spread_all(*) from s3;

-- select spread(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 88:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 89:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread(*) (stub agg function and group by tag only) (explain)
--Testcase 90:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select spread(*) (stub agg function and group by tag only) (result)
--Testcase 91:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select spread(*) (stub agg function, expose data, explain)
--Testcase 92:
EXPLAIN VERBOSE
SELECT (spread_all(*)::s3).* from s3;

-- select spread(*) (stub agg function, expose data, result)
--Testcase 93:
SELECT (spread_all(*)::s3).* from s3;

-- select spread(regex) (stub agg function, explain)
--Testcase 94:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') from s3;

-- select spread(regex) (stub agg function, result)
--Testcase 95:
SELECT spread('/value[1,4]/') from s3;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 96:
EXPLAIN VERBOSE
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 97:
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select spread(regex) (stub agg function and group by tag only) (explain)
--Testcase 98:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select spread(regex) (stub agg function and group by tag only) (result)
--Testcase 99:
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select spread(regex) (stub agg function, expose data, explain)
--Testcase 100:
EXPLAIN VERBOSE
SELECT (spread('/value[1,4]/')::s3).* from s3;

-- select spread(regex) (stub agg function, expose data, result)
--Testcase 101:
SELECT (spread('/value[1,4]/')::s3).* from s3;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 102:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float) + 1, (fields->>'value2')::bigint value2, tags->>'tag1' tag1, sqrt((fields->>'value2')::bigint) FROM s3;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 103:
SELECT abs((fields->>'value1')::float) + 1, (fields->>'value2')::bigint value2, tags->>'tag1' tag1, sqrt((fields->>'value2')::bigint) FROM s3;

-- select with order by limit (explain)
--Testcase 104:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float), abs((fields->>'value3')::float), sqrt((fields->>'value2')::bigint) FROM s3 ORDER BY abs((fields->>'value3')::float) LIMIT 1;

-- select with order by limit (result)
--Testcase 105:
SELECT abs((fields->>'value1')::float), abs((fields->>'value3')::float), sqrt((fields->>'value2')::bigint) FROM s3 ORDER BY abs((fields->>'value3')::float) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 106:
EXPLAIN VERBOSE
SELECT abs((fields->>'value1')::float), sqrt((fields->>'value2')::bigint), upper(tags->>'tag1') FROM s3;

-- select mixing with non pushdown func (result)
--Testcase 107:
SELECT abs((fields->>'value1')::float), sqrt((fields->>'value2')::bigint), upper(tags->>'tag1') FROM s3;

-- nested function in where clause (explain)
--Testcase 108:
EXPLAIN VERBOSE
SELECT sqrt(abs((fields->>'value3')::float)),min((fields->>'value1')::float) FROM s3 GROUP BY fields->>'value3' HAVING sqrt(abs((fields->>'value3')::float)) > 0 ORDER BY 1,2;

-- nested function in where clause (result)
--Testcase 109:
SELECT sqrt(abs((fields->>'value3')::float)),min((fields->>'value1')::float) FROM s3 GROUP BY fields->>'value3' HAVING sqrt(abs((fields->>'value3')::float)) > 0 ORDER BY 1,2;

--Testcase 110:
EXPLAIN VERBOSE
SELECT first(time, (fields->>'value1')::float), first(time, (fields->>'value2')::bigint), first(time, (fields->>'value3')::float), first(time, (fields->>'value4')::bigint) FROM s3;

--Testcase 111:
SELECT first(time, (fields->>'value1')::float), first(time, (fields->>'value2')::bigint), first(time, (fields->>'value3')::float), first(time, (fields->>'value4')::bigint) FROM s3;

-- select first(*) (stub agg function, explain)
--Testcase 112:
EXPLAIN VERBOSE
SELECT first_all(*) from s3;

-- select first(*) (stub agg function, result)
--Testcase 113:
SELECT first_all(*) from s3;

-- select first(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 114:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select first(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 115:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select first(*) (stub agg function and group by tag only) (explain)
--Testcase 116:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select first(*) (stub agg function and group by tag only) (result)
--Testcase 117:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select first(*) (stub agg function, expose data, explain)
--Testcase 118:
EXPLAIN VERBOSE
SELECT (first_all(*)::s3).* from s3;

-- select first(*) (stub agg function, expose data, result)
--Testcase 119:
SELECT (first_all(*)::s3).* from s3;

-- select first(regex) (stub function, explain)
--Testcase 120:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') from s3;

-- select first(regex) (stub function, explain)
--Testcase 121:
SELECT first('/value[1,4]/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 122:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 123:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select first(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 124:
EXPLAIN VERBOSE
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select first(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 125:
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select first(regex) (stub agg function and group by tag only) (explain)
--Testcase 126:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select first(regex) (stub agg function and group by tag only) (result)
--Testcase 127:
SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select first(regex) (stub agg function, expose data, explain)
--Testcase 128:
EXPLAIN VERBOSE
SELECT (first('/value[1,4]/')::s3).* from s3;

-- select first(regex) (stub agg function, expose data, result)
--Testcase 129:
SELECT (first('/value[1,4]/')::s3).* from s3;

--Testcase 130:
EXPLAIN VERBOSE
SELECT last(time, (fields->>'value1')::float), last(time, (fields->>'value2')::bigint), last(time, (fields->>'value3')::float), last(time, (fields->>'value4')::bigint) FROM s3;

--Testcase 131:
SELECT last(time, (fields->>'value1')::float), last(time, (fields->>'value2')::bigint), last(time, (fields->>'value3')::float), last(time, (fields->>'value4')::bigint) FROM s3;

-- select last(*) (stub agg function, explain)
--Testcase 132:
EXPLAIN VERBOSE
SELECT last_all(*) from s3;

-- select last(*) (stub agg function, result)
--Testcase 133:
SELECT last_all(*) from s3;

-- select last(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 134:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select last(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 135:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select last(*) (stub agg function and group by tag only) (explain)
--Testcase 136:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select last(*) (stub agg function and group by tag only) (result)
--Testcase 137:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select last(*) (stub agg function, expose data, explain)
--Testcase 138:
EXPLAIN VERBOSE
SELECT (last_all(*)::s3).* from s3;

-- select last(*) (stub agg function, expose data, result)
--Testcase 139:
SELECT (last_all(*)::s3).* from s3;

-- select last(regex) (stub function, explain)
--Testcase 140:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') from s3;

-- select last(regex) (stub function, result)
--Testcase 141:
SELECT last('/value[1,4]/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 142:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 143:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select last(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 144:
EXPLAIN VERBOSE
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select last(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 145:
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select last(regex) (stub agg function and group by tag only) (explain)
--Testcase 146:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select last(regex) (stub agg function and group by tag only) (result)
--Testcase 147:
SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select last(regex) (stub agg function, expose data, explain)
--Testcase 148:
EXPLAIN VERBOSE
SELECT (last('/value[1,4]/')::s3).* from s3;

-- select last(regex) (stub agg function, expose data, result)
--Testcase 149:
SELECT (last('/value[1,4]/')::s3).* from s3;

--Testcase 150:
EXPLAIN VERBOSE
SELECT sample((fields->>'value2')::bigint, 3) FROM s3 WHERE (fields->>'value2')::bigint < 200;

--Testcase 151:
SELECT sample((fields->>'value2')::bigint, 3) FROM s3 WHERE (fields->>'value2')::bigint < 200;

--Testcase 152:
EXPLAIN VERBOSE
SELECT sample((fields->>'value2')::bigint, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s');

--Testcase 153:
SELECT sample((fields->>'value2')::bigint, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s');

-- select sample(*, int) (stub agg function, explain)
--Testcase 154:
EXPLAIN VERBOSE
SELECT sample_all(50) from s3;

-- select sample(*, int) (stub agg function, result)
--Testcase 155:
SELECT sample_all(50) from s3;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 156:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 157:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select sample(*, int) (stub agg function and group by tag only) (explain)
--Testcase 158:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sample(*, int) (stub agg function and group by tag only) (result)
--Testcase 159:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sample(*, int) (stub agg function, expose data, explain)
--Testcase 160:
EXPLAIN VERBOSE
SELECT (sample_all(50)::s3).* from s3;

-- select sample(*, int) (stub agg function, expose data, result)
--Testcase 161:
SELECT (sample_all(50)::s3).* from s3;

-- select sample(regex) (stub agg function, explain)
--Testcase 162:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) from s3;

-- select sample(regex) (stub agg function, result)
--Testcase 163:
SELECT sample('/value[1,4]/', 50) from s3;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 164:
EXPLAIN VERBOSE
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select sample(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 165:
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select sample(regex) (stub agg function and group by tag only) (explain)
--Testcase 166:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sample(regex) (stub agg function and group by tag only) (result)
--Testcase 167:
SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sample(regex) (stub agg function, expose data, explain)
--Testcase 168:
EXPLAIN VERBOSE
SELECT (sample('/value[1,4]/', 50)::s3).* from s3;

-- select sample(regex) (stub agg function, expose data, result)
--Testcase 169:
SELECT (sample('/value[1,4]/', 50)::s3).* from s3;

--Testcase 170:
EXPLAIN VERBOSE
SELECT cumulative_sum((fields->>'value1')::float),cumulative_sum((fields->>'value2')::bigint),cumulative_sum((fields->>'value3')::float),cumulative_sum((fields->>'value4')::bigint) FROM s3;

--Testcase 171:
SELECT cumulative_sum((fields->>'value1')::float),cumulative_sum((fields->>'value2')::bigint),cumulative_sum((fields->>'value3')::float),cumulative_sum((fields->>'value4')::bigint) FROM s3;

-- select cumulative_sum(*) (stub function, explain)
--Testcase 172:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() from s3;

-- select cumulative_sum(*) (stub function, result)
--Testcase 173:
SELECT cumulative_sum_all() from s3;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 174:
SELECT cumulative_sum('/value[1,4]/') from s3;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 175:
SELECT cumulative_sum('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 176:
EXPLAIN VERBOSE
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 177:
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3;

-- select cumulative_sum(*) (stub function and group by tag only) (explain)
--Testcase 178:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select cumulative_sum(*) (stub function and group by tag only) (result)
--Testcase 179:
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select cumulative_sum(regex) (stub function and group by tag only) (explain)
--Testcase 180:
EXPLAIN VERBOSE
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select cumulative_sum(regex) (stub function and group by tag only) (result)
--Testcase 181:
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select cumulative_sum(*), cumulative_sum(regex) (stub agg function, expose data, explain)
--Testcase 182:
EXPLAIN VERBOSE
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3;

-- select cumulative_sum(*), cumulative_sum(regex) (stub agg function, expose data, result)
--Testcase 183:
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3;

--Testcase 184:
EXPLAIN VERBOSE
SELECT derivative((fields->>'value1')::float),derivative((fields->>'value2')::bigint),derivative((fields->>'value3')::float),derivative((fields->>'value4')::bigint) FROM s3;

--Testcase 185:
SELECT derivative((fields->>'value1')::float),derivative((fields->>'value2')::bigint),derivative((fields->>'value3')::float),derivative((fields->>'value4')::bigint) FROM s3;

--Testcase 186:
EXPLAIN VERBOSE
SELECT derivative((fields->>'value1')::float, interval '0.5s'),derivative((fields->>'value2')::bigint, interval '0.2s'),derivative((fields->>'value3')::float, interval '0.1s'),derivative((fields->>'value4')::bigint, interval '2s') FROM s3;

--Testcase 187:
SELECT derivative((fields->>'value1')::float, interval '0.5s'),derivative((fields->>'value2')::bigint, interval '0.2s'),derivative((fields->>'value3')::float, interval '0.1s'),derivative((fields->>'value4')::bigint, interval '2s') FROM s3;

-- select derivative(*) (stub function, explain)
--Testcase 188:
EXPLAIN VERBOSE
SELECT derivative_all() from s3;

-- select derivative(*) (stub function, result)
--Testcase 189:
SELECT derivative_all() from s3;

-- select derivative(regex) (stub function, explain)
--Testcase 190:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') from s3;

-- select derivative(regex) (stub function, result)
--Testcase 191:
SELECT derivative('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 192:
EXPLAIN VERBOSE
SELECT derivative_all(), derivative('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 193:
SELECT derivative_all(), derivative('/value[1,4]/') from s3;

-- select derivative(*) (stub function and group by tag only) (explain)
--Testcase 194:
EXPLAIN VERBOSE
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select derivative(*) (stub function and group by tag only) (result)
--Testcase 195:
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select derivative(regex) (stub function and group by tag only) (explain)
--Testcase 196:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select derivative(regex) (stub function and group by tag only) (result)
--Testcase 197:
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select derivative(*) (stub agg function, expose data, explain)
--Testcase 198:
EXPLAIN VERBOSE
SELECT (derivative_all()::s3).* from s3;

-- select derivative(*) (stub agg function, expose data, result)
--Testcase 199:
SELECT (derivative_all()::s3).* from s3;

-- select derivative(regex) (stub agg function, expose data, explain)
--Testcase 200:
EXPLAIN VERBOSE
SELECT (derivative('/value[1,4]/')::s3).* from s3;

-- select derivative(regex) (stub agg function, expose data, result)
--Testcase 201:
SELECT (derivative('/value[1,4]/')::s3).* from s3;

--Testcase 202:
EXPLAIN VERBOSE
SELECT non_negative_derivative((fields->>'value1')::float),non_negative_derivative((fields->>'value2')::bigint),non_negative_derivative((fields->>'value3')::float),non_negative_derivative((fields->>'value4')::bigint) FROM s3;

--Testcase 203:
SELECT non_negative_derivative((fields->>'value1')::float),non_negative_derivative((fields->>'value2')::bigint),non_negative_derivative((fields->>'value3')::float),non_negative_derivative((fields->>'value4')::bigint) FROM s3;

--Testcase 204:
EXPLAIN VERBOSE
SELECT non_negative_derivative((fields->>'value1')::float, interval '0.5s'),non_negative_derivative((fields->>'value2')::bigint, interval '0.2s'),non_negative_derivative((fields->>'value3')::float, interval '0.1s'),non_negative_derivative((fields->>'value4')::bigint, interval '2s') FROM s3;

--Testcase 205:
SELECT non_negative_derivative((fields->>'value1')::float, interval '0.5s'),non_negative_derivative((fields->>'value2')::bigint, interval '0.2s'),non_negative_derivative((fields->>'value3')::float, interval '0.1s'),non_negative_derivative((fields->>'value4')::bigint, interval '2s') FROM s3;

-- select non_negative_derivative(*) (stub function, explain)
--Testcase 206:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() from s3;

-- select non_negative_derivative(*) (stub function, result)
--Testcase 207:
SELECT non_negative_derivative_all() from s3;

-- select non_negative_derivative(regex) (stub function, explain)
--Testcase 208:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') from s3;

-- select non_negative_derivative(regex) (stub function, result)
--Testcase 209:
SELECT non_negative_derivative('/value[1,4]/') from s3;

-- select non_negative_derivative(*) (stub function and group by tag only) (explain)
--Testcase 210:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_derivative(*) (stub function and group by tag only) (result)
--Testcase 211:
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 212:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_derivative(regex) (stub agg function and group by tag only) (result)
--Testcase 213:
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_derivative(*) (stub function, expose data, explain)
--Testcase 214:
EXPLAIN VERBOSE
SELECT (non_negative_derivative_all()::s3).* from s3;

-- select non_negative_derivative(*) (stub agg function, expose data, result)
--Testcase 215:
SELECT (non_negative_derivative_all()::s3).* from s3;

-- select non_negative_derivative(regex) (stub function, expose data, explain)
--Testcase 216:
EXPLAIN VERBOSE
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3;

-- select non_negative_derivative(regex) (stub agg function, expose data, result)
--Testcase 217:
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3;

--Testcase 218:
EXPLAIN VERBOSE
SELECT difference((fields->>'value1')::float),difference((fields->>'value2')::bigint),difference((fields->>'value3')::float),difference((fields->>'value4')::bigint) FROM s3;

--Testcase 219:
SELECT difference((fields->>'value1')::float),difference((fields->>'value2')::bigint),difference((fields->>'value3')::float),difference((fields->>'value4')::bigint) FROM s3;

-- select difference(*) (stub function, explain)
--Testcase 220:
EXPLAIN VERBOSE
SELECT difference_all() from s3;

-- select difference(*) (stub function, result)
--Testcase 221:
SELECT difference_all() from s3;

-- select difference(regex) (stub function, explain)
--Testcase 222:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') from s3;

-- select difference(regex) (stub function, result)
--Testcase 223:
SELECT difference('/value[1,4]/') from s3;

-- select difference(*) (stub agg function and group by tag only) (explain)
--Testcase 224:
EXPLAIN VERBOSE
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select difference(*) (stub agg function and group by tag only) (result)
--Testcase 225:
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select difference(regex) (stub agg function and group by tag only) (explain)
--Testcase 226:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select difference(regex) (stub agg function and group by tag only) (result)
--Testcase 227:
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select difference(*) (stub function, expose data, explain)
--Testcase 228:
EXPLAIN VERBOSE
SELECT (difference_all()::s3).* from s3;

-- select difference(*) (stub function, expose data, result)
--Testcase 229:
SELECT (difference_all()::s3).* from s3;

-- select difference(regex) (stub function, expose data, explain)
--Testcase 230:
EXPLAIN VERBOSE
SELECT (difference('/value[1,4]/')::s3).* from s3;

-- select difference(regex) (stub function, expose data, result)
--Testcase 231:
SELECT (difference('/value[1,4]/')::s3).* from s3;

--Testcase 232:
EXPLAIN VERBOSE
SELECT non_negative_difference((fields->>'value1')::float),non_negative_difference((fields->>'value2')::bigint),non_negative_difference((fields->>'value3')::float),non_negative_difference((fields->>'value4')::bigint) FROM s3;

--Testcase 233:
SELECT non_negative_difference((fields->>'value1')::float),non_negative_difference((fields->>'value2')::bigint),non_negative_difference((fields->>'value3')::float),non_negative_difference((fields->>'value4')::bigint) FROM s3;

-- select non_negative_difference(*) (stub function, explain)
--Testcase 234:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() from s3;

-- select non_negative_difference(*) (stub function, result)
--Testcase 235:
SELECT non_negative_difference_all() from s3;

-- select non_negative_difference(regex) (stub agg function, explain)
--Testcase 236:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') from s3;

-- select non_negative_difference(*), non_negative_difference(regex) (stub function, result)
--Testcase 237:
SELECT non_negative_difference('/value[1,4]/') from s3;

-- select non_negative_difference(*) (stub function and group by tag only) (explain)
--Testcase 238:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_difference(*) (stub function and group by tag only) (result)
--Testcase 239:
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_difference(regex) (stub function and group by tag only) (explain)
--Testcase 240:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_difference(regex) (stub function and group by tag only) (result)
--Testcase 241:
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select non_negative_difference(*) (stub function, expose data, explain)
--Testcase 242:
EXPLAIN VERBOSE
SELECT (non_negative_difference_all()::s3).* from s3;

-- select non_negative_difference(*) (stub function, expose data, result)
--Testcase 243:
SELECT (non_negative_difference_all()::s3).* from s3;

-- select non_negative_difference(regex) (stub function, expose data, explain)
--Testcase 244:
EXPLAIN VERBOSE
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3;

-- select non_negative_difference(regex) (stub function, expose data, result)
--Testcase 245:
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3;

--Testcase 246:
EXPLAIN VERBOSE
SELECT elapsed((fields->>'value1')::float),elapsed((fields->>'value2')::bigint),elapsed((fields->>'value3')::float),elapsed((fields->>'value4')::bigint) FROM s3;

--Testcase 247:
SELECT elapsed((fields->>'value1')::float),elapsed((fields->>'value2')::bigint),elapsed((fields->>'value3')::float),elapsed((fields->>'value4')::bigint) FROM s3;

--Testcase 248:
EXPLAIN VERBOSE
SELECT elapsed((fields->>'value1')::float, interval '0.5s'),elapsed((fields->>'value2')::bigint, interval '0.2s'),elapsed((fields->>'value3')::float, interval '0.1s'),elapsed((fields->>'value4')::bigint, interval '2s') FROM s3;

--Testcase 249:
SELECT elapsed((fields->>'value1')::float, interval '0.5s'),elapsed((fields->>'value2')::bigint, interval '0.2s'),elapsed((fields->>'value3')::float, interval '0.1s'),elapsed((fields->>'value4')::bigint, interval '2s') FROM s3;

-- select elapsed(*) (stub function, explain)
--Testcase 250:
EXPLAIN VERBOSE
SELECT elapsed_all() from s3;

-- select elapsed(*) (stub function, result)
--Testcase 251:
SELECT elapsed_all() from s3;

-- select elapsed(regex) (stub function, explain)
--Testcase 252:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') from s3;

-- select elapsed(regex) (stub agg function, result)
--Testcase 253:
SELECT elapsed('/value[1,4]/') from s3;

-- select elapsed(*) (stub function and group by tag only) (explain)
--Testcase 254:
EXPLAIN VERBOSE
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select elapsed(*) (stub function and group by tag only) (result)
--Testcase 255:
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select elapsed(regex) (stub function and group by tag only) (explain)
--Testcase 256:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select elapsed(regex) (stub function and group by tag only) (result)
--Testcase 257:
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select elapsed(*) (stub function, expose data, explain)
--Testcase 258:
EXPLAIN VERBOSE
SELECT (elapsed_all()::s3).* from s3;

-- select elapsed(*) (stub function, expose data, result)
--Testcase 259:
SELECT (elapsed_all()::s3).* from s3;

-- select elapsed(regex) (stub function, expose data, explain)
--Testcase 260:
EXPLAIN VERBOSE
SELECT (elapsed('/value[1,4]/')::s3).* from s3;

-- select elapsed(regex) (stub agg function, expose data, result)
--Testcase 261:
SELECT (elapsed('/value[1,4]/')::s3).* from s3;

--Testcase 262:
EXPLAIN VERBOSE
SELECT moving_average((fields->>'value1')::float, 2),moving_average((fields->>'value2')::bigint, 2),moving_average((fields->>'value3')::float, 2),moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 263:
SELECT moving_average((fields->>'value1')::float, 2),moving_average((fields->>'value2')::bigint, 2),moving_average((fields->>'value3')::float, 2),moving_average((fields->>'value4')::bigint, 2) FROM s3;

-- select moving_average(*) (stub function, explain)
--Testcase 264:
EXPLAIN VERBOSE
SELECT moving_average_all(2) from s3;

-- select moving_average(*) (stub function, result)
--Testcase 265:
SELECT moving_average_all(2) from s3;

-- select moving_average(regex) (stub function, explain)
--Testcase 266:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) from s3;

-- select moving_average(regex) (stub function, result)
--Testcase 267:
SELECT moving_average('/value[1,4]/', 2) from s3;

-- select moving_average(*) (stub function and group by tag only) (explain)
--Testcase 268:
EXPLAIN VERBOSE
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select moving_average(*) (stub function and group by tag only) (result)
--Testcase 269:
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 270:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select moving_average(regex) (stub function and group by tag only) (result)
--Testcase 271:
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select moving_average(*) (stub function, expose data, explain)
--Testcase 272:
EXPLAIN VERBOSE
SELECT (moving_average_all(2)::s3).* from s3;

-- select moving_average(*) (stub function, expose data, result)
--Testcase 273:
SELECT (moving_average_all(2)::s3).* from s3;

-- select moving_average(regex) (stub function, expose data, explain)
--Testcase 274:
EXPLAIN VERBOSE
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3;

-- select moving_average(regex) (stub function, expose data, result)
--Testcase 275:
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3;

--Testcase 276:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator((fields->>'value1')::float, 2),chande_momentum_oscillator((fields->>'value2')::bigint, 2),chande_momentum_oscillator((fields->>'value3')::float, 2),chande_momentum_oscillator((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 277:
SELECT chande_momentum_oscillator((fields->>'value1')::float, 2),chande_momentum_oscillator((fields->>'value2')::bigint, 2),chande_momentum_oscillator((fields->>'value3')::float, 2),chande_momentum_oscillator((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 278:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator((fields->>'value1')::float, 2, 2),chande_momentum_oscillator((fields->>'value2')::bigint, 2, 2),chande_momentum_oscillator((fields->>'value3')::float, 2, 2),chande_momentum_oscillator((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 279:
SELECT chande_momentum_oscillator((fields->>'value1')::float, 2, 2),chande_momentum_oscillator((fields->>'value2')::bigint, 2, 2),chande_momentum_oscillator((fields->>'value3')::float, 2, 2),chande_momentum_oscillator((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select chande_momentum_oscillator(*) (stub function, explain)
--Testcase 280:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) from s3;

-- select chande_momentum_oscillator(*) (stub function, result)
--Testcase 281:
SELECT chande_momentum_oscillator_all(2) from s3;

-- select chande_momentum_oscillator(regex) (stub function, explain)
--Testcase 282:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3;

-- select chande_momentum_oscillator(regex) (stub agg function, result)
--Testcase 283:
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (explain)
--Testcase 284:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select chande_momentum_oscillator(*) (stub agg function and group by tag only) (result)
--Testcase 285:
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select chande_momentum_oscillator(regex) (stub agg function and group by tag only) (explain)
--Testcase 286:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (result)
--Testcase 287:
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select chande_momentum_oscillator(*) (stub agg function, expose data, explain)
--Testcase 288:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3;

-- select chande_momentum_oscillator(*) (stub function, expose data, result)
--Testcase 289:
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3;

-- select chande_momentum_oscillator(regex) (stub function, expose data, explain)
--Testcase 290:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3;

-- select chande_momentum_oscillator(regex) (stub function, expose data, result)
--Testcase 291:
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3;

--Testcase 292:
EXPLAIN VERBOSE
SELECT exponential_moving_average((fields->>'value1')::float, 2),exponential_moving_average((fields->>'value2')::bigint, 2),exponential_moving_average((fields->>'value3')::float, 2),exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 293:
SELECT exponential_moving_average((fields->>'value1')::float, 2),exponential_moving_average((fields->>'value2')::bigint, 2),exponential_moving_average((fields->>'value3')::float, 2),exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 294:
EXPLAIN VERBOSE
SELECT exponential_moving_average((fields->>'value1')::float, 2, 2),exponential_moving_average((fields->>'value2')::bigint, 2, 2),exponential_moving_average((fields->>'value3')::float, 2, 2),exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 295:
SELECT exponential_moving_average((fields->>'value1')::float, 2, 2),exponential_moving_average((fields->>'value2')::bigint, 2, 2),exponential_moving_average((fields->>'value3')::float, 2, 2),exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select exponential_moving_average(*) (stub function, explain)
--Testcase 296:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) from s3;

-- select exponential_moving_average(*) (stub function, result)
--Testcase 297:
SELECT exponential_moving_average_all(2) from s3;

-- select exponential_moving_average(regex) (stub function, explain)
--Testcase 298:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) from s3;

-- select exponential_moving_average(regex) (stub function, result)
--Testcase 299:
SELECT exponential_moving_average('/value[1,4]/',2) from s3;

-- select exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 300:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 301:
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 302:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 303:
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

--Testcase 304:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average((fields->>'value1')::float, 2),double_exponential_moving_average((fields->>'value2')::bigint, 2),double_exponential_moving_average((fields->>'value3')::float, 2),double_exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 305:
SELECT double_exponential_moving_average((fields->>'value1')::float, 2),double_exponential_moving_average((fields->>'value2')::bigint, 2),double_exponential_moving_average((fields->>'value3')::float, 2),double_exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 306:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average((fields->>'value1')::float, 2, 2),double_exponential_moving_average((fields->>'value2')::bigint, 2, 2),double_exponential_moving_average((fields->>'value3')::float, 2, 2),double_exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 307:
SELECT double_exponential_moving_average((fields->>'value1')::float, 2, 2),double_exponential_moving_average((fields->>'value2')::bigint, 2, 2),double_exponential_moving_average((fields->>'value3')::float, 2, 2),double_exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select double_exponential_moving_average(*) (stub function, explain)
--Testcase 308:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) from s3;

-- select double_exponential_moving_average(*) (stub function, result)
--Testcase 309:
SELECT double_exponential_moving_average_all(2) from s3;

-- select double_exponential_moving_average(regex) (stub function, explain)
--Testcase 310:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3;

-- select double_exponential_moving_average(regex) (stub function, result)
--Testcase 311:
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 312:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select double_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 313:
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 314:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 315:
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

--Testcase 316:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio((fields->>'value1')::float, 2),kaufmans_efficiency_ratio((fields->>'value2')::bigint, 2),kaufmans_efficiency_ratio((fields->>'value3')::float, 2),kaufmans_efficiency_ratio((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 317:
SELECT kaufmans_efficiency_ratio((fields->>'value1')::float, 2),kaufmans_efficiency_ratio((fields->>'value2')::bigint, 2),kaufmans_efficiency_ratio((fields->>'value3')::float, 2),kaufmans_efficiency_ratio((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 318:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio((fields->>'value1')::float, 2, 2),kaufmans_efficiency_ratio((fields->>'value2')::bigint, 2, 2),kaufmans_efficiency_ratio((fields->>'value3')::float, 2, 2),kaufmans_efficiency_ratio((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 319:
SELECT kaufmans_efficiency_ratio((fields->>'value1')::float, 2, 2),kaufmans_efficiency_ratio((fields->>'value2')::bigint, 2, 2),kaufmans_efficiency_ratio((fields->>'value3')::float, 2, 2),kaufmans_efficiency_ratio((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select kaufmans_efficiency_ratio(*) (stub function, explain)
--Testcase 320:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) from s3;

-- select kaufmans_efficiency_ratio(*) (stub function, result)
--Testcase 321:
SELECT kaufmans_efficiency_ratio_all(2) from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, explain)
--Testcase 322:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, result)
--Testcase 323:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (explain)
--Testcase 324:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (result)
--Testcase 325:
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (explain)
--Testcase 326:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (result)
--Testcase 327:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, explain)
--Testcase 328:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, result)
--Testcase 329:
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, explain)
--Testcase 330:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, result)
--Testcase 331:
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3;

--Testcase 332:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average((fields->>'value1')::float, 2),kaufmans_adaptive_moving_average((fields->>'value2')::bigint, 2),kaufmans_adaptive_moving_average((fields->>'value3')::float, 2),kaufmans_adaptive_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 333:
SELECT kaufmans_adaptive_moving_average((fields->>'value1')::float, 2),kaufmans_adaptive_moving_average((fields->>'value2')::bigint, 2),kaufmans_adaptive_moving_average((fields->>'value3')::float, 2),kaufmans_adaptive_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 334:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average((fields->>'value1')::float, 2, 2),kaufmans_adaptive_moving_average((fields->>'value2')::bigint, 2, 2),kaufmans_adaptive_moving_average((fields->>'value3')::float, 2, 2),kaufmans_adaptive_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 335:
SELECT kaufmans_adaptive_moving_average((fields->>'value1')::float, 2, 2),kaufmans_adaptive_moving_average((fields->>'value2')::bigint, 2, 2),kaufmans_adaptive_moving_average((fields->>'value3')::float, 2, 2),kaufmans_adaptive_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select kaufmans_adaptive_moving_average(*) (stub function, explain)
--Testcase 336:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) from s3;

-- select kaufmans_adaptive_moving_average(*) (stub function, result)
--Testcase 337:
SELECT kaufmans_adaptive_moving_average_all(2) from s3;

-- select kaufmans_adaptive_moving_average(regex) (stub function, explain)
--Testcase 338:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3;

-- select kaufmans_adaptive_moving_average(regex) (stub agg function, result)
--Testcase 339:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 340:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (result)
--Testcase 341:
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 342:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 343:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

--Testcase 344:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average((fields->>'value1')::float, 2),triple_exponential_moving_average((fields->>'value2')::bigint, 2),triple_exponential_moving_average((fields->>'value3')::float, 2),triple_exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 345:
SELECT triple_exponential_moving_average((fields->>'value1')::float, 2),triple_exponential_moving_average((fields->>'value2')::bigint, 2),triple_exponential_moving_average((fields->>'value3')::float, 2),triple_exponential_moving_average((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 346:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average((fields->>'value1')::float, 2, 2),triple_exponential_moving_average((fields->>'value2')::bigint, 2, 2),triple_exponential_moving_average((fields->>'value3')::float, 2, 2),triple_exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 347:
SELECT triple_exponential_moving_average((fields->>'value1')::float, 2, 2),triple_exponential_moving_average((fields->>'value2')::bigint, 2, 2),triple_exponential_moving_average((fields->>'value3')::float, 2, 2),triple_exponential_moving_average((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select triple_exponential_moving_average(*) (stub function, explain)
--Testcase 348:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) from s3;

-- select triple_exponential_moving_average(*) (stub function, result)
--Testcase 349:
SELECT triple_exponential_moving_average_all(2) from s3;

-- select triple_exponential_moving_average(regex) (stub function, explain)
--Testcase 350:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3;

-- select triple_exponential_moving_average(regex) (stub function, result)
--Testcase 351:
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 352:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 353:
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_moving_average(regex) (stub agg function and group by tag only) (explain)
--Testcase 354:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_moving_average(regex) (stub agg function and group by tag only) (result)
--Testcase 355:
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

--Testcase 356:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative((fields->>'value1')::float, 2),triple_exponential_derivative((fields->>'value2')::bigint, 2),triple_exponential_derivative((fields->>'value3')::float, 2),triple_exponential_derivative((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 357:
SELECT triple_exponential_derivative((fields->>'value1')::float, 2),triple_exponential_derivative((fields->>'value2')::bigint, 2),triple_exponential_derivative((fields->>'value3')::float, 2),triple_exponential_derivative((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 358:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative((fields->>'value1')::float, 2, 2),triple_exponential_derivative((fields->>'value2')::bigint, 2, 2),triple_exponential_derivative((fields->>'value3')::float, 2, 2),triple_exponential_derivative((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 359:
SELECT triple_exponential_derivative((fields->>'value1')::float, 2, 2),triple_exponential_derivative((fields->>'value2')::bigint, 2, 2),triple_exponential_derivative((fields->>'value3')::float, 2, 2),triple_exponential_derivative((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select triple_exponential_derivative(*) (stub function, explain)
--Testcase 360:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) from s3;

-- select triple_exponential_derivative(*) (stub function, result)
--Testcase 361:
SELECT triple_exponential_derivative_all(2) from s3;

-- select triple_exponential_derivative(regex) (stub function, explain)
--Testcase 362:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3;

-- select triple_exponential_derivative(regex) (stub function, result)
--Testcase 363:
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (explain)
--Testcase 364:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_derivative(*) (stub function and group by tag only) (result)
--Testcase 365:
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 366:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (result)
--Testcase 367:
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

--Testcase 368:
EXPLAIN VERBOSE
SELECT relative_strength_index((fields->>'value1')::float, 2),relative_strength_index((fields->>'value2')::bigint, 2),relative_strength_index((fields->>'value3')::float, 2),relative_strength_index((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 369:
SELECT relative_strength_index((fields->>'value1')::float, 2),relative_strength_index((fields->>'value2')::bigint, 2),relative_strength_index((fields->>'value3')::float, 2),relative_strength_index((fields->>'value4')::bigint, 2) FROM s3;

--Testcase 370:
EXPLAIN VERBOSE
SELECT relative_strength_index((fields->>'value1')::float, 2, 2),relative_strength_index((fields->>'value2')::bigint, 2, 2),relative_strength_index((fields->>'value3')::float, 2, 2),relative_strength_index((fields->>'value4')::bigint, 2, 2) FROM s3;

--Testcase 371:
SELECT relative_strength_index((fields->>'value1')::float, 2, 2),relative_strength_index((fields->>'value2')::bigint, 2, 2),relative_strength_index((fields->>'value3')::float, 2, 2),relative_strength_index((fields->>'value4')::bigint, 2, 2) FROM s3;

-- select relative_strength_index(*) (stub function, explain)
--Testcase 372:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) from s3;

-- select relative_strength_index(*) (stub function, result)
--Testcase 373:
SELECT relative_strength_index_all(2) from s3;

-- select relative_strength_index(regex) (stub agg function, explain)
--Testcase 374:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) from s3;

-- select relative_strength_index(regex) (stub agg function, result)
--Testcase 375:
SELECT relative_strength_index('/value[1,4]/',2) from s3;

-- select relative_strength_index(*) (stub function and group by tag only) (explain)
--Testcase 376:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select relative_strength_index(*) (stub function and group by tag only) (result)
--Testcase 377:
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select relative_strength_index(regex) (stub function and group by tag only) (explain)
--Testcase 378:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select relative_strength_index(regex) (stub function and group by tag only) (result)
--Testcase 379:
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select relative_strength_index(*) (stub function, expose data, explain)
--Testcase 380:
EXPLAIN VERBOSE
SELECT (relative_strength_index_all(2)::s3).* from s3;

-- select relative_strength_index(*) (stub function, expose data, result)
--Testcase 381:
SELECT (relative_strength_index_all(2)::s3).* from s3;

-- select relative_strength_index(regex) (stub function, expose data, explain)
--Testcase 382:
EXPLAIN VERBOSE
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3;

-- select relative_strength_index(regex) (stub function, expose data, result)
--Testcase 383:
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3;

-- select integral (stub agg function, explain)
--Testcase 384:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float),integral((fields->>'value2')::bigint),integral((fields->>'value3')::float),integral((fields->>'value4')::bigint) FROM s3;

-- select integral (stub agg function, result)
--Testcase 385:
SELECT integral((fields->>'value1')::float),integral((fields->>'value2')::bigint),integral((fields->>'value3')::float),integral((fields->>'value4')::bigint) FROM s3;

--Testcase 386:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float, interval '1s'),integral((fields->>'value2')::bigint, interval '1s'),integral((fields->>'value3')::float, interval '1s'),integral((fields->>'value4')::bigint, interval '1s') FROM s3;

-- select integral (stub agg function, result)
--Testcase 387:
SELECT integral((fields->>'value1')::float, interval '1s'),integral((fields->>'value2')::bigint, interval '1s'),integral((fields->>'value3')::float, interval '1s'),integral((fields->>'value4')::bigint, interval '1s') FROM s3;

-- select integral (stub agg function, raise exception if not expected type)
--Testcase 388:
SELECT integral((fields->>'value1')::numeric),integral((fields->>'value2')::numeric),integral((fields->>'value3')::numeric),integral((fields->>'value4')::numeric) FROM s3;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 389:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 390:
SELECT integral((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 391:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float, interval '1s'),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 392:
SELECT integral((fields->>'value1')::float, interval '1s'),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral (stub agg function and group by tag only) (result)
--Testcase 393:
SELECT tags->>'tag1' tag1,integral((fields->>'value1')::float) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1' ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 394:
SELECT sum((fields->>'value1')::float),integral((fields->>'value1')::float),count((fields->>'value1')::float) FROM s3;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 395:
SELECT tags->>'tag1' tag1,integral((fields->>'value1')::float, interval '1s') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1' ORDER BY 1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 396:
SELECT sum((fields->>'value1')::float),integral((fields->>'value1')::float, interval '1s'),count((fields->>'value1')::float) FROM s3;

-- select integral over join query (explain)
--Testcase 397:
EXPLAIN VERBOSE
SELECT integral((t1.fields->>'value1')::float), integral((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select integral over join query (result, stub call error)
--Testcase 398:
SELECT integral((t1.fields->>'value1')::float), integral((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select integral over join query (explain)
--Testcase 399:
EXPLAIN VERBOSE
SELECT integral((t1.fields->>'value1')::float, interval '1s'), integral((t2.fields->>'value1')::float, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select integral over join query (result, stub call error)
--Testcase 400:
SELECT integral((t1.fields->>'value1')::float, interval '1s'), integral((t2.fields->>'value1')::float, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select integral with having (explain)
--Testcase 401:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float) FROM s3 HAVING integral((fields->>'value1')::float) > 100;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 402:
SELECT integral((fields->>'value1')::float) FROM s3 HAVING integral((fields->>'value1')::float) > 100;

-- select integral with having (explain)
--Testcase 403:
EXPLAIN VERBOSE
SELECT integral((fields->>'value1')::float, interval '1s') FROM s3 HAVING integral((fields->>'value1')::float, interval '1s') > 100;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 404:
SELECT integral((fields->>'value1')::float, interval '1s') FROM s3 HAVING integral((fields->>'value1')::float, interval '1s') > 100;

-- select integral(*) (stub agg function, explain)
--Testcase 405:
EXPLAIN VERBOSE
SELECT integral_all(*) from s3;

-- select integral(*) (stub agg function, result)
--Testcase 406:
SELECT integral_all(*) from s3;

-- select integral(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 407:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 408:
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral(*) (stub agg function and group by tag only) (explain)
--Testcase 409:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 WHERE (fields->>'value1')::float > 0.3 GROUP BY tags->>'tag1';

-- select integral(*) (stub agg function and group by tag only) (result)
--Testcase 410:
SELECT integral_all(*) FROM s3 WHERE (fields->>'value1')::float > 0.3 GROUP BY tags->>'tag1';

-- select integral(*) (stub agg function, expose data, explain)
--Testcase 411:
EXPLAIN VERBOSE
SELECT (integral_all(*)::s3).* from s3;

-- select integral(*) (stub agg function, expose data, result)
--Testcase 412:
SELECT (integral_all(*)::s3).* from s3;

-- select integral(regex) (stub agg function, explain)
--Testcase 413:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') from s3;

-- select integral(regex) (stub agg function, result)
--Testcase 414:
SELECT integral('/value[1,4]/') from s3;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 415:
EXPLAIN VERBOSE
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 416:
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select integral(regex) (stub agg function and group by tag only) (explain)
--Testcase 417:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') FROM s3 WHERE (fields->>'value1')::float > 0.3 GROUP BY tags->>'tag1';

-- select integral(regex) (stub agg function and group by tag only) (result)
--Testcase 418:
SELECT integral('/value[1,4]/') FROM s3 WHERE (fields->>'value1')::float > 0.3 GROUP BY tags->>'tag1';

-- select integral(regex) (stub agg function, expose data, explain)
--Testcase 419:
EXPLAIN VERBOSE
SELECT (integral('/value[1,4]/')::s3).* from s3;

-- select integral(regex) (stub agg function, expose data, result)
--Testcase 420:
SELECT (integral('/value[1,4]/')::s3).* from s3;

-- select mean (stub agg function, explain)
--Testcase 421:
EXPLAIN VERBOSE
SELECT mean((fields->>'value1')::float),mean((fields->>'value2')::bigint),mean((fields->>'value3')::float),mean((fields->>'value4')::bigint) FROM s3;

-- select mean (stub agg function, result)
--Testcase 422:
SELECT mean((fields->>'value1')::float),mean((fields->>'value2')::bigint),mean((fields->>'value3')::float),mean((fields->>'value4')::bigint) FROM s3;

-- select mean (stub agg function, raise exception if not expected type)
--Testcase 423:
SELECT mean((fields->>'value1')::numeric),mean((fields->>'value2')::numeric),mean((fields->>'value3')::numeric),mean((fields->>'value4')::numeric) FROM s3;

-- select mean (stub agg function and group by influx_time() and tag) (explain)
--Testcase 424:
EXPLAIN VERBOSE
SELECT mean((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean (stub agg function and group by influx_time() and tag) (result)
--Testcase 425:
SELECT mean((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean (stub agg function and group by tag only) (result)
--Testcase 426:
SELECT tags->>'tag1' tag1,mean((fields->>'value1')::float) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select mean (stub agg function and other aggs) (result)
--Testcase 427:
SELECT sum((fields->>'value1')::float),mean((fields->>'value1')::float),count((fields->>'value1')::float) FROM s3;

-- select mean over join query (explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT mean((t1.fields->>'value1')::float), mean((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select mean over join query (result, stub call error)
--Testcase 429:
SELECT mean((t1.fields->>'value1')::float), mean((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select mean with having (explain)
--Testcase 430:
EXPLAIN VERBOSE
SELECT mean((fields->>'value1')::float) FROM s3 HAVING mean((fields->>'value1')::float) > 100;

-- select mean with having (explain, not pushdown, stub call error)
--Testcase 431:
SELECT mean((fields->>'value1')::float) FROM s3 HAVING mean((fields->>'value1')::float) > 100;

-- select mean(*) (stub agg function, explain)
--Testcase 432:
EXPLAIN VERBOSE
SELECT mean_all(*) from s3;

-- select mean(*) (stub agg function, result)
--Testcase 433:
SELECT mean_all(*) from s3;

-- select mean(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 434:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 435:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean(*) (stub agg function and group by tag only) (explain)
--Testcase 436:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select mean(*) (stub agg function and group by tag only) (result)
--Testcase 437:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select mean(*) (stub agg function, expose data, explain)
--Testcase 438:
EXPLAIN VERBOSE
SELECT (mean_all(*)::s3).* from s3;

-- select mean(*) (stub agg function, expose data, result)
--Testcase 439:
SELECT (mean_all(*)::s3).* from s3;

-- select mean(regex) (stub agg function, explain)
--Testcase 440:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') from s3;

-- select mean(regex) (stub agg function, result)
--Testcase 441:
SELECT mean('/value[1,4]/') from s3;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 442:
EXPLAIN VERBOSE
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 443:
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select mean(regex) (stub agg function and group by tag only) (explain)
--Testcase 444:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select mean(regex) (stub agg function and group by tag only) (result)
--Testcase 445:
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select mean(regex) (stub agg function, expose data, explain)
--Testcase 446:
EXPLAIN VERBOSE
SELECT (mean('/value[1,4]/')::s3).* from s3;

-- select mean(regex) (stub agg function, expose data, result)
--Testcase 447:
SELECT (mean('/value[1,4]/')::s3).* from s3;

-- select median (stub agg function, explain)
--Testcase 448:
EXPLAIN VERBOSE
SELECT median((fields->>'value1')::float),median((fields->>'value2')::bigint),median((fields->>'value3')::float),median((fields->>'value4')::bigint) FROM s3;

-- select median (stub agg function, result)
--Testcase 449:
SELECT median((fields->>'value1')::float),median((fields->>'value2')::bigint),median((fields->>'value3')::float),median((fields->>'value4')::bigint) FROM s3;

-- select median (stub agg function, raise exception if not expected type)
--Testcase 450:
SELECT median((fields->>'value1')::numeric),median((fields->>'value2')::numeric),median((fields->>'value3')::numeric),median((fields->>'value4')::numeric) FROM s3;

-- select median (stub agg function and group by influx_time() and tag) (explain)
--Testcase 451:
EXPLAIN VERBOSE
SELECT median((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median (stub agg function and group by influx_time() and tag) (result)
--Testcase 452:
SELECT median((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median (stub agg function and group by tag only) (result)
--Testcase 453:
SELECT tags->>'tag1' tag1,median((fields->>'value1')::float) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select median (stub agg function and other aggs) (result)
--Testcase 454:
SELECT sum((fields->>'value1')::float),median((fields->>'value1')::float),count((fields->>'value1')::float) FROM s3;

-- select median over join query (explain)
--Testcase 455:
EXPLAIN VERBOSE
SELECT median((t1.fields->>'value1')::float), median((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select median over join query (result, stub call error)
--Testcase 456:
SELECT median((t1.fields->>'value1')::float), median((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select median with having (explain)
--Testcase 457:
EXPLAIN VERBOSE
SELECT median((fields->>'value1')::float) FROM s3 HAVING median((fields->>'value1')::float) > 100;

-- select median with having (explain, not pushdown, stub call error)
--Testcase 458:
SELECT median((fields->>'value1')::float) FROM s3 HAVING median((fields->>'value1')::float) > 100;

-- select median(*) (stub agg function, explain)
--Testcase 459:
EXPLAIN VERBOSE
SELECT median_all(*) from s3;

-- select median(*) (stub agg function, result)
--Testcase 460:
SELECT median_all(*) from s3;

-- select median(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 461:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 462:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median(*) (stub agg function and group by tag only) (explain)
--Testcase 463:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select median(*) (stub agg function and group by tag only) (result)
--Testcase 464:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select median(*) (stub agg function, expose data, explain)
--Testcase 465:
EXPLAIN VERBOSE
SELECT (median_all(*)::s3).* from s3;

-- select median(*) (stub agg function, expose data, result)
--Testcase 466:
SELECT (median_all(*)::s3).* from s3;

-- select median(regex) (stub agg function, explain)
--Testcase 467:
EXPLAIN VERBOSE
SELECT median('/^v.*/') from s3;

-- select median(regex) (stub agg function, result)
--Testcase 468:
SELECT  median('/^v.*/') from s3;

-- select median(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 469:
EXPLAIN VERBOSE
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 470:
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select median(regex) (stub agg function and group by tag only) (explain)
--Testcase 471:
EXPLAIN VERBOSE
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select median(regex) (stub agg function and group by tag only) (result)
--Testcase 472:
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select median(regex) (stub agg function, expose data, explain)
--Testcase 473:
EXPLAIN VERBOSE
SELECT (median('/value[1,4]/')::s3).* from s3;

-- select median(regex) (stub agg function, expose data, result)
--Testcase 474:
SELECT (median('/value[1,4]/')::s3).* from s3;

-- select influx_mode (stub agg function, explain)
--Testcase 475:
EXPLAIN VERBOSE
SELECT influx_mode((fields->>'value1')::float),influx_mode((fields->>'value2')::bigint),influx_mode((fields->>'value3')::float),influx_mode((fields->>'value4')::bigint) FROM s3;

-- select influx_mode (stub agg function, result)
--Testcase 476:
SELECT influx_mode((fields->>'value1')::float),influx_mode((fields->>'value2')::bigint),influx_mode((fields->>'value3')::float),influx_mode((fields->>'value4')::bigint) FROM s3;

-- select influx_mode (stub agg function, raise exception if not expected type)
--Testcase 477:
SELECT influx_mode((fields->>'value1')::numeric),influx_mode((fields->>'value2')::numeric),influx_mode((fields->>'value3')::numeric),influx_mode((fields->>'value4')::numeric) FROM s3;

-- select influx_mode (stub agg function and group by influx_time() and tag) (explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT influx_mode((fields->>'value1')::numeric),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode (stub agg function and group by influx_time() and tag) (result)
--Testcase 479:
SELECT influx_mode((fields->>'value1')::numeric),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode (stub agg function and group by tag only) (result)
--Testcase 480:
SELECT tags->>'tag1' tag1,influx_mode((fields->>'value1')::numeric) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_mode (stub agg function and other aggs) (result)
--Testcase 481:
SELECT sum((fields->>'value1')::float),influx_mode((fields->>'value1')::numeric),count((fields->>'value1')::float) FROM s3;

-- select influx_mode over join query (explain)
--Testcase 482:
EXPLAIN VERBOSE
SELECT influx_mode((t1.fields->>'value1')::float), influx_mode((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select influx_mode over join query (result, stub call error)
--Testcase 483:
SELECT influx_mode((t1.fields->>'value1')::float), influx_mode((t2.fields->>'value1')::float) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select influx_mode with having (explain)
--Testcase 484:
EXPLAIN VERBOSE
SELECT influx_mode((fields->>'value1')::float) FROM s3 HAVING influx_mode((fields->>'value1')::float) > 100;

-- select influx_mode with having (explain, not pushdown, stub call error)
--Testcase 485:
SELECT influx_mode((fields->>'value1')::float) FROM s3 HAVING influx_mode((fields->>'value1')::float) > 100;

-- select influx_mode(*) (stub agg function, explain)
--Testcase 486:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) from s3;

-- select influx_mode(*) (stub agg function, result)
--Testcase 487:
SELECT influx_mode_all(*) from s3;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 488:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 489:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode(*) (stub agg function and group by tag only) (explain)
--Testcase 490:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_mode(*) (stub agg function and group by tag only) (result)
--Testcase 491:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_mode(*) (stub agg function, expose data, explain)
--Testcase 492:
EXPLAIN VERBOSE
SELECT (influx_mode_all(*)::s3).* from s3;

-- select influx_mode(*) (stub agg function, expose data, result)
--Testcase 493:
SELECT (influx_mode_all(*)::s3).* from s3;

-- select influx_mode(regex) (stub function, explain)
--Testcase 494:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') from s3;

-- select influx_mode(regex) (stub function, result)
--Testcase 495:
SELECT influx_mode('/value[1,4]/') from s3;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 496:
EXPLAIN VERBOSE
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 497:
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_mode(regex) (stub agg function and group by tag only) (explain)
--Testcase 498:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_mode(regex) (stub agg function and group by tag only) (result)
--Testcase 499:
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_mode(regex) (stub agg function, expose data, explain)
--Testcase 500:
EXPLAIN VERBOSE
SELECT (influx_mode('/value[1,4]/')::s3).* from s3;

-- select influx_mode(regex) (stub agg function, expose data, result)
--Testcase 501:
SELECT (influx_mode('/value[1,4]/')::s3).* from s3;

-- select stddev (agg function, explain)
--Testcase 502:
EXPLAIN VERBOSE
SELECT stddev((fields->>'value1')::float),stddev((fields->>'value2')::bigint),stddev((fields->>'value3')::float),stddev((fields->>'value4')::bigint) FROM s3;

-- select stddev (agg function, result)
--Testcase 503:
SELECT stddev((fields->>'value1')::float),stddev((fields->>'value2')::bigint),stddev((fields->>'value3')::float),stddev((fields->>'value4')::bigint) FROM s3;

-- select stddev (agg function and group by influx_time() and tag) (explain)
--Testcase 504:
EXPLAIN VERBOSE
SELECT stddev((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev (agg function and group by influx_time() and tag) (result)
--Testcase 505:
SELECT stddev((fields->>'value1')::float),influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev (agg function and group by tag only) (result)
--Testcase 506:
SELECT tags->>'tag1' tag1,stddev((fields->>'value1')::float) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select stddev (agg function and other aggs) (result)
--Testcase 507:
SELECT sum((fields->>'value1')::float),stddev((fields->>'value1')::float),count(fields->>'value1') FROM s3;

-- select stddev(*) (stub agg function, explain)
--Testcase 508:
EXPLAIN VERBOSE
SELECT stddev_all(*) from s3;

-- select stddev(*) (stub agg function, result)
--Testcase 509:
SELECT stddev_all(*) from s3;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 510:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 511:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev(*) (stub agg function and group by tag only) (explain)
--Testcase 512:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select stddev(*) (stub agg function and group by tag only) (result)
--Testcase 513:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select stddev(regex) (stub function, explain)
--Testcase 514:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') from s3;

-- select stddev(regex) (stub function, result)
--Testcase 515:
SELECT stddev('/value[1,4]/') from s3;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 517:
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select stddev(regex) (stub agg function and group by tag only) (explain)
--Testcase 518:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select stddev(regex) (stub agg function and group by tag only) (result)
--Testcase 519:
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_sum(*) (stub agg function, explain)
--Testcase 520:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) from s3;

-- select influx_sum(*) (stub agg function, result)
--Testcase 521:
SELECT influx_sum_all(*) from s3;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 522:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 523:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_sum(*) (stub agg function and group by tag only) (explain)
--Testcase 524:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_sum(*) (stub agg function and group by tag only) (result)
--Testcase 525:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_sum(*) (stub agg function, expose data, explain)
--Testcase 526:
EXPLAIN VERBOSE
SELECT (influx_sum_all(*)::s3).* from s3;

-- select influx_sum(*) (stub agg function, expose data, result)
--Testcase 527:
SELECT (influx_sum_all(*)::s3).* from s3;

-- select influx_sum(regex) (stub function, explain)
--Testcase 528:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') from s3;

-- select influx_sum(regex) (stub function, result)
--Testcase 529:
SELECT influx_sum('/value[1,4]/') from s3;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 530:
EXPLAIN VERBOSE
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 531:
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_sum(regex) (stub agg function and group by tag only) (explain)
--Testcase 532:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_sum(regex) (stub agg function and group by tag only) (result)
--Testcase 533:
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_sum(regex) (stub agg function, expose data, explain)
--Testcase 534:
EXPLAIN VERBOSE
SELECT (influx_sum('/value[1,4]/')::s3).* from s3;

-- select influx_sum(regex) (stub agg function, expose data, result)
--Testcase 535:
SELECT (influx_sum('/value[1,4]/')::s3).* from s3;

-- selector function bottom() (explain)
--Testcase 536:
EXPLAIN VERBOSE
SELECT bottom((fields->>'value1')::float, 1) FROM s3;

-- selector function bottom() (result)
--Testcase 537:
SELECT bottom((fields->>'value1')::float, 1) FROM s3;

-- selector function bottom() cannot be combined with other functions(explain)
--Testcase 538:
EXPLAIN VERBOSE
SELECT bottom((fields->>'value1')::float, 1), bottom((fields->>'value2')::bigint, 1), bottom((fields->>'value3')::float, 1), bottom((fields->>'value4')::bigint, 1) FROM s3;

-- selector function bottom() cannot be combined with other functions(result)
--Testcase 539:
SELECT bottom((fields->>'value1')::float, 1), bottom((fields->>'value2')::bigint, 1), bottom((fields->>'value3')::float, 1), bottom((fields->>'value4')::bigint, 1) FROM s3;

-- select influx_max(*) (stub agg function, explain)
--Testcase 540:
EXPLAIN VERBOSE
SELECT influx_max_all(*) from s3;

-- select influx_max(*) (stub agg function, result)
--Testcase 541:
SELECT influx_max_all(*) from s3;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 542:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 543:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_max(*) (stub agg function and group by tag only) (explain)
--Testcase 544:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_max(*) (stub agg function and group by tag only) (result)
--Testcase 545:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_max(*) (stub agg function, expose data, explain)
--Testcase 546:
EXPLAIN VERBOSE
SELECT (influx_max_all(*)::s3).* from s3;

-- select influx_max(*) (stub agg function, expose data, result)
--Testcase 547:
SELECT (influx_max_all(*)::s3).* from s3;

-- select influx_max(regex) (stub function, explain)
--Testcase 548:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') from s3;

-- select influx_max(regex) (stub function, result)
--Testcase 549:
SELECT influx_max('/value[1,4]/') from s3;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 550:
EXPLAIN VERBOSE
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 551:
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_max(regex) (stub agg function and group by tag only) (explain)
--Testcase 552:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_max(regex) (stub agg function and group by tag only) (result)
--Testcase 553:
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_max(regex) (stub agg function, expose data, explain)
--Testcase 554:
EXPLAIN VERBOSE
SELECT (influx_max('/value[1,4]/')::s3).* from s3;

-- select influx_max(regex) (stub agg function, expose data, result)
--Testcase 555:
SELECT (influx_max('/value[1,4]/')::s3).* from s3;

-- select influx_min(*) (stub agg function, explain)
--Testcase 556:
EXPLAIN VERBOSE
SELECT influx_min_all(*) from s3;

-- select influx_min(*) (stub agg function, result)
--Testcase 557:
SELECT influx_min_all(*) from s3;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 558:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 559:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_min(*) (stub agg function and group by tag only) (explain)
--Testcase 560:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_min(*) (stub agg function and group by tag only) (result)
--Testcase 561:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_min(*) (stub agg function, expose data, explain)
--Testcase 562:
EXPLAIN VERBOSE
SELECT (influx_min_all(*)::s3).* from s3;

-- select influx_min(*) (stub agg function, expose data, result)
--Testcase 563:
SELECT (influx_min_all(*)::s3).* from s3;

-- select influx_min(regex) (stub function, explain)
--Testcase 564:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') from s3;

-- select influx_min(regex) (stub function, result)
--Testcase 565:
SELECT influx_min('/value[1,4]/') from s3;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 566:
EXPLAIN VERBOSE
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 567:
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select influx_min(regex) (stub agg function and group by tag only) (explain)
--Testcase 568:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_min(regex) (stub agg function and group by tag only) (result)
--Testcase 569:
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select influx_min(regex) (stub agg function, expose data, explain)
--Testcase 570:
EXPLAIN VERBOSE
SELECT (influx_min('/value[1,4]/')::s3).* from s3;

-- select influx_min(regex) (stub agg function, expose data, result)
--Testcase 571:
SELECT (influx_min('/value[1,4]/')::s3).* from s3;

-- selector function percentile() (explain)
--Testcase 572:
EXPLAIN VERBOSE
SELECT percentile((fields->>'value1')::float, 50), percentile((fields->>'value2')::bigint, 60), percentile((fields->>'value3')::float, 25), percentile((fields->>'value4')::bigint, 33) FROM s3;

-- selector function percentile() (result)
--Testcase 573:
SELECT percentile((fields->>'value1')::float, 50), percentile((fields->>'value2')::bigint, 60), percentile((fields->>'value3')::float, 25), percentile((fields->>'value4')::bigint, 33) FROM s3;

-- selector function percentile() (explain)
--Testcase 574:
EXPLAIN VERBOSE
SELECT percentile((fields->>'value1')::float, 1.5), percentile((fields->>'value2')::bigint, 6.7), percentile((fields->>'value3')::float, 20.5), percentile((fields->>'value4')::bigint, 75.2) FROM s3;

-- selector function percentile() (result)
--Testcase 575:
SELECT percentile((fields->>'value1')::float, 1.5), percentile((fields->>'value2')::bigint, 6.7), percentile((fields->>'value3')::float, 20.5), percentile((fields->>'value4')::bigint, 75.2) FROM s3;

-- select percentile(*, int) (stub agg function, explain)
--Testcase 576:
EXPLAIN VERBOSE
SELECT percentile_all(50) from s3;

-- select percentile(*, int) (stub agg function, result)
--Testcase 577:
SELECT percentile_all(50) from s3;

-- select percentile(*, float8) (stub agg function, explain)
--Testcase 578:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) from s3;

-- select percentile(*, float8) (stub agg function, result)
--Testcase 579:
SELECT percentile_all(70.5) from s3;

-- select percentile(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 580:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 581:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(*, float8) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 582:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(*, float8) (stub agg function and group by influx_time() and tag) (result)
--Testcase 583:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(*, int) (stub agg function and group by tag only) (explain)
--Testcase 584:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(*, int) (stub agg function and group by tag only) (result)
--Testcase 585:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(*, float8) (stub agg function and group by tag only) (explain)
--Testcase 586:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(*, float8) (stub agg function and group by tag only) (result)
--Testcase 587:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(*, int) (stub agg function, expose data, explain)
--Testcase 588:
EXPLAIN VERBOSE
SELECT (percentile_all(50)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, result)
--Testcase 589:
SELECT (percentile_all(50)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, explain)
--Testcase 590:
EXPLAIN VERBOSE
SELECT (percentile_all(70.5)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, result)
--Testcase 591:
SELECT (percentile_all(70.5)::s3).* from s3;

-- select percentile(regex) (stub function, explain)
--Testcase 592:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 50) from s3;

-- select percentile(regex) (stub function, result)
--Testcase 593:
SELECT percentile('/value[1,4]/', 50) from s3;

-- select percentile(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 595:
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select percentile(regex) (stub agg function and group by tag only) (explain)
--Testcase 596:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(regex) (stub agg function and group by tag only) (result)
--Testcase 597:
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select percentile(regex) (stub agg function, expose data, explain)
--Testcase 598:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, result)
--Testcase 599:
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, explain)
--Testcase 600:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, result)
--Testcase 601:
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3;

-- selector function top(field_key,N) (explain)
--Testcase 602:
EXPLAIN VERBOSE
SELECT top((fields->>'value1')::float, 1) FROM s3;

-- selector function top(field_key,N) (result)
--Testcase 603:
SELECT top((fields->>'value1')::float, 1) FROM s3;

-- selector function top(field_key,tag_key(s),N) (explain)
--Testcase 604:
EXPLAIN VERBOSE
SELECT top((fields->>'value1')::float, tags->>'tag1', 1) FROM s3;

-- selector function top(field_key,tag_key(s),N) (result)
--Testcase 605:
SELECT top((fields->>'value1')::float, tags->>'tag1', 1) FROM s3;

-- selector function top() cannot be combined with other functions(explain)
--Testcase 606:
EXPLAIN VERBOSE
SELECT top((fields->>'value1')::float, 1), top((fields->>'value2')::bigint, 1), top((fields->>'value3')::float, 1), top((fields->>'value4')::bigint, 1) FROM s3;

-- selector function top() cannot be combined with other functions(result)
--Testcase 607:
SELECT top((fields->>'value1')::float, 1), top((fields->>'value2')::bigint, 1), top((fields->>'value3')::float, 1), top((fields->>'value4')::bigint, 1) FROM s3;

-- select acos (builtin function, explain)
--Testcase 608:
EXPLAIN VERBOSE
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3;

-- select acos (builtin function, result)
--Testcase 609:
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 610:
EXPLAIN VERBOSE
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) = '64';

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 611:
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) = '64';

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 612:
EXPLAIN VERBOSE
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 613:
SELECT acos((fields->>'value1')::float), acos((fields->>'value3')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos as nest function with agg (pushdown, explain)
--Testcase 614:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float), acos(sum((fields->>'value3')::float)) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos as nest function with agg (pushdown, result)
--Testcase 615:
SELECT sum((fields->>'value3')::float), acos(sum((fields->>'value3')::float)) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 616:
EXPLAIN VERBOSE
SELECT acos(log2((fields->>'value1')::float)),acos(log2(1/(fields->>'value1')::float)) FROM s3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 617:
SELECT acos(log2((fields->>'value1')::float)),acos(log2(1/(fields->>'value1')::float)) FROM s3;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 618:
EXPLAIN VERBOSE
SELECT acos((fields->>'value3')::float), pi(), 4.1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 619:
SELECT acos((fields->>'value3')::float), pi(), 4.1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos with order by (explain)
--Testcase 620:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, acos(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY acos(1-(fields->>'value1')::float);

-- select acos with order by (result)
--Testcase 621:
SELECT (fields->>'value1')::float value1, acos(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY acos(1-(fields->>'value1')::float);

-- select acos with order by index (result)
--Testcase 622:
SELECT (fields->>'value1')::float value1, acos(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 623:
SELECT (fields->>'value1')::float value1, acos(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY 1,2;

-- select acos and as
--Testcase 624:
SELECT acos((fields->>'value3')::float) as acos1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select acos(*) (stub agg function, explain)
--Testcase 625:
EXPLAIN VERBOSE
SELECT acos_all() from s3;

-- select acos(*) (stub agg function, result)
--Testcase 626:
SELECT acos_all() from s3;

-- select acos(*) (stub agg function and group by tag only) (explain)
--Testcase 627:
EXPLAIN VERBOSE
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select acos(*) (stub agg function and group by tag only) (result)
--Testcase 628:
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select acos(*) (stub agg function, expose data, explain)
--Testcase 629:
EXPLAIN VERBOSE
SELECT (acos_all()::s3).* from s3;

-- select acos(*) (stub agg function, expose data, result)
--Testcase 630:
SELECT (acos_all()::s3).* from s3;

-- select asin (builtin function, explain)
--Testcase 631:
EXPLAIN VERBOSE
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3;

-- select asin (builtin function, result)
--Testcase 632:
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 633:
EXPLAIN VERBOSE
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) = '64';

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 634:
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) = '64';

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 635:
EXPLAIN VERBOSE
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 636:
SELECT asin((fields->>'value1')::float), asin((fields->>'value3')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin as nest function with agg (pushdown, explain)
--Testcase 637:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float), asin(sum((fields->>'value3')::float)) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin as nest function with agg (pushdown, result)
--Testcase 638:
SELECT sum((fields->>'value3')::float), asin(sum((fields->>'value3')::float)) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 639:
EXPLAIN VERBOSE
SELECT asin(log2((fields->>'value1')::float)),asin(log2(1/(fields->>'value1')::float)) FROM s3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 640:
SELECT asin(log2((fields->>'value1')::float)),asin(log2(1/(fields->>'value1')::float)) FROM s3;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 641:
EXPLAIN VERBOSE
SELECT asin((fields->>'value3')::float), pi(), 4.1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 642:
SELECT asin((fields->>'value3')::float), pi(), 4.1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin with order by (explain)
--Testcase 643:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, asin(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY asin(1-(fields->>'value1')::float);

-- select asin with order by (result)
--Testcase 644:
SELECT (fields->>'value1')::float value1, asin(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY asin(1-(fields->>'value1')::float);

-- select asin with order by index (result)
--Testcase 645:
SELECT (fields->>'value1')::float value1, asin(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 646:
SELECT (fields->>'value1')::float value1, asin(1-(fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200 ORDER BY 1,2;

-- select asin and as
--Testcase 647:
SELECT asin((fields->>'value3')::float) as asin1 FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select asin(*) (stub agg function, explain)
--Testcase 648:
EXPLAIN VERBOSE
SELECT asin_all() from s3;

-- select asin(*) (stub agg function, result)
--Testcase 649:
SELECT asin_all() from s3;

-- select asin(*) (stub agg function and group by tag only) (explain)
--Testcase 650:
EXPLAIN VERBOSE
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select asin(*) (stub agg function and group by tag only) (result)
--Testcase 651:
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select asin(*) (stub agg function, expose data, explain)
--Testcase 652:
EXPLAIN VERBOSE
SELECT (asin_all()::s3).* from s3;

-- select asin(*) (stub agg function, expose data, result)
--Testcase 653:
SELECT (asin_all()::s3).* from s3;

-- select atan (builtin function, explain)
--Testcase 654:
EXPLAIN VERBOSE
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3;

-- select atan (builtin function, result)
--Testcase 655:
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 656:
EXPLAIN VERBOSE
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 657:
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 658:
EXPLAIN VERBOSE
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 659:
SELECT atan((fields->>'value1')::float), atan((fields->>'value2')::bigint), atan((fields->>'value3')::float), atan((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 660:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),atan(sum((fields->>'value3')::float)) FROM s3;

-- select atan as nest function with agg (pushdown, result)
--Testcase 661:
SELECT sum((fields->>'value3')::float),atan(sum((fields->>'value3')::float)) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 662:
EXPLAIN VERBOSE
SELECT atan(log2((fields->>'value1')::float)),atan(log2(1/(fields->>'value1')::float)) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 663:
SELECT atan(log2((fields->>'value1')::float)),atan(log2(1/(fields->>'value1')::float)) FROM s3;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 664:
EXPLAIN VERBOSE
SELECT atan((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 665:
SELECT atan((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select atan with order by (explain)
--Testcase 666:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, atan(1-(fields->>'value1')::float) FROM s3 order by atan(1-(fields->>'value1')::float);

-- select atan with order by (result)
--Testcase 667:
SELECT (fields->>'value1')::float value1, atan(1-(fields->>'value1')::float) FROM s3 order by atan(1-(fields->>'value1')::float);

-- select atan with order by index (result)
--Testcase 668:
SELECT (fields->>'value1')::float value1, atan(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select atan with order by index (result)
--Testcase 669:
SELECT (fields->>'value1')::float value1, atan(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select atan and as
--Testcase 670:
SELECT atan((fields->>'value3')::float) as atan1 FROM s3;

-- select atan(*) (stub agg function, explain)
--Testcase 671:
EXPLAIN VERBOSE
SELECT atan_all() from s3;

-- select atan(*) (stub agg function, result)
--Testcase 672:
SELECT atan_all() from s3;

-- select atan(*) (stub agg function and group by tag only) (explain)
--Testcase 673:
EXPLAIN VERBOSE
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select atan(*) (stub agg function and group by tag only) (result)
--Testcase 674:
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select atan(*) (stub agg function, expose data, explain)
--Testcase 675:
EXPLAIN VERBOSE
SELECT (atan_all()::s3).* from s3;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 676:
SELECT asin_all(), acos_all(), atan_all() FROM s3;

-- select atan2 (builtin function, explain)
--Testcase 677:
EXPLAIN VERBOSE
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3;

-- select atan2 (builtin function, result)
--Testcase 678:
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 679:
EXPLAIN VERBOSE
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 680:
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 681:
EXPLAIN VERBOSE
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 682:
SELECT atan2((fields->>'value1')::float, (fields->>'value2')::bigint), atan2((fields->>'value2')::bigint, (fields->>'value3')::float), atan2((fields->>'value3')::float, (fields->>'value4')::bigint), atan2((fields->>'value4')::bigint, (fields->>'value1')::float) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 683:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float), sum((fields->>'value4')::bigint),atan2(sum((fields->>'value3')::float), sum((fields->>'value3')::float)) FROM s3;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 684:
SELECT sum((fields->>'value3')::float), sum((fields->>'value4')::bigint),atan2(sum((fields->>'value3')::float), sum((fields->>'value3')::float)) FROM s3;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 685:
EXPLAIN VERBOSE
SELECT atan2(log2((fields->>'value1')::float), log2((fields->>'value1')::float)),atan2(log2(1/(fields->>'value1')::float), log2(1/(fields->>'value1')::float)) FROM s3;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 686:
SELECT atan2(log2((fields->>'value1')::float), log2((fields->>'value1')::float)),atan2(log2(1/(fields->>'value1')::float), log2(1/(fields->>'value1')::float)) FROM s3;

-- select atan2 with non pushdown func and explicit constant (explain)
--Testcase 687:
EXPLAIN VERBOSE
SELECT atan2((fields->>'value3')::float, (fields->>'value4')::bigint), pi(), 4.1 FROM s3;

-- select atan2 with non pushdown func and explicit constant (result)
--Testcase 688:
SELECT atan2((fields->>'value3')::float, (fields->>'value4')::bigint), pi(), 4.1 FROM s3;

-- select atan2 with order by (explain)
--Testcase 689:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint) FROM s3 order by atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint);

-- select atan2 with order by (result)
--Testcase 690:
SELECT (fields->>'value1')::float value1, atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint) FROM s3 order by atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint);

-- select atan2 with order by index (result)
--Testcase 691:
SELECT (fields->>'value1')::float value1, atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint) FROM s3 order by 2,1;

-- select atan2 with order by index (result)
--Testcase 692:
SELECT (fields->>'value1')::float value1, atan2(1-(fields->>'value1')::float, 1-(fields->>'value2')::bigint) FROM s3 order by 1,2;

-- select atan2 and as
--Testcase 693:
SELECT atan2((fields->>'value3')::float, (fields->>'value4')::bigint) as atan21 FROM s3;

-- select atan2(*) (stub function, explain)
--Testcase 694:
EXPLAIN VERBOSE
SELECT atan2_all((fields->>'value1')::float) from s3;

-- select atan2(*) (stub function, result)
--Testcase 695:
SELECT atan2_all((fields->>'value1')::float) from s3;

-- select ceil (builtin function, explain)
--Testcase 696:
EXPLAIN VERBOSE
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3;

-- select ceil (builtin function, result)
--Testcase 697:
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 698:
EXPLAIN VERBOSE
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 699:
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 700:
EXPLAIN VERBOSE
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 701:
SELECT ceil((fields->>'value1')::float), ceil((fields->>'value2')::bigint), ceil((fields->>'value3')::float), ceil((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 702:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),ceil(sum((fields->>'value3')::float)) FROM s3;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 703:
SELECT sum((fields->>'value3')::float),ceil(sum((fields->>'value3')::float)) FROM s3;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 704:
EXPLAIN VERBOSE
SELECT ceil(log2((fields->>'value1')::float)),ceil(log2(1/(fields->>'value1')::float)) FROM s3;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 705:
SELECT ceil(log2((fields->>'value1')::float)),ceil(log2(1/(fields->>'value1')::float)) FROM s3;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 706:
EXPLAIN VERBOSE
SELECT ceil((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 707:
SELECT ceil((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select ceil with order by (explain)
--Testcase 708:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, ceil(1-(fields->>'value1')::float) FROM s3 order by ceil(1-(fields->>'value1')::float);

-- select ceil with order by (result)
--Testcase 709:
SELECT (fields->>'value1')::float value1, ceil(1-(fields->>'value1')::float) FROM s3 order by ceil(1-(fields->>'value1')::float);

-- select ceil with order by index (result)
--Testcase 710:
SELECT (fields->>'value1')::float value1, ceil(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select ceil with order by index (result)
--Testcase 711:
SELECT (fields->>'value1')::float value1, ceil(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select ceil and as
--Testcase 712:
SELECT ceil((fields->>'value3')::float) as ceil1 FROM s3;

-- select ceil(*) (stub agg function, explain)
--Testcase 713:
EXPLAIN VERBOSE
SELECT ceil_all() from s3;

-- select ceil(*) (stub agg function, result)
--Testcase 714:
SELECT ceil_all() from s3;

-- select ceil(*) (stub agg function and group by tag only) (explain)
--Testcase 715:
EXPLAIN VERBOSE
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select ceil(*) (stub agg function and group by tag only) (result)
--Testcase 716:
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select ceil(*) (stub agg function, expose data, explain)
--Testcase 717:
EXPLAIN VERBOSE
SELECT (ceil_all()::s3).* from s3;

-- select ceil(*) (stub agg function, expose data, result)
--Testcase 718:
SELECT (ceil_all()::s3).* from s3;

-- select cos (builtin function, explain)
--Testcase 719:
EXPLAIN VERBOSE
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3;

-- select cos (builtin function, result)
--Testcase 720:
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 721:
EXPLAIN VERBOSE
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 722:
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 723:
EXPLAIN VERBOSE
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 724:
SELECT cos((fields->>'value1')::float), cos((fields->>'value2')::bigint), cos((fields->>'value3')::float), cos((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 725:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),cos(sum((fields->>'value3')::float)) FROM s3;

-- select cos as nest function with agg (pushdown, result)
--Testcase 726:
SELECT sum((fields->>'value3')::float),cos(sum((fields->>'value3')::float)) FROM s3;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 727:
EXPLAIN VERBOSE
SELECT cos(log2((fields->>'value1')::float)),cos(log2(1/(fields->>'value1')::float)) FROM s3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 728:
SELECT cos(log2((fields->>'value1')::float)),cos(log2(1/(fields->>'value1')::float)) FROM s3;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 729:
EXPLAIN VERBOSE
SELECT cos((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 730:
SELECT cos((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select cos with order by (explain)
--Testcase 731:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, cos(1-(fields->>'value1')::float) FROM s3 order by cos(1-(fields->>'value1')::float);

-- select cos with order by (result)
--Testcase 732:
SELECT (fields->>'value1')::float value1, cos(1-(fields->>'value1')::float) FROM s3 order by cos(1-(fields->>'value1')::float);

-- select cos with order by index (result)
--Testcase 733:
SELECT (fields->>'value1')::float value1, cos(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select cos with order by index (result)
--Testcase 734:
SELECT (fields->>'value1')::float value1, cos(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select cos and as
--Testcase 735:
SELECT cos((fields->>'value3')::float) as cos1 FROM s3;

-- select cos(*) (stub agg function, explain)
--Testcase 736:
EXPLAIN VERBOSE
SELECT cos_all() from s3;

-- select cos(*) (stub agg function, result)
--Testcase 737:
SELECT cos_all() from s3;

-- select cos(*) (stub agg function and group by tag only) (explain)
--Testcase 738:
EXPLAIN VERBOSE
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select cos(*) (stub agg function and group by tag only) (result)
--Testcase 739:
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select exp (builtin function, explain)
--Testcase 740:
EXPLAIN VERBOSE
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3;

-- select exp (builtin function, result)
--Testcase 741:
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 742:
EXPLAIN VERBOSE
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 743:
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 744:
EXPLAIN VERBOSE
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 745:
SELECT exp((fields->>'value1')::float), exp((fields->>'value2')::bigint), exp((fields->>'value3')::float), exp((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 746:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),exp(sum((fields->>'value3')::float)) FROM s3;

-- select exp as nest function with agg (pushdown, result)
--Testcase 747:
SELECT sum((fields->>'value3')::float),exp(sum((fields->>'value3')::float)) FROM s3;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 748:
EXPLAIN VERBOSE
SELECT exp(log2((fields->>'value1')::float)),exp(log2(1/(fields->>'value1')::float)) FROM s3;

-- select exp as nest with log2 (pushdown, result)
--Testcase 749:
SELECT exp(log2((fields->>'value1')::float)),exp(log2(1/(fields->>'value1')::float)) FROM s3;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 750:
EXPLAIN VERBOSE
SELECT exp((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 751:
SELECT exp((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select exp with order by (explain)
--Testcase 752:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, exp(1-(fields->>'value1')::float) FROM s3 order by exp(1-(fields->>'value1')::float);

-- select exp with order by (result)
--Testcase 753:
SELECT (fields->>'value1')::float value1, exp(1-(fields->>'value1')::float) FROM s3 order by exp(1-(fields->>'value1')::float);

-- select exp with order by index (result)
--Testcase 754:
SELECT (fields->>'value1')::float value1, exp(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select exp with order by index (result)
--Testcase 755:
SELECT (fields->>'value1')::float value1, exp(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select exp and as
--Testcase 756:
SELECT exp((fields->>'value3')::float) as exp1 FROM s3;

-- select exp(*) (stub agg function, explain)
--Testcase 757:
EXPLAIN VERBOSE
SELECT exp_all() from s3;

-- select exp(*) (stub agg function, result)
--Testcase 758:
SELECT exp_all() from s3;

-- select exp(*) (stub agg function and group by tag only) (explain)
--Testcase 759:
EXPLAIN VERBOSE
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select exp(*) (stub agg function and group by tag only) (result)
--Testcase 760:
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 761:
SELECT ceil_all(), cos_all(), exp_all() FROM s3;

-- select floor (builtin function, explain)
--Testcase 762:
EXPLAIN VERBOSE
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3;

-- select floor (builtin function, result)
--Testcase 763:
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 764:
EXPLAIN VERBOSE
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 765:
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 766:
EXPLAIN VERBOSE
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 767:
SELECT floor((fields->>'value1')::float), floor((fields->>'value2')::bigint), floor((fields->>'value3')::float), floor((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 768:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),floor(sum((fields->>'value3')::float)) FROM s3;

-- select floor as nest function with agg (pushdown, result)
--Testcase 769:
SELECT sum((fields->>'value3')::float),floor(sum((fields->>'value3')::float)) FROM s3;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 770:
EXPLAIN VERBOSE
SELECT floor(log2((fields->>'value1')::float)),floor(log2(1/(fields->>'value1')::float)) FROM s3;

-- select floor as nest with log2 (pushdown, result)
--Testcase 771:
SELECT floor(log2((fields->>'value1')::float)),floor(log2(1/(fields->>'value1')::float)) FROM s3;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 772:
EXPLAIN VERBOSE
SELECT floor((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 773:
SELECT floor((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select floor with order by (explain)
--Testcase 774:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, floor(1-(fields->>'value1')::float) FROM s3 order by floor(1-(fields->>'value1')::float);

-- select floor with order by (result)
--Testcase 775:
SELECT (fields->>'value1')::float value1, floor(1-(fields->>'value1')::float) FROM s3 order by floor(1-(fields->>'value1')::float);

-- select floor with order by index (result)
--Testcase 776:
SELECT (fields->>'value1')::float value1, floor(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select floor with order by index (result)
--Testcase 777:
SELECT (fields->>'value1')::float value1, floor(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select floor and as
--Testcase 778:
SELECT floor((fields->>'value3')::float) as floor1 FROM s3;

-- select floor(*) (stub agg function, explain)
--Testcase 779:
EXPLAIN VERBOSE
SELECT floor_all() from s3;

-- select floor(*) (stub agg function, result)
--Testcase 780:
SELECT floor_all() from s3;

-- select floor(*) (stub agg function and group by tag only) (explain)
--Testcase 781:
EXPLAIN VERBOSE
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select floor(*) (stub agg function and group by tag only) (result)
--Testcase 782:
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select floor(*) (stub agg function, expose data, explain)
--Testcase 783:
EXPLAIN VERBOSE
SELECT (floor_all()::s3).* from s3;

-- select floor(*) (stub agg function, expose data, result)
--Testcase 784:
SELECT (floor_all()::s3).* from s3;

-- select ln (builtin function, explain)
--Testcase 785:
EXPLAIN VERBOSE
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3;

-- select ln (builtin function, result)
--Testcase 786:
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 787:
EXPLAIN VERBOSE
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 788:
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 789:
EXPLAIN VERBOSE
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 790:
SELECT ln((fields->>'value1')::float), ln((fields->>'value2')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 791:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),ln(sum((fields->>'value3')::float)) FROM s3;

-- select ln as nest function with agg (pushdown, result)
--Testcase 792:
SELECT sum((fields->>'value3')::float),ln(sum((fields->>'value3')::float)) FROM s3;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 793:
EXPLAIN VERBOSE
SELECT ln(log2((fields->>'value1')::float)),ln(log2(1/(fields->>'value1')::float)) FROM s3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 794:
SELECT ln(log2((fields->>'value1')::float)),ln(log2(1/(fields->>'value1')::float)) FROM s3;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 795:
EXPLAIN VERBOSE
SELECT ln((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 796:
SELECT ln((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select ln with order by (explain)
--Testcase 797:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, ln(1-(fields->>'value1')::float) FROM s3 order by ln(1-(fields->>'value1')::float);

-- select ln with order by (result)
--Testcase 798:
SELECT (fields->>'value1')::float value1, ln(1-(fields->>'value1')::float) FROM s3 order by ln(1-(fields->>'value1')::float);

-- select ln with order by index (result)
--Testcase 799:
SELECT (fields->>'value1')::float value1, ln(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select ln with order by index (result)
--Testcase 800:
SELECT (fields->>'value1')::float value1, ln(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select ln and as
--Testcase 801:
SELECT ln((fields->>'value1')::float) as ln1 FROM s3;

-- select ln(*) (stub agg function, explain)
--Testcase 802:
EXPLAIN VERBOSE
SELECT ln_all() from s3;

-- select ln(*) (stub agg function, result)
--Testcase 803:
SELECT ln_all() from s3;

-- select ln(*) (stub agg function and group by tag only) (explain)
--Testcase 804:
EXPLAIN VERBOSE
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select ln(*) (stub agg function and group by tag only) (result)
--Testcase 805:
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 806:
SELECT ln_all(), floor_all() FROM s3;

-- select pow (builtin function, explain)
--Testcase 807:
EXPLAIN VERBOSE
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3;

-- select pow (builtin function, result)
--Testcase 808:
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 809:
EXPLAIN VERBOSE
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 810:
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 811:
EXPLAIN VERBOSE
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 812:
SELECT pow((fields->>'value1')::float, 2), pow((fields->>'value2')::bigint, 2), pow((fields->>'value3')::float, 2), pow((fields->>'value4')::bigint, 2) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 813:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),pow(sum((fields->>'value3')::float), 2) FROM s3;

-- select pow as nest function with agg (pushdown, result)
--Testcase 814:
SELECT sum((fields->>'value3')::float),pow(sum((fields->>'value3')::float), 2) FROM s3;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 815:
EXPLAIN VERBOSE
SELECT pow(log2((fields->>'value1')::float), 2),pow(log2(1/(fields->>'value1')::float), 2) FROM s3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 816:
SELECT pow(log2((fields->>'value1')::float), 2),pow(log2(1/(fields->>'value1')::float), 2) FROM s3;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 817:
EXPLAIN VERBOSE
SELECT pow((fields->>'value3')::float, 2), pi(), 4.1 FROM s3;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 818:
SELECT pow((fields->>'value3')::float, 2), pi(), 4.1 FROM s3;

-- select pow with order by (explain)
--Testcase 819:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, pow(1-(fields->>'value1')::float, 2) FROM s3 order by pow(1-(fields->>'value1')::float, 2);

-- select pow with order by (result)
--Testcase 820:
SELECT (fields->>'value1')::float value1, pow(1-(fields->>'value1')::float, 2) FROM s3 order by pow(1-(fields->>'value1')::float, 2);

-- select pow with order by index (result)
--Testcase 821:
SELECT (fields->>'value1')::float value1, pow(1-(fields->>'value1')::float, 2) FROM s3 order by 2,1;

-- select pow with order by index (result)
--Testcase 822:
SELECT (fields->>'value1')::float value1, pow(1-(fields->>'value1')::float, 2) FROM s3 order by 1,2;

-- select pow and as
--Testcase 823:
SELECT pow((fields->>'value3')::float, 2) as pow1 FROM s3;

-- select pow_all(2) (stub agg function, explain)
--Testcase 824:
EXPLAIN VERBOSE
SELECT pow_all(2) from s3;

-- select pow_all(2) (stub agg function, result)
--Testcase 825:
SELECT pow_all(2) from s3;

-- select pow_all(2) (stub agg function and group by tag only) (explain)
--Testcase 826:
EXPLAIN VERBOSE
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select pow_all(2) (stub agg function and group by tag only) (result)
--Testcase 827:
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select pow_all(2) (stub agg function, expose data, explain)
--Testcase 828:
EXPLAIN VERBOSE
SELECT (pow_all(2)::s3).* from s3;

-- select pow_all(2) (stub agg function, expose data, result)
--Testcase 829:
SELECT (pow_all(2)::s3).* from s3;

-- select round (builtin function, explain)
--Testcase 830:
EXPLAIN VERBOSE
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3;

-- select round (builtin function, result)
--Testcase 831:
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 832:
EXPLAIN VERBOSE
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select round (builtin function, not pushdown constraints, result)
--Testcase 833:
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select round (builtin function, pushdown constraints, explain)
--Testcase 834:
EXPLAIN VERBOSE
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select round (builtin function, pushdown constraints, result)
--Testcase 835:
SELECT round((fields->>'value1')::float), round((fields->>'value2')::bigint), round((fields->>'value3')::float), round((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select round as nest function with agg (pushdown, explain)
--Testcase 836:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),round(sum((fields->>'value3')::float)) FROM s3;

-- select round as nest function with agg (pushdown, result)
--Testcase 837:
SELECT sum((fields->>'value3')::float),round(sum((fields->>'value3')::float)) FROM s3;

-- select round as nest with log2 (pushdown, explain)
--Testcase 838:
EXPLAIN VERBOSE
SELECT round(log2((fields->>'value1')::float)),round(log2(1/(fields->>'value1')::float)) FROM s3;

-- select round as nest with log2 (pushdown, result)
--Testcase 839:
SELECT round(log2((fields->>'value1')::float)),round(log2(1/(fields->>'value1')::float)) FROM s3;

-- select round with non pushdown func and roundlicit constant (explain)
--Testcase 840:
EXPLAIN VERBOSE
SELECT round((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select round with non pushdown func and roundlicit constant (result)
--Testcase 841:
SELECT round((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select round with order by (explain)
--Testcase 842:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, round(1-(fields->>'value1')::float) FROM s3 order by round(1-(fields->>'value1')::float);

-- select round with order by (result)
--Testcase 843:
SELECT (fields->>'value1')::float value1, round(1-(fields->>'value1')::float) FROM s3 order by round(1-(fields->>'value1')::float);

-- select round with order by index (result)
--Testcase 844:
SELECT (fields->>'value1')::float value1, round(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select round with order by index (result)
--Testcase 845:
SELECT (fields->>'value1')::float value1, round(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select round and as
--Testcase 846:
SELECT round((fields->>'value3')::float) as round1 FROM s3;

-- select round(*) (stub agg function, explain)
--Testcase 847:
EXPLAIN VERBOSE
SELECT round_all() from s3;

-- select round(*) (stub agg function, result)
--Testcase 848:
SELECT round_all() from s3;

-- select round(*) (stub agg function and group by tag only) (explain)
--Testcase 849:
EXPLAIN VERBOSE
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select round(*) (stub agg function and group by tag only) (result)
--Testcase 850:
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select round(*) (stub agg function, expose data, explain)
--Testcase 851:
EXPLAIN VERBOSE
SELECT (round_all()::s3).* from s3;

-- select round(*) (stub agg function, expose data, result)
--Testcase 852:
SELECT (round_all()::s3).* from s3;

-- select sin (builtin function, explain)
--Testcase 853:
EXPLAIN VERBOSE
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3;

-- select sin (builtin function, result)
--Testcase 854:
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 855:
EXPLAIN VERBOSE
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 856:
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 857:
EXPLAIN VERBOSE
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 858:
SELECT sin((fields->>'value1')::float), sin((fields->>'value2')::bigint), sin((fields->>'value3')::float), sin((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 859:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),sin(sum((fields->>'value3')::float)) FROM s3;

-- select sin as nest function with agg (pushdown, result)
--Testcase 860:
SELECT sum((fields->>'value3')::float),sin(sum((fields->>'value3')::float)) FROM s3;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 861:
EXPLAIN VERBOSE
SELECT sin(log2((fields->>'value1')::float)),sin(log2(1/(fields->>'value1')::float)) FROM s3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 862:
SELECT sin(log2((fields->>'value1')::float)),sin(log2(1/(fields->>'value1')::float)) FROM s3;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 863:
EXPLAIN VERBOSE
SELECT sin((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 864:
SELECT sin((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select sin with order by (explain)
--Testcase 865:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, sin(1-(fields->>'value1')::float) FROM s3 order by sin(1-(fields->>'value1')::float);

-- select sin with order by (result)
--Testcase 866:
SELECT (fields->>'value1')::float value1, sin(1-(fields->>'value1')::float) FROM s3 order by sin(1-(fields->>'value1')::float);

-- select sin with order by index (result)
--Testcase 867:
SELECT (fields->>'value1')::float value1, sin(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select sin with order by index (result)
--Testcase 868:
SELECT (fields->>'value1')::float value1, sin(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select sin and as
--Testcase 869:
SELECT sin((fields->>'value3')::float) as sin1 FROM s3;

-- select sin(*) (stub agg function, explain)
--Testcase 870:
EXPLAIN VERBOSE
SELECT sin_all() from s3;

-- select sin(*) (stub agg function, result)
--Testcase 871:
SELECT sin_all() from s3;

-- select sin(*) (stub agg function and group by tag only) (explain)
--Testcase 872:
EXPLAIN VERBOSE
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select sin(*) (stub agg function and group by tag only) (result)
--Testcase 873:
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select tan (builtin function, explain)
--Testcase 874:
EXPLAIN VERBOSE
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3;

-- select tan (builtin function, result)
--Testcase 875:
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 876:
EXPLAIN VERBOSE
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 877:
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3 WHERE to_hex((fields->>'value2')::bigint) != '64';

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 878:
EXPLAIN VERBOSE
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 879:
SELECT tan((fields->>'value1')::float), tan((fields->>'value2')::bigint), tan((fields->>'value3')::float), tan((fields->>'value4')::bigint) FROM s3 WHERE (fields->>'value2')::bigint != 200;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 880:
EXPLAIN VERBOSE
SELECT sum((fields->>'value3')::float),tan(sum((fields->>'value3')::float)) FROM s3;

-- select tan as nest function with agg (pushdown, result)
--Testcase 881:
SELECT sum((fields->>'value3')::float),tan(sum((fields->>'value3')::float)) FROM s3;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 882:
EXPLAIN VERBOSE
SELECT tan(log2((fields->>'value1')::float)),tan(log2(1/(fields->>'value1')::float)) FROM s3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 883:
SELECT tan(log2((fields->>'value1')::float)),tan(log2(1/(fields->>'value1')::float)) FROM s3;

-- select tan with non pushdown func and tanlicit constant (explain)
--Testcase 884:
EXPLAIN VERBOSE
SELECT tan((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select tan with non pushdown func and tanlicit constant (result)
--Testcase 885:
SELECT tan((fields->>'value3')::float), pi(), 4.1 FROM s3;

-- select tan with order by (explain)
--Testcase 886:
EXPLAIN VERBOSE
SELECT (fields->>'value1')::float value1, tan(1-(fields->>'value1')::float) FROM s3 order by tan(1-(fields->>'value1')::float);

-- select tan with order by (result)
--Testcase 887:
SELECT (fields->>'value1')::float value1, tan(1-(fields->>'value1')::float) FROM s3 order by tan(1-(fields->>'value1')::float);

-- select tan with order by index (result)
--Testcase 888:
SELECT (fields->>'value1')::float value1, tan(1-(fields->>'value1')::float) FROM s3 order by 2,1;

-- select tan with order by index (result)
--Testcase 889:
SELECT (fields->>'value1')::float value1, tan(1-(fields->>'value1')::float) FROM s3 order by 1,2;

-- select tan and as
--Testcase 890:
SELECT tan((fields->>'value3')::float) as tan1 FROM s3;

-- select tan(*) (stub agg function, explain)
--Testcase 891:
EXPLAIN VERBOSE
SELECT tan_all() from s3;

-- select tan(*) (stub agg function, result)
--Testcase 892:
SELECT tan_all() from s3;

-- select tan(*) (stub agg function and group by tag only) (explain)
--Testcase 893:
EXPLAIN VERBOSE
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select tan(*) (stub agg function and group by tag only) (result)
--Testcase 894:
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 895:
SELECT sin_all(), round_all(), tan_all() FROM s3;

-- select predictors function holt_winters() (explain)
--Testcase 896:
EXPLAIN VERBOSE
SELECT holt_winters(min((fields->>'value1')::float), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters() (result)
--Testcase 897:
SELECT holt_winters(min((fields->>'value1')::float), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters_with_fit() (explain)
--Testcase 898:
EXPLAIN VERBOSE
SELECT holt_winters_with_fit(min((fields->>'value1')::float), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters_with_fit() (result)
--Testcase 899:
SELECT holt_winters_with_fit(min((fields->>'value1')::float), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select count(*) function of InfluxDB (stub agg function, explain)
--Testcase 900:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3;

-- select count(*) function of InfluxDB (stub agg function, result)
--Testcase 901:
SELECT influx_count_all(*) FROM s3;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (explain)
--Testcase 902:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (result)
--Testcase 903:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (explain)
--Testcase 904:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (result)
--Testcase 905:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select count(*) function of InfluxDB over join query (explain)
--Testcase 906:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select count(*) function of InfluxDB over join query (result, stub call error)
--Testcase 907:
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select distinct (stub agg function, explain)
--Testcase 908:
EXPLAIN VERBOSE
SELECT influx_distinct((fields->>'value1')::float) FROM s3;

-- select distinct (stub agg function, result)
--Testcase 909:
SELECT influx_distinct((fields->>'value1')::float) FROM s3;

-- select distinct (stub agg function and group by influx_time() and tag) (explain)
--Testcase 910:
EXPLAIN VERBOSE
SELECT influx_distinct((fields->>'value1')::float), influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select distinct (stub agg function and group by influx_time() and tag) (result)
--Testcase 911:
SELECT influx_distinct((fields->>'value1')::float), influx_time(time, interval '1s'),tags->>'tag1' tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tags->>'tag1';

-- select distinct (stub agg function and group by tag only) (explain)
--Testcase 912:
EXPLAIN VERBOSE
SELECT influx_distinct((fields->>'value2')::bigint) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select distinct (stub agg function and group by tag only) (result)
--Testcase 913:
SELECT influx_distinct((fields->>'value2')::bigint) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tags->>'tag1';

-- select distinct over join query (explain)
--Testcase 914:
EXPLAIN VERBOSE
SELECT influx_distinct((t1.fields->>'value2')::bigint) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select distinct over join query (result, stub call error)
--Testcase 915:
SELECT influx_distinct((t1.fields->>'value2')::bigint) FROM s3 t1 INNER JOIN s3 t2 ON ((t1.fields->>'value1')::float = (t2.fields->>'value1')::float) where (t1.fields->>'value1')::float = 0.1;

-- select distinct with having (explain)
--Testcase 916:
EXPLAIN VERBOSE
SELECT influx_distinct((fields->>'value2')::bigint) FROM s3 HAVING influx_distinct((fields->>'value2')::bigint) > 100;

-- select distinct with having (result, not pushdown, stub call error)
--Testcase 917:
SELECT influx_distinct((fields->>'value2')::bigint) FROM s3 HAVING influx_distinct((fields->>'value2')::bigint) > 100;

--Testcase 918:
DROP FOREIGN TABLE s3;

--Testcase 919:
CREATE FOREIGN TABLE b3(time timestamp with time zone, tags jsonb OPTIONS (tags 'true'), fields jsonb OPTIONS (fields 'true')) SERVER server1 OPTIONS(table 'b3', tags 'tag1', schemaless 'true');

-- bool type var in where clause (result)
--Testcase 920:
EXPLAIN VERBOSE
SELECT sqrt(abs((fields->>'value1')::float)) FROM b3 WHERE (fields->>'value3')::boolean != true ORDER BY 1;

-- bool type var in where clause (result)
--Testcase 921:
SELECT sqrt(abs((fields->>'value1')::float)) FROM b3 WHERE (fields->>'value3')::boolean != true ORDER BY 1;

--Testcase 922:
DROP FOREIGN TABLE b3;

--Testcase 923:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 924:
DROP SERVER server1;
--Testcase 925:
DROP EXTENSION influxdb_fdw;
