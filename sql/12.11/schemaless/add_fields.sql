SET datestyle=ISO;
-- timestamp with time zone differs based on this
SET timezone='UTC';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

-- Init data
\! influx -import -path=init/fields_original.txt -precision=ns > /dev/null
--Before update data

--Testcase 1:
CREATE EXTENSION influxdb_fdw CASCADE;
--Testcase 2:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'schemalessdb', host :INFLUXDB_HOST, port :INFLUXDB_PORT);
--Testcase 3:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user :INFLUXDB_USER, password :INFLUXDB_PASS);

--Testcase 4:
CREATE FOREIGN TABLE sctbl1 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'device_id');

--Testcase 5:
CREATE FOREIGN TABLE sctbl2 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'device_id');


--Before update data
--Testcase 6:
SELECT * FROM sctbl1;
--Testcase 7:
SELECT max(time), max((fields->>'sig1')::bigint), max((fields->>'sig1')::bigint)+10, max((fields->>'sig1')::bigint)-10, max((fields->>'sig3')::float8), max((fields->>'sig3')::float8)/2 FROM sctbl1 GROUP BY time,(fields->>'sig1')::bigint;
--Testcase 8:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4 from sctbl1 ORDER BY tags->>'device_id';
--Testcase 9:
SELECT bool_or((fields->>'sig1')::bigint <> 10) AND true, bool_and(fields->>'sig2' != 'aghsjfh'), bool_or((fields->>'sig1')::bigint+(fields->>'sig3')::float8 <=5.5) OR false from sctbl1 GROUP BY (fields->>'sig1')::bigint,fields->>'sig2';
--Testcase 10:
SELECT sqrt(abs((fields->>'sig1')::float8)), sqrt(abs((fields->>'sig3')::float8)) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint > -1000 AND (fields->>'sig3')::float8 < 1000 ) AS sctbl1 ORDER BY 1 ASC,2 DESC;
--Testcase 11:
SELECT fields->>'sig2' sig2, mode((fields->>'sig3')::float8) WITHIN GROUP (ORDER BY (fields->>'sig3')::float8) AS m1 from sctbl1 GROUP BY fields->>'sig2';
--Testcase 12:
SELECT upper(fields->>'sig2'), upper(fields->>'sig2'), lower(fields->>'sig2'), lower(fields->>'sig2') FROM sctbl1 ORDER BY 1 ASC,2 DESC,3 ASC,4;

-------------------------------------------------------------------------------------------Update data--Add 1 field------------------------------------------------------------------------------------------------------------
--Update data
\! influx -import -path=init/fields_add_1.txt -precision=ns > /dev/null

--Testcase 13:
DROP FOREIGN TABLE sctbl1;
--Testcase 14:
CREATE FOREIGN TABLE sctbl1 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'device_id');

--Testcase 15:
SELECT * FROM sctbl1;
--Select fields,tags
--Testcase 16:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3 FROM sctbl1 WHERE NOT (fields->>'sig1')::bigint < (fields->>'sig3')::float8 ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 0;
--Testcase 17:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3 FROM sctbl1 WHERE (fields->>'sig3')::float8 < 0 ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 0;
--Testcase 18:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3 FROM sctbl1 WHERE NOT time >'2020-1-3 20:30:50' ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 2;
--Testcase 19:
SELECT time, tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE true ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 20:
SELECT time, tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE false ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 21:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE (fields->>'sig1')::bigint BETWEEN 0 AND 10000 ORDER BY (fields->>'sig1')::bigint DESC LIMIT 5 OFFSET 0;
--Testcase 22:
SELECT time, tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE fields->>'sig2' LIKE 'x%' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 23:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4 FROM sctbl1 WHERE NOT EXISTS (SELECT fields->>'sig2' FROM sctbl1 WHERE fields->>'sig2'='AHW') ORDER BY 1 DESC,2 ASC LIMIT 5 OFFSET 0;
--Testcase 24:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE (fields->>'sig3')::float8 < ALL (SELECT (fields->>'sig1')::bigint FROM sctbl1 WHERE (fields->>'sig1')::bigint > 0) ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 0;
--Testcase 25:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE (fields->>'sig3')::float8 = ANY (ARRAY[0.78,0.32,0.34]) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 26:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig3' FROM sctbl1 WHERE (fields->>'sig3')::float8=0.25) ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 0;
--Testcase 27:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE fields->>'sig1'=ANY (ARRAY(SELECT fields->>'sig1' FROM sctbl1 WHERE (fields->>'sig1')::bigint%2=0)) ORDER BY 1 DESC LIMIT 5 OFFSET 0;
--Testcase 28:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig3' FROM sctbl1 WHERE (fields->>'sig4')::boolean=true) ORDER BY 1 DESC,2 ASC LIMIT 5 OFFSET 0;
--Testcase 29:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig5')::boolean sig5,(fields->>'sig1')::bigint+(fields->>'sig3')::float8 as ss FROM sctbl1 WHERE fields->>'sig2' IS NULL ORDER BY (fields->>'sig1')::bigint DESC,fields->>'sig2' ASC LIMIT 5 OFFSET 0;
--Testcase 30:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig5')::boolean sig5,(fields->>'sig1')::bigint/(fields->>'sig3')::float8 as dd FROM sctbl1 WHERE fields->>'sig2' IS NOT NULL ORDER BY fields->>'sig2' DESC,(fields->>'sig1')::bigint ASC LIMIT 5 OFFSET 0;
--Testcase 31:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig5')::boolean sig5,(fields->>'sig1')::bigint*(fields->>'sig3')::float8 as mm FROM sctbl1 WHERE NOT (fields->>'sig1')::bigint=5 ORDER BY fields->>'sig2' DESC LIMIT 5 OFFSET 0;
--Testcase 32:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE (fields->>'sig1')::bigint != 0 AND (fields->>'sig3')::float8=0.32 ORDER BY 1 DESC,2 ASC LIMIT 5 OFFSET 0;
--Testcase 33:
SELECT (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4, (fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE (fields->>'sig3')::float8 > -1.0 OR fields->>'sig2' != 'Hello' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 34:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE (fields->>'sig3')::float8 < -0.1 AND fields->>'sig2' > 'Mee' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 35:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE (fields->>'sig3')::float8 IN (-1,1,0,2,-2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 36:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE fields->>'sig2' LIKE 'A%' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 0;
--Testcase 37:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE NOT EXISTS (SELECT fields->>'sig2' FROM sctbl1 WHERE fields->>'sig2'='AHW') ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 2;
--Testcase 38:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE (fields->>'sig3')::float8 NOT IN (0, 1000, -1, -2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 1;
--Testcase 39:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig1')::bigint>-1000 AND (fields->>'sig3')::float8 < 1 ) AS tb1 WHERE fields->>'sig3'=ANY (ARRAY(SELECT fields->>'sig3' FROM sctbl1 WHERE (fields->>'sig1')::bigint%2=0)) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 1;
--Testcase 40:
SELECT time, fields->>'sig2' sig2 FROM sctbl1 WHERE fields->>'sig2' <= 'A' AND (fields->>'sig3')::float8 <>-5 AND (fields->>'sig1')::bigint <> 100 ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 1;

--Select aggregate functions
--Testcase 41:
SELECT max(time), max((fields->>'sig1')::bigint*0.5), max((fields->>'sig3')::float8+10) FROM sctbl1 WHERE (fields->>'sig3')::float8 NOT IN (0, 1000, -1, -2) GROUP BY fields->>'sig3', fields->>'sig1' HAVING min((fields->>'sig3')::float8) < min((fields->>'sig1')::bigint) ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 42:
SELECT tags->>'device_id' device_id,abs((fields->>'sig1')::bigint), ceil((fields->>'sig3')::float8), (fields->>'sig5')::boolean sig5 FROM sctbl1 WHERE (fields->>'sig1')::bigint > 0 AND (fields->>'sig4')::boolean = true;
--Testcase 43:
SELECT count(tags->>'device_id'),sum((fields->>'sig1')::bigint),sum((fields->>'sig1')::bigint+(fields->>'sig3')::float8),stddev((fields->>'sig3')::float8 order by (fields->>'sig3')::float8) from sctbl1 ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 5 OFFSET 0;
--Testcase 44:
SELECT mode((fields->>'sig1')::bigint) WITHIN GROUP (order by (fields->>'sig1')::bigint) from sctbl1;
--Testcase 45:
SELECT (fields->>'sig1')::bigint sig1,spread((fields->>'sig1')::bigint) FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig3' FROM sctbl1 WHERE (fields->>'sig4')::boolean in (true,false)) GROUP BY tags->>'device_id', fields->>'sig1',fields->>'sig5' HAVING (fields->>'sig5')::boolean != true ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 1;
--Testcase 46:
SELECT (fields->>'sig3')::float8 sig3, acos((fields->>'sig3')::float8), atan((fields->>'sig3')::float8) FROM sctbl1 WHERE fields->>'sig2' IS NULL GROUP BY fields->>'sig3' HAVING min((fields->>'sig1')::bigint) < min((fields->>'sig3')::float8) ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 47:
SELECT (fields->>'sig3')::float8 sig3, log((fields->>'sig3')::float8),cos((fields->>'sig3')::float8) FROM sctbl1 WHERE fields->>'sig2' IS NOT NULL AND (fields->>'sig3')::float8 > 0 GROUP BY fields->>'sig3' HAVING min((fields->>'sig3')::float8) < 100 AND max((fields->>'sig1')::bigint) < 1000 AND sum((fields->>'sig3')::float8) > -1000 AND avg((fields->>'sig3')::float8) > -1000 ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 48:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,ln((fields->>'sig1')::bigint), log10((fields->>'sig3')::float8) FROM sctbl1 WHERE NOT (fields->>'sig1')::bigint=5 GROUP BY fields->>'sig1', fields->>'sig3' HAVING min((fields->>'sig3')::float8) < 100 AND max((fields->>'sig1')::bigint) < 1000 AND (fields->>'sig1')::bigint > 0 AND (fields->>'sig3')::float8 > 0 ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 49:
SELECT max(time), max((fields->>'sig1')::bigint + (fields->>'sig3')::float8), min((fields->>'sig1')::bigint + (fields->>'sig3')::float8) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig3')::float8 > -1000 AND (fields->>'sig4')::boolean != true ) AS tb1 WHERE (fields->>'sig3')::float8 != -1 AND (fields->>'sig5')::boolean != true GROUP BY fields->>'sig1' ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 50:
SELECT every((fields->>'sig1')::bigint > 5),every((fields->>'sig3')::float8 != 5) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig3')::float8 > -1000 AND (fields->>'sig5')::boolean = true ) AS tb1 WHERE (fields->>'sig3')::float8 < 0 GROUP BY fields->>'sig1', fields->>'sig4' HAVING sum((fields->>'sig3')::float8) < avg((fields->>'sig1')::float8) ORDER BY 1 DESC, 2 LIMIT 5 OFFSET 0;
--Testcase 51:
SELECT (fields->>'sig3')::float8 sig3,exp((fields->>'sig3')::float8),exp((fields->>'sig3')::float8*2) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig3')::float8 > -1000 AND (fields->>'sig5')::boolean = true ) AS tb1 WHERE true GROUP BY fields->>'sig3' ORDER BY 1 DESC, 2, 3 LIMIT 5 OFFSET 0;
--Testcase 52:
SELECT min(time)+'10 days'::interval, min((fields->>'sig1')::bigint + (fields->>'sig3')::float8) FROM sctbl1 WHERE NOT time>'2020-01-03 20:30:50' GROUP BY fields->>'sig1', fields->>'sig3' HAVING sum((fields->>'sig3')::float8) < avg((fields->>'sig1')::float8) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 53:
SELECT floor((fields->>'sig1')::bigint*(fields->>'sig3')::float8), floor((fields->>'sig1')::bigint/(fields->>'sig3')::float8) FROM sctbl1 WHERE ((fields->>'sig3')::float8 - 1)/3 != 1 GROUP BY fields->>'sig1', fields->>'sig3' HAVING sum((fields->>'sig3')::float8) < avg((fields->>'sig1')::float8) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 54:
SELECT time, tags->>'device_id' device_id, pow((fields->>'sig1')::bigint,-2) FROM sctbl1 WHERE ((fields->>'sig3')::float8 - 1)/3 != 1 GROUP BY time, tags->>'device_id', fields->>'sig1' ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 55:
SELECT min(time)+'10 days'::interval, min((fields->>'sig3')::float8) FROM sctbl1 WHERE false GROUP BY fields->>'sig1',fields->>'sig2', fields->>'sig3' HAVING sum((fields->>'sig3')::float8) < avg((fields->>'sig1')::float8) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 56:
SELECT min(time)+'10 days'::interval, min((fields->>'sig3')::float8) FROM sctbl1 WHERE (fields->>'sig3')::float8 IN (-1,0.32,0.34,0.91,0.78) GROUP BY fields->>'sig3' HAVING min((fields->>'sig1')::bigint) > min((fields->>'sig3')::float8) ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 0;
--Testcase 57:
SELECT max((fields->>'sig3')::float8), count(*), exists(SELECT * FROM sctbl1 WHERE (fields->>'sig3')::float8 > 1), exists (SELECT count(*) FROM sctbl1 WHERE (fields->>'sig4')::boolean in ('t','f')) FROM sctbl1 WHERE (fields->>'sig5')::boolean =true GROUP BY time ORDER BY 1 ASC,2 DESC,3 ASC,4 LIMIT 5 OFFSET 0;

--Join table, each table has 5 fields
--Testcase 58:
SELECT * FROM sctbl1 s1 FULL JOIN sctbl2 s2 ON s1.tags->>'device_id'=s2.tags->>'device_id';
--Testcase 59:
SELECT s1.tags->>'device_id' device_id,(s1.fields->>'sig1')::bigint sig1,s1.fields->>'sig2' sig2,(s1.fields->>'sig3')::float8 sig3,(s1.fields->>'sig4')::boolean sig4,s2.fields->>'sig5' sig5 FROM sctbl1 s1 LEFT JOIN sctbl2 s2 ON (s1.fields->>'sig4')::boolean=(s2.fields->>'sig4')::boolean;
--Testcase 60:
SELECT s2.device_id,s2.sig1,s2.sig2,s2.sig3,s1.sig4,s1.sig5 FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1) s1 RIGHT JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM  sctbl2) s2 using(sig2) where (s2.sig1)::bigint > 0 ORDER BY s2.device_id,s2.sig1,s2.sig2,s2.sig3,s1.sig4,s1.sig5;
--Testcase 61:
SELECT * FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1) s1 LEFT OUTER JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM sctbl2) s2 using (sig2) ORDER BY s1.sig1,s1.sig2;
--Testcase 62:
SELECT s1.device_id,s1.sig1,s1.sig2,s1.sig3,s1.sig4,s1.sig5 FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5 FROM sctbl1) s1 NATURAL JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM sctbl2) s2;
--Testcase 63:
SELECT s1.tags->>'device_id' device_id,(s1.fields->>'sig1')::bigint sig1,s1.fields->>'sig2' sig2,(s1.fields->>'sig3')::float8 sig3,(s1.fields->>'sig4')::boolean sig4,(s1.fields->>'sig5')::boolean sig5 FROM sctbl1 s1 JOIN sctbl2 s2 on true;


-------------------------------------------------------------------------------------------Update data--Add 20 field------------------------------------------------------------------------------------------------------------
--Update data
\! influx -import -path=init/fields_add_20.txt -precision=ns > /dev/null

--Testcase 64:
DROP FOREIGN TABLE sctbl1;
--Testcase 65:
CREATE FOREIGN TABLE sctbl1 (time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS(fields 'true')) SERVER influxdb_svr OPTIONS (schemaless 'true', tags 'device_id');

--Testcase 66:
SELECT * FROM sctbl1;
--Testcase 67:
SELECT avg(null::numeric) FROM sctbl1;
--Testcase 68:
SELECT sqrt(null::float8) FROM sctbl1;
--Testcase 69:
SELECT sum('NaN'::numeric) FROM sctbl1;

--Select fields,tags
--Testcase 70:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig6')::bigint sig6 FROM sctbl1 WHERE NOT (fields->>'sig6')::bigint < (fields->>'sig1')::bigint ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 0;
--Testcase 71:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig7')::float8 sig7 FROM sctbl1 WHERE (fields->>'sig7')::float8 < 0 ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 0;
--Testcase 72:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::float8 sig3,(fields->>'sig8')::float8 sig8 FROM sctbl1 WHERE NOT time >'2020-1-3 20:30:50' ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 2;
--Testcase 73:
SELECT time, tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6,(fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::int sig10,fields->>'sig11' sig11,fields->>'sig12' sig12,(fields->>'sig13')::boolean sig13,fields->>'sig14' sig14,(fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16,(fields->>'sig17')::bigint sig17,fields->>'sig18' sig18,fields->>'sig19' sig19,fields->>'sig20' sig20,(fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM sctbl1 WHERE true ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 74:
SELECT time, tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6,(fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::int sig10,fields->>'sig11' sig11,fields->>'sig12' sig12,(fields->>'sig13')::boolean sig13,fields->>'sig14' sig14,(fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16,(fields->>'sig17')::bigint sig17,fields->>'sig18' sig18,fields->>'sig19' sig19,fields->>'sig20' sig20,(fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM sctbl1 WHERE false ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 75:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig9')::float8 sig9, (fields->>'sig10')::int sig10,fields->>'sig11' sig11 FROM sctbl1 WHERE (fields->>'sig8')::float8 BETWEEN 0.0 AND 10.0 ORDER BY (fields->>'sig1')::bigint DESC LIMIT 15 OFFSET 2;
--Testcase 76:
SELECT * FROM sctbl1 WHERE fields->>'sig11' LIKE 'w%' ORDER BY fields->>'sig11' DESC LIMIT 15 OFFSET 0;
--Testcase 77:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,fields->>'sig12' sig12,(fields->>'sig13')::boolean sig13 FROM sctbl1 WHERE NOT EXISTS (SELECT fields->>'sig12' FROM sctbl1 WHERE fields->>'sig11'='33') ORDER BY tags->>'device_id' DESC,(fields->>'sig1')::bigint ASC LIMIT 15 OFFSET 0;
--Testcase 78:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,fields->>'sig14' sig14,(fields->>'sig15')::bigint sig15 FROM sctbl1 WHERE (fields->>'sig9')::float8 < ALL (SELECT (fields->>'sig8')::float8 FROM sctbl1 WHERE (fields->>'sig1')::bigint > 0 AND fields->>'sig8' IS NOT NULL) ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 0;
--Testcase 79:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig16')::bigint sig16 FROM sctbl1 WHERE (fields->>'sig9')::float8 = ANY (ARRAY[-0.22,0.425,-0.9]) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 80:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,(fields->>'sig17')::bigint sig17 FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig10' FROM sctbl1 WHERE (fields->>'sig10')::bigint!=77) ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 0;
--Testcase 81:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,(fields->>'sig4')::boolean sig4,fields->>'sig18' sig18 FROM sctbl1 WHERE fields->>'sig6'=ANY (ARRAY(SELECT fields->>'sig10' FROM sctbl1 WHERE (fields->>'sig10')::bigint%2 !=0)) ORDER BY 1 DESC LIMIT 15 OFFSET 0;
--Testcase 82:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::float8 sig3,fields->>'sig19' sig19,fields->>'sig20' sig20 FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig11' FROM sctbl1 WHERE (fields->>'sig13')::boolean=true) ORDER BY 1 DESC,2 ASC LIMIT 5 OFFSET 0;
--Testcase 83:
SELECT (fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16,(fields->>'sig15')::bigint+(fields->>'sig16')::bigint as ss,fields->>'sig20' sig20,(fields->>'sig21')::boolean sig21 FROM sctbl1 WHERE fields->>'sig12' IS NULL ORDER BY (fields->>'sig1')::bigint DESC,fields->>'sig12' ASC LIMIT 15 OFFSET 0;
--Testcase 84:
SELECT (fields->>'sig16')::bigint sig16,(fields->>'sig17')::bigint sig17,(fields->>'sig16')::bigint/(fields->>'sig17')::bigint as dd,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23 FROM sctbl1 WHERE fields->>'sig12' IS NOT NULL ORDER BY fields->>'sig12' DESC,(fields->>'sig1')::int ASC LIMIT 15 OFFSET 0;
--Testcase 85:
SELECT (fields->>'sig1')::bigint sig1,(fields->>'sig17')::bigint sig17,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25,(fields->>'sig17')::bigint*(fields->>'sig25')::float8 as mm FROM sctbl1 WHERE NOT (fields->>'sig10')::bigint=15 ORDER BY fields->>'sig20' DESC LIMIT 15 OFFSET 0;
--Testcase 86:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE (fields->>'sig10')::bigint != 0 AND (fields->>'sig7')::float8=-1.234456e+78 ORDER BY 1 DESC,2 ASC LIMIT 15 OFFSET 0;
--Testcase 87:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE (fields->>'sig7')::float8 > -1.0 OR fields->>'sig12' != 'Hello' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 88:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE (fields->>'sig7')::float8 < 0 AND fields->>'sig12' > 'Mee' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 89:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE (fields->>'sig7')::float8 IN (1.234456e+8,-1.234456e+8) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 90:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE fields->>'sig12' LIKE 't%' ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 91:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE NOT EXISTS (SELECT fields->>'sig22' FROM sctbl1 WHERE fields->>'sig12'='AHWEMAKDF') ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 1;
--Testcase 92:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE (fields->>'sig8')::float8 NOT IN (0, 1000, -1, -2) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 5 OFFSET 2;
--Testcase 93:
SELECT (fields->>'sig21')::boolean sig21,fields->>'sig22' sig22,(fields->>'sig23')::bigint sig23,(fields->>'sig24')::int sig24,(fields->>'sig25')::float8 sig25 FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig6')::bigint>-1000 AND (fields->>'sig9')::float8 < 1 ) AS tb1 WHERE fields->>'sig6'=ANY (ARRAY(SELECT fields->>'sig6' FROM sctbl1 WHERE (fields->>'sig10')::bigint%2!=0)) ORDER BY 1 DESC,2 ASC,3 DESC,4,5 LIMIT 15 OFFSET 0;
--Testcase 94:
SELECT time, (fields->>'sig10')::bigint sig10,fields->>'sig12' sig12 FROM sctbl1 WHERE (fields->>'sig10')::bigint <= 1000 AND (fields->>'sig15')::float8 <> -5 AND (fields->>'sig10')::bigint <> 100 ORDER BY 1 ASC,2 DESC LIMIT 5 OFFSET 1;

--Select aggregate functions
--Testcase 95:
SELECT max(time), max((fields->>'sig15')::bigint*0.5), max((fields->>'sig17')::bigint - 10) FROM sctbl1 WHERE (fields->>'sig8')::float8 NOT IN (0.0, 1000, -1.0, -2.0) GROUP BY fields->>'sig15', fields->>'sig17' HAVING min((fields->>'sig8')::float8) < min((fields->>'sig17')::bigint) ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 96:
SELECT tags->>'device_id' device_id,abs((fields->>'sig16')::bigint), ceil((fields->>'sig8')::float8), (fields->>'sig25')::float8 sig25 FROM sctbl1 WHERE (fields->>'sig15')::bigint > 0 AND (fields->>'sig13')::boolean = true;
--Testcase 97:
SELECT count(tags->>'device_id'),sum((fields->>'sig10')::bigint),sum((fields->>'sig7')::float8+(fields->>'sig10')::bigint),stddev((fields->>'sig8')::float8 order by (fields->>'sig8')::float8) from sctbl1 ORDER BY 1 DESC,2 ASC,3 DESC LIMIT 15 OFFSET 0;
--Testcase 98:
SELECT mode(fields->>'sig12') WITHIN GROUP (order by fields->>'sig12') from sctbl1;
--Testcase 99:
SELECT (fields->>'sig10')::int sig10,spread((fields->>'sig10')::bigint) FROM sctbl1 WHERE EXISTS (SELECT fields->>'sig6' FROM sctbl1 WHERE (fields->>'sig13')::boolean in (true,false)) GROUP BY tags->>'device_id', fields->>'sig10',fields->>'sig21' HAVING (fields->>'sig21')::boolean != true ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 1;
--Testcase 100:
SELECT (fields->>'sig9')::float8 sig9, acos((fields->>'sig9')::float8), atan((fields->>'sig9')::float8) FROM sctbl1 WHERE fields->>'sig12' IS NULL GROUP BY fields->>'sig9' HAVING min((fields->>'sig10')::bigint) < min((fields->>'sig6')::bigint) ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 101:
SELECT (fields->>'sig9')::float8 sig9, log((fields->>'sig9')::float8),cos((fields->>'sig9')::float8) FROM sctbl1 WHERE fields->>'sig12' IS NOT NULL AND (fields->>'sig9')::float8 > 0 GROUP BY fields->>'sig9' HAVING min((fields->>'sig9')::float8) < 100 AND max((fields->>'sig1')::bigint) < 1000 AND sum((fields->>'sig3')::float8) > -1000 AND avg((fields->>'sig3')::float8) > -1000 ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 102:
SELECT (fields->>'sig10')::bigint sig10,(fields->>'sig8')::float8 sig8,ln((fields->>'sig10')::bigint), log10((fields->>'sig8')::float8) FROM sctbl1 WHERE NOT (fields->>'sig10')::bigint=5 GROUP BY fields->>'sig10', fields->>'sig8' HAVING min((fields->>'sig7')::float8) < 100 AND max((fields->>'sig6')::bigint) < 1000 AND (fields->>'sig10')::bigint > 0 AND (fields->>'sig8')::float8 > 0 ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 103:
SELECT max(time), max((fields->>'sig6')::bigint + (fields->>'sig7')::float8), min((fields->>'sig6')::bigint + (fields->>'sig7')::float8) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig8')::float8 > -1000 AND (fields->>'sig13')::boolean != true ) AS tb1 WHERE (fields->>'sig7')::float8 != -1 AND (fields->>'sig21')::boolean != true GROUP BY fields->>'sig6' ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 104:
SELECT avg((fields->>'sig23')::bigint order by (fields->>'sig23')::bigint),avg((fields->>'sig24')::bigint * 0.5) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig8')::float8 > -1000 AND (fields->>'sig21')::boolean = true ) AS tb1 WHERE (fields->>'sig9')::float8 < 0 GROUP BY (fields->>'sig23')::bigint, fields->>'sig24' HAVING sum((fields->>'sig8')::float8) > avg((fields->>'sig9')::float8) ORDER BY 1 DESC, 2 LIMIT 15 OFFSET 0;
--Testcase 105:
SELECT (fields->>'sig8')::float8 sig8,exp((fields->>'sig8')::float8),exp((fields->>'sig8')::float8*2) FROM ( SELECT * FROM sctbl1 WHERE (fields->>'sig9')::float8 > -1000 AND (fields->>'sig21')::boolean = true ) AS tb1 WHERE true GROUP BY fields->>'sig8' ORDER BY 1 DESC, 2, 3 LIMIT 15 OFFSET 0;
--Testcase 106:
SELECT min(time)+'10 days'::interval, min((fields->>'sig10')::bigint + (fields->>'sig25')::float8) FROM sctbl1 WHERE NOT time>'2020-01-03 20:30:50' GROUP BY fields->>'sig10', fields->>'sig25' HAVING sum((fields->>'sig23')::bigint) > avg((fields->>'sig24')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 15 OFFSET 0;
--Testcase 107:
SELECT floor((fields->>'sig23')::bigint*(fields->>'sig25')::float8), floor((fields->>'sig24')::bigint/(fields->>'sig25')::float8) FROM sctbl1 WHERE ((fields->>'sig25')::float8 - 1)/3 != 1 GROUP BY (fields->>'sig23')::bigint, (fields->>'sig24')::bigint,(fields->>'sig25')::float8 HAVING sum((fields->>'sig23')::bigint) > avg((fields->>'sig24')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 15 OFFSET 0;
--Testcase 108:
SELECT time, tags->>'device_id' device_id, pow((fields->>'sig25')::float8,2) FROM sctbl1 WHERE ((fields->>'sig25')::float8 - 1)/3 != 1 GROUP BY time,tags->>'device_id',fields->>'sig25' ORDER BY 1 ASC,2 DESC LIMIT 15 OFFSET 0;
--Testcase 109:
SELECT min(time)+'10 days'::interval, min((fields->>'sig23')::bigint) FROM sctbl1 WHERE false GROUP BY (fields->>'sig23')::bigint HAVING sum((fields->>'sig23')::bigint) > avg((fields->>'sig24')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 15 OFFSET 0;
--Testcase 110:
SELECT min(time)+'10 days'::interval, min((fields->>'sig23')::bigint) FROM sctbl1 WHERE (fields->>'sig23')::bigint IN (1112,1000,0) GROUP BY (fields->>'sig23')::bigint HAVING min((fields->>'sig23')::bigint) > min((fields->>'sig24')::bigint) ORDER BY 1 ASC,2 DESC LIMIT 15 OFFSET 0;
--Testcase 111:
SELECT max((fields->>'sig23')::bigint), count(*), exists(SELECT * FROM sctbl1 WHERE (fields->>'sig24')::bigint > 1), exists (SELECT count(*) FROM sctbl1 WHERE (fields->>'sig21')::boolean in ('T','F')) FROM sctbl1 WHERE (fields->>'sig13')::boolean =true GROUP BY time ORDER BY 1 ASC,2 DESC,3 ASC,4 LIMIT 15 OFFSET 0;
--Testcase 112:
SELECT (fields->>'sig9')::float8 sig9, abs(avg((fields->>'sig16')::bigint)),string_agg(fields->>'sig22',',' order by fields->>'sig22'),round(sin((fields->>'sig9')::float8)*2.3),sqrt(pow((fields->>'sig25')::float8,2)) FROM sctbl1 WHERE fields->>'sig12' IS NOT NULL AND (fields->>'sig9')::float8 > 0 GROUP BY (fields->>'sig9')::float8,(fields->>'sig25')::float8;

--Join table
--Testcase 113:
SELECT s1.tags->>'device_id' device_id,(s1.fields->>'sig21')::boolean sig21,s1.fields->>'sig22' sig22,(s1.fields->>'sig23')::bigint sig23,(s1.fields->>'sig24')::int sig24,(s1.fields->>'sig25')::float8 sig25 FROM sctbl1 s1 FULL JOIN sctbl2 s2 ON s1.tags->>'device_id'=s2.tags->>'device_id' ORDER BY device_id,sig21,sig22,sig23,sig24,sig25;
--Testcase 114:
SELECT s1.tags->>'device_id' device_id,(s1.fields->>'sig21')::boolean sig21,s1.fields->>'sig22' sig22,(s1.fields->>'sig23')::bigint sig23,(s2.fields->>'sig4')::boolean sig4,s2.fields->>'sig5' sig5 FROM sctbl1 s1 LEFT JOIN sctbl2 s2 ON (s1.fields->>'sig21')::boolean=(s2.fields->>'sig4')::boolean;
--Testcase 115:
SELECT s1.device_id,s1.sig21,s1.sig22,s1.sig23,s1.sig24,s1.sig25 FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6, (fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::bigint sig10,fields->>'sig11' sig11,fields->>'sig12' sig12, (fields->>'sig13')::boolean sig13, fields->>'sig14' sig14, (fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16, (fields->>'sig17')::bigint sig17, fields->>'sig18' sig18,fields->>'sig19' sig19, fields->>'sig20' sig20, (fields->>'sig21')::boolean sig21, fields->>'sig22' sig22, (fields->>'sig23')::bigint sig23, (fields->>'sig24')::bigint sig24, (fields->>'sig25')::float8 sig25 FROM sctbl1) s1 RIGHT JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4, (fields->>'sig5')::boolean sig5 FROM sctbl2) s2 using(sig1) where s2.sig3 != 0;
--Testcase 116:
SELECT * FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6, (fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::bigint sig10,fields->>'sig11' sig11,fields->>'sig12' sig12, (fields->>'sig13')::boolean sig13, fields->>'sig14' sig14, (fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16, (fields->>'sig17')::bigint sig17, fields->>'sig18' sig18,fields->>'sig19' sig19, fields->>'sig20' sig20, (fields->>'sig21')::boolean sig21, fields->>'sig22' sig22, (fields->>'sig23')::bigint sig23, (fields->>'sig24')::bigint sig24, (fields->>'sig25')::float8 sig25 FROM sctbl1) s1 FULL OUTER JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM sctbl2) s2 USING(sig2) ORDER BY s1.sig2, s1.time, s1.device_id, s2.time, s2.device_id;
--Testcase 117:
SELECT s2.device_id,s2.sig1,s2.sig2,s2.sig3,s2.sig4,s2.sig5 FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6, (fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::bigint sig10,fields->>'sig11' sig11,fields->>'sig12' sig12, (fields->>'sig13')::boolean sig13, fields->>'sig14' sig14, (fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16, (fields->>'sig17')::bigint sig17, fields->>'sig18' sig18,fields->>'sig19' sig19, fields->>'sig20' sig20, (fields->>'sig21')::boolean sig21, fields->>'sig22' sig22, (fields->>'sig23')::bigint sig23, (fields->>'sig24')::bigint sig24, (fields->>'sig25')::float8 sig25 FROM sctbl1) s1 NATURAL JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM sctbl2) s2;
--Testcase 118:
SELECT s1.device_id,s1.sig11,s1.sig12,s1.sig13,s1.sig14,s1.sig15 FROM (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,(fields->>'sig5')::boolean sig5,(fields->>'sig6')::bigint sig6, (fields->>'sig7')::float8 sig7,(fields->>'sig8')::float8 sig8,(fields->>'sig9')::float8 sig9,(fields->>'sig10')::bigint sig10,fields->>'sig11' sig11,fields->>'sig12' sig12, (fields->>'sig13')::boolean sig13, fields->>'sig14' sig14, (fields->>'sig15')::bigint sig15,(fields->>'sig16')::bigint sig16, (fields->>'sig17')::bigint sig17, fields->>'sig18' sig18,fields->>'sig19' sig19, fields->>'sig20' sig20, (fields->>'sig21')::boolean sig21, fields->>'sig22' sig22, (fields->>'sig23')::bigint sig23, (fields->>'sig24')::bigint sig24, (fields->>'sig25')::float8 sig25 FROM sctbl1) s1 JOIN (SELECT time, tags->>'device_id' device_id, (fields->>'sig1')::bigint sig1, fields->>'sig2' sig2, (fields->>'sig3')::float8 sig3, (fields->>'sig4')::boolean sig4,fields->>'sig5' sig5 FROM sctbl2) s2 on true;

--Clean
--Testcase 119:
DROP FOREIGN TABLE sctbl1;
DROP FOREIGN TABLE sctbl2;
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
DROP SERVER influxdb_svr CASCADE;
DROP EXTENSION influxdb_fdw;
