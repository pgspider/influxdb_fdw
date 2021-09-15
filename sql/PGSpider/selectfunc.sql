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

-- select sqrt (builtin function, result)
--Testcase 10:
SELECT sqrt(value1), sqrt(value2) FROM s3;

-- select sqrt (builtin function, not pushdown constraints, explain)
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

-- select sqrt(*) (stub agg function, explain)
--Testcase 419:
EXPLAIN VERBOSE
SELECT sqrt_all() from s3;

-- select sqrt(*) (stub agg function, result)
--Testcase 420:
SELECT sqrt_all() from s3;

-- select sqrt(*) (stub agg function and group by tag only) (explain)
--Testcase 421:
EXPLAIN VERBOSE
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sqrt(*) (stub agg function and group by tag only) (result)
--Testcase 422:
SELECT sqrt_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select abs (builtin function, explain)
--Testcase 15:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- ABS() returns negative values if integer (https://github.com/influxdata/influxdb/issues/10261)
-- select abs (builtin function, result)
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

-- select log (builtin function, need to swap arguments, float8, explain)
--Testcase 23:
EXPLAIN VERBOSE
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, float8, result)
--Testcase 24:
SELECT log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, bigint, explain)
--Testcase 25:
EXPLAIN VERBOSE
SELECT log(value2::numeric, 3::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, bigint, result)
--Testcase 26:
SELECT log(value2::numeric, 3::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, mix type, explain)
--Testcase 27:
EXPLAIN VERBOSE
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function, need to swap arguments, mix type, result)
--Testcase 28:
SELECT log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log(*) (stub agg function, explain)
--Testcase 423:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3;

-- select log(*) (stub agg function, result)
--Testcase 424:
SELECT log_all(50) FROM s3;

-- select log(*) (stub agg function, explain)
--Testcase 869:
EXPLAIN VERBOSE
SELECT log_all(70.5) FROM s3;

-- select log(*) (stub agg function, result)
--Testcase 870:
SELECT log_all(70.5) FROM s3;

-- select log(*) (stub agg function and group by tag only) (explain)
--Testcase 425:
EXPLAIN VERBOSE
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select log(*) (stub agg function and group by tag only) (result)
--Testcase 426:
SELECT log_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 427:
SELECT ln_all(),log10_all(),log_all(50) FROM s3;

-- select log2 (stub function, explain)
--Testcase 29:
EXPLAIN VERBOSE
SELECT log2(value1),log2(value2) FROM s3;

-- select log2 (stub function, result)
--Testcase 30:
SELECT log2(value1),log2(value2) FROM s3;

-- select log2(*) (stub agg function, explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT log2_all() from s3;

-- select log2(*) (stub agg function, result)
--Testcase 429:
SELECT log2_all() from s3;

-- select log2(*) (stub agg function and group by tag only) (explain)
--Testcase 430:
EXPLAIN VERBOSE
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select log2(*) (stub agg function and group by tag only) (result)
--Testcase 431:
SELECT log2_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select log10 (stub function, explain)
--Testcase 104:
EXPLAIN VERBOSE
SELECT log10(value1),log10(value2) FROM s3;

-- select log10 (stub function, result)
--Testcase 105:
SELECT log10(value1),log10(value2) FROM s3;

-- select log10(*) (stub agg function, explain)
--Testcase 106:
EXPLAIN VERBOSE
SELECT log10_all() from s3;

-- select log10(*) (stub agg function, result)
--Testcase 107:
SELECT log10_all() from s3;

-- select log10(*) (stub agg function and group by tag only) (explain)
--Testcase 108:
EXPLAIN VERBOSE
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select log10(*) (stub agg function and group by tag only) (result)
--Testcase 109:
SELECT log10_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 110:
SELECT log2_all(), log10_all() FROM s3;

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

-- select abs(*) (stub agg function, explain)
--Testcase 432:
EXPLAIN VERBOSE
SELECT abs_all() from s3;

-- select abs(*) (stub agg function, result)
--Testcase 433:
SELECT abs_all() from s3;

-- select abs(*) (stub agg function and group by tag only) (explain)
--Testcase 434:
EXPLAIN VERBOSE
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select abs(*) (stub agg function and group by tag only) (result)
--Testcase 435:
SELECT abs_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select abs(*) (stub agg function, expose data, explain)
--Testcase 436:
EXPLAIN VERBOSE
SELECT (abs_all()::s3).* from s3;

-- select abs(*) (stub agg function, expose data, result)
--Testcase 437:
SELECT (abs_all()::s3).* from s3;

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

-- select spread with having (result, not pushdown, stub call error)
--Testcase 55:
SELECT spread(value1) FROM s3 HAVING spread(value1) > 100;

-- select spread(*) (stub agg function, explain)
--Testcase 438:
EXPLAIN VERBOSE
SELECT spread_all(*) from s3;

-- select spread(*) (stub agg function, result)
--Testcase 439:
SELECT spread_all(*) from s3;

-- select spread(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 440:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 441:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread(*) (stub agg function and group by tag only) (explain)
--Testcase 442:
EXPLAIN VERBOSE
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select spread(*) (stub agg function and group by tag only) (result)
--Testcase 443:
SELECT spread_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select spread(*) (stub agg function, expose data, explain)
--Testcase 445:
EXPLAIN VERBOSE
SELECT (spread_all(*)::s3).* from s3;

-- select spread(*) (stub agg function, expose data, result)
--Testcase 446:
SELECT (spread_all(*)::s3).* from s3;

-- select spread(regex) (stub agg function, explain)
--Testcase 447:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') from s3;

-- select spread(regex) (stub agg function, result)
--Testcase 448:
SELECT spread('/value[1,4]/') from s3;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 449:
EXPLAIN VERBOSE
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 450:
SELECT spread('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select spread(regex) (stub agg function and group by tag only) (explain)
--Testcase 451:
EXPLAIN VERBOSE
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select spread(regex) (stub agg function and group by tag only) (result)
--Testcase 452:
SELECT spread('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select spread(regex) (stub agg function, expose data, explain)
--Testcase 454:
EXPLAIN VERBOSE
SELECT (spread('/value[1,4]/')::s3).* from s3;

-- select spread(regex) (stub agg function, expose data, result)
--Testcase 455:
SELECT (spread('/value[1,4]/')::s3).* from s3;

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

-- select with order by limit (result)
--Testcase 59:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 60:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3;

-- select mixing with non pushdown func (result)
--Testcase 61:
SELECT abs(value1), sqrt(value2), upper(tag1) FROM s3;

-- nested function in where clause (explain)
--Testcase 66:
EXPLAIN VERBOSE
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

-- nested function in where clause (result)
--Testcase 67:
SELECT sqrt(abs(value3)),min(value1) FROM s3 GROUP BY value3 HAVING sqrt(abs(value3)) > 0 ORDER BY 1,2;

--Testcase 72:
EXPLAIN VERBOSE
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3;

--Testcase 73:
SELECT first(time, value1), first(time, value2), first(time, value3), first(time, value4) FROM s3;

-- select first(*) (stub agg function, explain)
--Testcase 456:
EXPLAIN VERBOSE
SELECT first_all(*) from s3;

-- select first(*) (stub agg function, result)
--Testcase 457:
SELECT first_all(*) from s3;

-- select first(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 458:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select first(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 459:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select first(*) (stub agg function and group by tag only) (explain)
--Testcase 460:
EXPLAIN VERBOSE
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(*) (stub agg function and group by tag only) (result)
--Testcase 461:
SELECT first_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(*) (stub agg function, expose data, explain)
--Testcase 463:
EXPLAIN VERBOSE
SELECT (first_all(*)::s3).* from s3;

-- select first(*) (stub agg function, expose data, result)
--Testcase 464:
SELECT (first_all(*)::s3).* from s3;

-- select first(regex) (stub function, explain)
--Testcase 871:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') from s3;

-- select first(regex) (stub function, explain)
--Testcase 872:
SELECT first('/value[1,4]/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 465:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 466:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select first(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 467:
EXPLAIN VERBOSE
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select first(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 468:
SELECT first('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select first(regex) (stub agg function and group by tag only) (explain)
--Testcase 469:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(regex) (stub agg function and group by tag only) (result)
--Testcase 470:
SELECT first('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select first(regex) (stub agg function, expose data, explain)
--Testcase 472:
EXPLAIN VERBOSE
SELECT (first('/value[1,4]/')::s3).* from s3;

-- select first(regex) (stub agg function, expose data, result)
--Testcase 473:
SELECT (first('/value[1,4]/')::s3).* from s3;

--Testcase 74:
EXPLAIN VERBOSE
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3;

--Testcase 75:
SELECT last(time, value1), last(time, value2), last(time, value3), last(time, value4) FROM s3;

-- select last(*) (stub agg function, explain)
--Testcase 474:
EXPLAIN VERBOSE
SELECT last_all(*) from s3;

-- select last(*) (stub agg function, result)
--Testcase 475:
SELECT last_all(*) from s3;

-- select last(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 476:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select last(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 477:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select last(*) (stub agg function and group by tag only) (explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(*) (stub agg function and group by tag only) (result)
--Testcase 479:
SELECT last_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(*) (stub agg function, expose data, explain)
--Testcase 481:
EXPLAIN VERBOSE
SELECT (last_all(*)::s3).* from s3;

-- select last(*) (stub agg function, expose data, result)
--Testcase 482:
SELECT (last_all(*)::s3).* from s3;

-- select last(regex) (stub function, explain)
--Testcase 483:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') from s3;

-- select last(regex) (stub function, result)
--Testcase 484:
SELECT last('/value[1,4]/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 873:
EXPLAIN VERBOSE
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select multiple regex functions (do not push down, raise warning and stub error) (result)
--Testcase 874:
SELECT first('/value[1,4]/'), first('/^v.*/') from s3;

-- select last(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 485:
EXPLAIN VERBOSE
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select last(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 486:
SELECT last('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select last(regex) (stub agg function and group by tag only) (explain)
--Testcase 487:
EXPLAIN VERBOSE
SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(regex) (stub agg function and group by tag only) (result)
--Testcase 488:
SELECT last('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select last(regex) (stub agg function, expose data, explain)
--Testcase 490:
EXPLAIN VERBOSE
SELECT (last('/value[1,4]/')::s3).* from s3;

-- select last(regex) (stub agg function, expose data, result)
--Testcase 491:
SELECT (last('/value[1,4]/')::s3).* from s3;

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

-- select sample(*, int) (stub agg function, explain)
--Testcase 492:
EXPLAIN VERBOSE
SELECT sample_all(50) from s3;

-- select sample(*, int) (stub agg function, result)
--Testcase 493:
SELECT sample_all(50) from s3;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 494:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select sample(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 495:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select sample(*, int) (stub agg function and group by tag only) (explain)
--Testcase 496:
EXPLAIN VERBOSE
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(*, int) (stub agg function and group by tag only) (result)
--Testcase 497:
SELECT sample_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(*, int) (stub agg function, expose data, explain)
--Testcase 499:
EXPLAIN VERBOSE
SELECT (sample_all(50)::s3).* from s3;

-- select sample(*, int) (stub agg function, expose data, result)
--Testcase 500:
SELECT (sample_all(50)::s3).* from s3;

-- select sample(regex) (stub agg function, explain)
--Testcase 501:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) from s3;

-- select sample(regex) (stub agg function, result)
--Testcase 502:
SELECT sample('/value[1,4]/', 50) from s3;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 503:
EXPLAIN VERBOSE
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select sample(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 504:
SELECT sample('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select sample(regex) (stub agg function and group by tag only) (explain)
--Testcase 505:
EXPLAIN VERBOSE
SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(regex) (stub agg function and group by tag only) (result)
--Testcase 506:
SELECT sample('/value[1,4]/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sample(regex) (stub agg function, expose data, explain)
--Testcase 508:
EXPLAIN VERBOSE
SELECT (sample('/value[1,4]/', 50)::s3).* from s3;

-- select sample(regex) (stub agg function, expose data, result)
--Testcase 509:
SELECT (sample('/value[1,4]/', 50)::s3).* from s3;

--Testcase 80:
EXPLAIN VERBOSE
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3;

--Testcase 81:
SELECT cumulative_sum(value1),cumulative_sum(value2),cumulative_sum(value3),cumulative_sum(value4) FROM s3;

-- select cumulative_sum(*) (stub function, explain)
--Testcase 510:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() from s3;

-- select cumulative_sum(*) (stub function, result)
--Testcase 511:
SELECT cumulative_sum_all() from s3;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 875:
SELECT cumulative_sum('/value[1,4]/') from s3;

-- select cumulative_sum(regex) (stub function, result)
--Testcase 876:
SELECT cumulative_sum('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 877:
EXPLAIN VERBOSE
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (result)
--Testcase 878:
SELECT cumulative_sum_all(), cumulative_sum('/value[1,4]/') from s3;

-- select cumulative_sum(*) (stub function and group by tag only) (explain)
--Testcase 512:
EXPLAIN VERBOSE
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select cumulative_sum(*) (stub function and group by tag only) (result)
--Testcase 513:
SELECT cumulative_sum_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select cumulative_sum(regex) (stub function and group by tag only) (explain)
--Testcase 879:
EXPLAIN VERBOSE
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select cumulative_sum(regex) (stub function and group by tag only) (result)
--Testcase 880:
SELECT cumulative_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select cumulative_sum(*), cumulative_sum(regex) (stub agg function, expose data, explain)
--Testcase 514:
EXPLAIN VERBOSE
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3;

-- select cumulative_sum(*), cumulative_sum(regex) (stub agg function, expose data, result)
--Testcase 515:
SELECT (cumulative_sum_all()::s3).*, (cumulative_sum('/value[1,4]/')::s3).* from s3;

--Testcase 82:
EXPLAIN VERBOSE
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3;

--Testcase 83:
SELECT derivative(value1),derivative(value2),derivative(value3),derivative(value4) FROM s3;

--Testcase 84:
EXPLAIN VERBOSE
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3;

--Testcase 85:
SELECT derivative(value1, interval '0.5s'),derivative(value2, interval '0.2s'),derivative(value3, interval '0.1s'),derivative(value4, interval '2s') FROM s3;

-- select derivative(*) (stub function, explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT derivative_all() from s3;

-- select derivative(*) (stub function, result)
--Testcase 517:
SELECT derivative_all() from s3;

-- select derivative(regex) (stub function, explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') from s3;

-- select derivative(regex) (stub function, result)
--Testcase 517:
SELECT derivative('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 516:
EXPLAIN VERBOSE
SELECT derivative_all(), derivative('/value[1,4]/') from s3;

-- select multiple star and regex functions (do not push down, raise warning and stub error) (explain)
--Testcase 517:
SELECT derivative_all(), derivative('/value[1,4]/') from s3;

-- select derivative(*) (stub function and group by tag only) (explain)
--Testcase 518:
EXPLAIN VERBOSE
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select derivative(*) (stub function and group by tag only) (result)
--Testcase 519:
SELECT derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select derivative(regex) (stub function and group by tag only) (explain)
--Testcase 881:
EXPLAIN VERBOSE
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select derivative(regex) (stub function and group by tag only) (result)
--Testcase 882:
SELECT derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select derivative(*) (stub agg function, expose data, explain)
--Testcase 520:
EXPLAIN VERBOSE
SELECT (derivative_all()::s3).* from s3;

-- select derivative(*) (stub agg function, expose data, result)
--Testcase 521:
SELECT (derivative_all()::s3).* from s3;

-- select derivative(regex) (stub agg function, expose data, explain)
--Testcase 883:
EXPLAIN VERBOSE
SELECT (derivative('/value[1,4]/')::s3).* from s3;

-- select derivative(regex) (stub agg function, expose data, result)
--Testcase 884:
SELECT (derivative('/value[1,4]/')::s3).* from s3;

--Testcase 86:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3;

--Testcase 87:
SELECT non_negative_derivative(value1),non_negative_derivative(value2),non_negative_derivative(value3),non_negative_derivative(value4) FROM s3;

--Testcase 88:
EXPLAIN VERBOSE
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3;

--Testcase 89:
SELECT non_negative_derivative(value1, interval '0.5s'),non_negative_derivative(value2, interval '0.2s'),non_negative_derivative(value3, interval '0.1s'),non_negative_derivative(value4, interval '2s') FROM s3;

-- select non_negative_derivative(*) (stub function, explain)
--Testcase 522:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() from s3;

-- select non_negative_derivative(*) (stub function, result)
--Testcase 523:
SELECT non_negative_derivative_all() from s3;

-- select non_negative_derivative(regex) (stub function, explain)
--Testcase 885:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') from s3;

-- select non_negative_derivative(regex) (stub function, result)
--Testcase 886:
SELECT non_negative_derivative('/value[1,4]/') from s3;

-- select non_negative_derivative(*) (stub function and group by tag only) (explain)
--Testcase 524:
EXPLAIN VERBOSE
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_derivative(*) (stub function and group by tag only) (result)
--Testcase 525:
SELECT non_negative_derivative_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 887:
EXPLAIN VERBOSE
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_derivative(regex) (stub agg function and group by tag only) (result)
--Testcase 888:
SELECT non_negative_derivative('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_derivative(*) (stub function, expose data, explain)
--Testcase 526:
EXPLAIN VERBOSE
SELECT (non_negative_derivative_all()::s3).* from s3;

-- select non_negative_derivative(*) (stub agg function, expose data, result)
--Testcase 527:
SELECT (non_negative_derivative_all()::s3).* from s3;

-- select non_negative_derivative(regex) (stub function, expose data, explain)
--Testcase 889:
EXPLAIN VERBOSE
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3;

-- select non_negative_derivative(regex) (stub agg function, expose data, result)
--Testcase 890:
SELECT (non_negative_derivative('/value[1,4]/')::s3).* from s3;

--Testcase 90:
EXPLAIN VERBOSE
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3;

--Testcase 91:
SELECT difference(value1),difference(value2),difference(value3),difference(value4) FROM s3;

-- select difference(*) (stub function, explain)
--Testcase 528:
EXPLAIN VERBOSE
SELECT difference_all() from s3;

-- select difference(*) (stub function, result)
--Testcase 529:
SELECT difference_all() from s3;

-- select difference(regex) (stub function, explain)
--Testcase 891:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') from s3;

-- select difference(regex) (stub function, result)
--Testcase 892:
SELECT difference('/value[1,4]/') from s3;

-- select difference(*) (stub agg function and group by tag only) (explain)
--Testcase 530:
EXPLAIN VERBOSE
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select difference(*) (stub agg function and group by tag only) (result)
--Testcase 531:
SELECT difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select difference(regex) (stub agg function and group by tag only) (explain)
--Testcase 893:
EXPLAIN VERBOSE
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select difference(regex) (stub agg function and group by tag only) (result)
--Testcase 894:
SELECT difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select difference(*) (stub function, expose data, explain)
--Testcase 532:
EXPLAIN VERBOSE
SELECT (difference_all()::s3).* from s3;

-- select difference(*) (stub function, expose data, result)
--Testcase 533:
SELECT (difference_all()::s3).* from s3;

-- select difference(regex) (stub function, expose data, explain)
--Testcase 895:
EXPLAIN VERBOSE
SELECT (difference('/value[1,4]/')::s3).* from s3;

-- select difference(regex) (stub function, expose data, result)
--Testcase 896:
SELECT (difference('/value[1,4]/')::s3).* from s3;

--Testcase 92:
EXPLAIN VERBOSE
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3;

--Testcase 93:
SELECT non_negative_difference(value1),non_negative_difference(value2),non_negative_difference(value3),non_negative_difference(value4) FROM s3;

-- select non_negative_difference(*) (stub function, explain)
--Testcase 534:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() from s3;

-- select non_negative_difference(*) (stub function, result)
--Testcase 535:
SELECT non_negative_difference_all() from s3;

-- select non_negative_difference(regex) (stub agg function, explain)
--Testcase 897:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') from s3;

-- select non_negative_difference(*), non_negative_difference(regex) (stub function, result)
--Testcase 898:
SELECT non_negative_difference('/value[1,4]/') from s3;

-- select non_negative_difference(*) (stub function and group by tag only) (explain)
--Testcase 536:
EXPLAIN VERBOSE
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_difference(*) (stub function and group by tag only) (result)
--Testcase 537:
SELECT non_negative_difference_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_difference(regex) (stub function and group by tag only) (explain)
--Testcase 899:
EXPLAIN VERBOSE
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_difference(regex) (stub function and group by tag only) (result)
--Testcase 900:
SELECT non_negative_difference('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select non_negative_difference(*) (stub function, expose data, explain)
--Testcase 538:
EXPLAIN VERBOSE
SELECT (non_negative_difference_all()::s3).* from s3;

-- select non_negative_difference(*) (stub function, expose data, result)
--Testcase 539:
SELECT (non_negative_difference_all()::s3).* from s3;

-- select non_negative_difference(regex) (stub function, expose data, explain)
--Testcase 538:
EXPLAIN VERBOSE
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3;

-- select non_negative_difference(regex) (stub function, expose data, result)
--Testcase 901:
SELECT (non_negative_difference('/value[1,4]/')::s3).* from s3;

--Testcase 94:
EXPLAIN VERBOSE
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3;

--Testcase 95:
SELECT elapsed(value1),elapsed(value2),elapsed(value3),elapsed(value4) FROM s3;

--Testcase 96:
EXPLAIN VERBOSE
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3;

--Testcase 97:
SELECT elapsed(value1, interval '0.5s'),elapsed(value2, interval '0.2s'),elapsed(value3, interval '0.1s'),elapsed(value4, interval '2s') FROM s3;

-- select elapsed(*) (stub function, explain)
--Testcase 540:
EXPLAIN VERBOSE
SELECT elapsed_all() from s3;

-- select elapsed(*) (stub function, result)
--Testcase 541:
SELECT elapsed_all() from s3;

-- select elapsed(regex) (stub function, explain)
--Testcase 902:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') from s3;

-- select elapsed(regex) (stub agg function, result)
--Testcase 903:
SELECT elapsed('/value[1,4]/') from s3;

-- select elapsed(*) (stub function and group by tag only) (explain)
--Testcase 542:
EXPLAIN VERBOSE
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select elapsed(*) (stub function and group by tag only) (result)
--Testcase 543:
SELECT elapsed_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select elapsed(regex) (stub function and group by tag only) (explain)
--Testcase 904:
EXPLAIN VERBOSE
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select elapsed(regex) (stub function and group by tag only) (result)
--Testcase 905:
SELECT elapsed('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select elapsed(*) (stub function, expose data, explain)
--Testcase 544:
EXPLAIN VERBOSE
SELECT (elapsed_all()::s3).* from s3;

-- select elapsed(*) (stub function, expose data, result)
--Testcase 545:
SELECT (elapsed_all()::s3).* from s3;

-- select elapsed(regex) (stub function, expose data, explain)
--Testcase 906:
EXPLAIN VERBOSE
SELECT (elapsed('/value[1,4]/')::s3).* from s3;

-- select elapsed(regex) (stub agg function, expose data, result)
--Testcase 907:
SELECT (elapsed('/value[1,4]/')::s3).* from s3;

--Testcase 98:
EXPLAIN VERBOSE
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3;

--Testcase 99:
SELECT moving_average(value1, 2),moving_average(value2, 2),moving_average(value3, 2),moving_average(value4, 2) FROM s3;

-- select moving_average(*) (stub function, explain)
--Testcase 546:
EXPLAIN VERBOSE
SELECT moving_average_all(2) from s3;

-- select moving_average(*) (stub function, result)
--Testcase 547:
SELECT moving_average_all(2) from s3;

-- select moving_average(regex) (stub function, explain)
--Testcase 908:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) from s3;

-- select moving_average(regex) (stub function, result)
--Testcase 909:
SELECT moving_average('/value[1,4]/', 2) from s3;

-- select moving_average(*) (stub function and group by tag only) (explain)
--Testcase 548:
EXPLAIN VERBOSE
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select moving_average(*) (stub function and group by tag only) (result)
--Testcase 549:
SELECT moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 910:
EXPLAIN VERBOSE
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select moving_average(regex) (stub function and group by tag only) (result)
--Testcase 911:
SELECT moving_average('/value[1,4]/', 2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select moving_average(*) (stub function, expose data, explain)
--Testcase 550:
EXPLAIN VERBOSE
SELECT (moving_average_all(2)::s3).* from s3;

-- select moving_average(*) (stub function, expose data, result)
--Testcase 551:
SELECT (moving_average_all(2)::s3).* from s3;

-- select moving_average(regex) (stub function, expose data, explain)
--Testcase 912:
EXPLAIN VERBOSE
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3;

-- select moving_average(regex) (stub function, expose data, result)
--Testcase 913:
SELECT (moving_average('/value[1,4]/', 2)::s3).* from s3;

--Testcase 111:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3;

--Testcase 112:
SELECT chande_momentum_oscillator(value1, 2),chande_momentum_oscillator(value2, 2),chande_momentum_oscillator(value3, 2),chande_momentum_oscillator(value4, 2) FROM s3;

--Testcase 113:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3;

--Testcase 114:
SELECT chande_momentum_oscillator(value1, 2, 2),chande_momentum_oscillator(value2, 2, 2),chande_momentum_oscillator(value3, 2, 2),chande_momentum_oscillator(value4, 2, 2) FROM s3;

-- select chande_momentum_oscillator(*) (stub function, explain)
--Testcase 552:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) from s3;

-- select chande_momentum_oscillator(*) (stub function, result)
--Testcase 553:
SELECT chande_momentum_oscillator_all(2) from s3;

-- select chande_momentum_oscillator(regex) (stub function, explain)
--Testcase 914:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3;

-- select chande_momentum_oscillator(regex) (stub agg function, result)
--Testcase 915:
SELECT chande_momentum_oscillator('/value[1,4]/',2) from s3;

-- select chande_momentum_oscillator(*) (stub function and group by tag only) (explain)
--Testcase 554:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select chande_momentum_oscillator(*) (stub agg function and group by tag only) (result)
--Testcase 555:
SELECT chande_momentum_oscillator_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select chande_momentum_oscillator(regex) (stub agg function and group by tag only) (explain)
--Testcase 916:
EXPLAIN VERBOSE
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select chande_momentum_oscillator(regex) (stub function and group by tag only) (result)
--Testcase 917:
SELECT chande_momentum_oscillator('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select chande_momentum_oscillator(*) (stub agg function, expose data, explain)
--Testcase 556:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3;

-- select chande_momentum_oscillator(*) (stub function, expose data, result)
--Testcase 557:
SELECT (chande_momentum_oscillator_all(2)::s3).* from s3;

-- select chande_momentum_oscillator(regex) (stub function, expose data, explain)
--Testcase 918:
EXPLAIN VERBOSE
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3;

-- select chande_momentum_oscillator(regex) (stub function, expose data, result)
--Testcase 919:
SELECT (chande_momentum_oscillator('/value[1,4]/',2)::s3).* from s3;

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

-- select exponential_moving_average(*) (stub function, explain)
--Testcase 558:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) from s3;

-- select exponential_moving_average(*) (stub function, result)
--Testcase 559:
SELECT exponential_moving_average_all(2) from s3;

-- select exponential_moving_average(regex) (stub function, explain)
--Testcase 920:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) from s3;

-- select exponential_moving_average(regex) (stub function, result)
--Testcase 921:
SELECT exponential_moving_average('/value[1,4]/',2) from s3;

-- select exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 560:
EXPLAIN VERBOSE
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 561:
SELECT exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 922:
EXPLAIN VERBOSE
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 923:
SELECT exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

--Testcase 115:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3;

--Testcase 116:
SELECT double_exponential_moving_average(value1, 2),double_exponential_moving_average(value2, 2),double_exponential_moving_average(value3, 2),double_exponential_moving_average(value4, 2) FROM s3;

--Testcase 117:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3;

--Testcase 118:
SELECT double_exponential_moving_average(value1, 2, 2),double_exponential_moving_average(value2, 2, 2),double_exponential_moving_average(value3, 2, 2),double_exponential_moving_average(value4, 2, 2) FROM s3;

-- select double_exponential_moving_average(*) (stub function, explain)
--Testcase 562:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) from s3;

-- select double_exponential_moving_average(*) (stub function, result)
--Testcase 563:
SELECT double_exponential_moving_average_all(2) from s3;

-- select double_exponential_moving_average(regex) (stub function, explain)
--Testcase 924:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3;

-- select double_exponential_moving_average(regex) (stub function, result)
--Testcase 925:
SELECT double_exponential_moving_average('/value[1,4]/',2) from s3;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 564:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select double_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 565:
SELECT double_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 926:
EXPLAIN VERBOSE
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select double_exponential_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 927:
SELECT double_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

--Testcase 119:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3;

--Testcase 120:
SELECT kaufmans_efficiency_ratio(value1, 2),kaufmans_efficiency_ratio(value2, 2),kaufmans_efficiency_ratio(value3, 2),kaufmans_efficiency_ratio(value4, 2) FROM s3;

--Testcase 121:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3;

--Testcase 122:
SELECT kaufmans_efficiency_ratio(value1, 2, 2),kaufmans_efficiency_ratio(value2, 2, 2),kaufmans_efficiency_ratio(value3, 2, 2),kaufmans_efficiency_ratio(value4, 2, 2) FROM s3;

-- select kaufmans_efficiency_ratio(*) (stub function, explain)
--Testcase 566:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) from s3;

-- select kaufmans_efficiency_ratio(*) (stub function, result)
--Testcase 567:
SELECT kaufmans_efficiency_ratio_all(2) from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, explain)
--Testcase 928:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, result)
--Testcase 929:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) from s3;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (explain)
--Testcase 568:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_efficiency_ratio(*) (stub function and group by tag only) (result)
--Testcase 569:
SELECT kaufmans_efficiency_ratio_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (explain)
--Testcase 930:
EXPLAIN VERBOSE
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_efficiency_ratio(regex) (stub function and group by tag only) (result)
--Testcase 931:
SELECT kaufmans_efficiency_ratio('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, explain)
--Testcase 570:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(*) (stub function, expose data, result)
--Testcase 571:
SELECT (kaufmans_efficiency_ratio_all(2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, explain)
--Testcase 932:
EXPLAIN VERBOSE
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3;

-- select kaufmans_efficiency_ratio(regex) (stub function, expose data, result)
--Testcase 933:
SELECT (kaufmans_efficiency_ratio('/value[1,4]/',2)::s3).* from s3;

--Testcase 123:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3;

--Testcase 124:
SELECT kaufmans_adaptive_moving_average(value1, 2),kaufmans_adaptive_moving_average(value2, 2),kaufmans_adaptive_moving_average(value3, 2),kaufmans_adaptive_moving_average(value4, 2) FROM s3;

--Testcase 125:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3;

--Testcase 126:
SELECT kaufmans_adaptive_moving_average(value1, 2, 2),kaufmans_adaptive_moving_average(value2, 2, 2),kaufmans_adaptive_moving_average(value3, 2, 2),kaufmans_adaptive_moving_average(value4, 2, 2) FROM s3;

-- select kaufmans_adaptive_moving_average(*) (stub function, explain)
--Testcase 572:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) from s3;

-- select kaufmans_adaptive_moving_average(*) (stub function, result)
--Testcase 573:
SELECT kaufmans_adaptive_moving_average_all(2) from s3;

-- select kaufmans_adaptive_moving_average(regex) (stub function, explain)
--Testcase 934:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3;

-- select kaufmans_adaptive_moving_average(regex) (stub agg function, result)
--Testcase 935:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) from s3;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 574:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_adaptive_moving_average(*) (stub function and group by tag only) (result)
--Testcase 575:
SELECT kaufmans_adaptive_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (explain)
--Testcase 936:
EXPLAIN VERBOSE
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select kaufmans_adaptive_moving_average(regex) (stub function and group by tag only) (result)
--Testcase 937:
SELECT kaufmans_adaptive_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

--Testcase 127:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3;

--Testcase 128:
SELECT triple_exponential_moving_average(value1, 2),triple_exponential_moving_average(value2, 2),triple_exponential_moving_average(value3, 2),triple_exponential_moving_average(value4, 2) FROM s3;

--Testcase 129:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3;

--Testcase 130:
SELECT triple_exponential_moving_average(value1, 2, 2),triple_exponential_moving_average(value2, 2, 2),triple_exponential_moving_average(value3, 2, 2),triple_exponential_moving_average(value4, 2, 2) FROM s3;

-- select triple_exponential_moving_average(*) (stub function, explain)
--Testcase 576:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) from s3;

-- select triple_exponential_moving_average(*) (stub function, result)
--Testcase 577:
SELECT triple_exponential_moving_average_all(2) from s3;

-- select triple_exponential_moving_average(regex) (stub function, explain)
--Testcase 938:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3;

-- select triple_exponential_moving_average(regex) (stub function, result)
--Testcase 939:
SELECT triple_exponential_moving_average('/value[1,4]/',2) from s3;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (explain)
--Testcase 578:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_moving_average(*) (stub function and group by tag only) (result)
--Testcase 579:
SELECT triple_exponential_moving_average_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_moving_average(regex) (stub agg function and group by tag only) (explain)
--Testcase 940:
EXPLAIN VERBOSE
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_moving_average(regex) (stub agg function and group by tag only) (result)
--Testcase 941:
SELECT triple_exponential_moving_average('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

--Testcase 131:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3;

--Testcase 132:
SELECT triple_exponential_derivative(value1, 2),triple_exponential_derivative(value2, 2),triple_exponential_derivative(value3, 2),triple_exponential_derivative(value4, 2) FROM s3;

--Testcase 133:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3;

--Testcase 134:
SELECT triple_exponential_derivative(value1, 2, 2),triple_exponential_derivative(value2, 2, 2),triple_exponential_derivative(value3, 2, 2),triple_exponential_derivative(value4, 2, 2) FROM s3;

-- select triple_exponential_derivative(*) (stub function, explain)
--Testcase 580:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) from s3;

-- select triple_exponential_derivative(*) (stub function, result)
--Testcase 581:
SELECT triple_exponential_derivative_all(2) from s3;

-- select triple_exponential_derivative(regex) (stub function, explain)
--Testcase 942:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3;

-- select triple_exponential_derivative(regex) (stub function, result)
--Testcase 943:
SELECT triple_exponential_derivative('/value[1,4]/',2) from s3;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (explain)
--Testcase 582:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_derivative(*) (stub function and group by tag only) (result)
--Testcase 583:
SELECT triple_exponential_derivative_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (explain)
--Testcase 944:
EXPLAIN VERBOSE
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select triple_exponential_derivative(regex) (stub function and group by tag only) (result)
--Testcase 945:
SELECT triple_exponential_derivative('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

--Testcase 135:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3;

--Testcase 136:
SELECT relative_strength_index(value1, 2),relative_strength_index(value2, 2),relative_strength_index(value3, 2),relative_strength_index(value4, 2) FROM s3;

--Testcase 137:
EXPLAIN VERBOSE
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3;

--Testcase 138:
SELECT relative_strength_index(value1, 2, 2),relative_strength_index(value2, 2, 2),relative_strength_index(value3, 2, 2),relative_strength_index(value4, 2, 2) FROM s3;

-- select relative_strength_index(*) (stub function, explain)
--Testcase 584:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) from s3;

-- select relative_strength_index(*) (stub function, result)
--Testcase 585:
SELECT relative_strength_index_all(2) from s3;

-- select relative_strength_index(regex) (stub agg function, explain)
--Testcase 946:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) from s3;

-- select relative_strength_index(regex) (stub agg function, result)
--Testcase 947:
SELECT relative_strength_index('/value[1,4]/',2) from s3;

-- select relative_strength_index(*) (stub function and group by tag only) (explain)
--Testcase 586:
EXPLAIN VERBOSE
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select relative_strength_index(*) (stub function and group by tag only) (result)
--Testcase 587:
SELECT relative_strength_index_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select relative_strength_index(regex) (stub function and group by tag only) (explain)
--Testcase 948:
EXPLAIN VERBOSE
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select relative_strength_index(regex) (stub function and group by tag only) (result)
--Testcase 949:
SELECT relative_strength_index('/value[1,4]/',2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select relative_strength_index(*) (stub function, expose data, explain)
--Testcase 588:
EXPLAIN VERBOSE
SELECT (relative_strength_index_all(2)::s3).* from s3;

-- select relative_strength_index(*) (stub function, expose data, result)
--Testcase 589:
SELECT (relative_strength_index_all(2)::s3).* from s3;

-- select relative_strength_index(regex) (stub function, expose data, explain)
--Testcase 950:
EXPLAIN VERBOSE
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3;

-- select relative_strength_index(regex) (stub function, expose data, result)
--Testcase 951:
SELECT (relative_strength_index('/value[1,4]/',2)::s3).* from s3;

-- select integral (stub agg function, explain)
--Testcase 139:
EXPLAIN VERBOSE
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3;

-- select integral (stub agg function, result)
--Testcase 140:
SELECT integral(value1),integral(value2),integral(value3),integral(value4) FROM s3;

--Testcase 141:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3;

-- select integral (stub agg function, result)
--Testcase 142:
SELECT integral(value1, interval '1s'),integral(value2, interval '1s'),integral(value3, interval '1s'),integral(value4, interval '1s') FROM s3;

-- select integral (stub agg function, raise exception if not expected type)
--Testcase 143:
SELECT integral(value1::numeric),integral(value2::numeric),integral(value3::numeric),integral(value4::numeric) FROM s3;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 144:
EXPLAIN VERBOSE
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 145:
SELECT integral("value1"),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral (stub agg function and group by influx_time() and tag) (explain)
--Testcase 146:
EXPLAIN VERBOSE
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral (stub agg function and group by influx_time() and tag) (result)
--Testcase 147:
SELECT integral("value1", interval '1s'),influx_time(time, interval '1s'),tag1 FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 148:
SELECT tag1,integral("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY tag1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 149:
SELECT sum("value1"),integral("value1"),count("value1") FROM s3;

-- select integral (stub agg function and group by tag only) (result)
--Testcase 150:
SELECT tag1,integral("value1", interval '1s') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1 ORDER BY tag1;

-- select integral (stub agg function and other aggs) (result)
--Testcase 151:
SELECT sum("value1"),integral("value1", interval '1s'),count("value1") FROM s3;

-- select integral over join query (explain)
--Testcase 152:
EXPLAIN VERBOSE
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select integral over join query (result, stub call error)
--Testcase 153:
SELECT integral(t1.value1), integral(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select integral over join query (explain)
--Testcase 154:
EXPLAIN VERBOSE
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select integral over join query (result, stub call error)
--Testcase 155:
SELECT integral(t1.value1, interval '1s'), integral(t2.value1, interval '1s') FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select integral with having (explain)
--Testcase 156:
EXPLAIN VERBOSE
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 157:
SELECT integral(value1) FROM s3 HAVING integral(value1) > 100;

-- select integral with having (explain)
--Testcase 158:
EXPLAIN VERBOSE
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100;

-- select integral with having (explain, not pushdown, stub call error)
--Testcase 159:
SELECT integral(value1, interval '1s') FROM s3 HAVING integral(value1, interval '1s') > 100;

-- select integral(*) (stub agg function, explain)
--Testcase 590:
EXPLAIN VERBOSE
SELECT integral_all(*) from s3;

-- select integral(*) (stub agg function, result)
--Testcase 591:
SELECT integral_all(*) from s3;

-- select integral(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 592:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 593:
SELECT integral_all(*) FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral(*) (stub agg function and group by tag only) (explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1;

-- select integral(*) (stub agg function and group by tag only) (result)
--Testcase 595:
SELECT integral_all(*) FROM s3 WHERE value1 > 0.3 GROUP BY tag1;

-- select integral(*) (stub agg function, expose data, explain)
--Testcase 597:
EXPLAIN VERBOSE
SELECT (integral_all(*)::s3).* from s3;

-- select integral(*) (stub agg function, expose data, result)
--Testcase 598:
SELECT (integral_all(*)::s3).* from s3;

-- select integral(regex) (stub agg function, explain)
--Testcase 599:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') from s3;

-- select integral(regex) (stub agg function, result)
--Testcase 600:
SELECT integral('/value[1,4]/') from s3;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 601:
EXPLAIN VERBOSE
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 602:
SELECT integral('/^v.*/') FROM s3 GROUP BY influx_time(time, interval '1s'), tag1;

-- select integral(regex) (stub agg function and group by tag only) (explain)
--Testcase 603:
EXPLAIN VERBOSE
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1;

-- select integral(regex) (stub agg function and group by tag only) (result)
--Testcase 604:
SELECT integral('/value[1,4]/') FROM s3 WHERE value1 > 0.3 GROUP BY tag1;

-- select integral(regex) (stub agg function, expose data, explain)
--Testcase 606:
EXPLAIN VERBOSE
SELECT (integral('/value[1,4]/')::s3).* from s3;

-- select integral(regex) (stub agg function, expose data, result)
--Testcase 607:
SELECT (integral('/value[1,4]/')::s3).* from s3;

-- select mean (stub agg function, explain)
--Testcase 160:
EXPLAIN VERBOSE
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3;

-- select mean (stub agg function, result)
--Testcase 161:
SELECT mean(value1),mean(value2),mean(value3),mean(value4) FROM s3;

-- select mean (stub agg function, raise exception if not expected type)
--Testcase 162:
SELECT mean(value1::numeric),mean(value2::numeric),mean(value3::numeric),mean(value4::numeric) FROM s3;

-- select mean (stub agg function and group by influx_time() and tag) (explain)
--Testcase 163:
EXPLAIN VERBOSE
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean (stub agg function and group by influx_time() and tag) (result)
--Testcase 164:
SELECT mean("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean (stub agg function and group by tag only) (result)
--Testcase 165:
SELECT tag1,mean("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select mean (stub agg function and other aggs) (result)
--Testcase 166:
SELECT sum("value1"),mean("value1"),count("value1") FROM s3;

-- select mean over join query (explain)
--Testcase 167:
EXPLAIN VERBOSE
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select mean over join query (result, stub call error)
--Testcase 168:
SELECT mean(t1.value1), mean(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select mean with having (explain)
--Testcase 169:
EXPLAIN VERBOSE
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100;

-- select mean with having (explain, not pushdown, stub call error)
--Testcase 170:
SELECT mean(value1) FROM s3 HAVING mean(value1) > 100;

-- select mean(*) (stub agg function, explain)
--Testcase 608:
EXPLAIN VERBOSE
SELECT mean_all(*) from s3;

-- select mean(*) (stub agg function, result)
--Testcase 609:
SELECT mean_all(*) from s3;

-- select mean(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 610:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 611:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean(*) (stub agg function and group by tag only) (explain)
--Testcase 612:
EXPLAIN VERBOSE
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select mean(*) (stub agg function and group by tag only) (result)
--Testcase 613:
SELECT mean_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select mean(*) (stub agg function, expose data, explain)
--Testcase 615:
EXPLAIN VERBOSE
SELECT (mean_all(*)::s3).* from s3;

-- select mean(*) (stub agg function, expose data, result)
--Testcase 616:
SELECT (mean_all(*)::s3).* from s3;

-- select mean(regex) (stub agg function, explain)
--Testcase 617:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') from s3;

-- select mean(regex) (stub agg function, result)
--Testcase 618:
SELECT mean('/value[1,4]/') from s3;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 619:
EXPLAIN VERBOSE
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 620:
SELECT mean('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select mean(regex) (stub agg function and group by tag only) (explain)
--Testcase 621:
EXPLAIN VERBOSE
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select mean(regex) (stub agg function and group by tag only) (result)
--Testcase 622:
SELECT mean('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select mean(regex) (stub agg function, expose data, explain)
--Testcase 624:
EXPLAIN VERBOSE
SELECT (mean('/value[1,4]/')::s3).* from s3;

-- select mean(regex) (stub agg function, expose data, result)
--Testcase 625:
SELECT (mean('/value[1,4]/')::s3).* from s3;

-- select median (stub agg function, explain)
--Testcase 171:
EXPLAIN VERBOSE
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3;

-- select median (stub agg function, result)
--Testcase 172:
SELECT median(value1),median(value2),median(value3),median(value4) FROM s3;

-- select median (stub agg function, raise exception if not expected type)
--Testcase 173:
SELECT median(value1::numeric),median(value2::numeric),median(value3::numeric),median(value4::numeric) FROM s3;

-- select median (stub agg function and group by influx_time() and tag) (explain)
--Testcase 174:
EXPLAIN VERBOSE
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median (stub agg function and group by influx_time() and tag) (result)
--Testcase 175:
SELECT median("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median (stub agg function and group by tag only) (result)
--Testcase 176:
SELECT tag1,median("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select median (stub agg function and other aggs) (result)
--Testcase 177:
SELECT sum("value1"),median("value1"),count("value1") FROM s3;

-- select median over join query (explain)
--Testcase 178:
EXPLAIN VERBOSE
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select median over join query (result, stub call error)
--Testcase 179:
SELECT median(t1.value1), median(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select median with having (explain)
--Testcase 180:
EXPLAIN VERBOSE
SELECT median(value1) FROM s3 HAVING median(value1) > 100;

-- select median with having (explain, not pushdown, stub call error)
--Testcase 181:
SELECT median(value1) FROM s3 HAVING median(value1) > 100;

-- select median(*) (stub agg function, explain)
--Testcase 626:
EXPLAIN VERBOSE
SELECT median_all(*) from s3;

-- select median(*) (stub agg function, result)
--Testcase 627:
SELECT median_all(*) from s3;

-- select median(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 628:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 629:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median(*) (stub agg function and group by tag only) (explain)
--Testcase 630:
EXPLAIN VERBOSE
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select median(*) (stub agg function and group by tag only) (result)
--Testcase 631:
SELECT median_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select median(*) (stub agg function, expose data, explain)
--Testcase 633:
EXPLAIN VERBOSE
SELECT (median_all(*)::s3).* from s3;

-- select median(*) (stub agg function, expose data, result)
--Testcase 634:
SELECT (median_all(*)::s3).* from s3;

-- select median(regex) (stub agg function, explain)
--Testcase 635:
EXPLAIN VERBOSE
SELECT median('/^v.*/') from s3;

-- select median(regex) (stub agg function, result)
--Testcase 636:
SELECT  median('/^v.*/') from s3;

-- select median(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 637:
EXPLAIN VERBOSE
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 638:
SELECT median('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select median(regex) (stub agg function and group by tag only) (explain)
--Testcase 639:
EXPLAIN VERBOSE
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select median(regex) (stub agg function and group by tag only) (result)
--Testcase 640:
SELECT median('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select median(regex) (stub agg function, expose data, explain)
--Testcase 642:
EXPLAIN VERBOSE
SELECT (median('/value[1,4]/')::s3).* from s3;

-- select median(regex) (stub agg function, expose data, result)
--Testcase 643:
SELECT (median('/value[1,4]/')::s3).* from s3;

-- select influx_mode (stub agg function, explain)
--Testcase 182:
EXPLAIN VERBOSE
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3;

-- select influx_mode (stub agg function, result)
--Testcase 183:
SELECT influx_mode(value1),influx_mode(value2),influx_mode(value3),influx_mode(value4) FROM s3;

-- select influx_mode (stub agg function, raise exception if not expected type)
--Testcase 184:
SELECT influx_mode(value1::numeric),influx_mode(value2::numeric),influx_mode(value3::numeric),influx_mode(value4::numeric) FROM s3;

-- select influx_mode (stub agg function and group by influx_time() and tag) (explain)
--Testcase 185:
EXPLAIN VERBOSE
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode (stub agg function and group by influx_time() and tag) (result)
--Testcase 186:
SELECT influx_mode("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode (stub agg function and group by tag only) (result)
--Testcase 187:
SELECT tag1,influx_mode("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_mode (stub agg function and other aggs) (result)
--Testcase 188:
SELECT sum("value1"),influx_mode("value1"),count("value1") FROM s3;

-- select influx_mode over join query (explain)
--Testcase 189:
EXPLAIN VERBOSE
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select influx_mode over join query (result, stub call error)
--Testcase 190:
SELECT influx_mode(t1.value1), influx_mode(t2.value1) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select influx_mode with having (explain)
--Testcase 191:
EXPLAIN VERBOSE
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100;

-- select influx_mode with having (explain, not pushdown, stub call error)
--Testcase 192:
SELECT influx_mode(value1) FROM s3 HAVING influx_mode(value1) > 100;

-- select influx_mode(*) (stub agg function, explain)
--Testcase 644:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) from s3;

-- select influx_mode(*) (stub agg function, result)
--Testcase 645:
SELECT influx_mode_all(*) from s3;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 646:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 647:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode(*) (stub agg function and group by tag only) (explain)
--Testcase 648:
EXPLAIN VERBOSE
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_mode(*) (stub agg function and group by tag only) (result)
--Testcase 649:
SELECT influx_mode_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_mode(*) (stub agg function, expose data, explain)
--Testcase 651:
EXPLAIN VERBOSE
SELECT (influx_mode_all(*)::s3).* from s3;

-- select influx_mode(*) (stub agg function, expose data, result)
--Testcase 652:
SELECT (influx_mode_all(*)::s3).* from s3;

-- select influx_mode(regex) (stub function, explain)
--Testcase 653:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') from s3;

-- select influx_mode(regex) (stub function, result)
--Testcase 654:
SELECT influx_mode('/value[1,4]/') from s3;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 655:
EXPLAIN VERBOSE
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 656:
SELECT influx_mode('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_mode(regex) (stub agg function and group by tag only) (explain)
--Testcase 657:
EXPLAIN VERBOSE
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_mode(regex) (stub agg function and group by tag only) (result)
--Testcase 658:
SELECT influx_mode('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_mode(regex) (stub agg function, expose data, explain)
--Testcase 660:
EXPLAIN VERBOSE
SELECT (influx_mode('/value[1,4]/')::s3).* from s3;

-- select influx_mode(regex) (stub agg function, expose data, result)
--Testcase 661:
SELECT (influx_mode('/value[1,4]/')::s3).* from s3;

-- select stddev (agg function, explain)
--Testcase 193:
EXPLAIN VERBOSE
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3;

-- select stddev (agg function, result)
--Testcase 194:
SELECT stddev(value1),stddev(value2),stddev(value3),stddev(value4) FROM s3;

-- select stddev (agg function and group by influx_time() and tag) (explain)
--Testcase 195:
EXPLAIN VERBOSE
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev (agg function and group by influx_time() and tag) (result)
--Testcase 196:
SELECT stddev("value1"),influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev (agg function and group by tag only) (result)
--Testcase 197:
SELECT tag1,stddev("value1") FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select stddev (agg function and other aggs) (result)
--Testcase 198:
SELECT sum("value1"),stddev("value1"),count("value1") FROM s3;

-- select stddev(*) (stub agg function, explain)
--Testcase 662:
EXPLAIN VERBOSE
SELECT stddev_all(*) from s3;

-- select stddev(*) (stub agg function, result)
--Testcase 663:
SELECT stddev_all(*) from s3;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 664:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 665:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev(*) (stub agg function and group by tag only) (explain)
--Testcase 666:
EXPLAIN VERBOSE
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select stddev(*) (stub agg function and group by tag only) (result)
--Testcase 667:
SELECT stddev_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select stddev(regex) (stub function, explain)
--Testcase 669:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') from s3;

-- select stddev(regex) (stub function, result)
--Testcase 670:
SELECT stddev('/value[1,4]/') from s3;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 671:
EXPLAIN VERBOSE
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 672:
SELECT stddev('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select stddev(regex) (stub agg function and group by tag only) (explain)
--Testcase 673:
EXPLAIN VERBOSE
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select stddev(regex) (stub agg function and group by tag only) (result)
--Testcase 674:
SELECT stddev('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_sum(*) (stub agg function, explain)
--Testcase 676:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) from s3;

-- select influx_sum(*) (stub agg function, result)
--Testcase 677:
SELECT influx_sum_all(*) from s3;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 678:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_sum(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 679:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_sum(*) (stub agg function and group by tag only) (explain)
--Testcase 680:
EXPLAIN VERBOSE
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_sum(*) (stub agg function and group by tag only) (result)
--Testcase 681:
SELECT influx_sum_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_sum(*) (stub agg function, expose data, explain)
--Testcase 683:
EXPLAIN VERBOSE
SELECT (influx_sum_all(*)::s3).* from s3;

-- select influx_sum(*) (stub agg function, expose data, result)
--Testcase 684:
SELECT (influx_sum_all(*)::s3).* from s3;

-- select influx_sum(regex) (stub function, explain)
--Testcase 685:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') from s3;

-- select influx_sum(regex) (stub function, result)
--Testcase 686:
SELECT influx_sum('/value[1,4]/') from s3;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 687:
EXPLAIN VERBOSE
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_sum(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 688:
SELECT influx_sum('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_sum(regex) (stub agg function and group by tag only) (explain)
--Testcase 689:
EXPLAIN VERBOSE
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_sum(regex) (stub agg function and group by tag only) (result)
--Testcase 690:
SELECT influx_sum('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_sum(regex) (stub agg function, expose data, explain)
--Testcase 692:
EXPLAIN VERBOSE
SELECT (influx_sum('/value[1,4]/')::s3).* from s3;

-- select influx_sum(regex) (stub agg function, expose data, result)
--Testcase 693:
SELECT (influx_sum('/value[1,4]/')::s3).* from s3;

-- selector function bottom() (explain)
--Testcase 199:
EXPLAIN VERBOSE
SELECT bottom(value1, 1) FROM s3;

-- selector function bottom() (result)
--Testcase 200:
SELECT bottom(value1, 1) FROM s3;

-- selector function bottom() cannot be combined with other functions(explain)
--Testcase 201:
EXPLAIN VERBOSE
SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3;

-- selector function bottom() cannot be combined with other functions(result)
--Testcase 202:
SELECT bottom(value1, 1), bottom(value2, 1), bottom(value3, 1), bottom(value4, 1) FROM s3;

-- select influx_max(*) (stub agg function, explain)
--Testcase 694:
EXPLAIN VERBOSE
SELECT influx_max_all(*) from s3;

-- select influx_max(*) (stub agg function, result)
--Testcase 695:
SELECT influx_max_all(*) from s3;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 696:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_max(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 697:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_max(*) (stub agg function and group by tag only) (explain)
--Testcase 698:
EXPLAIN VERBOSE
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_max(*) (stub agg function and group by tag only) (result)
--Testcase 699:
SELECT influx_max_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_max(*) (stub agg function, expose data, explain)
--Testcase 701:
EXPLAIN VERBOSE
SELECT (influx_max_all(*)::s3).* from s3;

-- select influx_max(*) (stub agg function, expose data, result)
--Testcase 702:
SELECT (influx_max_all(*)::s3).* from s3;

-- select influx_max(regex) (stub function, explain)
--Testcase 703:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') from s3;

-- select influx_max(regex) (stub function, result)
--Testcase 704:
SELECT influx_max('/value[1,4]/') from s3;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 705:
EXPLAIN VERBOSE
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_max(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 706:
SELECT influx_max('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_max(regex) (stub agg function and group by tag only) (explain)
--Testcase 707:
EXPLAIN VERBOSE
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_max(regex) (stub agg function and group by tag only) (result)
--Testcase 708:
SELECT influx_max('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_max(regex) (stub agg function, expose data, explain)
--Testcase 710:
EXPLAIN VERBOSE
SELECT (influx_max('/value[1,4]/')::s3).* from s3;

-- select influx_max(regex) (stub agg function, expose data, result)
--Testcase 711:
SELECT (influx_max('/value[1,4]/')::s3).* from s3;

-- select influx_min(*) (stub agg function, explain)
--Testcase 712:
EXPLAIN VERBOSE
SELECT influx_min_all(*) from s3;

-- select influx_min(*) (stub agg function, result)
--Testcase 713:
SELECT influx_min_all(*) from s3;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 714:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_min(*) (stub agg function and group by influx_time() and tag) (result)
--Testcase 715:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_min(*) (stub agg function and group by tag only) (explain)
--Testcase 716:
EXPLAIN VERBOSE
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_min(*) (stub agg function and group by tag only) (result)
--Testcase 717:
SELECT influx_min_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_min(*) (stub agg function, expose data, explain)
--Testcase 719:
EXPLAIN VERBOSE
SELECT (influx_min_all(*)::s3).* from s3;

-- select influx_min(*) (stub agg function, expose data, result)
--Testcase 720:
SELECT (influx_min_all(*)::s3).* from s3;

-- select influx_min(regex) (stub function, explain)
--Testcase 721:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') from s3;

-- select influx_min(regex) (stub function, result)
--Testcase 722:
SELECT influx_min('/value[1,4]/') from s3;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 723:
EXPLAIN VERBOSE
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_min(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 724:
SELECT influx_min('/^v.*/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select influx_min(regex) (stub agg function and group by tag only) (explain)
--Testcase 725:
EXPLAIN VERBOSE
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_min(regex) (stub agg function and group by tag only) (result)
--Testcase 726:
SELECT influx_min('/value[1,4]/') FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select influx_min(regex) (stub agg function, expose data, explain)
--Testcase 728:
EXPLAIN VERBOSE
SELECT (influx_min('/value[1,4]/')::s3).* from s3;

-- select influx_min(regex) (stub agg function, expose data, result)
--Testcase 729:
SELECT (influx_min('/value[1,4]/')::s3).* from s3;

-- selector function percentile() (explain)
--Testcase 203:
EXPLAIN VERBOSE
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3;

-- selector function percentile() (result)
--Testcase 204:
SELECT percentile(value1, 50), percentile(value2, 60), percentile(value3, 25), percentile(value4, 33) FROM s3;

-- selector function percentile() (explain)
--Testcase 730:
EXPLAIN VERBOSE
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3;

-- selector function percentile() (result)
--Testcase 731:
SELECT percentile(value1, 1.5), percentile(value2, 6.7), percentile(value3, 20.5), percentile(value4, 75.2) FROM s3;

-- select percentile(*, int) (stub agg function, explain)
--Testcase 732:
EXPLAIN VERBOSE
SELECT percentile_all(50) from s3;

-- select percentile(*, int) (stub agg function, result)
--Testcase 733:
SELECT percentile_all(50) from s3;

-- select percentile(*, float8) (stub agg function, explain)
--Testcase 734:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) from s3;

-- select percentile(*, float8) (stub agg function, result)
--Testcase 735:
SELECT percentile_all(70.5) from s3;

-- select percentile(*, int) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 736:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(*, int) (stub agg function and group by influx_time() and tag) (result)
--Testcase 737:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(*, float8) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 738:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(*, float8) (stub agg function and group by influx_time() and tag) (result)
--Testcase 739:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(*, int) (stub agg function and group by tag only) (explain)
--Testcase 740:
EXPLAIN VERBOSE
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(*, int) (stub agg function and group by tag only) (result)
--Testcase 741:
SELECT percentile_all(50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(*, float8) (stub agg function and group by tag only) (explain)
--Testcase 742:
EXPLAIN VERBOSE
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(*, float8) (stub agg function and group by tag only) (result)
--Testcase 743:
SELECT percentile_all(70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(*, int) (stub agg function, expose data, explain)
--Testcase 745:
EXPLAIN VERBOSE
SELECT (percentile_all(50)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, result)
--Testcase 746:
SELECT (percentile_all(50)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, explain)
--Testcase 747:
EXPLAIN VERBOSE
SELECT (percentile_all(70.5)::s3).* from s3;

-- select percentile(*, int) (stub agg function, expose data, result)
--Testcase 748:
SELECT (percentile_all(70.5)::s3).* from s3;

-- select percentile(regex) (stub function, explain)
--Testcase 749:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 50) from s3;

-- select percentile(regex) (stub function, result)
--Testcase 750:
SELECT percentile('/value[1,4]/', 50) from s3;

-- select percentile(regex) (stub agg function and group by influx_time() and tag) (explain)
--Testcase 751:
EXPLAIN VERBOSE
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(regex) (stub agg function and group by influx_time() and tag) (result)
--Testcase 752:
SELECT percentile('/^v.*/', 50) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select percentile(regex) (stub agg function and group by tag only) (explain)
--Testcase 753:
EXPLAIN VERBOSE
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(regex) (stub agg function and group by tag only) (result)
--Testcase 754:
SELECT percentile('/value[1,4]/', 70.5) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select percentile(regex) (stub agg function, expose data, explain)
--Testcase 756:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, result)
--Testcase 757:
SELECT (percentile('/value[1,4]/', 50)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, explain)
--Testcase 758:
EXPLAIN VERBOSE
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3;

-- select percentile(regex) (stub agg function, expose data, result)
--Testcase 759:
SELECT (percentile('/value[1,4]/', 70.5)::s3).* from s3;

-- selector function top(field_key,N) (explain)
--Testcase 205:
EXPLAIN VERBOSE
SELECT top(value1, 1) FROM s3;

-- selector function top(field_key,N) (result)
--Testcase 206:
SELECT top(value1, 1) FROM s3;

-- selector function top(field_key,tag_key(s),N) (explain)
--Testcase 207:
EXPLAIN VERBOSE
SELECT top(value1, tag1, 1) FROM s3;

-- selector function top(field_key,tag_key(s),N) (result)
--Testcase 208:
SELECT top(value1, tag1, 1) FROM s3;

-- selector function top() cannot be combined with other functions(explain)
--Testcase 209:
EXPLAIN VERBOSE
SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3;

-- selector function top() cannot be combined with other functions(result)
--Testcase 210:
SELECT top(value1, 1), top(value2, 1), top(value3, 1), top(value4, 1) FROM s3;

-- select acos (builtin function, explain)
--Testcase 211:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3;

-- select acos (builtin function, result)
--Testcase 212:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 213:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 214:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 215:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 216:
SELECT acos(value1), acos(value2), acos(value3), acos(value4) FROM s3 WHERE value2 != 200;

-- select acos as nest function with agg (pushdown, explain)
--Testcase 217:
EXPLAIN VERBOSE
SELECT sum(value3),acos(sum(value3)) FROM s3;

-- select acos as nest function with agg (pushdown, result)
--Testcase 218:
SELECT sum(value3),acos(sum(value3)) FROM s3;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 219:
EXPLAIN VERBOSE
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 220:
SELECT acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 221:
EXPLAIN VERBOSE
SELECT acos(value3), pi(), 4.1 FROM s3;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 222:
SELECT acos(value3), pi(), 4.1 FROM s3;

-- select acos with order by (explain)
--Testcase 223:
EXPLAIN VERBOSE
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by (result)
--Testcase 224:
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by index (result)
--Testcase 225:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 226:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 1,2;

-- select acos and as
--Testcase 227:
SELECT acos(value3) as acos1 FROM s3;

-- select acos(*) (stub agg function, explain)
--Testcase 760:
EXPLAIN VERBOSE
SELECT acos_all() from s3;

-- select acos(*) (stub agg function, result)
--Testcase 761:
SELECT acos_all() from s3;

-- select acos(*) (stub agg function and group by tag only) (explain)
--Testcase 762:
EXPLAIN VERBOSE
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select acos(*) (stub agg function and group by tag only) (result)
--Testcase 763:
SELECT acos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select acos(*) (stub agg function, expose data, explain)
--Testcase 764:
EXPLAIN VERBOSE
SELECT (acos_all()::s3).* from s3;

-- select acos(*) (stub agg function, expose data, result)
--Testcase 765:
SELECT (acos_all()::s3).* from s3;

-- select asin (builtin function, explain)
--Testcase 228:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3;

-- select asin (builtin function, result)
--Testcase 229:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 230:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 231:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 232:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 233:
SELECT asin(value1), asin(value2), asin(value3), asin(value4) FROM s3 WHERE value2 != 200;

-- select asin as nest function with agg (pushdown, explain)
--Testcase 234:
EXPLAIN VERBOSE
SELECT sum(value3), asin(sum(value3)) FROM s3;

-- select asin as nest function with agg (pushdown, result)
--Testcase 235:
SELECT sum(value3), asin(sum(value3)) FROM s3;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 236:
EXPLAIN VERBOSE
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 237:
SELECT asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 238:
EXPLAIN VERBOSE
SELECT asin(value3), pi(), 4.1 FROM s3;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 239:
SELECT asin(value3), pi(), 4.1 FROM s3;

-- select asin with order by (explain)
--Testcase 240:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by (result)
--Testcase 241:
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by index (result)
--Testcase 242:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 243:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 1,2;

-- select asin and as
--Testcase 244:
SELECT asin(value3) as asin1 FROM s3;

-- select asin(*) (stub agg function, explain)
--Testcase 766:
EXPLAIN VERBOSE
SELECT asin_all() from s3;

-- select asin(*) (stub agg function, result)
--Testcase 767:
SELECT asin_all() from s3;

-- select asin(*) (stub agg function and group by tag only) (explain)
--Testcase 768:
EXPLAIN VERBOSE
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select asin(*) (stub agg function and group by tag only) (result)
--Testcase 769:
SELECT asin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select asin(*) (stub agg function, expose data, explain)
--Testcase 770:
EXPLAIN VERBOSE
SELECT (asin_all()::s3).* from s3;

-- select asin(*) (stub agg function, expose data, result)
--Testcase 771:
SELECT (asin_all()::s3).* from s3;

-- select atan (builtin function, explain)
--Testcase 245:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3;

-- select atan (builtin function, result)
--Testcase 246:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 247:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 248:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 249:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 250:
SELECT atan(value1), atan(value2), atan(value3), atan(value4) FROM s3 WHERE value2 != 200;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 251:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest function with agg (pushdown, result)
--Testcase 252:
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 253:
EXPLAIN VERBOSE
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 254:
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 255:
EXPLAIN VERBOSE
SELECT atan(value3), pi(), 4.1 FROM s3;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 256:
SELECT atan(value3), pi(), 4.1 FROM s3;

-- select atan with order by (explain)
--Testcase 257:
EXPLAIN VERBOSE
SELECT value1, atan(1-value1) FROM s3 order by atan(1-value1);

-- select atan with order by (result)
--Testcase 258:
SELECT value1, atan(1-value1) FROM s3 order by atan(1-value1);

-- select atan with order by index (result)
--Testcase 259:
SELECT value1, atan(1-value1) FROM s3 order by 2,1;

-- select atan with order by index (result)
--Testcase 260:
SELECT value1, atan(1-value1) FROM s3 order by 1,2;

-- select atan and as
--Testcase 261:
SELECT atan(value3) as atan1 FROM s3;

-- select atan(*) (stub agg function, explain)
--Testcase 772:
EXPLAIN VERBOSE
SELECT atan_all() from s3;

-- select atan(*) (stub agg function, result)
--Testcase 773:
SELECT atan_all() from s3;

-- select atan(*) (stub agg function and group by tag only) (explain)
--Testcase 774:
EXPLAIN VERBOSE
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select atan(*) (stub agg function and group by tag only) (result)
--Testcase 775:
SELECT atan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select atan(*) (stub agg function, expose data, explain)
--Testcase 776:
EXPLAIN VERBOSE
SELECT (atan_all()::s3).* from s3;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 778:
SELECT asin_all(), acos_all(), atan_all() FROM s3;

-- select atan2 (builtin function, explain)
--Testcase 262:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3;

-- select atan2 (builtin function, result)
--Testcase 263:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 264:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64';

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 265:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE to_hex(value2) != '64';

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 266:
EXPLAIN VERBOSE
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 267:
SELECT atan2(value1, value2), atan2(value2, value3), atan2(value3, value4), atan2(value4, value1) FROM s3 WHERE value2 != 200;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 268:
EXPLAIN VERBOSE
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 269:
SELECT sum(value3), sum(value4),atan2(sum(value3), sum(value3)) FROM s3;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 270:
EXPLAIN VERBOSE
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 271:
SELECT atan2(log2(value1), log2(value1)),atan2(log2(1/value1), log2(1/value1)) FROM s3;

-- select atan2 with non pushdown func and explicit constant (explain)
--Testcase 272:
EXPLAIN VERBOSE
SELECT atan2(value3, value4), pi(), 4.1 FROM s3;

-- select atan2 with non pushdown func and explicit constant (result)
--Testcase 273:
SELECT atan2(value3, value4), pi(), 4.1 FROM s3;

-- select atan2 with order by (explain)
--Testcase 274:
EXPLAIN VERBOSE
SELECT value1, atan2(1-value1, 1-value2) FROM s3 order by atan2(1-value1, 1-value2);

-- select atan2 with order by (result)
--Testcase 275:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 order by atan2(1-value1, 1-value2);

-- select atan2 with order by index (result)
--Testcase 276:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 order by 2,1;

-- select atan2 with order by index (result)
--Testcase 277:
SELECT value1, atan2(1-value1, 1-value2) FROM s3 order by 1,2;

-- select atan2 and as
--Testcase 278:
SELECT atan2(value3, value4) as atan21 FROM s3;

-- select atan2(*) (stub function, explain)
--Testcase 779:
EXPLAIN VERBOSE
SELECT atan2_all(value1) from s3;

-- select atan2(*) (stub function, result)
--Testcase 780:
SELECT atan2_all(value1) from s3;

-- select ceil (builtin function, explain)
--Testcase 279:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3;

-- select ceil (builtin function, result)
--Testcase 280:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 281:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 282:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 283:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 284:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4) FROM s3 WHERE value2 != 200;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 285:
EXPLAIN VERBOSE
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 286:
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 287:
EXPLAIN VERBOSE
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 288:
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 289:
EXPLAIN VERBOSE
SELECT ceil(value3), pi(), 4.1 FROM s3;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 290:
SELECT ceil(value3), pi(), 4.1 FROM s3;

-- select ceil with order by (explain)
--Testcase 291:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value1) FROM s3 order by ceil(1-value1);

-- select ceil with order by (result)
--Testcase 292:
SELECT value1, ceil(1-value1) FROM s3 order by ceil(1-value1);

-- select ceil with order by index (result)
--Testcase 293:
SELECT value1, ceil(1-value1) FROM s3 order by 2,1;

-- select ceil with order by index (result)
--Testcase 294:
SELECT value1, ceil(1-value1) FROM s3 order by 1,2;

-- select ceil and as
--Testcase 295:
SELECT ceil(value3) as ceil1 FROM s3;

-- select ceil(*) (stub agg function, explain)
--Testcase 783:
EXPLAIN VERBOSE
SELECT ceil_all() from s3;

-- select ceil(*) (stub agg function, result)
--Testcase 784:
SELECT ceil_all() from s3;

-- select ceil(*) (stub agg function and group by tag only) (explain)
--Testcase 785:
EXPLAIN VERBOSE
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select ceil(*) (stub agg function and group by tag only) (result)
--Testcase 786:
SELECT ceil_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select ceil(*) (stub agg function, expose data, explain)
--Testcase 787:
EXPLAIN VERBOSE
SELECT (ceil_all()::s3).* from s3;

-- select ceil(*) (stub agg function, expose data, result)
--Testcase 788:
SELECT (ceil_all()::s3).* from s3;

-- select cos (builtin function, explain)
--Testcase 296:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3;

-- select cos (builtin function, result)
--Testcase 297:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 298:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 299:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 300:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 301:
SELECT cos(value1), cos(value2), cos(value3), cos(value4) FROM s3 WHERE value2 != 200;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 302:
EXPLAIN VERBOSE
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest function with agg (pushdown, result)
--Testcase 303:
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 304:
EXPLAIN VERBOSE
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 305:
SELECT cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 306:
EXPLAIN VERBOSE
SELECT cos(value3), pi(), 4.1 FROM s3;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 307:
SELECT cos(value3), pi(), 4.1 FROM s3;

-- select cos with order by (explain)
--Testcase 308:
EXPLAIN VERBOSE
SELECT value1, cos(1-value1) FROM s3 order by cos(1-value1);

-- select cos with order by (result)
--Testcase 309:
SELECT value1, cos(1-value1) FROM s3 order by cos(1-value1);

-- select cos with order by index (result)
--Testcase 310:
SELECT value1, cos(1-value1) FROM s3 order by 2,1;

-- select cos with order by index (result)
--Testcase 311:
SELECT value1, cos(1-value1) FROM s3 order by 1,2;

-- select cos and as
--Testcase 312:
SELECT cos(value3) as cos1 FROM s3;

-- select cos(*) (stub agg function, explain)
--Testcase 789:
EXPLAIN VERBOSE
SELECT cos_all() from s3;

-- select cos(*) (stub agg function, result)
--Testcase 790:
SELECT cos_all() from s3;

-- select cos(*) (stub agg function and group by tag only) (explain)
--Testcase 791:
EXPLAIN VERBOSE
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select cos(*) (stub agg function and group by tag only) (result)
--Testcase 792:
SELECT cos_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select exp (builtin function, explain)
--Testcase 313:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3;

-- select exp (builtin function, result)
--Testcase 314:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 315:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 316:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 317:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 318:
SELECT exp(value1), exp(value2), exp(value3), exp(value4) FROM s3 WHERE value2 != 200;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 319:
EXPLAIN VERBOSE
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest function with agg (pushdown, result)
--Testcase 320:
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 321:
EXPLAIN VERBOSE
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp as nest with log2 (pushdown, result)
--Testcase 322:
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 323:
EXPLAIN VERBOSE
SELECT exp(value3), pi(), 4.1 FROM s3;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 324:
SELECT exp(value3), pi(), 4.1 FROM s3;

-- select exp with order by (explain)
--Testcase 325:
EXPLAIN VERBOSE
SELECT value1, exp(1-value1) FROM s3 order by exp(1-value1);

-- select exp with order by (result)
--Testcase 326:
SELECT value1, exp(1-value1) FROM s3 order by exp(1-value1);

-- select exp with order by index (result)
--Testcase 327:
SELECT value1, exp(1-value1) FROM s3 order by 2,1;

-- select exp with order by index (result)
--Testcase 328:
SELECT value1, exp(1-value1) FROM s3 order by 1,2;

-- select exp and as
--Testcase 329:
SELECT exp(value3) as exp1 FROM s3;

-- select exp(*) (stub agg function, explain)
--Testcase 793:
EXPLAIN VERBOSE
SELECT exp_all() from s3;

-- select exp(*) (stub agg function, result)
--Testcase 794:
SELECT exp_all() from s3;

-- select exp(*) (stub agg function and group by tag only) (explain)
--Testcase 795:
EXPLAIN VERBOSE
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select exp(*) (stub agg function and group by tag only) (result)
--Testcase 796:
SELECT exp_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 797:
SELECT ceil_all(), cos_all(), exp_all() FROM s3;

-- select floor (builtin function, explain)
--Testcase 330:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3;

-- select floor (builtin function, result)
--Testcase 331:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 332:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 333:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 334:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 335:
SELECT floor(value1), floor(value2), floor(value3), floor(value4) FROM s3 WHERE value2 != 200;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 336:
EXPLAIN VERBOSE
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest function with agg (pushdown, result)
--Testcase 337:
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 338:
EXPLAIN VERBOSE
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor as nest with log2 (pushdown, result)
--Testcase 339:
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 340:
EXPLAIN VERBOSE
SELECT floor(value3), pi(), 4.1 FROM s3;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 341:
SELECT floor(value3), pi(), 4.1 FROM s3;

-- select floor with order by (explain)
--Testcase 342:
EXPLAIN VERBOSE
SELECT value1, floor(1-value1) FROM s3 order by floor(1-value1);

-- select floor with order by (result)
--Testcase 343:
SELECT value1, floor(1-value1) FROM s3 order by floor(1-value1);

-- select floor with order by index (result)
--Testcase 344:
SELECT value1, floor(1-value1) FROM s3 order by 2,1;

-- select floor with order by index (result)
--Testcase 345:
SELECT value1, floor(1-value1) FROM s3 order by 1,2;

-- select floor and as
--Testcase 346:
SELECT floor(value3) as floor1 FROM s3;

-- select floor(*) (stub agg function, explain)
--Testcase 798:
EXPLAIN VERBOSE
SELECT floor_all() from s3;

-- select floor(*) (stub agg function, result)
--Testcase 799:
SELECT floor_all() from s3;

-- select floor(*) (stub agg function and group by tag only) (explain)
--Testcase 800:
EXPLAIN VERBOSE
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select floor(*) (stub agg function and group by tag only) (result)
--Testcase 801:
SELECT floor_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select floor(*) (stub agg function, expose data, explain)
--Testcase 802:
EXPLAIN VERBOSE
SELECT (floor_all()::s3).* from s3;

-- select floor(*) (stub agg function, expose data, result)
--Testcase 803:
SELECT (floor_all()::s3).* from s3;

-- select ln (builtin function, explain)
--Testcase 347:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3;

-- select ln (builtin function, result)
--Testcase 348:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 349:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 350:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 351:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 352:
SELECT ln(value1), ln(value2), ln(value3), ln(value4) FROM s3 WHERE value2 != 200;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 353:
EXPLAIN VERBOSE
SELECT sum(value3),ln(sum(value3)) FROM s3;

-- select ln as nest function with agg (pushdown, result)
--Testcase 354:
SELECT sum(value3),ln(sum(value3)) FROM s3;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 355:
EXPLAIN VERBOSE
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 356:
SELECT ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 357:
EXPLAIN VERBOSE
SELECT ln(value3), pi(), 4.1 FROM s3;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 358:
SELECT ln(value3), pi(), 4.1 FROM s3;

-- select ln with order by (explain)
--Testcase 359:
EXPLAIN VERBOSE
SELECT value1, ln(1-value1) FROM s3 order by ln(1-value1);

-- select ln with order by (result)
--Testcase 360:
SELECT value1, ln(1-value1) FROM s3 order by ln(1-value1);

-- select ln with order by index (result)
--Testcase 361:
SELECT value1, ln(1-value1) FROM s3 order by 2,1;

-- select ln with order by index (result)
--Testcase 362:
SELECT value1, ln(1-value1) FROM s3 order by 1,2;

-- select ln and as
--Testcase 363:
SELECT ln(value1) as ln1 FROM s3;

-- select ln(*) (stub agg function, explain)
--Testcase 804:
EXPLAIN VERBOSE
SELECT ln_all() from s3;

-- select ln(*) (stub agg function, result)
--Testcase 805:
SELECT ln_all() from s3;

-- select ln(*) (stub agg function and group by tag only) (explain)
--Testcase 806:
EXPLAIN VERBOSE
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select ln(*) (stub agg function and group by tag only) (result)
--Testcase 807:
SELECT ln_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 808:
SELECT ln_all(), floor_all() FROM s3;

-- select pow (builtin function, explain)
--Testcase 364:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3;

-- select pow (builtin function, result)
--Testcase 365:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 366:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 367:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 368:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 369:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 370:
EXPLAIN VERBOSE
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest function with agg (pushdown, result)
--Testcase 371:
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 372:
EXPLAIN VERBOSE
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 373:
SELECT pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 374:
EXPLAIN VERBOSE
SELECT pow(value3, 2), pi(), 4.1 FROM s3;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 375:
SELECT pow(value3, 2), pi(), 4.1 FROM s3;

-- select pow with order by (explain)
--Testcase 376:
EXPLAIN VERBOSE
SELECT value1, pow(1-value1, 2) FROM s3 order by pow(1-value1, 2);

-- select pow with order by (result)
--Testcase 377:
SELECT value1, pow(1-value1, 2) FROM s3 order by pow(1-value1, 2);

-- select pow with order by index (result)
--Testcase 378:
SELECT value1, pow(1-value1, 2) FROM s3 order by 2,1;

-- select pow with order by index (result)
--Testcase 379:
SELECT value1, pow(1-value1, 2) FROM s3 order by 1,2;

-- select pow and as
--Testcase 380:
SELECT pow(value3, 2) as pow1 FROM s3;

-- select pow_all(2) (stub agg function, explain)
--Testcase 809:
EXPLAIN VERBOSE
SELECT pow_all(2) from s3;

-- select pow_all(2) (stub agg function, result)
--Testcase 810:
SELECT pow_all(2) from s3;

-- select pow_all(2) (stub agg function and group by tag only) (explain)
--Testcase 811:
EXPLAIN VERBOSE
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select pow_all(2) (stub agg function and group by tag only) (result)
--Testcase 812:
SELECT pow_all(2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select pow_all(2) (stub agg function, expose data, explain)
--Testcase 813:
EXPLAIN VERBOSE
SELECT (pow_all(2)::s3).* from s3;

-- select pow_all(2) (stub agg function, expose data, result)
--Testcase 814:
SELECT (pow_all(2)::s3).* from s3;

-- select round (builtin function, explain)
--Testcase 381:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3;

-- select round (builtin function, result)
--Testcase 382:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 383:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select round (builtin function, not pushdown constraints, result)
--Testcase 384:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select round (builtin function, pushdown constraints, explain)
--Testcase 385:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200;

-- select round (builtin function, pushdown constraints, result)
--Testcase 386:
SELECT round(value1), round(value2), round(value3), round(value4) FROM s3 WHERE value2 != 200;

-- select round as nest function with agg (pushdown, explain)
--Testcase 387:
EXPLAIN VERBOSE
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest function with agg (pushdown, result)
--Testcase 388:
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest with log2 (pushdown, explain)
--Testcase 389:
EXPLAIN VERBOSE
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round as nest with log2 (pushdown, result)
--Testcase 390:
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round with non pushdown func and roundlicit constant (explain)
--Testcase 391:
EXPLAIN VERBOSE
SELECT round(value3), pi(), 4.1 FROM s3;

-- select round with non pushdown func and roundlicit constant (result)
--Testcase 392:
SELECT round(value3), pi(), 4.1 FROM s3;

-- select round with order by (explain)
--Testcase 393:
EXPLAIN VERBOSE
SELECT value1, round(1-value1) FROM s3 order by round(1-value1);

-- select round with order by (result)
--Testcase 394:
SELECT value1, round(1-value1) FROM s3 order by round(1-value1);

-- select round with order by index (result)
--Testcase 395:
SELECT value1, round(1-value1) FROM s3 order by 2,1;

-- select round with order by index (result)
--Testcase 396:
SELECT value1, round(1-value1) FROM s3 order by 1,2;

-- select round and as
--Testcase 397:
SELECT round(value3) as round1 FROM s3;

-- select round(*) (stub agg function, explain)
--Testcase 815:
EXPLAIN VERBOSE
SELECT round_all() from s3;

-- select round(*) (stub agg function, result)
--Testcase 816:
SELECT round_all() from s3;

-- select round(*) (stub agg function and group by tag only) (explain)
--Testcase 817:
EXPLAIN VERBOSE
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select round(*) (stub agg function and group by tag only) (result)
--Testcase 818:
SELECT round_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select round(*) (stub agg function, expose data, explain)
--Testcase 819:
EXPLAIN VERBOSE
SELECT (round_all()::s3).* from s3;

-- select round(*) (stub agg function, expose data, result)
--Testcase 820:
SELECT (round_all()::s3).* from s3;

-- select sin (builtin function, explain)
--Testcase 398:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3;

-- select sin (builtin function, result)
--Testcase 399:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 400:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 401:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 402:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 403:
SELECT sin(value1), sin(value2), sin(value3), sin(value4) FROM s3 WHERE value2 != 200;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 404:
EXPLAIN VERBOSE
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest function with agg (pushdown, result)
--Testcase 405:
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 406:
EXPLAIN VERBOSE
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 407:
SELECT sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 408:
EXPLAIN VERBOSE
SELECT sin(value3), pi(), 4.1 FROM s3;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 409:
SELECT sin(value3), pi(), 4.1 FROM s3;

-- select sin with order by (explain)
--Testcase 410:
EXPLAIN VERBOSE
SELECT value1, sin(1-value1) FROM s3 order by sin(1-value1);

-- select sin with order by (result)
--Testcase 411:
SELECT value1, sin(1-value1) FROM s3 order by sin(1-value1);

-- select sin with order by index (result)
--Testcase 412:
SELECT value1, sin(1-value1) FROM s3 order by 2,1;

-- select sin with order by index (result)
--Testcase 413:
SELECT value1, sin(1-value1) FROM s3 order by 1,2;

-- select sin and as
--Testcase 414:
SELECT sin(value3) as sin1 FROM s3;

-- select sin(*) (stub agg function, explain)
--Testcase 821:
EXPLAIN VERBOSE
SELECT sin_all() from s3;

-- select sin(*) (stub agg function, result)
--Testcase 822:
SELECT sin_all() from s3;

-- select sin(*) (stub agg function and group by tag only) (explain)
--Testcase 823:
EXPLAIN VERBOSE
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select sin(*) (stub agg function and group by tag only) (result)
--Testcase 824:
SELECT sin_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select tan (builtin function, explain)
--Testcase 825:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3;

-- select tan (builtin function, result)
--Testcase 826:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 827:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 828:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 829:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 830:
SELECT tan(value1), tan(value2), tan(value3), tan(value4) FROM s3 WHERE value2 != 200;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 831:
EXPLAIN VERBOSE
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest function with agg (pushdown, result)
--Testcase 832:
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 833:
EXPLAIN VERBOSE
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 834:
SELECT tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan with non pushdown func and tanlicit constant (explain)
--Testcase 835:
EXPLAIN VERBOSE
SELECT tan(value3), pi(), 4.1 FROM s3;

-- select tan with non pushdown func and tanlicit constant (result)
--Testcase 836:
SELECT tan(value3), pi(), 4.1 FROM s3;

-- select tan with order by (explain)
--Testcase 837:
EXPLAIN VERBOSE
SELECT value1, tan(1-value1) FROM s3 order by tan(1-value1);

-- select tan with order by (result)
--Testcase 838:
SELECT value1, tan(1-value1) FROM s3 order by tan(1-value1);

-- select tan with order by index (result)
--Testcase 839:
SELECT value1, tan(1-value1) FROM s3 order by 2,1;

-- select tan with order by index (result)
--Testcase 840:
SELECT value1, tan(1-value1) FROM s3 order by 1,2;

-- select tan and as
--Testcase 841:
SELECT tan(value3) as tan1 FROM s3;

-- select tan(*) (stub agg function, explain)
--Testcase 842:
EXPLAIN VERBOSE
SELECT tan_all() from s3;

-- select tan(*) (stub agg function, result)
--Testcase 843:
SELECT tan_all() from s3;

-- select tan(*) (stub agg function and group by tag only) (explain)
--Testcase 844:
EXPLAIN VERBOSE
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select tan(*) (stub agg function and group by tag only) (result)
--Testcase 845:
SELECT tan_all() FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select multiple star functions (do not push down, raise warning and stub error) (result)
--Testcase 846:
SELECT sin_all(), round_all(), tan_all() FROM s3;

-- select predictors function holt_winters() (explain)
--Testcase 415:
EXPLAIN VERBOSE
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters() (result)
--Testcase 416:
SELECT holt_winters(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters_with_fit() (explain)
--Testcase 417:
EXPLAIN VERBOSE
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select predictors function holt_winters_with_fit() (result)
--Testcase 418:
SELECT holt_winters_with_fit(min(value1), 5, 1) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s');

-- select count(*) function of InfluxDB (stub agg function, explain)
--Testcase 847:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3;

-- select count(*) function of InfluxDB (stub agg function, result)
--Testcase 848:
SELECT influx_count_all(*) FROM s3;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (explain)
--Testcase 849:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select count(*) function of InfluxDB (stub agg function and group by influx_time() and tag) (result)
--Testcase 850:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (explain)
--Testcase 851:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select count(*) function of InfluxDB (stub agg function and group by tag only) (result)
--Testcase 852:
SELECT influx_count_all(*) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select count(*) function of InfluxDB over join query (explain)
--Testcase 854:
EXPLAIN VERBOSE
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select count(*) function of InfluxDB over join query (result, stub call error)
--Testcase 855:
SELECT influx_count_all(*) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select distinct (stub agg function, explain)
--Testcase 858:
EXPLAIN VERBOSE
SELECT influx_distinct(value1) FROM s3;

-- select distinct (stub agg function, result)
--Testcase 859:
SELECT influx_distinct(value1) FROM s3;

-- select distinct (stub agg function and group by influx_time() and tag) (explain)
--Testcase 860:
EXPLAIN VERBOSE
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select distinct (stub agg function and group by influx_time() and tag) (result)
--Testcase 861:
SELECT influx_distinct(value1), influx_time(time, interval '1s'),tag1 FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY influx_time(time, interval '1s'), tag1;

-- select distinct (stub agg function and group by tag only) (explain)
--Testcase 862:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select distinct (stub agg function and group by tag only) (result)
--Testcase 863:
SELECT influx_distinct(value2) FROM s3 WHERE time >= to_timestamp(0) and time <= to_timestamp(4) GROUP BY tag1;

-- select distinct over join query (explain)
--Testcase 865:
EXPLAIN VERBOSE
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select distinct over join query (result, stub call error)
--Testcase 866:
SELECT influx_distinct(t1.value2) FROM s3 t1 INNER JOIN s3 t2 ON (t1.value1 = t2.value1) where t1.value1 = 0.1;

-- select distinct with having (explain)
--Testcase 867:
EXPLAIN VERBOSE
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100;

-- select distinct with having (result, not pushdown, stub call error)
--Testcase 868:
SELECT influx_distinct(value2) FROM s3 HAVING influx_distinct(value2) > 100;

--Testcase 62:
DROP FOREIGN TABLE s3;

--Testcase 68:
CREATE FOREIGN TABLE b3(time timestamp with time zone, tag1 text, value1 float8, value2 bigint, value3 bool) SERVER server1 OPTIONS(table 'b3', tags 'tag1');

-- bool type var in where clause (result)
--Testcase 69:
EXPLAIN VERBOSE
SELECT sqrt(abs(value1)) FROM b3 WHERE value3 != true ORDER BY 1;

-- bool type var in where clause (result)
--Testcase 70:
SELECT sqrt(abs(value1)) FROM b3 WHERE value3 != true ORDER BY 1;

--Testcase 71:
DROP FOREIGN TABLE b3;

--Testcase 63:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 64:
DROP SERVER server1;
--Testcase 65:
DROP EXTENSION influxdb_fdw CASCADE;
