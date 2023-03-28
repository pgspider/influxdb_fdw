# InfluxDB Foreign Data Wrapper for PostgreSQL
This PostgreSQL extension is a Foreign Data Wrapper (FDW) for InfluxDB.

The current version can work with PostgreSQL 11, 12, 13, 14, 15 and confirmed with:   
  - InfluxDB 1.8: with either [influxdb1-go](#install-influxdb-go-client-library) client or [influxdb-cxx](#install-influxdb_cxx-client-library) client.
  - InfluxDB 2.2: with [influxdb-cxx](#install-influxdb_cxx-client-library) client via InfluxDB v1 compatibility API.

## Installation
Influxdb_fdw supports 2 different client: Go client and Influxdb_cxx client. The installation for each kind of client is described as below.
### Install InfluxDB Go client library
Go version should be 1.10.4 or later.
<pre>
go get github.com/influxdata/influxdb1-client/v2
</pre>
To use Go client, use GO_CLIENT=1 flag when compile the source code

### Install Influxdb_cxx client library
Get source code from [`influxdb-cxx github repository`](https://github.com/pgspider/influxdb-cxx) and install as manual:
```
git clone https://github.com/pgspider/influxdb-cxx
cd influxdb-cxx
cmake .. -DINFLUXCXX_WITH_BOOST=OFF -DINFLUXCXX_TESTING=OFF
sudo make install
```

Update LD_LIBRARY_PATH follow the installation folder of Influxdb_cxx client

To use Influxdb_cxx, use CXX_CLIENT=1 flag when compile the source code. It is required to use gcc version 7 to build influxdb_fdw with influxdb_cxx client.

### Compile source code and install
Add a directory of pg_config to PATH and build and install influxdb_fdw.

Using Go client
<pre>
make USE_PGXS=1 with_llvm=no GO_CLIENT=1
make install USE_PGXS=1 with_llvm=no GO_CLIENT=1
</pre>

Using Influxdb_cxx client
<pre>
make USE_PGXS=1 with_llvm=no CXX_CLIENT=1
make install USE_PGXS=1 with_llvm=no CXX_CLIENT=1
</pre>
with_llvm=no is necessary to disable llvm bit code generation when PostgreSQL is configured with --with-llvm because influxdb_fdw use go code and cannot be compiled to llvm bit code.

If you want to build influxdb_fdw in a source tree of PostgreSQL instead, use

Using Go client
<pre>
make with_llvm=no GO_CLIENT=1
make install  with_llvm=no GO_CLIENT=1
</pre>

Using Influxdb_cxx client
<pre>
make with_llvm=no CXX_CLIENT=1
make install  with_llvm=no CXX_CLIENT=1
</pre>

## Usage
### Load extension
<pre>
CREATE EXTENSION influxdb_fdw;
</pre>

### Create server
#### Go Client connect to InfluxDB ver 1.x
<pre>
CREATE SERVER influxdb_server FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086') ;
</pre>
#### Influxdb_cxx Client connect to InfluxDB ver 1.x
<pre>
CREATE SERVER influxdb_server FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086', version '1') ;
</pre>
#### Influxdb_cxx Client connect to InfluxDB ver 2.x
<pre>
CREATE SERVER influxdb_server FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086', version '2', retention_policy '') ;
</pre>


### Create user mapping
#### Go Client connect to InfluxDB ver 1.x
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_server OPTIONS(user 'user', password 'pass');
</pre>
#### Influxdb_cxx Client connect to InfluxDB ver 1.x
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_server OPTIONS(user 'user', password 'pass');
</pre>
#### Influxdb_cxx Client connect to InfluxDB ver 2.x
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_server OPTIONS(auth_token 'token');
</pre>


### Create foreign table
You need to declare a column named "time" to access InfluxDB time column.
<pre>
CREATE FOREIGN TABLE t1(time timestamp with time zone , tag1 text, field1 integer) SERVER influxdb_server OPTIONS (table 'measurement1');
</pre>
You can use "tags" option to specify tag keys of a foreign table.
<pre>
CREATE FOREIGN TABLE t2(tag1 text, field1 integer, tag2 text, field2 integer) SERVER influxdb_server OPTIONS (tags 'tag1, tag2');
</pre>

### Import foreign schema
<pre>
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_server INTO public;
</pre>

Following options are supported:
* **host** - the address used to connect to InfluxDB server.
* **port** - the port used to connect to InfluxDB server.
* **dbname** - target database name
* **retention_policy** - retention policy of target database (default empty ``).
* **user** - username for V1 basic authentication.
* **password** - password for V1 basic authentication.
* **auth_token** - token for V2 Token authentication.
* **version** - InfluxDB server version which to connect to (Only `1` or `2`). If not, InfluxDB FDW will try to connect to InfluxDB V2 first. If unsuccessful, it will try to connect to InfluxDB V1. If it is still unsuccessful, error will be raised.

### Access foreign table
<pre>
SELECT * FROM t1;
</pre>

## Features
### GROUP BY time intervals and fill()

Support GROUP BY times() fill() syntax for influxdb.
The fill() is supported by two stub function:
- influx_fill_numeric(): use with numeric parameter for example: 100, 100.1111
- influx_fill_option(): use with specified option such as: none, null, linear, previous.

The influx_fill_numeric() and influx_fill_option() is embeded as last parameter of time() function. The table below illustrates the usage:

| PostgreSQL syntax | Influxdb Syntax |
|-------------------|-----------------|
|influx_time(time, interval '2h')|time(2h)|
|influx_time(time, interval '2h', interval '1h')|time(2h, 1h)|
|influx_time(time, interval '2h', influx_fill_numeric(100))|time(2h) fill(100)|
|influx_time(time, interval '2h', influx_fill_option('linear'))|time(2h) fill(linear)|
|influx_time(time, interval '2h', interval '1h', influx_fill_numeric(100))|time(2h, 1h) fill(100)|
|influx_time(time, interval '2h', interval '1h', influx_fill_option('linear'))|time(2h,1h) fill(linear)|

### Schemaless feature
- The feature enables user to utilize schema-less feature of InfluxDB.
- For example, without schemaless feature if a tag-key or field-key is added to InfluxDB measurement, user have to create corresponding foreign
table in PostgreSQL. This feature eliminates this re-creation of foreign table.
- `schemaless` foreign table option in influxdb_fdw:
  - schemaless `true` enable schemaless mode.
  - schemaless `false` disable schemaless mode.
- `schemaless` option is supported in `IMPORT FOREIGN SCHEMA`.
- If schemaless option is not configured, default value is `false`.
- If schemaless is `false` or not configured, influxdb_fdw works as non-schemaless mode.

Columns of foreign table in schemaless mode
- The columns are fixed with names and types as below:
  <pre>
    (time timestamp with time zone, tags jsonb, fields jsonb)
  </pre>
- The tag and/or field keys of InfluxDB are represented by key-value column in PostgreSQL's `jsonb` type.
- The columns are created with `tags` or `fields` foreign column options:
  - tags `true` indicates this column as containing values of tags in InfluxDB measurement.
  - fields `true` indicates this column as containing values of fields in InfluxDB measurement.
- Creation of foreign table in schemaless mode, for example:
  <pre>
  -- Create foreign table
  CREATE FOREIGN TABLE sc1(
      time timestamp with time zone,
      tags jsonb OPTIONS(tags 'true'),
      fields jsonb OPTIONS (fields 'true')
  )SERVER influxdb_svr OPTIONS(table 'sc1', tags 'device_id', schemaless 'true');

  -- import foreign schema
  IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_svr INTO public OPTIONS (schemaless 'true');
  </pre>

Querying foreign tables:
- Initialize data in InfluxDB.
  <pre>
  sc1,device_id=dev1 sig1=1i,sig2="a",sig3=1.1,sig4=true 0
  sc1,device_id=dev2 sig1=2i,sig2="b",sig3=1.2,sig4=false 0
  sc1,device_id=dev3 sig1=3i,sig2="c",sig3=1.3,sig4=false 0
  sc1,device_id=dev1 sig1=4i,sig2="d",sig3=2.4,sig4=true 1
  sc1,device_id=dev2 sig1=5i,sig2="e",sig3=2.5,sig4=false 1
  sc1,device_id=dev3 sig1=6i,sig2="f",sig3=2.6,sig4=false 1
  sc1,device_id=dev1 sig1=7i,sig2="g",sig3=3.7,sig4=true 2
  sc1,device_id=dev2 sig1=8i,sig2="h",sig3=3.8,sig4=false 2
  sc1,device_id=dev3 sig1=9i,sig2="i",sig3=3.9,sig4=false 2
  </pre>

- Get data through schemaless foreign table:
  <pre>
  
  EXPLAIN VERBOSE
  SELECT * FROM sc1;
                              QUERY PLAN                             
  --------------------------------------------------------------------
  Foreign Scan on public.sc1  (cost=10.00..853.00 rows=853 width=72)
    Output: "time", tags, fields
    InfluxDB query: SELECT * FROM "sc1"
  (3 rows)

  SELECT * FROM sc1;
            time          |         tags          |                           fields                           
  ------------------------+-----------------------+------------------------------------------------------------
  1970-01-01 09:00:00+09 | {"device_id": "dev1"} | {"sig1": "1", "sig2": "a", "sig3": "1.1", "sig4": "true"}
  1970-01-01 09:00:00+09 | {"device_id": "dev2"} | {"sig1": "2", "sig2": "b", "sig3": "1.2", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev3"} | {"sig1": "3", "sig2": "c", "sig3": "1.3", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev1"} | {"sig1": "4", "sig2": "d", "sig3": "2.4", "sig4": "true"}
  1970-01-01 09:00:00+09 | {"device_id": "dev2"} | {"sig1": "5", "sig2": "e", "sig3": "2.5", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev3"} | {"sig1": "6", "sig2": "f", "sig3": "2.6", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev1"} | {"sig1": "7", "sig2": "g", "sig3": "3.7", "sig4": "true"}
  1970-01-01 09:00:00+09 | {"device_id": "dev2"} | {"sig1": "8", "sig2": "h", "sig3": "3.8", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev3"} | {"sig1": "9", "sig2": "i", "sig3": "3.9", "sig4": "false"}
  (9 rows)
  </pre>

Fetch values in jsonb expression:
- Using `->>` jsonb arrow operator to fetch actual remote InfluxDB tag or fields keys from foreign schemaless columns.
  User may cast type of the jsonb expression to get corresponding data representation.
- For example, `fields->>'sig1'` expression of fetch value `sig1` is actual field key `sig1` in remote data source InfluxDB.
- The jsonb expression can be pushed down in WHERE, GROUP BY, ORDER BY and aggregation.

For examples:
- Fetch all column based on all actual columns:
  <pre>
  
  EXPLAIN VERBOSE
  SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;
                                                                                              QUERY PLAN                                                                                              
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Foreign Scan on public.sc1  (cost=10.00..876.46 rows=853 width=89)
    Output: "time", (tags ->> 'device_id'::text), ((fields ->> 'sig1'::text))::bigint, (fields ->> 'sig2'::text), ((fields ->> 'sig3'::text))::double precision, ((fields ->> 'sig4'::text))::boolean
    InfluxDB query: SELECT "device_id", "sig1", "sig2", "sig3", "sig4" FROM "sc1"
  (3 rows)

  SELECT time,tags->>'device_id' device_id,(fields->>'sig1')::bigint sig1,fields->>'sig2' sig2,(fields->>'sig3')::double precision sig3,(fields->>'sig4')::boolean sig4 FROM sc1;
            time          | device_id | sig1 | sig2 | sig3 | sig4 
  ------------------------+-----------+------+------+------+------
  1970-01-01 09:00:00+09 | dev1      |    1 | a    |  1.1 | t
  1970-01-01 09:00:00+09 | dev2      |    2 | b    |  1.2 | f
  1970-01-01 09:00:00+09 | dev3      |    3 | c    |  1.3 | f
  1970-01-01 09:00:00+09 | dev1      |    4 | d    |  2.4 | t
  1970-01-01 09:00:00+09 | dev2      |    5 | e    |  2.5 | f
  1970-01-01 09:00:00+09 | dev3      |    6 | f    |  2.6 | f
  1970-01-01 09:00:00+09 | dev1      |    7 | g    |  3.7 | t
  1970-01-01 09:00:00+09 | dev2      |    8 | h    |  3.8 | f
  1970-01-01 09:00:00+09 | dev3      |    9 | i    |  3.9 | f
  (9 rows)
  </pre>

- jsonb expression is pushed down in WHERE.
  <pre>
  
  EXPLAIN VERBOSE
  SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2;
                              QUERY PLAN                             
  --------------------------------------------------------------------
  Foreign Scan on public.sc1  (cost=10.00..284.00 rows=284 width=72)
    Output: "time", tags, fields
    InfluxDB query: SELECT * FROM "sc1" WHERE (("sig3" > 2))
  (3 rows)

  SELECT * FROM sc1 WHERE (fields->>'sig3')::double precision > 2;
            time          |         tags          |                           fields                           
  ------------------------+-----------------------+------------------------------------------------------------
  1970-01-01 09:00:00+09 | {"device_id": "dev1"} | {"sig1": "4", "sig2": "d", "sig3": "2.4", "sig4": "true"}
  1970-01-01 09:00:00+09 | {"device_id": "dev2"} | {"sig1": "5", "sig2": "e", "sig3": "2.5", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev3"} | {"sig1": "6", "sig2": "f", "sig3": "2.6", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev1"} | {"sig1": "7", "sig2": "g", "sig3": "3.7", "sig4": "true"}
  1970-01-01 09:00:00+09 | {"device_id": "dev2"} | {"sig1": "8", "sig2": "h", "sig3": "3.8", "sig4": "false"}
  1970-01-01 09:00:00+09 | {"device_id": "dev3"} | {"sig1": "9", "sig2": "i", "sig3": "3.9", "sig4": "false"}
  (6 rows)
  </pre>

- jsonb expression is pushed down in aggregate sum (remote) + tag + group by
  <pre>
  
  EXPLAIN VERBOSE
  SELECT sum((fields->>'sig1')::bigint),tags->>'device_id' device_id FROM sc1 GROUP BY tags->>'device_id';
                                        QUERY PLAN                                      
  --------------------------------------------------------------------------------------
  Foreign Scan  (cost=1.00..1.00 rows=1 width=64)
    Output: (sum(((fields ->> 'sig1'::text))::bigint)), ((tags ->> 'device_id'::text))
    InfluxDB query: SELECT sum("sig1") FROM "sc1" GROUP BY ("device_id")
  (3 rows)

  SELECT sum((fields->>'sig1')::bigint),tags->>'device_id' device_id FROM sc1 GROUP BY tags->>'device_id';
  sum | device_id 
  -----+-----------
    12 | dev1
    15 | dev2
    18 | dev3
  (3 rows)
  </pre>

### Others
- InfluxDB FDW supports pushed down some aggregate functions: count, stddev, sum, max, min.
- InfluxDB FDW supports INSERT, DELETE statements.
  - `time` and `time_text` column can used for INSERT, DELETE statements.
  - `time` column can express timestamp with precision down to microseconds.
  - `time_text` column can express timestamp with precision down to nanoseconds.
- InfluxDB FDW supports bulk INSERT by using batch_size option from PostgreSQL version 14 or later.
- WHERE clauses including timestamp, interval and `now()` functions are pushed down.
- LIMIT...OFFSET clauses are pushed down when there is LIMIT clause only or both LIMIT and OFFSET.<br>
- Support pushdown DISTINCT argument for only count clause.
- Support pushdown ANY ARRAY.

## Limitations
- UPDATE is not supported.
- WITH CHECK OPTION constraints is not supported.
Following limitations originate from data model and query language of InfluxDB.
- Result sets have different number of rows depending on specified target list.
For example, `SELECT field1 FROM t1` and `SELECT field2 FROM t1` returns different number of rows if
the number of points with field1 and field2 are different in InfluxDB database.
- Timestamp precision may be lost because timestamp resolution of PostgreSQL is microseconds while that of InfluxDB is nanoseconds.
- Conditions like `WHERE time + interval '1 day' < now()` do not work. Please use `WHERE time < now() - interval '1 day'`.

When a query to foreign tables fails, you can find why it fails by seeing a query executed in InfluxDB with `EXPLAIN VERBOSE`.

### The existence of null values depends on the target list in remote query in InfluxDB
- If specific field keys are selected, InfluxDB does not return null values for any row that has null value.
- In InfluxDB, `SELECT tag_keys` - selecting only tag keys does not return values, so some field keys are required to be selected.
Current implementation of non-schemaless need arbitrary on field key added to remote select query. And this is a limitation of current influxdb_fdw, e.g. remote query: `SELECT tag_keys, field_key`. 
Even though the field key has null values, this InfluxDB query does not return null values.
- If all field key is selected by `SELECT *` in remote query, null values are returned by InfluxDB.

For example:
- Initialize data: 8 records are inserted.
  <pre>
  CREATE FOREIGN TABLE J2_TBL (
    i integer,
    k integer
  ) SERVER influxdb_svr;

  -- Insert data with some null values
  INSERT INTO J2_TBL VALUES (1, -1);
  INSERT INTO J2_TBL VALUES (2, 2);
  INSERT INTO J2_TBL VALUES (3, -3);
  INSERT INTO J2_TBL VALUES (2, 4);
  INSERT INTO J2_TBL VALUES (5, -5);
  INSERT INTO J2_TBL VALUES (5, -5);
  INSERT INTO J2_TBL VALUES (0, NULL);
  INSERT INTO J2_TBL VALUES (NULL, 0);
  </pre>
- Query in InfluxDB server by selecting specific field keys: 7 records are returned without null value.
  <pre>
  > SELECT k FROM j2_tbl;
  name: j2_tbl
  time k
  ---- -
  1    -1
  2    2
  3    -3
  4    4
  5    -5
  6    -5
  10   0
  </pre>
- Query in InfluxDB server by selecting all field key: 8 records are returned with null value.
  <pre>
  > SELECT * FROM j2_tbl;
  name: j2_tbl
  time i k
  ---- - -
  1    1 -1
  2    2 2
  3    3 -3
  4    2 4
  5    5 -5
  6    5 -5
  7    0 
  10     0
  </pre>

### The targets list contains both functions and `fields` schemaless jsonb column
- If the targets list contains both functions and `fields` schemaless jsonb column, the function is not pushed down.
- For examples, if the target list contains:
  - `fields, fields->>'c2', sqrt((fields->>'c1')::int)`: function `sqrt()` is not pushed down.
  - `fields, sqrt((fields->>'c1')::int)`: function `sqrt()` is not pushed down.
  - `fields->>'c2', sqrt((fields->>'c1')::int)`: there is no fields jsonb column, so function `sqrt()` is pushed down.

## Notes
- InfluxDB FDW does not return an error even if it is overflow.
- EXP function of InfluxDB may return different precision number in different PC.

## Contributing
Opening issues and pull requests on GitHub are welcome.

## License
Copyright (c) 2018, TOSHIBA CORPORATION
Copyright (c) 2011-2016, EnterpriseDB Corporation

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][4] file for full details.

[4]: LICENSE
