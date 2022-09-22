SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='UTC';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

-- Init data original
\! influx -import -path=init/multikey_original.txt -precision=ns > /dev/null
-- Before update data
--Testcase 1:
CREATE EXTENSION influxdb_fdw CASCADE;
--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'schemalessdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE sctbl3 (time timestamp with time zone, fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true');

-------------------------------------------------TC for before update test data------------------
-- Select all data with condition and combine clause
--Testcase 5:
SELECT * FROM sctbl3 WHERE time='2020-01-09 01:00:00+00' OR (fields->>'c3')::bigint=3 OR (fields->>'c3')::bigint=10.746 ORDER BY fields->>'c2';
--Testcase 6:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE (fields->>'c3')::bigint IN (-1,1,0,2,-2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 7:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE true ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 0;
--Testcase 8:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE false ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 0;
--Testcase 9:
SELECT * FROM sctbl3 WHERE (fields->>'c5')::bool= true;
--Testcase 10:
SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint BETWEEN 0 AND 1000 ORDER BY fields->>'c2', (fields->>'c3')::bigint;
--Testcase 11:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE fields->>'c2' LIKE 'C%' AND (fields->>'c5')::bool!= true  ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 12:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE NOT EXISTS (SELECT fields->>'c2' FROM sctbl3 WHERE fields->>'c2'='abcd') ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 13:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE (fields->>'c3')::bigint < ALL (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint>0) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;

-- Select aggregate function  and specific column from original table
--Testcase 14:
SELECT time, fields->>'c2' c2 FROM sctbl3 WHERE fields->>'c2'<='$' OR (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 ORDER BY 1 ASC,2 DESC LIMIT 25 OFFSET 8;
--Testcase 15:
SELECT max((fields->>'c3')::bigint), count(*), exists(SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>1), exists (SELECT count(*) FROM sctbl3 WHERE (fields->>'c3')::bigint>10.5) FROM view_sctbl3 WHERE time>= '2000-1-3 20:30:51' GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC,3 ASC,4 LIMIT 25 OFFSET 8;
--Testcase 16:
SELECT max(time), max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)+10, max((fields->>'c3')::bigint)-10, max((fields->>'c4')::double precision), max((fields->>'c4')::double precision)/2 FROM sctbl3 GROUP BY fields->>'c2';
--Testcase 17:
SELECT count(fields->>'c2'), (fields->>'c3')::bigint c3, fields->>'c4' c4 from sctbl3 GROUP BY fields->>'c2';
--Testcase 18:
SELECT 32 + (fields->>'c3')::bigint, (fields->>'c3')::bigint + (fields->>'c3')::bigint from sctbl3 GROUP  BY fields->>'c3', fields->>'c5', fields->>'c2' ORDER BY fields->>'c2';
--Testcase 19:
SELECT max(fields->>'c2'), min((fields->>'c3')::bigint), max((fields->>'c3')::bigint)  from sctbl3 GROUP BY fields->>'c3' ORDER BY (fields->>'c3')::bigint;
--Testcase 20:
SELECT sum((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC;
--Testcase 21:
SELECT count(*), count(time), count (DISTINCT (fields->>'c3')::bigint), count (ALL (fields->>'c3')::bigint) FROM sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 22:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 23:
SELECT string_agg(fields->>'c2', ';' ORDER BY fields->>'c2') FROM sctbl3 GROUP BY fields->>'c2' ORDER BY 1;
--Testcase 24:
SELECT every((fields->>'c3')::bigint>0), every((fields->>'c3')::bigint != (fields->>'c3')::bigint) FROM sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 25:
SELECT bool_and((fields->>'c3')::bigint <> 10) AND true, bool_and(fields->>'c2' != 'aghsjfh'), bool_and((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false from sctbl3 ORDER BY 1,2,3;
--Testcase 26:
SELECT bool_or((fields->>'c4')::double precision <> 10) AND true, bool_or(fields->>'c2' != 'aghsjfh'), bool_or((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false from sctbl3 ORDER BY 1,2,3;

-- Select combine aggregate via operation
--Testcase 27:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 GROUP BY time ORDER BY 1 ASC;
--Testcase 28:
SELECT max(time), max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)+10, max((fields->>'c3')::bigint)-10, max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)/2 FROM sctbl3 GROUP BY fields->>'c2';
--Testcase 29:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint+(fields->>'c3')::bigint), sum((fields->>'c3')::bigint*2), sum((fields->>'c3')::bigint)-5 FROM sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 30:
SELECT avg((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), avg((fields->>'c3')::bigint), avg((fields->>'c3')::bigint)-10, avg((fields->>'c3')::bigint)*0.5 FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 31:
SELECT array_agg((fields->>'c3')::bigint/2 ORDER BY (fields->>'c3')::bigint), array_agg(fields->>'c2' ORDER BY fields->>'c2'), array_agg(time ORDER BY time) FROM sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 32:
SELECT bit_and((fields->>'c3')::bigint), bit_and((fields->>'c3')::bigint+15) FROM sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 33:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 34:
SELECT bool_and((fields->>'c3')::bigint>0), bool_and((fields->>'c3')::bigint<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint) FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 DESC, 2, 3;
--Testcase 35:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM sctbl3 WHERE (fields->>'c3')::bigint NOT IN (0, 1000, -1, -2) GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 36:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM sctbl3 WHERE NOT (fields->>'c3')::bigint=5 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 37:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE NOT time>'2020-1-3 20:30:50' GROUP BY fields->>'c2', fields->>'c3', fields->>'c3' HAVING sum((fields->>'c3')::bigint)>avg((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 8;
--Testcase 38:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE ((fields->>'c3')::bigint-1)/(fields->>'c3')::bigint=1 GROUP BY time ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 39:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE (fields->>'c3')::bigint IN (-1,1,0,2,-2) GROUP BY fields->>'c3', fields->>'c3'HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
-- Select from sub query
--Testcase 40:
SELECT time, fields->>'c2' c2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c4')::double precision<1000 ) AS sctbl3;
--Testcase 41:
SELECT time, fields->>'c2' c2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3;
--Testcase 42:
SELECT max(time), max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)+10, max((fields->>'c3')::bigint)-10, max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)/2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY fields->>'c2' ORDER BY 1;
--Testcase 43:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 44:
SELECT sqrt(abs((fields->>'c3')::bigint)), sqrt(abs((fields->>'c3')::bigint)) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 ORDER BY 1 ASC,2 DESC;
--Testcase 45:
SELECT * FROM ( SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE time='2020-01-09 01:00:00+00' AND c3=0 AND c3=10.746 ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 46:
SELECT * FROM ( SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5 FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE c3>10.746 OR c2 != 'Hello' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 47:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE (fields->>'c3')::bigint != -1 AND (fields->>'c5')::bool != true GROUP BY fields->>'c2' ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 8;

-- Within group
--Testcase 48:
--SELECT (fields->>'c5')::bool (fields->>'c5')::bool, mode((fields->>'c3')::bigint) WITHIN GROUP (ORDER BY (fields->>'c3')::bigint) AS m1 from sctbl3 GROUP BY (fields->>'c5')::bool;

-- Select from view
--Testcase 49:
create view view_sctbl3 as select * from sctbl3 where ((fields->>'c3')::bigint != 6789);
--Testcase 50:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 51:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM view_sctbl3 GROUP BY fields->>'c5' HAVING (fields->>'c5')::bool != true ORDER BY 1 ASC,2 DESC;
--Testcase 52:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 53:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint+(fields->>'c3')::bigint), sum((fields->>'c3')::bigint*2), sum((fields->>'c3')::bigint)-5 FROM view_sctbl3 GROUP BY fields->>'c2' ORDER BY 1 DESC, 2, 3;
--Testcase 54:
SELECT avg((fields->>'c3')::bigint-(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint-(fields->>'c3')::bigint), avg((fields->>'c3')::bigint)>50 FROM view_sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 55:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM view_sctbl3 GROUP BY (fields->>'c3')::bigint, fields->>'c3' HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 56:
SELECT bool_and((fields->>'c3')::bigint>0), bool_and((fields->>'c3')::bigint<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 57:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5
 FROM view_sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 8;
 --Testcase 58:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5
 FROM view_sctbl3 WHERE (fields->>'c3')::bigint>10.746 OR fields->>'c2' != 'Hello' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;
--Testcase 59:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5
 FROM view_sctbl3 WHERE NOT (fields->>'c3')::bigint<(fields->>'c3')::bigint ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;
--Testcase 60:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5
 FROM view_sctbl3 WHERE true ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;
--Testcase 61:
SELECT time,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4,(fields->>'c5')::bool c5
 FROM view_sctbl3 WHERE (fields->>'c3')::bigint IN (-1,1,0,2,-2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;

-- Select many target aggregate in one query and combine with condition
--Testcase 62:
SELECT upper(fields->>'c2'), upper(fields->>'c2'), lower(fields->>'c2'), lower(fields->>'c2') FROM sctbl3 ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 63:
SELECT max(time), min((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), count(*), avg((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 64:
SELECT (fields->>'c3')::bigint*(random()<=1)::int, (random()<=1)::int*(25-10)+10 FROM sctbl3 ORDER BY 1 ASC,2 DESC;
--Testcase 65:
SELECT max((fields->>'c3')::bigint), count(*), exists(SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>1), exists (SELECT count(*) FROM sctbl3 WHERE (fields->>'c3')::bigint>10.5) FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 66:
SELECT sum((fields->>'c3')::bigint) filter (WHERE (fields->>'c3')::bigint<100 and (fields->>'c3')::bigint>-100), avg((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) filter (WHERE (fields->>'c3')::bigint >0 AND (fields->>'c3')::bigint<100) FROM sctbl3 GROUP BY (fields->>'c5')::bool HAVING (fields->>'c5')::bool != true ORDER BY 1 ASC,2 DESC;
--Testcase 67:
SELECT 'abcd', 1234, (fields->>'c3')::bigint/2, 10+(fields->>'c3')::bigint * (random()<=1)::int * 0.5 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 68:
SELECT count((fields->>'c3')::bigint), bit_and((fields->>'c3')::bigint) FROM sctbl3 GROUP BY influx_time(time, interval '2d') ORDER BY 1;
--Testcase 69:
SELECT max((fields->>'c3')::bigint), min((fields->>'c4')::double precision), avg((fields->>'c3')::bigint), count((fields->>'c3')::bigint) FROM sctbl3 WHERE time > '2020-01-10 00:00:00' AND time < '2020-01-15 00:00:00' GROUP BY influx_time(time, interval '1d', interval '10h30m') ORDER BY 1 ASC, 2 DESC, 3 ASC, 4 DESC;
--Testcase 70:
SELECT min(time), max(time), count(time) FROM sctbl3 GROUP BY (fields->>'c3') ORDER BY 1,2,3;
--Testcase 71:
SELECT count((fields->>'c3')::bigint), max((fields->>'c3')::bigint), sum((fields->>'c3')::bigint) FROM sctbl3 GROUP BY fields->>'c3' HAVING(max(fields->>'c2')!='HELLO' and count(fields->>'c2')>1) ORDER BY 1,2,3;
--Testcase 72:
SELECT count(fields->>'c2'), bit_and((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint), bool_and((fields->>'c5')::bool) FROM sctbl3 GROUP BY fields->>'c2' ORDER BY 1,2,3,4;
--Testcase 73:
SELECT array_agg((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint), array_agg((fields->>'c3')::bigint/(fields->>'c3')::bigint*(fields->>'c3')::bigint), array_agg(((fields->>'c3')::bigint+(fields->>'c3')::bigint/(fields->>'c3')::bigint)*-1000), array_agg((fields->>'c3')::bigint*(fields->>'c3')::bigint-(fields->>'c3')::bigint), array_agg(((fields->>'c3')::bigint-(fields->>'c3')::bigint+(fields->>'c3')::bigint)+9999999999999.998) from sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint ORDER BY 1, 2, 3, 4, 5;
--Testcase 74:
SELECT avg((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint)-0.567-avg((fields->>'c3')::bigint/3+(fields->>'c3')::bigint)+17.55435, avg((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint+45))- -9.5+2*avg((fields->>'c3')::bigint), avg((fields->>'c3')::bigint/((fields->>'c3')::bigint-10.2)*(fields->>'c3')::bigint)+0.567+avg((fields->>'c3')::bigint)*4.5+(fields->>'c3')::bigint, avg((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint+5.6))+100-(fields->>'c3')::bigint from sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746  GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4 limit 5;
--Testcase 75:
SELECT bit_and((fields->>'c3')::bigint/3*(fields->>'c3')::bigint)-1 + bit_and((fields->>'c3')::bigint/4/((fields->>'c3')::bigint+6)),2* bit_and((fields->>'c3')::bigint-(fields->>'c3')::bigint+(fields->>'c3')::bigint)*1, 5-bit_and((fields->>'c3')::bigint+(fields->>'c3')::bigint-(fields->>'c3')::bigint)-1000000+(fields->>'c3')::bigint  from sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 GROUP BY fields->>'c3' ORDER BY 1,2,3;
--Testcase 76:
SELECT bit_or((fields->>'c3')::bigint/3*(fields->>'c3')::bigint)-1 + bit_or((fields->>'c3')::bigint/4/((fields->>'c3')::bigint+6)),2* bit_or((fields->>'c3')::bigint-(fields->>'c3')::bigint+(fields->>'c3')::bigint)*1, 5-bit_or((fields->>'c3')::bigint+(fields->>'c3')::bigint-(fields->>'c3')::bigint)-1000000+(fields->>'c3')::bigint  from sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 GROUP BY fields->>'c3' ORDER BY 1,2,3;
--Testcase 77:
SELECT count(*)-5.6, 2*count(*), 10.2/count(*)+count(*)-(fields->>'c3')::bigint from sctbl3 WHERE (fields->>'c3')::bigint>0.774 OR fields->>'c2' = 'Which started out as a kind' GROUP BY fields->>'c3' ORDER BY 1, 2, 3;
--Testcase 78:
SELECT count(fields->>'c2')-2*count((fields->>'c3')::bigint), count((fields->>'c3')::bigint)/count((fields->>'c5')::bool)-(fields->>'c3')::bigint from sctbl3 GROUP BY fields->>'c5', fields->>'c3' order by 1, 2 limit 1;
--Testcase 79:
SELECT every((fields->>'c3')::bigint != 5.5) AND true, every((fields->>'c3')::bigint <> 10) OR every((fields->>'c3')::bigint > 5.6), every((fields->>'c3')::bigint <= 2) OR (fields->>'c5')::bool from sctbl3 GROUP BY (fields->>'c5')::bool ORDER BY 1,2,3 limit 6;
--Testcase 80:
SELECT stddev((fields->>'c3')::bigint*3-(fields->>'c3')::bigint)*1000000-(fields->>'c3')::bigint, stddev((fields->>'c3')::bigint)-0.567, stddev((fields->>'c3')::bigint/((fields->>'c3')::bigint-1.3))/6, stddev((fields->>'c3')::bigint+4*(fields->>'c3')::bigint)*100, stddev((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint-52.1))+1 from sctbl3 WHERE (fields->>'c3')::bigint<0 GROUP BY fields->>'c3' ORDER BY 1,2,3,4,5 ;
--Testcase 81:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint-(fields->>'c3')::bigint)-6, sum((fields->>'c3')::bigint/((fields->>'c3')::bigint+9999999)-(fields->>'c3')::bigint)*9999999999999.998, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint/((fields->>'c3')::bigint+111111))*-9.5, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint)/17.55435, sum((fields->>'c3')::bigint+(fields->>'c3')::bigint+(fields->>'c3')::bigint)*6 from sctbl3;
--Testcase 82:
SELECT sum((fields->>'c3')::bigint-(fields->>'c3')::bigint)-6+sum((fields->>'c3')::bigint), sum((fields->>'c3')::bigint*1.3-(fields->>'c3')::bigint)*9.998-sum((fields->>'c3')::bigint)*4, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint/4)*-9.5-(fields->>'c3')::bigint, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint)/17.55435+(fields->>'c3')::bigint, sum((fields->>'c3')::bigint+(fields->>'c3')::bigint+(fields->>'c3')::bigint)*6-(fields->>'c3')::bigint-(fields->>'c3')::bigint from sctbl3 GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4,5;
--Testcase 83:
SELECT max((fields->>'c4')::double precision), max((fields->>'c3')::bigint)+(fields->>'c3')::bigint-1, max((fields->>'c3')::bigint+(fields->>'c3')::bigint)-(fields->>'c3')::bigint-3, max((fields->>'c3')::bigint)+max((fields->>'c3')::bigint) from sctbl3 WHERE (fields->>'c4')::double precision>= 0 GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4;
--Testcase 84:
SELECT min(fields->>'c2'), min((fields->>'c3')::bigint)+(fields->>'c3')::bigint-1, min((fields->>'c3')::bigint+(fields->>'c3')::bigint)-(fields->>'c3')::bigint-3, min((fields->>'c3')::bigint)+min((fields->>'c3')::bigint) from sctbl3 WHERE (fields->>'c4')::double precision<0 GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4;
--Testcase 85:
SELECT variance((fields->>'c3')::bigint+(fields->>'c3')::bigint)+(fields->>'c3')::bigint, variance((fields->>'c3')::bigint*3)+(fields->>'c3')::bigint+1, variance((fields->>'c3')::bigint-2)+10 from sctbl3 GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3;
--Testcase 86:
SELECT sqrt(abs((fields->>'c3')::bigint*5)) + sqrt(abs((fields->>'c3')::bigint+6)), sqrt(abs((fields->>'c3')::bigint)+5)+(fields->>'c3')::bigint, 4*sqrt(abs((fields->>'c3')::bigint-100))-(fields->>'c3')::bigint from sctbl3 WHERE (fields->>'c3')::bigint<ALL (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint>0) ORDER BY 1, 2, 3;
--Testcase 87:
SELECT max((fields->>'c3')::bigint)+min((fields->>'c3')::bigint)+3, min((fields->>'c3')::bigint)-sqrt(abs((fields->>'c3')::bigint-45.21))+(fields->>'c3')::bigint*2, count(*)-count((fields->>'c5')::bool)+2, (fields->>'c5')::bool c5, (fields->>'c3')::bigint c3 from sctbl3 GROUP BY fields->>'c3', fields->>'c3', fields->>'c5' ORDER BY 1,2,3,4;
--Testcase 88:
SELECT variance((fields->>'c3')::bigint)-5*min((fields->>'c3')::bigint)-1, every((fields->>'c5')::bool <> true), max((fields->>'c3')::bigint+4.56)*3-min((fields->>'c3')::bigint), count((fields->>'c3')::bigint)-4 from sctbl3 WHERE (fields->>'c3')::bigint=ANY (ARRAY[1,2,3]) ORDER BY 1,2,3,4;
--Testcase 89:
SELECT (fields->>'c3')::bigint-30, (fields->>'c3')::bigint-10, sum((fields->>'c3')::bigint)/3-(fields->>'c3')::bigint, min((fields->>'c3')::bigint)+(fields->>'c3')::bigint/4, (fields->>'c5')::bool c5 from sctbl3 GROUP BY fields->>'c3', fields->>'c3', fields->>'c5' ORDER BY 1,2,3,4,5;


---------------------------------------------------------- Update data: add 1 tag and 1 fields-------------------------------------------------------------------------------------------------
-- Update data
\! influx -import -path=init/multikey_add_1tag_1field.txt -precision=ns > /dev/null
--Testcase 202:
drop view if exists view_sctbl3 ;
--Testcase 203:
drop foreign table if exists sctbl3;

--Testcase 204:
CREATE FOREIGN TABLE sctbl3 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 't1');

-- Select all data with condition and combine clause
--Testcase 90:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM sctbl3 WHERE (fields->>'c3')::bigint=ANY (ARRAY[1,2,3]) ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 91:
SELECT * FROM sctbl3 WHERE EXISTS (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint != 40.772) ORDER BY tags->>'t1';
--Testcase 92:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM sctbl3 WHERE fields->>'c2'=ANY (ARRAY(SELECT fields->>'c2' FROM sctbl3 WHERE (fields->>'c3')::bigint%2=0)) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 0;
--Testcase 93:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM sctbl3 WHERE  NOT EXISTS (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint=40.772) ORDER BY 1 DESC,2 ASC,3 DESC,4;
--Testcase 94:
SELECT * FROM sctbl3 WHERE fields->>'c2' IS NULL OR tags->>'t1' LIKE 'afefea' ORDER BY (fields->>'c1')::bool, fields->>'c2';
--Testcase 95:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM sctbl3 WHERE fields->>'c2' IS NOT NULL ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 96:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM sctbl3 WHERE NOT (fields->>'c3')::bigint=5 ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;

-- Select aggregate function  and specific column from original table
--Testcase 97:
SELECT tags->>'t1' t1, (fields->>'c1')::bool c1, max(tags->>'t1'), sum((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM sctbl3 GROUP BY tags->>'t1', (fields->>'c1')::bool, (fields->>'c3')::bigint, fields->>'c2' ORDER BY 1;
--Testcase 98:
SELECT sum((fields->>'c3')::bigint), tags->>'t1' t1, sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), fields->>'c1' c1 FROM sctbl3 GROUP BY fields->>'c1', fields->>'c3', fields->>'c3', tags->>'t1' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC;
--Testcase 99:
SELECT stddev((fields->>'c3')::bigint), (fields->>'c1')::bool c1, stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), tags->>'t1' t1 FROM sctbl3 GROUP BY time, fields->>'c3', tags->>'t1', fields->>'c1' ORDER BY tags->>'t1' ASC,fields->>'c1' DESC;
--Testcase 100:
SELECT every((fields->>'c3')::bigint>0), (fields->>'c1')::bool c1, every((fields->>'c3')::bigint != (fields->>'c3')::bigint) FROM sctbl3 GROUP BY time, fields->>'c1', fields->>'c3' ORDER BY (fields->>'c1')::bool ASC, (fields->>'c3')::bigint DESC;
--Testcase 101:
SELECT bool_and((fields->>'c3')::bigint <> 10) AND true, bool_and((fields->>'c1')::bool), bool_and(fields->>'c2' != 'aghsjfh'), bool_and((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false from sctbl3 ORDER BY 1,2,3;
--Testcase 102:
SELECT bool_or((fields->>'c4')::double precision <> 10) AND true, bool_or(fields->>'c2' != 'aghsjfh'), bool_or((fields->>'c1')::bool), bool_or((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false, tags->>'t1' t1 from sctbl3 GROUP BY (fields->>'c1')::bool, tags->>'t1', fields->>'c2', (fields->>'c3')::bigint ORDER BY (fields->>'c1')::bool, tags->>'t1';

-- Select combine aggregate via operation
--Testcase 103:
SELECT max(time), max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)+10, max((fields->>'c3')::bigint)-10, max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)/2, max(tags->>'t1') FROM sctbl3 GROUP BY fields->>'c2', tags->>'t1';
--Testcase 104:
SELECT array_agg((fields->>'c3')::bigint/2 ORDER BY (fields->>'c3')::bigint), array_agg((fields->>'c1')::bool), array_agg(tags->>'t1'), array_agg(fields->>'c2' ORDER BY fields->>'c2'), array_agg(time ORDER BY time) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY fields->>'c5' HAVING (fields->>'c5')::boolean != true ORDER BY 1 DESC, 2, 3;
--Testcase 105:
SELECT bit_and((fields->>'c3')::bigint), bit_and((fields->>'c3')::bigint+15) FROM sctbl3 GROUP BY fields->>'c2', fields->>'c3', fields->>'c3' HAVING sum((fields->>'c3')::bigint)>avg((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC;
--Testcase 106:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 107:
SELECT bool_and((fields->>'c3')::bigint>0), bool_and((fields->>'c1')::bool), bool_and((fields->>'c3')::bigint<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint) FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 DESC, 2, 3;
--Testcase 108:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM sctbl3 WHERE EXISTS (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint=40.772) GROUP BY tags->>'t1', fields->>'c5' HAVING (fields->>'c5')::bool != true ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 8;
--Testcase 109:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM sctbl3 WHERE fields->>'c2' IS NOT NULL GROUP BY fields->>'c3', fields->>'c1' HAVING min((fields->>'c3')::bigint)>=min((fields->>'c3')::bigint) ORDER BY (fields->>'c1')::bool DESC, 2, 3;
--Testcase 110:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint), min(tags->>'t1') FROM sctbl3 WHERE ((fields->>'c3')::bigint-1)/(fields->>'c3')::bigint=1 GROUP BY fields->>'c2', fields->>'c3', fields->>'c3' HAVING sum((fields->>'c3')::bigint)>avg((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 8;
--Testcase 111:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE ((fields->>'c3')::bigint-1)/(fields->>'c3')::bigint=1 GROUP BY time ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 112:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE (fields->>'c3')::bigint IN (-1,1,0,2,-2) GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint, tags->>'t1', (fields->>'c4')::double precision HAVING max((fields->>'c3')::bigint)>min((fields->>'c4')::double precision) ORDER BY tags->>'t1' ASC LIMIT 5 OFFSET 0;
-- Select from sub query
--Testcase 113:
SELECT time, fields->>'c2' c2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3;
--Testcase 114:
SELECT max(time), max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)+10, max((fields->>'c3')::bigint)-10, max((fields->>'c3')::bigint), max((fields->>'c3')::bigint)/2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c1')::bool = true ) AS sctbl3 GROUP BY fields->>'c2' ORDER BY 1;
--Testcase 115:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM ( SELECT * FROM sctbl3 WHERE tags->>'t1' LIKE 't1là' ) AS sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 116:
SELECT sqrt(abs((fields->>'c3')::bigint)), sqrt(abs((fields->>'c3')::bigint)) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 ORDER BY 1 ASC,tags->>'t1' DESC;
--Testcase 117:
SELECT tags->>'t1' t1, (fields->>'c1')::bool c1, (fields->>'c3')::bigint c3 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE fields->>'c2' LIKE 'C%' ORDER BY tags->>'t1' DESC,fields->>'c2' ASC LIMIT 25 OFFSET 0;
--Testcase 118:
SELECT (fields->>'c1')::bool c1, tags->>'t1' t1, (fields->>'c4')::double precision c4 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c4')::double precision>-1000 OR (fields->>'c3')::bigint<1000 ) AS tb3 WHERE NOT EXISTS (SELECT fields->>'c2' FROM sctbl3 WHERE fields->>'c2'='abcd') ORDER BY 1 DESC,2 ASC;
--Testcase 119:
SELECT tags->>'t1' t1, (fields->>'c1')::bool c1, fields->>'c2' c2  FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c1')::bool != TRUE ) AS tb3 WHERE (fields->>'c3')::bigint NOT IN (345245, 1000, -132, -254) ORDER BY 1 DESC,2 ASC,3 LIMIT 5;
--Testcase 120:
SELECT (fields->>'c1')::bool c1, fields->>'c2' c2, (fields->>'c4')::double precision c4 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE fields->>'c2'=ANY (ARRAY(SELECT fields->>'c2' FROM sctbl3 WHERE (fields->>'c3')::bigint%2=0)) ORDER BY tags->>'t1';
--Testcase 121:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10), max(tags->>'t1') FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE true GROUP BY fields->>'c2' ORDER BY 1 DESC, 2, 3 LIMIT 25 OFFSET 8;

-- Select from view
--Testcase 122:
create view view_sctbl3 as select * from sctbl3 where ((fields->>'c1')::bool != false);
--Testcase 123:
SELECT stddev((fields->>'c3')::bigint), tags->>'t1' t1, stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY time, tags->>'t1' ORDER BY 1 ASC,2 DESC;
--Testcase 124:
SELECT tags->>'t1' t1 , max((fields->>'c3')::bigint), count(*), exists(SELECT * FROM sctbl3 WHERE (fields->>'c1')::bool=false), exists (SELECT count(*) FROM sctbl3 WHERE (fields->>'c3')::bigint>10.5) FROM view_sctbl3 WHERE time <= '2000-1-3 20:30:51' GROUP BY fields->>'c2', tags->>'t1' ORDER BY 1 ASC,2 DESC,3 ASC,4 LIMIT 25;
--Testcase 125:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM view_sctbl3 GROUP BY (fields->>'c5')::bool HAVING (fields->>'c5')::bool != true ORDER BY 1 ASC,2 DESC;
--Testcase 126:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10), max(tags->>'t1') FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 127:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint+(fields->>'c3')::bigint), sum((fields->>'c3')::bigint*2), sum((fields->>'c3')::bigint)-5 FROM view_sctbl3 GROUP BY fields->>'c1' ORDER BY 1 DESC, 2, 3;
--Testcase 128:
SELECT avg((fields->>'c3')::bigint-(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint-(fields->>'c3')::bigint), avg((fields->>'c3')::bigint)>50 FROM view_sctbl3 GROUP BY (fields->>'c1')::bool, (fields->>'c3')::bigint HAVING (fields->>'c1')::bool=true AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 129:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM view_sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 130:
SELECT bool_and((fields->>'c3')::bigint>0), bool_and((fields->>'c3')::bigint<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY fields->>'c1' ORDER BY 1 DESC, 2, 3;
--Testcase 131:
SELECT time,tags->>'t1' t1,(fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5 FROM view_sctbl3 WHERE fields->>'c2'<='$' OR (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 20;
--Testcase 132:
SELECT * FROM view_sctbl3 WHERE (fields->>'c3')::bigint>10.746 OR fields->>'c2' != 'Hello' ORDER BY 1 DESC,2 ASC,3;
--Testcase 133:
SELECT * FROM view_sctbl3 WHERE NOT (fields->>'c3')::bigint<(fields->>'c3')::bigint ORDER BY (fields->>'c1')::bool ASC LIMIT 5;
--Testcase 134:
SELECT * FROM view_sctbl3 WHERE true ORDER BY (fields->>'c1')::bool DESC,tags->>'t1' LIMIT 5;
--Testcase 135:
SELECT * FROM view_sctbl3 WHERE (fields->>'c3')::bigint NOT IN (-1,1,0,2,-2) ORDER BY tags->>'t1' DESC;

-- Select many target aggregate in one query and combine with (fields->>'c1')::bool
--Testcase 136:
SELECT upper(fields->>'c2'), lower(fields->>'c2'), lower(tags->>'t1') FROM sctbl3 ORDER BY 1 ASC,2 DESC,3;
--Testcase 137:
SELECT max(time), min((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), count(*), count(tags->>'t1'), avg((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 138:
SELECT (fields->>'c3')::bigint*(random()<=1)::int, (random()<=1)::int*(25-10)+10 FROM sctbl3 ORDER BY tags->>'t1' ASC,fields->>'c1' DESC;
--Testcase 139:
SELECT max((fields->>'c3')::bigint), count(*), exists(SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>1), exists (SELECT count(*) FROM sctbl3 WHERE (fields->>'c3')::bigint>10.5) FROM sctbl3 GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 140:
SELECT sum((fields->>'c3')::bigint) filter (WHERE (fields->>'c1')::bool = true), avg((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint) filter (WHERE (fields->>'c3')::bigint >0 AND (fields->>'c3')::bigint<100) FROM sctbl3 GROUP BY fields->>'c5' HAVING (fields->>'c5')::bool != true ORDER BY 1 ASC,2 DESC;
--Testcase 141:
SELECT 'abcd', 1234, (fields->>'c3')::bigint/2, 10+(fields->>'c3')::bigint * (random()<=1)::int * 0.5 FROM ( SELECT * FROM sctbl3 WHERE tags->>'t1' LIKE 't1' ) AS sctbl3 ORDER BY 1 ASC,2 DESC,3 ASC,4;
--Testcase 142:
SELECT max((fields->>'c3')::bigint), min(tags->>'t1'), avg((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), count((fields->>'c3')::bigint) FROM  sctbl3 WHERE time > '1970-01-10 00:00:00' AND time < '2020-01-15 00:00:00' GROUP BY influx_time(time, interval '1d', interval '10h30m') ORDER BY 1,2,3,4,5;
--Testcase 143:
SELECT min(time), max(time), count(time) FROM sctbl3 GROUP BY fields->>'c3' ORDER BY 1,2,3;
--Testcase 144:
SELECT count((fields->>'c3')::bigint), max((fields->>'c3')::bigint), sum((fields->>'c3')::bigint) FROM sctbl3 GROUP BY fields->>'c3' HAVING(max(fields->>'c2')!='change for new change' and count(fields->>'c2')>0) ORDER BY 1,2,3;
--Testcase 145:
SELECT array_agg((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint), array_agg((fields->>'c3')::bigint/(fields->>'c3')::bigint*(fields->>'c3')::bigint), array_agg(((fields->>'c3')::bigint+(fields->>'c3')::bigint/(fields->>'c3')::bigint)*-1000), array_agg((fields->>'c3')::bigint*(fields->>'c3')::bigint-(fields->>'c3')::bigint), array_agg(((fields->>'c3')::bigint-(fields->>'c3')::bigint+(fields->>'c3')::bigint)+9999999999999.998) from sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint ORDER BY 1, 2, 3, 4, 5;
--Testcase 146:
SELECT avg((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint)-0.567-avg((fields->>'c3')::bigint/3+(fields->>'c3')::bigint)+17.55435, avg((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint+45))- -9.5+2*avg((fields->>'c3')::bigint), avg((fields->>'c3')::bigint/((fields->>'c3')::bigint-10.2)*(fields->>'c3')::bigint)+0.567+avg((fields->>'c3')::bigint)*4.5+(fields->>'c3')::bigint, avg((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint+5.6))+100-(fields->>'c3')::bigint from sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746  GROUP BY fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4 limit 5;
--Testcase 147:
SELECT count(*)-5.6, 2*count(*), 10.2/count(*)+count(*)-(fields->>'c3')::bigint from sctbl3 WHERE (fields->>'c3')::bigint>0.774 OR fields->>'c2' = 'Which started out as a kind' GROUP BY fields->>'c3' ORDER BY 1, 2, 3;

-- ------------------------------Update data: add 5 tags and 20 fields-----------------------------------------
-- Update data
\! influx -import -path=init/multikey_add_5tag_20field.txt -precision=ns > /dev/null
--Testcase 205:
drop view if exists view_sctbl3 ;
--Testcase 206:
drop foreign table if exists sctbl3;

--Testcase 207:
CREATE FOREIGN TABLE sctbl3 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 't1, t2, t3, t4, t5');

--Testcase 208:
create view view_sctbl3 as select * from sctbl3 where ((fields->>'c20')::int != 6789 OR (fields->>'c19')::double precision != -1);


-- Update data: add 5 tags and 20 fields
-- Select all data with condition and combine clause
--Testcase 148:
SELECT * FROM sctbl3 WHERE (fields->>'c6')::double precision != -1 AND (fields->>'c5')::bool != true OR (fields->>'c8')::float > 0 ORDER BY tags->>'t1' DESC,(tags->>'t2')::int ASC, (fields->>'c6')::float DESC, fields->>'c9', (fields->>'c20')::int LIMIT 5 OFFSET 0;
--Testcase 149:
SELECT * FROM sctbl3 WHERE NOT (fields->>'c16')::int<(fields->>'c3')::bigint ORDER BY (fields->>'c7')::float DESC, (fields->>'c8')::double precision ASC,fields->>'c9' DESC,fields->>'c10',(fields->>'c11')::bigint LIMIT 5 OFFSET 0;
--Testcase 150:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM sctbl3 WHERE (fields->>'c20')::int > 0 ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 151:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM sctbl3 WHERE NOT time>'2020-1-3 20:30:50' ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 152:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM sctbl3 WHERE EXISTS (SELECT fields->>'c15' FROM sctbl3 WHERE (fields->>'c19')::double precision!=40.772) ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 153:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM sctbl3 WHERE fields->>'c2'=ANY (ARRAY(SELECT fields->>'c2' FROM sctbl3 WHERE (fields->>'c3')::bigint%2=0)) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 0;
--Testcase 154:
SELECT tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 from sctbl3 WHERE (fields->>'c13')::int >=0;

-- Select aggregate function  and specific column from original table
--Testcase 155:
SELECT max(tags->>'t4'), max(tags->>'t5'), max((fields->>'c3')::bigint), count(*),count((fields->>'c11')::bigint), count((fields->>'c13')::int), count((fields->>'c19')::double precision), exists(SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>1), exists (SELECT count(*) FROM sctbl3 WHERE (fields->>'c3')::bigint>10.5) FROM view_sctbl3 WHERE (fields->>'c3')::bigint<0 GROUP BY time ORDER BY 1 ASC,2 DESC,3 ASC,4 LIMIT 25 OFFSET 0;
--Testcase 156:
SELECT max(fields->>'c2'), min((fields->>'c3')::bigint), max((fields->>'c3')::bigint), max((fields->>'c11')::bigint), max((fields->>'c6')::double precision), max((fields->>'c7')::double precision), max((fields->>'c8')::float), max (20) from sctbl3 GROUP BY fields->>'c3' ORDER BY (fields->>'c3')::bigint;
--Testcase 157:
SELECT sum((fields->>'c3')::bigint), sum((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), sum((fields->>'c6')::double precision), sum((fields->>'c7')::double precision), sum((fields->>'c8')::float), sum((fields->>'c11')::bigint), sum((fields->>'c13')::int), sum((fields->>'c16')::int) FROM sctbl3 GROUP BY fields->>'c2' ORDER BY 1;
--Testcase 158:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), stddev((fields->>'c11')::bigint), stddev((fields->>'c13')::int), stddev((fields->>'c14')::bigint), stddev((fields->>'c16')::int), stddev((fields->>'c19')::double precision), stddev((fields->>'c20')::int) FROM sctbl3 GROUP BY fields->>'c5', fields->>'c12' HAVING (fields->>'c12')::bool = true ORDER BY 1 ASC,2 DESC;
--Testcase 159:
SELECT every((fields->>'c3')::bigint>0), every((fields->>'c3')::bigint != (fields->>'c3')::bigint) FROM sctbl3 GROUP BY time, (fields->>'c20')::int, tags->>'t5' ORDER BY (fields->>'c20')::int ASC,tags->>'t5' DESC;
--Testcase 160:
SELECT bool_and((fields->>'c3')::bigint <> 10) AND true, bool_and(fields->>'c2' != 'aghsjfh'), bool_and((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false, bool_and((fields->>'c12')::bool), bool_and((fields->>'c17')::bool), bool_and((fields->>'c17')::bool) AND TRUE from sctbl3 ORDER BY 1,2,3;
--Testcase 161:
SELECT bool_or((fields->>'c3')::bigint <> 10) AND true, bool_or(fields->>'c2' != 'aghsjfh'), bool_or((fields->>'c3')::bigint+(fields->>'c3')::bigint <=5.5) OR false, bool_or((fields->>'c17')::bool), bool_or((fields->>'c1')::bool), bool_or((fields->>'c5')::bool) OR FALSE from sctbl3 ORDER BY 1,2,3;

-- Select combine aggregate via operation
--Testcase 162:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint+(fields->>'c3')::bigint), sum((fields->>'c3')::bigint*2), sum((fields->>'c3')::bigint)-5, sum((fields->>'c13')::int + -43.3)-3, sum((fields->>'c16')::int*2) + 1, sum((fields->>'c19')::double precision-7554)+785 FROM sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 163:
SELECT array_agg((fields->>'c3')::bigint/2 ORDER BY (fields->>'c3')::bigint), array_agg(fields->>'c2' ORDER BY fields->>'c2'), array_agg(time ORDER BY time), array_agg((fields->>'c6')::double precision+2), array_agg((fields->>'c7')::double precision/10), array_agg((fields->>'c8')::float-2) FROM sctbl3 GROUP BY (fields->>'c17')::bool, (fields->>'c20')::int, (fields->>'c18')::bool, (fields->>'c19')::double precision HAVING (fields->>'c17')::bool != true ORDER BY (fields->>'c20')::int DESC, (fields->>'c19')::double precision, (fields->>'c18')::bool;
--Testcase 164:
SELECT bit_and((fields->>'c3')::bigint), bit_and((fields->>'c3')::bigint+15), bit_and((fields->>'c13')::int+768) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c16')::int>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY fields->>'c13', fields->>'c14' HAVING min((fields->>'c13')::int)<min((fields->>'c14')::bigint) ORDER BY (fields->>'c13')::int ASC,(fields->>'c14')::bigint DESC;
--Testcase 165:
SELECT bool_and((fields->>'c3')::bigint>0), bool_and((fields->>'c3')::bigint<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint), bool_and((fields->>'c19')::double precision <= (fields->>'c20')::int) FROM sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 DESC, 2, 3;
--Testcase 166:
SELECT max(tags->>'t1'), max(tags->>'t2'), max(time), max((fields->>'c3')::bigint*0.5/(fields->>'c11')::bigint), max((fields->>'c3')::bigint+10-(fields->>'c8')::float), max((fields->>'c6')::double precision*2+(fields->>'c13')::int), max((fields->>'c8')::float-32+(fields->>'c16')::int), max((fields->>'c19')::double precision/32) FROM sctbl3 WHERE fields->>'c2' IS NOT NULL GROUP BY fields->>'c3', fields->>'c3' HAVING min((fields->>'c3')::bigint)<100 AND max((fields->>'c3')::bigint)<1000 AND sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 167:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM sctbl3 WHERE fields->>'c2' IS NULL GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint HAVING min((fields->>'c3')::bigint)>min((fields->>'c3')::bigint) ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 168:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint), min((fields->>'c19')::double precision + (fields->>'c20')::int/2) FROM sctbl3 WHERE true GROUP BY fields->>'c2', fields->>'c3', fields->>'c3', fields->>'c14' HAVING sum((fields->>'c3')::bigint)>avg((fields->>'c14')::bigint) ORDER BY 1 ASC,2 DESC;
--Testcase 169:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint), min((fields->>'c11')::bigint-(fields->>'c7')::double precision), min((fields->>'c6')::double precision+(fields->>'c8')::float)  FROM sctbl3 WHERE false GROUP BY fields->>'c2', fields->>'c3', fields->>'c3' HAVING sum((fields->>'c3')::bigint)>avg((fields->>'c3')::bigint) ORDER BY 1 ASC,2 DESC;
--Testcase 170:
SELECT min(time)+'10 days'::interval, min((fields->>'c3')::bigint+(fields->>'c3')::bigint) FROM sctbl3 WHERE (fields->>'c3')::bigint IN (-1,1,0,2,-2) GROUP BY fields->>'c19', fields->>'c20' HAVING min((fields->>'c19')::double precision)>min((fields->>'c20')::int) ORDER BY 1 ASC,2 DESC;

-- Select from sub query
--Testcase 171:
SELECT time, fields->>'c2' c2, fields->>'c15' c15, tags->>'t1' t1, (tags->>'t3')::double precision t3, tags->>'t5' t5, (fields->>'c12')::bool c12, (fields->>'c14')::bigint c14 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c13')::int>-1000 OR (fields->>'c19')::double precision<1000 ) AS sctbl3;
--Testcase 172:
SELECT max(time), max(7), max((fields->>'c7')::double precision)+17, max((fields->>'c11')::bigint)+10, max((fields->>'c3')::bigint), max((fields->>'c14')::bigint)/2 FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY fields->>'c2' ORDER BY fields->>'c2';
--Testcase 173:
SELECT stddev((fields->>'c3')::bigint), stddev((fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint), stddev((fields->>'c11')::bigint), stddev((fields->>'c14')::bigint), stddev((fields->>'c19')::double precision) FROM ( SELECT * FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS sctbl3 GROUP BY time ORDER BY 1 ASC,2 DESC;
--Testcase 174:
SELECT sqrt(abs((fields->>'c3')::bigint)), sqrt(abs((fields->>'c3')::bigint)), sqrt(abs((fields->>'c11')::bigint)), sqrt(abs((fields->>'c20')::int)) FROM ( SELECT * FROM sctbl3 WHERE tags->>'t5' LIKE '111111' ) AS sctbl3 ORDER BY 1 ASC,2 DESC;
--Testcase 175:
SELECT * FROM ( SELECT tags->>'t1' t1, (tags->>'t2')::int t2, (tags->>'t3')::double precision t3, tags->>'t4' t4, tags->>'t5' t5, fields->>'c2' c2, (fields->>'c3')::bigint c3 FROM sctbl3 WHERE (fields->>'c13')::int>-1000 OR (fields->>'c14')::bigint<1000 ) AS tb3 WHERE c3 <-1 AND c2 > 'KissMe' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 176:
SELECT * FROM ( SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM sctbl3 WHERE (fields->>'c3')::bigint>-1000 AND (fields->>'c3')::bigint<1000 ) AS tb3 WHERE c3 IN (-1,1,0,2,-2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 25 OFFSET 0;
--Testcase 177:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM ( SELECT * FROM sctbl3 WHERE fields->>'c10' LIKE 'a       a') AS tb3 WHERE (fields->>'c3')::bigint > 0 GROUP BY fields->>'c2', fields->>'c3', fields->>'c3' HAVING sum((fields->>'c3')::bigint) < avg((fields->>'c3')::bigint) ORDER BY 1 DESC, 2, 3;

-- Select from view
--Testcase 179:
SELECT stddev((fields->>'c13')::int), stddev((fields->>'c14')::bigint ORDER BY (fields->>'c14')::bigint)  FROM view_sctbl3 GROUP BY time, fields->>'c13', fields->>'c14' ORDER BY (fields->>'c13')::int ASC, (fields->>'c14')::bigint DESC;
--Testcase 180:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2) FROM view_sctbl3 GROUP BY fields->>'c5' HAVING (fields->>'c5')::bool != true ORDER BY 1 ASC,2 DESC;
--Testcase 181:
SELECT max(time), max((fields->>'c3')::bigint*0.5), max((fields->>'c3')::bigint+10) FROM view_sctbl3 GROUP BY time ORDER BY 1 DESC, 2, 3;
--Testcase 182:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint+(fields->>'c3')::bigint), sum((fields->>'c3')::bigint*2), sum((fields->>'c3')::bigint)-5 FROM view_sctbl3 GROUP BY fields->>'c2' ORDER BY 1 DESC, 2, 3;
--Testcase 183:
SELECT avg((fields->>'c3')::bigint-(fields->>'c3')::bigint ORDER BY (fields->>'c3')::bigint-(fields->>'c3')::bigint), avg((fields->>'c3')::bigint)>50, tags->>'t4' t4, (fields->>'c12')::bool c12, (fields->>'c19')::double precision+(fields->>'c20')::int FROM view_sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint, tags->>'t4', (fields->>'c12')::bool, (fields->>'c19')::double precision, (fields->>'c20')::int HAVING sum((fields->>'c13')::int)<100 OR sum((fields->>'c3')::bigint)>-1000 AND avg((fields->>'c11')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 184:
SELECT bit_or((fields->>'c3')::bigint), bit_or((fields->>'c3')::bigint/2), (tags->>'t2')::int t2, (tags->>'t3')::double precision t3 FROM view_sctbl3 GROUP BY tags->>'t2', tags->>'t3', fields->>'c3', fields->>'c3' HAVING min((fields->>'c16')::int)<100 AND max((fields->>'c11')::bigint)<1000 OR sum((fields->>'c7')::double precision)>-7894 AND avg((fields->>'c3')::bigint)>-1000 ORDER BY 1 ASC,2 DESC;
--Testcase 185:
SELECT bool_and((fields->>'c11')::bigint>0), bool_and((fields->>'c13')::int<0), bool_and((fields->>'c3')::bigint<(fields->>'c3')::bigint), bool_and((fields->>'c7')::double precision>=(fields->>'c8')::float) FROM view_sctbl3 GROUP BY time, tags->>'t1', tags->>'t2',tags->>'t3' ORDER BY tags->>'t1' DESC,(tags->>'t2')::float, (tags->>'t3')::double precision;
--Testcase 186:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM view_sctbl3 WHERE fields->>'c2'<='$' AND (fields->>'c3')::bigint<>-5 AND (fields->>'c3')::bigint<>10.746 ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 187:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM view_sctbl3 WHERE (fields->>'c3')::bigint>10.746 OR fields->>'c2' != 'Hello' ORDER BY 1 DESC,2 ASC,3 DESC,4,5;
--Testcase 188:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM view_sctbl3 WHERE NOT (fields->>'c3')::bigint<(fields->>'c3')::bigint ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;
--Testcase 189:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM view_sctbl3 WHERE true ORDER BY 1 DESC,2 ASC,3 DESC,4,5 DESC;
--Testcase 190:
SELECT time,tags->>'t1' t1,(tags->>'t2')::int t2,(tags->>'t3')::double precision t3,tags->>'t4' t4, tags->>'t5' t5, (fields->>'c1')::bool c1,fields->>'c2' c2,(fields->>'c3')::bigint c3,(fields->>'c4')::double precision c4, (fields->>'c5')::bool c5, (fields->>'c6')::double precision c6, (fields->>'c7')::double precision c7, (fields->>'c8')::float c8, fields->>'c9' c9, fields->>'c10' c10, (fields->>'c11')::bigint c11, (fields->>'c12')::bool c12, (fields->>'c13')::int c13, (fields->>'c14')::bigint c14, fields->>'c15' c15, (fields->>'c16')::int c16, (fields->>'c17')::bool c17, (fields->>'c18')::bool c18, (fields->>'c19')::double precision c19, (fields->>'c20')::int c20 FROM view_sctbl3 WHERE (fields->>'c3')::bigint NOT IN (-42,65,0,78,-891) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 8;

-- Select many target aggregate in one query and combine with condition
--Testcase 191:
SELECT count((fields->>'c1')::bool)+count(fields->>'c2')-2*count((fields->>'c3')::bigint), count((fields->>'c3')::bigint)/count((fields->>'c5')::bool)-(fields->>'c3')::bigint, count((fields->>'c11')::bigint-(fields->>'c14')::bigint), 2*count(*) from sctbl3 GROUP BY fields->>'c5', fields->>'c3', fields->>'c1', fields->>'c20', tags->>'t5' order by tags->>'t5', fields->>'c1', (fields->>'c20')::int limit 1;
--Testcase 192:
SELECT every((fields->>'c1')::bool != TRUE) AND true, every((fields->>'c3')::bigint <> 10) OR every((fields->>'c3')::bigint > 5.6), every((fields->>'c3')::bigint <= 2) OR (fields->>'c5')::bool from sctbl3 GROUP BY fields->>'c5' ORDER BY 1,2,3 limit 6;
--Testcase 193:
SELECT stddev((fields->>'c3')::bigint*3-(fields->>'c3')::bigint)*1000000-(fields->>'c3')::bigint, stddev((fields->>'c3')::bigint)-0.567, stddev((fields->>'c3')::bigint/((fields->>'c3')::bigint-1.3))/6, stddev((fields->>'c3')::bigint+4*(fields->>'c3')::bigint)*100, stddev((fields->>'c3')::bigint+(fields->>'c3')::bigint/((fields->>'c3')::bigint-52.1))+1 from sctbl3 WHERE (fields->>'c3')::bigint<0 GROUP BY fields->>'c3' ORDER BY 1,2,3,4,5 ;
--Testcase 194:
SELECT sum((fields->>'c3')::bigint+(fields->>'c3')::bigint-(fields->>'c3')::bigint)-6, sum((fields->>'c3')::bigint/((fields->>'c3')::bigint+9999999)-(fields->>'c3')::bigint)*9999999999999.998, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint/((fields->>'c3')::bigint+111111))*-9.5, sum((fields->>'c3')::bigint-(fields->>'c3')::bigint-(fields->>'c3')::bigint)/17.55435, sum((fields->>'c3')::bigint+(fields->>'c3')::bigint+(fields->>'c3')::bigint)*6 from sctbl3;
--Testcase 195:
SELECT sum((fields->>'c14')::bigint+(fields->>'c3')::bigint)-6+sum((fields->>'c11')::bigint), sum((fields->>'c3')::bigint*1.3-(fields->>'c3')::bigint)*9.998-sum((fields->>'c7')::double precision)*4, sum((fields->>'c8')::float-(fields->>'c7')::double precision/4)*-9.5-(fields->>'c3')::bigint, sum((fields->>'c20')::int-(fields->>'c3')::bigint-(fields->>'c16')::int)/17.55435+(fields->>'c3')::bigint, sum((fields->>'c3')::bigint+(fields->>'c3')::bigint+(fields->>'c3')::bigint)*6-(fields->>'c3')::bigint-(fields->>'c3')::bigint from sctbl3 GROUP BY fields->>'c13', fields->>'c14', fields->>'c16', fields->>'c11', fields->>'c3', fields->>'c3' ORDER BY 1,2,3,4,5;
--Testcase 196:
SELECT max((fields->>'c16')::int), max((fields->>'c3')::bigint)+(fields->>'c3')::bigint-1, max((fields->>'c3')::bigint+(fields->>'c3')::bigint)-(fields->>'c3')::bigint-3, max((fields->>'c3')::bigint)+max((fields->>'c3')::bigint) from sctbl3 WHERE (fields->>'c13')::int>= 0 GROUP BY fields->>'c3', fields->>'c3' ORDER BY (fields->>'c3')::int, (fields->>'c3')::int;
--Testcase 197:
SELECT variance((fields->>'c3')::bigint+(fields->>'c3')::bigint)+(fields->>'c3')::bigint, variance((fields->>'c3')::bigint*3)+(fields->>'c3')::bigint+1, variance((fields->>'c3')::bigint-2)+10 from sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint, (tags->>'t3')::double precision ORDER BY (tags->>'t3')::double precision;
--Testcase 198:
SELECT sqrt(abs((fields->>'c3')::bigint*5)) + sqrt(abs((fields->>'c3')::bigint+6)), sqrt(abs((fields->>'c3')::bigint)+5)+(fields->>'c3')::bigint, 4*sqrt(abs((fields->>'c3')::bigint-100))-(fields->>'c3')::bigint from sctbl3 WHERE (fields->>'c3')::bigint<ALL (SELECT (fields->>'c3')::bigint FROM sctbl3 WHERE (fields->>'c3')::bigint>0) ORDER BY 1, 2, 3;
--Testcase 199:
SELECT max((fields->>'c3')::bigint)+min((fields->>'c3')::bigint)+3, min((fields->>'c3')::bigint)-sqrt(abs((fields->>'c3')::bigint-45.21))+(fields->>'c3')::bigint*2, count(*)-count((fields->>'c5')::bool)+2, (fields->>'c5')::bool c5, (fields->>'c3')::bigint c3 from sctbl3 GROUP BY (fields->>'c3')::bigint, (fields->>'c3')::bigint, (fields->>'c5')::bool ORDER BY 1,2,3,4;
--Testcase 200:
SELECT variance((fields->>'c3')::bigint)-5*min((fields->>'c3')::bigint)-1, every((fields->>'c5')::bool <> true), max((fields->>'c3')::bigint+4.56)*3-min((fields->>'c3')::bigint), count((fields->>'c3')::bigint)-4 from sctbl3 WHERE (fields->>'c3')::bigint=ANY (ARRAY[1,2,3]) ORDER BY 1,2,3,4;
--Testcase 201:
SELECT (fields->>'c3')::bigint-30, (fields->>'c3')::bigint-10, sum((fields->>'c3')::bigint)/3-(fields->>'c3')::bigint, min((fields->>'c3')::bigint)+(fields->>'c3')::bigint/4, (fields->>'c5')::bool c5, (fields->>'c20')::int-(fields->>'c19')::double precision-(fields->>'c16')::int from sctbl3 GROUP BY (fields->>'c20')::int, (fields->>'c19')::double precision, (fields->>'c16')::int, (fields->>'c3')::bigint, (fields->>'c3')::bigint, (fields->>'c5')::bool ORDER BY 1,2,3,4,5;

-- Clean
--Testcase 209:
DROP FOREIGN TABLE sctbl3 CASCADE;
--Testcase 210:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 211:
DROP SERVER influxdb_svr CASCADE;
--Testcase 212:
DROP EXTENSION influxdb_fdw;
