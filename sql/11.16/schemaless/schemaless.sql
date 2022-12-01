--Testcase 1:
SET datestyle=ISO;
-- timestamp with time zone differs based on this
--Testcase 2:
SET timezone='Japan';

\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 3:
DROP EXTENSION IF EXISTS influxdb_fdw CASCADE;

--Testcase 4:
CREATE EXTENSION influxdb_fdw CASCADE;

--Testcase 5:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'schemalessdb', :SERVER);

--Testcase 6:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (:AUTHENTICATION);

-- create foreign table
--Testcase 7:
CREATE FOREIGN TABLE sc1(time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(table 'sc1', tags 'device_id', schemaless 'true');
--Testcase 8:
CREATE FOREIGN TABLE sc2(time timestamp with time zone, tags jsonb OPTIONS(tags 'true'), fields jsonb OPTIONS (fields 'true')) SERVER influxdb_svr OPTIONS(table 'sc2', tags 'device_id', schemaless 'true');

--Testcase 9:
DROP FOREIGN TABLE sc1;
--Testcase 10:
DROP FOREIGN TABLE sc2;
-- import foreign table
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO public OPTIONS (schemaless 'true');
--Testcase 11:
ALTER FOREIGN TABLE sc2 RENAME COLUMN fields TO fields2;
--Testcase 12:
ALTER FOREIGN TABLE sc2 RENAME COLUMN tags TO tags2;

-- baserel *
--Testcase 13:
EXPLAIN VERBOSE
SELECT * FROM sc1;

--Testcase 14:
SELECT * FROM sc1;

-- baserel all column names
--Testcase 15:
EXPLAIN VERBOSE
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

--Testcase 16:
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

-- baserel time only
--Testcase 17:
EXPLAIN VERBOSE
SELECT time FROM sc1;

--Testcase 18:
SELECT time FROM sc1;

-- baserel tag only
--Testcase 19:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id FROM sc1;

--Testcase 20:
SELECT tags->>'device_id' device_id FROM sc1;

-- baserel field only
--Testcase 21:
EXPLAIN VERBOSE
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

--Testcase 22:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

-- baserel tag+field
--Testcase 23:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

--Testcase 24:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;

-- baserel * (remote restrict only)
--Testcase 25:
EXPLAIN VERBOSE
SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

--Testcase 26:
SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

-- baserel all (remote restrict only)
--Testcase 27:
EXPLAIN VERBOSE
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

--Testcase 28:
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

-- baserel field only (remote restrict only)
--Testcase 29:
EXPLAIN VERBOSE
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

--Testcase 30:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

-- baserel tag+field (remote restrict only)
--Testcase 31:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

--Testcase 32:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

-- baserel tag+field(except restrict var) (remote restrict only)
--Testcase 33:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

--Testcase 34:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2;

-- baserel * (local restrict only)
--Testcase 35:
EXPLAIN VERBOSE
SELECT * FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

--Testcase 36:
SELECT * FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

-- baserel all (local restrict only)
--Testcase 37:
EXPLAIN VERBOSE
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

--Testcase 38:
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

-- baserel field only (local restrict only)
--Testcase 39:
EXPLAIN VERBOSE
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

--Testcase 40:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

-- baserel tag+field (local restrict only)
--Testcase 41:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

--Testcase 42:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

-- baserel tag+field(except local restrict var) (local restrict only)
--Testcase 43:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

--Testcase 44:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE upper(fields->>'sig2') <> 'I';

-- baserel * (both restricts)
--Testcase 45:
EXPLAIN VERBOSE
SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 46:
SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel all (both restricts)
--Testcase 47:
EXPLAIN VERBOSE
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 48:
SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel field only (both restricts)
--Testcase 49:
EXPLAIN VERBOSE
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 50:
SELECT (fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel tag+field (both restricts)
--Testcase 51:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 52:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel tag+field(except local restrict var) (both restricts)
--Testcase 53:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 54:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel tag+field(except remote restrict var) (both restricts)
--Testcase 55:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 56:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- baserel tag+field(except local and remote restrict var) (both restricts)
--Testcase 57:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

--Testcase 58:
SELECT tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,(fields->>'sig4')::boolean sig4 FROM sc1 WHERE (fields->>'sig3')::double precision > 2 AND upper(fields->>'sig2') <> 'I';

-- aggregate sum (remote)
--Testcase 59:
EXPLAIN VERBOSE
SELECT sum((fields->>'sig1')::bigint),sum((fields->>'sig3')::double precision) FROM sc1;

--Testcase 60:
SELECT sum((fields->>'sig1')::bigint),sum((fields->>'sig3')::double precision) FROM sc1;

-- aggregate count (remote)
--Testcase 61:
EXPLAIN VERBOSE
SELECT count(fields->>'sig1'),count(fields->>'sig2'),count(fields->>'sig3'),count(fields->>'sig4') FROM sc1;

--Testcase 62:
SELECT count(fields->>'sig1'),count(fields->>'sig2'),count(fields->>'sig3'),count(fields->>'sig4') FROM sc1;

-- aggregate avg (local)
--Testcase 63:
EXPLAIN VERBOSE
SELECT avg((fields->>'sig1')::bigint),avg((fields->>'sig3')::double precision) FROM sc1;

--Testcase 64:
SELECT avg((fields->>'sig1')::bigint),avg((fields->>'sig3')::double precision) FROM sc1;

-- aggregate sum (remote) + tag + group by
--Testcase 65:
EXPLAIN VERBOSE
SELECT sum((fields->>'sig1')::bigint),tags->>'device_id' device_id FROM sc1 GROUP BY tags->>'device_id';

--Testcase 66:
SELECT sum((fields->>'sig1')::bigint),tags->>'device_id' device_id FROM sc1 GROUP BY tags->>'device_id';

-- aggregate sum (remote) + tag + group by time
--Testcase 67:
EXPLAIN VERBOSE
SELECT sum((fields->>'sig1')::bigint) FROM sc1 WHERE time >= to_timestamp(0) AND time <= to_timestamp(2) GROUP BY influx_time(time, interval '1s');

--Testcase 68:
SELECT sum((fields->>'sig1')::bigint) FROM sc1 WHERE time >= to_timestamp(0) AND time <= to_timestamp(2) GROUP BY influx_time(time, interval '1s');

-- aggreagte sum (remote) + tag + group by time
--Testcase 69:
EXPLAIN VERBOSE
SELECT tags->>'device_id' device_id,sum((fields->>'sig1')::bigint),fields->>'sid' sid FROM sc3 GROUP BY fields->>'sid', tags->>'device_id';

--Testcase 70:
SELECT tags->>'device_id' device_id,sum((fields->>'sig1')::bigint),fields->>'sid' sid FROM sc3 GROUP BY fields->>'sid', tags->>'device_id';

-- fucntion (remote)
--Testcase 71:
EXPLAIN VERBOSE
SELECT sqrt((fields->>'sig1')::bigint) FROM sc1;

--Testcase 72:
SELECT sqrt((fields->>'sig1')::bigint) FROM sc1;

-- sparse data - baserel field only
--Testcase 73:
EXPLAIN VERBOSE
SELECT (fields->>'sig')::double precision sig FROM sc4;

--Testcase 74:
SELECT (fields->>'sig')::double precision sig FROM sc4;

-- sparse data - baserel filed + remote restrict - no result by filter
--Testcase 75:
EXPLAIN VERBOSE
SELECT (fields->>'sig')::double precision sig FROM sc4 WHERE time >= to_timestamp(1) AND time <= to_timestamp(2);

--Testcase 76:
SELECT (fields->>'sig')::double precision sig FROM sc4 WHERE time >= to_timestamp(1) AND time <= to_timestamp(2);

-- sparse data - aggreate avg (local) + remote restrict - ?
--Testcase 77:
EXPLAIN VERBOSE
SELECT avg((fields->>'sig')::double precision) FROM sc4 WHERE time >= to_timestamp(1) AND time <= to_timestamp(2);

--Testcase 78:
SELECT avg((fields->>'sig')::double precision) FROM sc4 WHERE time >= to_timestamp(1) AND time <= to_timestamp(2);

-- aggregate sum (remote) and avg (local)
--Testcase 79:
EXPLAIN VERBOSE
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig1')::bigint) FROM sc1;

--Testcase 80:
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig1')::bigint) FROM sc1;

-- aggregate sum (remote) and avg (local) different remote column
--Testcase 81:
EXPLAIN VERBOSE
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig3')::double precision) FROM sc1;

--Testcase 82:
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig3')::double precision) FROM sc1;

-- aggregate sum (remote) and avg (local) having non existed remote column
--Testcase 83:
EXPLAIN VERBOSE
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig')::double precision) FROM sc1;

--Testcase 84:
SELECT avg((fields->>'sig1')::bigint), sum((fields->>'sig')::double precision) FROM sc1;

-- aggregate sum (remote) + field + group by(field) + order by(field) - no pushdown for aggregation
--Testcase 85:
EXPLAIN VERBOSE
SELECT sum((fields->>'sig1')::bigint),(fields->>'sig1')::bigint sig1 FROM sc1 GROUP BY (fields->>'sig1')::bigint ORDER BY (fields->>'sig1')::bigint;

--Testcase 86:
SELECT sum((fields->>'sig1')::bigint),(fields->>'sig1')::bigint sig1 FROM sc1 GROUP BY (fields->>'sig1')::bigint ORDER BY (fields->>'sig1')::bigint;

--Testcase 87:
EXPLAIN VERBOSE
SELECT count(*) FROM (SELECT (fields->>'sig1')::bigint sig1 FROM sc1) sc;

--Testcase 88:
SELECT count(*) FROM (SELECT (fields->>'sig1')::bigint sig1 FROM sc1) sc;

-- drop extension
--Testcase 89:
DROP FOREIGN TABLE sc1;
--Testcase 90:
DROP FOREIGN TABLE sc2;
--Testcase 91:
DROP FOREIGN TABLE sc3;
--Testcase 92:
DROP FOREIGN TABLE sc4;
--Testcase 93:
DROP USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 94:
DROP SERVER influxdb_svr;
--Testcase 95:
DROP EXTENSION influxdb_fdw;
