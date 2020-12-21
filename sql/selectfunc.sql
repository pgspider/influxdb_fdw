SET datestyle=ISO;
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 1:
CREATE EXTENSION influxdb_fdw;
--Testcase 2:
CREATE SERVER server1 FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb2', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1 OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');
--Testcase 4:
CREATE FOREIGN TABLE s3(time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 float8, value4 bigint) SERVER server1 OPTIONS(table 's3', tags 'tag1');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 5:
\d s3;
--Testcase 6:
SELECT * FROM s3;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 7:
EXPLAIN VERBOSE
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3;

-- select float8() (not pushdown, remove float8, result)
--Testcase 8:
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3;

-- select sqrt (builtin function, explain)
--Testcase 9:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3;

-- select sqrt (buitin function, result)
--Testcase 10:
SELECT sqrt(value1), sqrt(value2) FROM s3;

-- select sqrt (builtin function,, not pushdown constraints, explain)
--Testcase 11:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64';

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 12:
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE to_hex(value2) != '64';

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 13:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 14:
SELECT sqrt(value1), sqrt(value2) FROM s3 WHERE value2 != 200;

-- select abs (builtin function, explain)
--Testcase 15:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- ABS() returns negative values if integer (https://github.com/influxdata/influxdb/issues/10261)
-- select abs (buitin function, result)
--Testcase 16:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 17:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 18:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 19:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 20:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200;

-- select log (builtin function, need to swap arguments, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), influxdb (v, base)
--Testcase 21:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, numeric cast, result)
--Testcase 22:
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, float8, explain)
--Testcase 23:
EXPLAIN VERBOSE
SELECT log(value1, 0.1) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, float8, result)
--Testcase 24:
SELECT log(value1, 0.1) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, bigint, explain)
--Testcase 25:
EXPLAIN VERBOSE
SELECT log(value2, 3) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, bigint, result)
--Testcase 26:
SELECT log(value2, 3) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, mix type, explain)
--Testcase 27:
EXPLAIN VERBOSE
SELECT log(value1, value2) FROM s3 WHERE value1 != 1;

-- select log (stub function, need to swap arguments, mix type, result)
--Testcase 28:
SELECT log(value1, value2) FROM s3 WHERE value1 != 1;

-- select log2 (stub function, explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT log2(value1),log2(value2) FROM s3;

-- select log2 (stub function, result)
--Testcase 30:
SELECT log2(value1),log2(value2) FROM s3;

-- select spread (stub agg function, explain)
--Testcase 31:
EXPLAIN VERBOSE
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3;

-- select spread (stub agg function, result)
--Testcase 32:
SELECT spread(value1),spread(value2),spread(value3),spread(value4) FROM s3;

-- select spread (stub agg function, raise exception if not expected type)
--Testcase 33:
SELECT spread(value1::numeric),spread(value2::numeric),spread(value3::numeric),spread(value4::numeric) FROM s3;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 34:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest function with agg (pushdown, result)
--Testcase 35:
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 36:
EXPLAIN VERBOSE
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 37:
SELECT abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 38:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 39:
SELECT abs(value3), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 40:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 41:
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 42:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1, tag1 FROM s3;

-- select spread (stub agg function and group by influx_time() and tag) (explain)
--Testcase 43:
EXPLAIN VERBOSE
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread (stub agg function and group by influx_time() and tag) (result)
--Testcase 44:
SELECT spread("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread (stub agg function and group by tag only) (result)
--Testcase 45:
SELECT tag1,spread("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select spread (stub agg function and other aggs) (result)
--Testcase 46:
SELECT sum("value1"),spread("value1"),count("value1") FROM s3;

-- select abs with order by (explain)
--Testcase 47:
EXPLAIN VERBOSE
SELECT value1, abs(1-value1) FROM s3 order by abs(1-value1);

-- select abs with order by (result)
--Testcase 48:
SELECT value1, abs(1-value1) FROM s3 order by abs(1-value1);

-- select abs with order by index (result)
--Testcase 49:
SELECT value1, abs(1-value1) FROM s3 order by 2,1;

-- select abs with order by index (result)
--Testcase 50:
SELECT value1, abs(1-value1) FROM s3 order by 1,2;

-- select abs and as
--Testcase 51:
SELECT abs(value3) as abs1 FROM s3;

-- select spread over join query (explain)
--Testcase 52:
EXPLAIN VERBOSE
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select spread over join query (result, stub call error)
--Testcase 53:
SELECT spread(t1.value1), spread(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select spread with having (explain)
--Testcase 54:
EXPLAIN VERBOSE
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100;

-- select spread with having (explain, cannot pushdown, stub call error)
--Testcase 55:
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 56:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 57:
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3;

-- select with order by limit (explain)
--Testcase 58:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (explain)
--Testcase 59:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 60:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3;

-- select mixing with non pushdown func (result)
--Testcase 61:
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3;

--Testcase 66:
-- nested function in where clause (explain)
EXPLAIN VERBOSE
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

--Testcase 67:
-- nested function in where clause (result)
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

--Testcase 72:
EXPLAIN VERBOSE
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3;

--Testcase 73:
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3;

--Testcase 74:
EXPLAIN VERBOSE
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3;

--Testcase 75:
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3;

--Testcase 76:
EXPLAIN VERBOSE
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200;

--Testcase 77:
SELECT sample(value2, 3) FROM s3 WHERE value2 < 200;

--Testcase 78:
EXPLAIN VERBOSE
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s');

--Testcase 79:
SELECT sample(value2, 1) FROM s3 WHERE time >= to_timestamp(0) AND time <= to_timestamp(5) GROUP BY influx_time(time, interval '3s');

--Testcase 80:
EXPLAIN VERBOSE
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3;

--Testcase 81:
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3;

--Testcase 82:
EXPLAIN VERBOSE
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3;

--Testcase 83:
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3;

--Testcase 84:
EXPLAIN VERBOSE
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3;

--Testcase 85:
--cf.) SELECT derivative(value1, 500ms),derivative(value2, 200ms),derivative(value3, 100ms),derivative(value4, 2s) FROM s3;
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3;

--Testcase 86:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3;

--Testcase 87:
--cf.) SELECT non_negative_derivative(value1, 500ms),non_negative_derivative(value2, 200ms),non_negative_derivative(value3, 100ms),non_negative_derivative(value4, 2s) FROM s3;
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3;

--Testcase 88:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3;

--Testcase 89:
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3;

--Testcase 90:
EXPLAIN VERBOSE
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3;

--Testcase 91:
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3;

--Testcase 92:
EXPLAIN VERBOSE
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3;

--Testcase 93:
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3;

--Testcase 94:
EXPLAIN VERBOSE
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3;

--Testcase 95:
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3;

--Testcase 96:
EXPLAIN VERBOSE
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3;

--Testcase 97:
--cf.) SELECT elapsed(value1, 500ms),elapsed(value2, 200ms),elapsed(value3, 100ms),elapsed(value4, 2s) FROM s3;
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3;

--Testcase 98:
EXPLAIN VERBOSE
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3;

--Testcase 99:
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3;

--Testcase 100:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3;

--Testcase 101:
SELECT exponential_moving_average(value1, 2),exponential_moving_average(value2, 2),exponential_moving_average(value3, 2),exponential_moving_average(value4, 2) FROM s3;

--Testcase 102:
EXPLAIN VERBOSE
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3;

--Testcase 103:
SELECT exponential_moving_average(value1, 2, 2),exponential_moving_average(value2, 2, 2),exponential_moving_average(value3, 2, 2),exponential_moving_average(value4, 2, 2) FROM s3;

--Testcase 62:
DROP FOREIGN TABLE s3;

--Testcase 68:
CREATE FOREIGN TABLE b3(time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 bool) SERVER server1 OPTIONS(table 'b3', tags 'tag1');

--Testcase 69:
-- bool type var in where clause (explain)
EXPLAIN VERBOSE
SELECT sqrt(abs(value1)) FROM b3 WHERE value3 != true ORDER BY 1;

--Testcase 70:
-- bool type var in where clause (result)
SELECT sqrt(abs(value1)) FROM b3 WHERE value3 != true ORDER BY 1;

--Testcase 71:
DROP FOREIGN TABLE b3;

--Testcase 63:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 64:
DROP SERVER server1;
--Testcase 65:
DROP EXTENSION influxdb_fdw CASCADE;
