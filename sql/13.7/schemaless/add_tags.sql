SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='UTC';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

-- Init data original
\! influx -import -path=init/tag_original.txt -precision=s > /dev/null
-- Before update data
-- Testcase 1:
CREATE EXTENSION influxdb_fdw CASCADE;
--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'schemalessdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE sctbl9 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true'), time timestamp) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'sid, sname');
--Testcase 5:
CREATE FOREIGN TABLE sctbl4 (fields jsonb OPTIONS(fields 'true'), time timestamp) SERVER influxdb_svr OPTIONS (schemaless 'true');


--------------------------------------------------------------------------------------- TC for before update test data -------------------------------------------------------------------------------------------------
--Testcase 6:
select * from sctbl4;
--Testcase 7:
select time, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::double precision sig3, (fields->>'sig4')::boolean sig4 from sctbl4;
--Testcase 8:
select max(fields->>'sig2'), min(time), bool_or(fields->>'sig2' != 'JAPA') from sctbl4;
--Testcase 9:
select bool_and((fields->>'sig3')::double precision > -10), string_agg('446757svbvskkk', fields->>'sig2'), avg ((fields->>'sig1')::bigint) from sctbl4;
--Testcase 10:
select count(fields->>'sig1'), stddev((fields->>'sig3')::double precision + 333), min(fields->>'sig2') from sctbl4;
--Testcase 11:
select bool_or((fields->>'sig1')::bigint >= 1234), stddev((fields->>'sig1')::bigint), stddev((fields->>'sig3')::double precision) from sctbl4;


--------------------------------------------------------------------------------------- Update: Add 1 tag --------------------------------------------------------------------------------------------------------------
-- Update data : add 1 tag
\! influx -import -path=init/tag_add_1.txt -precision=s > /dev/null

--Testcase 12:
DROP FOREIGN TABLE sctbl4;
--Testcase 13:
CREATE FOREIGN TABLE sctbl4 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true'), time timestamp) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'sid');
-- Select all data with aggregate
--Testcase 14:
select avg((fields->>'sig3')::double precision), bool_and(fields->>'sig2' != '%a%'), count(*) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 15:
select bool_or((fields->>'sig1')::bigint >= 1234), stddev((fields->>'sig1')::bigint), avg((fields->>'sig3')::double precision) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 16:
select max(time), avg((fields->>'sig3')::double precision), sum((fields->>'sig1')::bigint) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 17:
select string_agg(fields->>'sig2', 'ASDFG!@#$%zxc'), count(time), avg((fields->>'sig1')::bigint) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 18:
select sum((fields->>'sig3')::double precision), stddev((fields->>'sig3')::double precision), min((fields->>'sig1')::bigint) from sctbl4 GROUP BY tags->>'sid' ORDER BY 1, 2, 3;

-- Select aggregate contain expression
--Testcase 19:
select bool_or(((fields->>'sig1')::bigint + (fields->>'sig3')::double precision - 9999) > 0), stddev((fields->>'sig3')::double precision / (fields->>'sig1')::bigint + 3291), stddev((fields->>'sig3')::double precision * 12.3 - (fields->>'sig1')::bigint) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 20:
select avg((fields->>'sig3')::double precision * (fields->>'sig1')::bigint / 34241), bool_and(fields->>'sig2' != '%c'), bool_and((fields->>'sig4')::boolean AND true OR true) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 21:
select sum((fields->>'sig3')::double precision * 123.456 + (fields->>'sig1')::bigint), bool_and((fields->>'sig4')::boolean OR false), bool_or((fields->>'sig4')::boolean AND true AND true) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 22:
select min((fields->>'sig3')::double precision / ((fields->>'sig3')::double precision + 223344)), max((fields->>'sig1')::bigint * (fields->>'sig3')::double precision - (fields->>'sig3')::double precision), count(*) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 23:
select every((fields->>'sig4')::boolean OR (fields->>'sig4')::boolean AND true), max (fields->>'sig2' || 'handsome' || 'ugly'), avg((fields->>'sig1')::bigint / (fields->>'sig1')::bigint + 9999.999) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';

-- Select combine-aggregate
--Testcase 24:
select avg((fields->>'sig3')::double precision) + sum((fields->>'sig3')::double precision) / avg((fields->>'sig1')::bigint), bool_and(fields->>'sig2' != '%a%') AND bool_and((fields->>'sig4')::boolean AND true) AND true , max((fields->>'sig1')::bigint * (fields->>'sig1')::bigint / 0.0001) + min((fields->>'sig3')::double precision / ((fields->>'sig1')::bigint + 99999)) * sum((fields->>'sig1')::bigint * (fields->>'sig1')::bigint - (fields->>'sig3')::double precision) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 25:
select stddev((fields->>'sig3')::double precision * 0.0001 - (fields->>'sig1')::bigint) + min((fields->>'sig3')::double precision / ((fields->>'sig1')::bigint + 3.344)) * stddev((fields->>'sig1')::bigint * (fields->>'sig1')::bigint - (fields->>'sig3')::double precision), bool_or((fields->>'sig3')::double precision / (fields->>'sig1')::bigint < -10) OR bool_or((fields->>'sig4')::boolean OR true OR false) AND bool_and(fields->>'sig2' != '%c'), string_agg(fields->>'sig2', '恨挫') from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 26:
select max((fields->>'sig1')::bigint) * max((fields->>'sig3')::double precision) + sum((fields->>'sig1')::bigint), stddev((fields->>'sig1')::bigint) * avg((fields->>'sig3')::double precision) / avg((fields->>'sig1')::bigint), sum((fields->>'sig3')::double precision) + stddev((fields->>'sig3')::double precision) - count((fields->>'sig4')::boolean) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 27:
select count(fields->>'sig2') * count(fields->>'sig4') / min((fields->>'sig1')::bigint), stddev((fields->>'sig1')::bigint) - count(fields->>'sig2') * sum((fields->>'sig1')::bigint), avg((fields->>'sig3')::double precision) - avg((fields->>'sig1')::bigint) * sum((fields->>'sig1')::bigint) from sctbl4 GROUP BY tags->>'sid' ORDER BY tags->>'sid';

-- Select with WHERE multi-condition
--Testcase 28:
select max(fields->>'sig2'), sum((fields->>'sig3')::double precision), bool_or(fields->>'sig2' != 'viEtnAM') from sctbl4 WHERE (fields->>'sig1')::bigint > 0 AND (fields->>'sig4')::boolean = true OR fields->>'sig2' LIKE '%a%' GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 29:
select bool_and((fields->>'sig3')::double precision >= 1.6789), string_agg('ったのか誰も質問しま', fields->>'sig2'), avg ((fields->>'sig1')::bigint) from sctbl4 WHERE (fields->>'sig3')::double precision = 0 AND fields->>'sig2' IN ('%開発%', '%b%') OR ((fields->>'sig3')::double precision / (fields->>'sig1')::bigint) <= 6.1234 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 30:
select avg((fields->>'sig3')::double precision), count(*), count(fields->>'sig2') from sctbl4 WHERE (fields->>'sig4')::boolean = true OR time = '2020-01-09 01:00:00+00' AND (fields->>'sig3')::double precision != 0 GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 31:
select string_agg(fields->>'sig2', fields->>'sig2'), min(time), max(time) from sctbl4 WHERE (fields->>'sig4')::boolean = false OR (fields->>'sig4')::boolean = true AND time < '2000-01-01 23:00:00+00' GROUP BY tags->>'sid' ORDER BY tags->>'sid';
--Testcase 32:
select count(fields->>'sig4'), every((fields->>'sig3')::double precision < 0), stddev((fields->>'sig3')::double precision) from sctbl4 WHERE (fields->>'sig4')::boolean <> true AND fields->>'sig2' ILIKE 'ターフェー' OR fields->>'sig2' LIKE 'akewo0' GROUP BY tags->>'sid' ORDER BY tags->>'sid';

-- Select with HAVING LIMIT OFFSET
--Testcase 33:
select sum((fields->>'sig1')::bigint + (fields->>'sig1')::bigint * (fields->>'sig3')::double precision), string_agg(fields->>'sig2', fields->>'sig2'), string_agg(fields->>'sig2' || 'vjbkvba', 'も質問' || (fields->>'sig2')::text) from sctbl4 WHERE fields->>'sig2' LIKE '%a%' OR (fields->>'sig1')::bigint > 0 GROUP BY tags->>'sid',(fields->>'sig3')::double precision HAVING (fields->>'sig3')::double precision > 0 ORDER BY tags->>'sid' LIMIT 5 OFFSET 0;
--Testcase 34:
select string_agg(fields->>'sig2' || (fields->>'sig2')::text, fields->>'sig2' || '!@#$%^&*'), every((fields->>'sig4')::boolean OR true AND false), stddev((fields->>'sig3')::double precision - (fields->>'sig1')::bigint / (fields->>'sig1')::bigint) from sctbl4 WHERE (fields->>'sig3')::double precision <= 999999999 GROUP BY tags->>'sid',fields->>'sig4' HAVING (fields->>'sig4')::boolean <> false ORDER BY tags->>'sid' LIMIT 5 OFFSET 1;
--Testcase 35:
select stddev((fields->>'sig3')::double precision * 0.416754 + (fields->>'sig1')::bigint), min((fields->>'sig3')::double precision / ((fields->>'sig1')::bigint + 3.344)), stddev((fields->>'sig1')::bigint * (fields->>'sig1')::bigint - (fields->>'sig3')::double precision) from sctbl4 WHERE (fields->>'sig1')::bigint >= -1555.555 GROUP BY tags->>'sid',fields->>'sig4' HAVING (fields->>'sig4')::boolean <> true ORDER BY tags->>'sid' LIMIT 5 OFFSET 1;
--Testcase 36:
select bool_or((fields->>'sig3')::double precision / (fields->>'sig1')::bigint >= 15.5678), max ((fields->>'sig3')::double precision / (fields->>'sig1')::bigint * (fields->>'sig1')::bigint), every(((fields->>'sig3')::double precision - (fields->>'sig1')::bigint) < 0) from sctbl4 WHERE (fields->>'sig4')::boolean <> false GROUP BY tags->>'sid',fields->>'sig4' HAVING (fields->>'sig4')::boolean = true ORDER BY tags->>'sid' LIMIT 5 OFFSET 2;
--Testcase 37:
select max (fields->>'sig2' || 'kethattinh' || 'hanoilanhqua'), sum ((fields->>'sig3')::double precision - (fields->>'sig3')::double precision - (fields->>'sig1')::bigint), avg((fields->>'sig1')::bigint + (fields->>'sig1')::bigint + (fields->>'sig3')::double precision) from sctbl4 WHERE (fields->>'sig1')::bigint <= 10000000 GROUP BY tags->>'sid',fields->>'sig2',fields->>'sig4' HAVING fields->>'sig2' IN ('%c%', '%1%') OR fields->>'sig2' LIKE '%a%' ORDER BY tags->>'sid' LIMIT 5 OFFSET 2;

-- Select with subquery
--Testcase 38:
select time, tags->>'sname' sname, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::double precision sig3, (fields->>'sig4')::boolean sig4 from (select * from sctbl9 ORDER BY tags->>'sid') AS sctbl9;
--Testcase 39:
select time, max(sig1), avg(sig3) from (select time, tags->>'sname' sname, ((fields->>'sig1')::bigint) sig1, fields->>'sig2' sig2, ((fields->>'sig3')::double precision) sig3, (fields->>'sig4')::boolean sig4 from sctbl9 GROUP BY time,tags->>'sname',fields->>'sig1',fields->>'sig2',fields->>'sig3',fields->>'sig4' ORDER BY 1,2,3,4,5,6) AS sctbl9 GROUP BY time;
--Testcase 40:
select sum(sig3::double precision), string_agg(sig2, sname), count(sid) from (select time, tags->>'sid' sid, tags->>'sname' sname, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::double precision sig3, (fields->>'sig4')::boolean sig4 from sctbl9 ORDER BY tags->>'sid') AS sctbl9;


--------------------------------------------------------------------------------------- Update: Add 20 tag --------------------------------------------------------------------------------------------------------------
-- Update data : add 1 tag
\! influx -import -path=init/tag_add_20.txt -precision=s > /dev/null
--Testcase 41:
DROP FOREIGN TABLE sctbl4;
--Testcase 42:
CREATE FOREIGN TABLE sctbl4 (tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true'), time timestamp) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'sid, sid1, sid2, sid3, sid4, sid5, sid6, sid7, sid8, sid9, sid10, sid11, sid12, sid13, sid14, sid15, sid16, sid17, sid18, sid19, sid20');
--Testcase 43:
select * from sctbl4;
--Testcase 44:
select (fields->>'sig1')::bigint sig1, tags->>'sid1' sid1, (tags->>'sid2')::bigint sid2, (tags->>'sid3')::bigint sid3, tags->>'sid4' sid4, (tags->>'sid5')::boolean sid5, (tags->>'sid6')::boolean sid6, tags->>'sid7' sid7, tags->>'sid8' sid8, tags->>'sid9' sid9, tags->>'sid10' sid10, tags->>'sid11' sid11, (tags->>'sid12')::bigint sid12, (tags->>'sid13')::double precision sid13, tags->>'sid14' sid14, (tags->>'sid15')::boolean sid15, tags->>'sid16' sid16, tags->>'sid17' sid17, tags->>'sid18' sid18, tags->>'sid19' sid19, (tags->>'sid20')::bigint sid20 from sctbl4;

-- Select all data with aggregate
--Testcase 45:
select max(time), count(tags->>'sid1'), sum((tags->>'sid2')::bigint) from sctbl4 GROUP BY time,tags->>'sid1',(tags->>'sid2')::bigint,(fields->>'sig1')::bigint ORDER BY (fields->>'sig1')::bigint;
--Testcase 46:
select string_agg(tags->>'sid19', tags->>'sid17'), avg((tags->>'sid3')::bigint), stddev((tags->>'sid13')::double precision) from sctbl4 GROUP BY tags->>'sid17',tags->>'sid19',(tags->>'sid3')::bigint,(tags->>'sid13')::double precision,(fields->>'sig1')::bigint ORDER BY (fields->>'sig1')::bigint;
--Testcase 47:
select sum((tags->>'sid3')::bigint), sum((tags->>'sid20')::bigint), bool_and((tags->>'sid5')::boolean != (tags->>'sid6')::boolean) from sctbl4 GROUP BY fields->>'sig2' ORDER BY fields->>'sig2';
--Testcase 48:
select stddev((tags->>'sid20')::bigint), avg((tags->>'sid2')::bigint order by (tags->>'sid2')::bigint), min(tags->>'sid10') from sctbl4 GROUP BY fields->>'sig3' ORDER BY (fields->>'sig3')::double precision;
--Testcase 49:
select every((tags->>'sid11')::boolean = (tags->>'sid15')::boolean), bool_or((tags->>'sid6')::boolean != (tags->>'sid11')::boolean), count(time) from sctbl4 GROUP BY fields->>'sig2' ORDER BY fields->>'sig2';
--Testcase 50:
select count(*), sum((tags->>'sid3')::bigint), string_agg(tags->>'sid9', tags->>'sid17') from sctbl4 GROUP BY fields->>'sig3' ORDER BY (fields->>'sig3')::double precision;
--Testcase 51:
select count(tags->>'sid1'), bool_and(tags->>'sid4' != '%c%'), max(tags->>'sid8') from sctbl4 GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;
--Testcase 52:
select bool_and((tags->>'sid6')::boolean != false), min((tags->>'sid13')::double precision), avg((tags->>'sid20')::bigint) from sctbl4 GROUP BY fields->>'sig4' ORDER BY fields->>'sig4';
--Testcase 53:
select stddev((tags->>'sid13')::double precision), sum((tags->>'sid12')::bigint), string_agg(tags->>'sid7', tags->>'sid17') from sctbl4  GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;
--Testcase 54:
select stddev((tags->>'sid3')::bigint), min(tags->>'sid10'), max(tags->>'sid4') from sctbl4 GROUP BY (fields->>'sig4')::boolean ORDER BY (fields->>'sig4')::boolean;
--Testcase 55:
select string_agg(tags->>'sid19', tags->>'sid4'), string_agg(tags->>'sid9', tags->>'sid1'), max(time) from sctbl4 GROUP BY fields->>'sig3' ORDER BY (fields->>'sig3')::double precision;
--Testcase 56:
select avg((tags->>'sid3')::bigint), count(*), every((tags->>'sid15')::boolean != (tags->>'sid5')::boolean) from sctbl4 GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;
--Testcase 57:
select every((tags->>'sid6')::boolean = (tags->>'sid11')::boolean), string_agg(tags->>'sid14', tags->>'sid16'), string_agg(tags->>'sid18', tags->>'sid19') from sctbl4 GROUP BY fields->>'sig4' ORDER BY fields->>'sig4';
--Testcase 58:
select stddev((tags->>'sid12')::double precision), stddev((tags->>'sid13')::double precision), sum((tags->>'sid13')::double precision) from sctbl4 GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;

-- Select aggregate contain expression
--Testcase 59:
select max((tags->>'sid2')::bigint / (tags->>'sid3')::bigint + (fields->>'sig3')::double precision), avg((tags->>'sid20')::bigint - (fields->>'sig3')::double precision * (tags->>'sid3')::bigint), sum((tags->>'sid2')::bigint + (fields->>'sig3')::double precision / (tags->>'sid3')::bigint) from sctbl4 GROUP BY tags->>'sid20' ORDER BY (tags->>'sid20')::bigint;
--Testcase 60:
select string_agg(tags->>'sid19' || (fields->>'sig2')::text, tags->>'sid17' || (tags->>'sid1')::text), avg((tags->>'sid3')::bigint * (tags->>'sid2')::bigint - (tags->>'sid12')::bigint), stddev((tags->>'sid13')::double precision / (tags->>'sid3')::bigint + (tags->>'sid12')::bigint) from sctbl4 GROUP BY tags->>'sid19' ORDER BY tags->>'sid19';
--Testcase 61:
select sum((tags->>'sid3')::bigint - (tags->>'sid2')::bigint - (fields->>'sig1')::bigint), sum((tags->>'sid20')::bigint - (tags->>'sid13')::double precision + (tags->>'sid2')::bigint), bool_and((tags->>'sid5')::boolean AND (tags->>'sid6')::boolean OR (fields->>'sig4')::boolean) from sctbl4 GROUP BY tags->>'sid18' ORDER BY tags->>'sid18';
--Testcase 62:
select stddev((tags->>'sid12')::bigint * (tags->>'sid20')::bigint / (tags->>'sid2')::bigint), avg((tags->>'sid2')::bigint + (tags->>'sid3')::bigint / (tags->>'sid12')::bigint), min(tags->>'sid10' || 'BkbKJBT45%^&') from sctbl4 GROUP BY tags->>'sid16' ORDER BY tags->>'sid16';
--Testcase 63:
select every((tags->>'sid6')::boolean = (tags->>'sid15')::boolean), bool_or(tags->>'sid4' LIKE 'Hello'), sum((fields->>'sig1')::bigint * (fields->>'sig3')::double precision - (tags->>'sid20')::bigint) from sctbl4 GROUP BY tags->>'sid15' ORDER BY tags->>'sid15';
--Testcase 64:
select every((tags->>'sid5')::boolean <> (tags->>'sid6')::boolean), sum((tags->>'sid2')::bigint / (fields->>'sig1')::bigint * (fields->>'sig3')::double precision), string_agg(tags->>'sid9' || (tags->>'sid18')::text, tags->>'sid17' || (tags->>'sid16')::text) from sctbl4 GROUP BY tags->>'sid14' ORDER BY tags->>'sid14';
--Testcase 65:
select min((fields->>'sig1')::bigint * (tags->>'sid20')::bigint - (tags->>'sid13')::double precision), bool_and(tags->>'sid4' != '%c%' AND tags->>'sid4' != '%a%'), max((tags->>'sid3')::bigint - (fields->>'sig3')::double precision + (tags->>'sid12')::double precision) from sctbl4 GROUP BY tags->>'sid13' ORDER BY (tags->>'sid13')::double precision;
--Testcase 66:
select bool_and((tags->>'sid6')::boolean != false OR (tags->>'sid11')::boolean = true), min((tags->>'sid13')::double precision / (fields->>'sig3')::double precision - (tags->>'sid12')::bigint), avg((tags->>'sid20')::bigint / (tags->>'sid12')::bigint + (tags->>'sid3')::bigint) from sctbl4 GROUP BY tags->>'sid12' ORDER BY (tags->>'sid12')::bigint;
--Testcase 67:
select stddev((tags->>'sid13')::double precision + (fields->>'sig1')::bigint * (tags->>'sid2')::bigint), sum((tags->>'sid12')::bigint + (tags->>'sid20')::bigint - (tags->>'sid3')::bigint), string_agg(tags->>'sid7' || '豚は誰も好', 'なぜ18歳で' || (tags->>'sid17')::text) from sctbl4 GROUP BY tags->>'sid8' ORDER BY tags->>'sid8';
--Testcase 68:
select stddev((tags->>'sid3')::bigint * (tags->>'sid2')::bigint - (tags->>'sid20')::bigint), min(tags->>'sid10' || '12345#$%&7' || (tags->>'sid19')::text), every(tags->>'sid4' IN ('japan', 'vietnam')) from sctbl4 GROUP BY tags->>'sid9' ORDER BY tags->>'sid9';

-- Select combine-aggregate
--Testcase 69:
select stddev((tags->>'sid3')::bigint) + count(tags->>'sid10') + count(tags->>'sid4'), count(time) + count(tags->>'sid1') - sum((tags->>'sid2')::bigint), avg((tags->>'sid3')::bigint) * count(*) + count(tags->>'sid17') from sctbl4 GROUP BY fields->>'sig2' ORDER BY fields->>'sig2';
--Testcase 70:
select stddev((tags->>'sid13')::double precision) * avg((fields->>'sig1')::bigint) / avg((fields->>'sig3')::double precision), sum((tags->>'sid2')::bigint) / count(tags->>'sid10') + sum((fields->>'sig1')::bigint), stddev((fields->>'sig3')::double precision) / stddev((tags->>'sid12')::double precision) - min((tags->>'sid12')::double precision) from sctbl4 GROUP BY tags->>'sid2' ORDER BY (tags->>'sid2')::bigint;
--Testcase 71:
select string_agg(tags->>'sid7' || (tags->>'sid10')::text || (tags->>'sid4')::text, tags->>'sid7' || 'JBkbg7t96' || (tags->>'sid18')::text), avg((tags->>'sid2')::bigint) - stddev((fields->>'sig3')::double precision) + avg((tags->>'sid12')::bigint), bool_and(tags->>'sid19' LIKE '%な%') OR bool_and((tags->>'sid5')::boolean = true) AND bool_or((tags->>'sid6')::boolean) from sctbl4 GROUP BY tags->>'sid3' ORDER BY (tags->>'sid3')::bigint;
--Testcase 72:
select avg((tags->>'sid3')::bigint) + count(*) - sum((tags->>'sid20')::bigint), every((tags->>'sid15')::boolean != (tags->>'sid5')::boolean) OR bool_and((tags->>'sid15')::boolean) AND bool_or((tags->>'sid6')::boolean), string_agg(tags->>'sid14' || (tags->>'sid16')::text || (tags->>'sid18')::text, tags->>'sid17' || '&^&*$^&*^*' || (tags->>'sid19')::text) from sctbl4 GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;
--Testcase 73:
select bool_and((tags->>'sid11')::boolean) AND bool_or((tags->>'sid11')::boolean) OR true, count(time) + count(tags->>'sid1') - sum((tags->>'sid3')::bigint), count(tags->>'sid1') + count(tags->>'sid10') - avg((tags->>'sid3')::bigint) from sctbl4 GROUP BY fields->>'sig4' ORDER BY fields->>'sig4';
--Testcase 74:
select bool_or(tags->>'sid16' = 'id1') OR false AND every((tags->>'sid15')::boolean), string_agg(tags->>'sid14' || (tags->>'sid8')::text || (tags->>'sid4')::text, (tags->>'sid14')::text), avg((tags->>'sid2')::bigint) + avg((tags->>'sid3')::bigint) - avg((tags->>'sid12')::bigint) from sctbl4 GROUP BY fields->>'sig4' ORDER BY fields->>'sig4';
--Testcase 75:
select bool_and(time > '1900-09-09 23:59:00+00') AND bool_and((fields->>'sig4')::boolean) AND every((fields->>'sig4')::boolean), stddev((tags->>'sid20')::bigint) / stddev((fields->>'sig1')::bigint) / sum((tags->>'sid13')::double precision), stddev((tags->>'sid13')::double precision) / sum((tags->>'sid13')::double precision) * count(*) from sctbl4 GROUP BY tags->>'sid7' ORDER BY tags->>'sid7';
--Testcase 76:
select sum((tags->>'sid2')::bigint) + count(tags->>'sid1') - count(tags->>'sid8'), count((fields->>'sig3')::double precision) - count(tags->>'sid9') + count(tags->>'sid17'), string_agg(tags->>'sid19' || 'hf675578ytgu', tags->>'sid17' || (tags->>'sid14')::text) from sctbl4 GROUP BY tags->>'sid8' ORDER BY tags->>'sid8';
--Testcase 77:
select sum((tags->>'sid3')::bigint) - avg((tags->>'sid12')::bigint) * count(tags->>'sid9'), bool_and((tags->>'sid11')::boolean) AND bool_and((tags->>'sid20')::bigint >= -16735467) OR every(tags->>'sid16' != 'id3'), sum((tags->>'sid20')::bigint) + avg((tags->>'sid12')::bigint) / count(tags->>'sid19') from sctbl4 GROUP BY fields->>'sig2' ORDER BY fields->>'sig2';
--Testcase 78:
select string_agg(tags->>'sid19' || (tags->>'sid17')::text || (tags->>'sid10')::text, tags->>'sid9' || (tags->>'sid8')::text || (tags->>'sid7')::text), avg((tags->>'sid20')::bigint) / avg((tags->>'sid2')::bigint) + stddev((tags->>'sid12')::bigint), count(tags->>'sid1') - count(tags->>'sid14') + count((fields->>'sig3')::double precision) from sctbl4 GROUP BY tags->>'sid10' ORDER BY tags->>'sid10';

-- Select with WHERE multi-condition
--Testcase 79:
select avg((fields->>'sig3')::double precision + (tags->>'sid3')::bigint / (tags->>'sid12')::bigint), count(time) + count(tags->>'sid1') - sum((tags->>'sid2')::bigint), every((tags->>'sid11')::boolean = (tags->>'sid15')::boolean) from sctbl4 WHERE tags->>'sid9' LIKE '%挫败%' OR (tags->>'sid5')::boolean <> true OR tags->>'sid16' ILIKE 'id4' AND (tags->>'sid20')::bigint < 0 GROUP BY tags->>'sid11' ORDER BY tags->>'sid11';
--Testcase 80:
select avg((tags->>'sid2')::bigint), count(*), every((tags->>'sid11')::boolean != (tags->>'sid5')::boolean) from sctbl4 WHERE (tags->>'sid20')::bigint > 100000 AND (tags->>'sid6')::boolean != true OR tags->>'sid16' LIKE '2i3uth78wgbg' AND tags->>'sid1' ILIKE 'bMBOphOey0kXMun' GROUP BY fields->>'sig1' ORDER BY (fields->>'sig1')::bigint;
--Testcase 81:
select every((tags->>'sid6')::boolean <> (tags->>'sid11')::boolean), string_agg(tags->>'sid1', tags->>'sid16'), string_agg(tags->>'sid18', tags->>'sid7') from sctbl4 WHERE (tags->>'sid13')::double precision > 0.985689524 OR tags->>'sid8' LIKE '%^%' OR (tags->>'sid15')::boolean = true OR tags->>'sid4' IN ('%1%', '516541') GROUP BY fields->>'sig1',fields->>'sig3' ORDER BY (fields->>'sig3')::double precision;
--Testcase 82:
select string_agg(tags->>'sid16', tags->>'sid17'), avg((tags->>'sid13')::double precision), stddev((tags->>'sid12')::bigint) from sctbl4 WHERE (tags->>'sid6')::boolean <> false AND tags->>'sid19' LIKE 'ターフェー' AND tags->>'sid17' LIKE 'akewo0' AND tags->>'sid10' IN ('%2%', '%vợ%') GROUP BY tags->>'sid14',fields->>'sig2',fields->>'sig3' ORDER BY tags->>'sid14',fields->>'sig2',(fields->>'sig3')::double precision;
--Testcase 83:
select stddev((tags->>'sid13')::double precision + (fields->>'sig1')::bigint * (tags->>'sid2')::bigint), bool_or(tags->>'sid4' LIKE 'xinchao'), sum((fields->>'sig1')::bigint * (fields->>'sig3')::double precision - (tags->>'sid20')::bigint) from sctbl4 WHERE tags->>'sid4' IN ('%japnam', 'vietpan%') OR (tags->>'sid11')::boolean = true OR (tags->>'sid13')::double precision < 99999999999.99 OR (fields->>'sig3')::double precision > 0 GROUP BY (fields->>'sig1')::bigint,(fields->>'sig3')::double precision ORDER BY (fields->>'sig1')::bigint;

-- Select with HAVING LIMIT OFFSET
--Testcase 84:
select stddev((tags->>'sid2')::bigint * 0.9804754 + (tags->>'sid3')::bigint), min((tags->>'sid13')::double precision / ((fields->>'sig1')::bigint + 3.144)), stddev((tags->>'sid20')::bigint * (tags->>'sid2')::bigint - (tags->>'sid13')::double precision) from sctbl4 WHERE (fields->>'sig3')::double precision >= -999995.955 GROUP BY (fields->>'sig1')::bigint,(fields->>'sig3')::double precision HAVING (fields->>'sig3')::double precision > 0 ORDER BY (fields->>'sig1')::bigint LIMIT 10 OFFSET 10;
--Testcase 85:
select sum((fields->>'sig3')::double precision + (tags->>'sid3')::bigint * (tags->>'sid12')::bigint), string_agg(tags->>'sid7', tags->>'sid8'), string_agg(fields->>'sig2' || '568hvsvbka', 'も9質18問' || (tags->>'sid9')::text) from sctbl4 WHERE (fields->>'sig3')::double precision >= 0.3871647691 GROUP BY (fields->>'sig1')::bigint,(fields->>'sig3')::double precision,tags->>'sid15' HAVING (fields->>'sig3')::double precision <> 0 ORDER BY tags->>'sid15' LIMIT 10 OFFSET 0;
--Testcase 86:
select max (tags->>'sid10' || 'codonlangthang' || 'hoanghonhanoi'), sum ((tags->>'sid13')::double precision - (tags->>'sid12')::bigint - (tags->>'sid20')::bigint), avg((tags->>'sid2')::bigint + (tags->>'sid3')::bigint + (tags->>'sid12')::bigint) from sctbl4 WHERE (fields->>'sig1')::bigint <= 87986847478 GROUP BY (fields->>'sig1')::bigint,tags->>'sid10' HAVING tags->>'sid10' NOT IN ('%1 vợ%', '%1 chồng%') ORDER BY (fields->>'sig1')::bigint LIMIT 10 OFFSET 2;
--Testcase 87:
select stddev((tags->>'sid13')::double precision) * avg((tags->>'sid3')::bigint) / avg((tags->>'sid13')::double precision), sum((tags->>'sid2')::bigint) + max((fields->>'sig1')::bigint) + sum((tags->>'sid3')::bigint), stddev((tags->>'sid2')::bigint) / stddev((tags->>'sid12')::bigint) - min((tags->>'sid20')::bigint) from sctbl4 WHERE fields->>'sig2' NOT IN ('%c%', '%^%') GROUP BY tags->>'sid19' HAVING tags->>'sid19' != '%v' ORDER BY tags->>'sid19' LIMIT 10 OFFSET 0;
--Testcase 88:
select bool_or((tags->>'sid2')::bigint / (tags->>'sid13')::double precision >= 15.5678), max ((tags->>'sid3')::bigint / (tags->>'sid20')::bigint * (tags->>'sid12')::bigint), every(((tags->>'sid13')::double precision - (tags->>'sid2')::bigint) < 0) from sctbl4 WHERE (fields->>'sig1')::bigint != 0 GROUP BY (fields->>'sig1')::bigint,(fields->>'sig3')::double precision,tags->>'sid20' HAVING (fields->>'sig3')::double precision != 0 ORDER BY (tags->>'sid20')::bigint LIMIT 10 OFFSET 5;

-- Select JOIN
--Testcase 89:
select * from sctbl4 JOIN sctbl9 ON sctbl4.tags->>'sid14' = sctbl9.tags->>'sid' LIMIT 30 OFFSET 15;
--Testcase 90:
select sctbl4.time, (sctbl4.fields->>'sig1')::bigint sig1, sctbl9.fields->>'sig2' sig2, (sctbl4.fields->>'sig3')::double precision sig3, (sctbl9.fields->>'sig4')::boolean sig4 from sctbl4 JOIN sctbl9 ON sctbl4.tags->>'sid' = sctbl9.tags->>'sid' ORDER BY sctbl4.time LIMIT 30 OFFSET 5;
--Testcase 91:
select sctbl9.time, (sctbl9.fields->>'sig1')::bigint sig1, sctbl9.fields->>'sig2' sig2, (sctbl4.fields->>'sig3')::double precision sig3, (sctbl9.fields->>'sig4')::boolean sig4, (sctbl4.tags->>'sid3')::bigint sid3, sctbl4.tags->>'sid' sid, (sctbl4.tags->>'sid3')::bigint sid3, sctbl4.tags->>'sid7' sid7 from sctbl4 JOIN sctbl9 ON sctbl4.tags->>'sid' = sctbl9.tags->>'sid' WHERE (sctbl4.fields->>'sig1')::bigint > (sctbl9.fields->>'sig1')::bigint AND sctbl4.fields->>'sig2' != NULL LIMIT 30 OFFSET 5;
--Testcase 92:
select sctbl4.time, (sctbl9.fields->>'sig1')::bigint sig1, sctbl9.fields->>'sig2' sig2, (sctbl9.fields->>'sig3')::double precision sig3, (sctbl4.fields->>'sig4')::boolean sig4, (sctbl4.tags->>'sid13')::double precision sid13, sctbl4.tags->>'sid' sid, (sctbl4.tags->>'sid5')::boolean sid5, sctbl4.tags->>'sid16' sid16 from sctbl4 JOIN sctbl9 ON (sctbl4.fields->>'sig1')::bigint / (sctbl4.fields->>'sig3')::double precision < (sctbl9.fields->>'sig1')::bigint LIMIT 15 OFFSET 0;
--Testcase 93:
select sctbl4.time, (sctbl4.fields->>'sig1')::bigint sig1, sctbl9.fields->>'sig2' sig2, (sctbl4.fields->>'sig3')::double precision sig3, (sctbl4.fields->>'sig4')::boolean sig4, sctbl4.tags->>'sid19' sid19 from sctbl4 JOIN sctbl9 ON (sctbl4.tags->>'sid3')::bigint BETWEEN -10000 AND 9999999 OR sctbl9.fields->>'sig2' ILIKE '%a%' ORDER BY sctbl4.time, sig1, sig2, sig3, sig4, sid19 LIMIT 10 OFFSET 0;
--Testcase 94:
select sctbl4.time, (sctbl4.tags->>'sid15')::boolean sid15, (sctbl9.fields->>'sig4')::boolean sig4, sctbl4.fields->>'sig2' sig2, sctbl4.tags->>'sid8' sid8 from sctbl4 LEFT OUTER JOIN sctbl9 ON ((sctbl4.fields->>'sig3')::double precision = (sctbl9.fields->>'sig1')::bigint/25000 OR (sctbl4.fields->>'sig4')::boolean = (sctbl9.fields->>'sig4')::boolean) GROUP BY (sctbl4.fields->>'sig1')::bigint,sctbl4.time,(sctbl4.tags->>'sid15')::boolean,(sctbl9.fields->>'sig4')::boolean,sctbl4.fields->>'sig2',sctbl4.tags->>'sid8' HAVING (sctbl4.fields->>'sig1')::bigint > 0 LIMIT 10 OFFSET 2;
--Testcase 95:
select (sctbl9.fields->>'sig4')::boolean sig4, (sctbl4.tags->>'sid5')::boolean sid5, (sctbl4.tags->>'sid6')::boolean sid6, sctbl4.tags->>'sid7' sid7, sctbl4.tags->>'sid8' sid8, sctbl4.tags->>'sid9' sid9 from sctbl4 LEFT OUTER JOIN sctbl9 ON ((sctbl4.fields->>'sig1')::bigint = (sctbl9.fields->>'sig1')::bigint OR (sctbl4.fields->>'sig3')::double precision> (sctbl9.fields->>'sig3')::double precision) GROUP BY (sctbl4.fields->>'sig1')::bigint,(sctbl9.fields->>'sig3')::double precision,(sctbl9.fields->>'sig4')::boolean,(sctbl4.tags->>'sid5')::boolean,(sctbl4.tags->>'sid6')::boolean,sctbl4.tags->>'sid7',sctbl4.tags->>'sid8',sctbl4.tags->>'sid9' HAVING (sctbl4.fields->>'sig1')::bigint > sum((sctbl9.fields->>'sig3')::double precision) ORDER BY sid7, sid8, sid9 LIMIT 20 OFFSET 0;
--Testcase 96:
select (sctbl9.fields->>'sig4')::boolean sig4, sctbl9.fields->>'sig2' sig2, (sctbl4.tags->>'sid3')::bigint sid3, (sctbl4.tags->>'sid5')::boolean sid5, sctbl4.tags->>'sid7' sid7, sctbl4.tags->>'sid9' sid9, sctbl4.tags->>'sid16' sid16 from sctbl4 LEFT OUTER JOIN sctbl9 ON ((sctbl4.fields->>'sig3')::double precision > (sctbl9.fields->>'sig3')::double precision AND sctbl9.tags->>'sname' LIKE 'rapviet') GROUP BY (sctbl9.fields->>'sig4')::boolean,sctbl9.fields->>'sig2',(sctbl4.tags->>'sid3')::bigint,(sctbl4.tags->>'sid5')::boolean,sctbl4.tags->>'sid7',sctbl4.tags->>'sid9',sctbl4.tags->>'sid16',(sctbl4.fields->>'sig1')::bigint,sctbl9.tags->>'sname' ORDER BY (sctbl4.fields->>'sig1')::bigint DESC, sctbl9.tags->>'sname' LIMIT 10 OFFSET 8;
--Testcase 97:
select (sctbl4.tags->>'sid3')::bigint sid3, (sctbl4.tags->>'sid5')::boolean sid5, sctbl4.tags->>'sid7' sid7, sctbl4.tags->>'sid9' sid9, sctbl4.tags->>'sid16' sid16 from sctbl4 RIGHT OUTER JOIN sctbl9 ON (sctbl4.fields->>'sig4')::boolean = (sctbl9.fields->>'sig4')::boolean LIMIT 17 OFFSET 2;
--Testcase 98:
select sctbl4.tags->>'sid4' sid4, sctbl9.tags->>'sname' sname, sctbl4.tags->>'sid8' sid8, (sctbl4.tags->>'sid12')::bigint sid12, sctbl4.tags->>'sid14' sid14, (sctbl4.tags->>'sid20')::bigint sid20 from sctbl4 RIGHT OUTER JOIN sctbl9 ON ((sctbl4.fields->>'sig1')::bigint = (sctbl9.fields->>'sig3')::double precision OR (sctbl4.fields->>'sig3')::double precision > (sctbl9.fields->>'sig3')::double precision) GROUP BY (sctbl4.fields->>'sig1')::bigint,(sctbl9.fields->>'sig3')::double precision,sctbl4.tags->>'sid4',sctbl9.tags->>'sname',sctbl4.tags->>'sid8',(sctbl4.tags->>'sid12')::bigint,sctbl4.tags->>'sid14',(sctbl4.tags->>'sid20')::bigint HAVING (sctbl4.fields->>'sig1')::bigint < avg((sctbl9.fields->>'sig3')::double precision) ORDER BY sid12, sid20 LIMIT 9 OFFSET 1;
--Testcase 99:
select (sctbl4.tags->>'sid3')::bigint sid3, (sctbl4.tags->>'sid5')::boolean sid5, sctbl4.tags->>'sid7' sid7, sctbl4.tags->>'sid' sid, sctbl9.tags->>'sid' sid from sctbl4 FULL OUTER JOIN sctbl9 ON (sctbl4.fields->>'sig1')::bigint = (sctbl9.fields->>'sig1')::bigint GROUP BY (sctbl4.tags->>'sid3')::bigint,(sctbl4.tags->>'sid5')::boolean,sctbl4.tags->>'sid7',sctbl4.tags->>'sid',sctbl9.tags->>'sid';
--Testcase 100:
select sctbl4.tags->>'sid' sid, sctbl9.tags->>'sid' sid, (sctbl4.tags->>'sid3')::bigint sid3, sctbl4.tags->>'sid16' sid16, sctbl4.tags->>'sid18' sid18, (sctbl4.fields->>'sig4')::boolean sig4 from sctbl4 FULL OUTER JOIN sctbl9 ON (sctbl4.fields->>'sig3')::double precision < (sctbl9.fields->>'sig3')::double precision WHERE (sctbl4.fields->>'sig1')::bigint > 0 AND (sctbl9.fields->>'sig3')::double precision != 1 AND sctbl9.tags->>'sname' LIKE 'kingofrap' OR (sctbl9.fields->>'sig1')::bigint = -9999 GROUP BY sctbl4.tags->>'sid',sctbl9.tags->>'sid',sctbl4.tags->>'sid3',sctbl4.tags->>'sid16',sctbl4.tags->>'sid18',sctbl4.fields->>'sig4';
--Testcase 101:
select * from sctbl4 CROSS JOIN sctbl9 ORDER BY sctbl4.tags->>'sid1',(sctbl4.tags->>'sid2')::bigint,(sctbl4.tags->>'sid3')::bigint,sctbl4.tags->>'sid4',sctbl4.tags->>'sid5',sctbl4.tags->>'sid6',sctbl4.tags->>'sid7',sctbl4.tags->>'sid8',sctbl4.tags->>'sid9',sctbl4.tags->>'sid10',(sctbl9.fields->>'sig1')::bigint,sctbl9.fields->>'sig2',(sctbl9.fields->>'sig3')::double precision,sctbl9.fields->>'sig4' LIMIT 10 OFFSET 0;
--Testcase 102:
select sctbl4.tags->>'sid8' sid8, sctbl4.tags->>'sid9' sid9, (sctbl9.fields->>'sig1')::bigint sig1 from sctbl4 CROSS JOIN sctbl9 GROUP BY sctbl4.tags->>'sid8',sctbl4.tags->>'sid9',sctbl9.fields->>'sig1',sctbl4.fields->>'sig3',sctbl9.fields->>'sig1' HAVING (sctbl4.fields->>'sig3')::double precision >= sum((sctbl9.fields->>'sig1')::bigint) ORDER BY (sctbl9.fields->>'sig1')::bigint,(sctbl4.fields->>'sig3')::double precision LIMIT 10 OFFSET 0;

-- Clean
--Testcase 103:
DROP FOREIGN TABLE sctbl4;
DROP FOREIGN TABLE sctbl9;
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
DROP SERVER influxdb_svr CASCADE;
DROP EXTENSION influxdb_fdw;
