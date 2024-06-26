InfluxDB Foreign Data Wrapper for PostgreSQL
============================================

This is a foreign data wrapper (FDW) to connect [PostgreSQL](https://www.postgresql.org/)
to [InfluxDB](https://www.influxdata.com) database file. This FDW works with PostgreSQL 12, 13, 14, 15, 16.0 and confirmed with
- InfluxDB 1.8: with either [influxdb1-go](#install-influxdb-go-client-library) client or [influxdb-cxx](#install-influxdb_cxx-client-library) client.
- InfluxDB 2.2: with [influxdb-cxx](#install-influxdb_cxx-client-library) client via InfluxDB v1 compatibility API.

<img src="https://upload.wikimedia.org/wikipedia/commons/2/29/Postgresql_elephant.svg" align="center" height="100" alt="PostgreSQL"/>	+	<img src="https://assets.zabbix.com/img/brands/influxdb.svg" align="center" height="100" alt="InfluxDB"/>

Contents
--------

1. [Features](#features)
2. [Supported platforms](#supported-platforms)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Functions](#functions)
6. [Identifier case handling](#identifier-case-handling)
7. [Generated columns](#generated-columns)
8. [Character set handling](#character-set-handling)
9. [Examples](#examples)
10. [Limitations](#limitations)
11. [Contributing](#contributing)
12. [Useful links](#useful-links)
13. [License](#license)

Features
--------
### Common features

- InfluxDB FDW supports `INSERT`, `DELETE` statements.
  - `time` and `time_text` column can used for `INSERT`, `DELETE` statements.
  - `time` column can express timestamp with precision down to microseconds.
  - `time_text` column can express timestamp with precision down to nanoseconds.
- InfluxDB FDW supports bulk `INSERT` by using `batch_size` option (with PostgreSQL 14+).

#### `GROUP BY` time intervals and `fill()`

Support `GROUP BY` `times()` `fill()` syntax for InfluxDB.
The `fill()` is supported by two stub function:
- `influx_fill_numeric()`: use with numeric parameter for example: `100`, `100.1111`
- `influx_fill_option()`: use with specified option such as: `none`, `null`, `linear`, `previous`.

The `influx_fill_numeric()` and `influx_fill_option()` is embeded as last parameter of `time()` function. The table below illustrates the usage:

| PostgreSQL syntax | Influxdb Syntax |
|-------------------|-----------------|
|influx_time(time, interval '2h')|time(2h)|
|influx_time(time, interval '2h', interval '1h')|time(2h, 1h)|
|influx_time(time, interval '2h', influx_fill_numeric(100))|time(2h) fill(100)|
|influx_time(time, interval '2h', influx_fill_option('linear'))|time(2h) fill(linear)|
|influx_time(time, interval '2h', interval '1h', influx_fill_numeric(100))|time(2h, 1h) fill(100)|
|influx_time(time, interval '2h', interval '1h', influx_fill_option('linear'))|time(2h,1h) fill(linear)|

#### Schemaless feature
- The feature enables user to utilize schema-less feature of InfluxDB, enabled by setting special options.
- For example, without schemaless feature if a tag-key or field-key is added to InfluxDB measurement, user have to create corresponding foreign table in PostgreSQL. This feature eliminates this re-creation of foreign table.

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
```sql
  -- Create foreign table
	CREATE FOREIGN TABLE sc1(
	  time timestamp with time zone,
          tags jsonb OPTIONS(tags 'true'),
          fields jsonb OPTIONS (fields 'true')
	)
	SERVER influxdb_svr
	OPTIONS (
	  table 'sc1',
          tags 'device_id',
          schemaless 'true'
	);
-- import foreign schema
	IMPORT FOREIGN SCHEMA public
	FROM SERVER influxdb_svr
	INTO public
	OPTIONS (
          schemaless 'true'
        );
```
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
- Using `->>` `jsonb` arrow operator to fetch actual remote InfluxDB tag or fields keys from foreign schemaless columns.
  User may cast type of the jsonb expression to get corresponding data representation.
- For example, `fields->>'sig1'` expression of fetch value `sig1` is actual field key `sig1` in remote data source InfluxDB.
- The `jsonb` expression can be pushed down in `WHERE`, `GROUP BY`, `ORDER BY` and aggregation.

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

- `jsonb` expression is pushed down in `WHERE`.
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

- `jsonb` expression is pushed down in aggregate `sum` (remote) + tag + `group by`
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

### Pushdowning

- `WHERE` clauses including `timestamp`, `interval` and `now()` functions.
- Some of aggregate functions: `count`, `stddev`, `sum`, `max`, `min`.
- `LIMIT...OFFSET` clauses when there is `LIMIT` clause only or both `LIMIT` and `OFFSET`.
- `DISTINCT` argument for only `count` clause.
- `ANY ARRAY`.

### Notes about features

#### The existence of `NULL` values depends on the target list in remote query in InfluxDB
- If specific field keys are selected, InfluxDB does not return `NULL` values for any row that has `NULL` value.
- In InfluxDB, `SELECT tag_keys` - selecting only tag keys does not return values, so some field keys are required to be selected.
Current implementation of non-schemaless need arbitrary on field key added to remote select query. And this is a limitation of current `influxdb_fdw`, e.g. remote query: `SELECT tag_keys, field_key`.
Even though the field key has `NULL` values, this InfluxDB query does not return `NULL` values.
- If all field key is selected by `SELECT *` in remote query, `NULL` values are returned by InfluxDB.

For example:
- Initialize data: 8 records are inserted.
```sql
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
```
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

#### The targets list contains both functions and `fields` schemaless jsonb column
- If the targets list contains both functions and `fields` schemaless `jsonb` column, the function is not pushed down.
- For examples, if the target list contains:
  - `fields, fields->>'c2', sqrt((fields->>'c1')::int)`: function `sqrt()` is not pushed down.
  - `fields, sqrt((fields->>'c1')::int)`: function `sqrt()` is not pushed down.
  - `fields->>'c2', sqrt((fields->>'c1')::int)`: there is no fields jsonb column, so function `sqrt()` is pushed down.

Also see [Limitations](#limitations).

Supported platforms
-------------------

`influxdb_fdw` was developed on Linux, and should run on any
reasonably POSIX-compliant system.

`influxdb_fdw` is designed to be compatible with PostgreSQL 12 ~ 16.0.

Installation
------------
### Prerequisites

`Influxdb_fdw` supports 2 different client:
- Go client
- `Influxdb_cxx` client.

The installation for each kind of client is described as below.

#### Install InfluxDB Go client library

Go version should be 1.10.4 or later.
```
go get github.com/influxdata/influxdb1-client/v2
```
To use Go client, use GO_CLIENT=1 flag when compile the source code

#### Install `Influxdb_cxx` client library

Get source code from [`influxdb-cxx`](https://github.com/pgspider/influxdb-cxx) github repository and install as manual:
```
git clone https://github.com/pgspider/influxdb-cxx
cd influxdb-cxx
cmake .. -DINFLUXCXX_WITH_BOOST=OFF -DINFLUXCXX_TESTING=OFF
sudo make install
```
Update `LD_LIBRARY_PATH` follow the installation folder of `Influxdb_cxx` client

To use `Influxdb_cxx`, use `CXX_CLIENT=1` flag when compile the source code. It is required to use `gcc` version 7 to build `influxdb_fdw` with `influxdb_cxx` client.

### Source installation
Add a directory of `pg_config` to PATH and build and install `influxdb_fdw`.
If you want to build `influxdb_fdw` in a source tree of PostgreSQL instead, don't use `USE_PGXS=1`.

#### Using Go client
```sh
make USE_PGXS=1 with_llvm=no GO_CLIENT=1
make install USE_PGXS=1 with_llvm=no GO_CLIENT=1
```

`with_llvm=no` is necessary to disable llvm bit code generation when PostgreSQL is configured with `--with-llvm` because `influxdb_fdw` use go code and cannot be compiled to llvm bit code.

#### Using `Influxdb_cxx` client
```sh
make USE_PGXS=1 with_llvm=no CXX_CLIENT=1
make install USE_PGXS=1 with_llvm=no CXX_CLIENT=1
```

Usage
-----

## CREATE SERVER options

`influxdb_fdw` accepts the following options via the `CREATE SERVER` command:

- **dbname** as *string*, optional

Target database name.

- **host** as *string*, optional

The address used to connect to InfluxDB server. Please note it's important to use `http://` or `https://` prefix before host address.

- **port** as *integer*, optional

The port used to connect to InfluxDB server.

- **version** as *integer*, optional, no default

InfluxDB server version which to connect to. If not, InfluxDB FDW will try to connect to InfluxDB V2 first. If unsuccessful, it will try to connect to InfluxDB V1. If it is still unsuccessful, error will be raised.
Availlable values: `1` for InfluxDB ver 1.x and `2` for InfluxDB ver 2.x.

- **retention_policy** as *string*, optional, default empty.

Retention policy of target database. See in InfluxDB ver 2.x documentation.

## CREATE USER MAPPING options

`influxdb_fdw` accepts the following options via the `CREATE USER MAPPING`
command:

- **user** as *string*, no default

  Username for V1 basic authentication (InfluxDB ver. 1.x).

- **password** as *string*, no default

  Password for V1 basic authentication (InfluxDB ver. 1.x).

- **auth_token** as *string*, no default

  Token for V2 Token authentication (InfluxDB ver. 2.x).

## CREATE FOREIGN TABLE options

`influxdb_fdw` accepts the following table-level options via the
`CREATE FOREIGN TABLE` command.

- **tags** as *string*, optional, no default

- **table** as *string*, optional, no default

- **schemaless** as *boolean*, optional, default `false`

  Enable schemaless mode.

## IMPORT FOREIGN SCHEMA options

`influxdb_fdw` supports [IMPORT FOREIGN SCHEMA](https://www.postgresql.org/docs/current/sql-importforeignschema.html) and
 accepts the following options via the
`IMPORT FOREIGN SCHEMA` command.

- **schemaless** as *boolean*, optional, default `false`

  Enable schemaless mode.

## TRUNCATE support

`influxdb_fdw` **don't support** the foreign data wrapper `TRUNCATE` API, available
from PostgreSQL 14.

Functions
---------

As well as the standard `influxdb_fdw_handler()` and `influxdb_fdw_validator()`
functions, `influxdb_fdw` provides the following user-callable utility functions:

Listed as *type*, *name with arguments*, *returm datatype* where such function types are availlable:
- **vf** - volatile functions
- **a** - aggregations
- **sf** - stable functions
- **f** - simple function

### Common functions
- vf  'log2(float8)', 'float8'
- vf  'log10(float8)', 'float8'

### Special aggregations
- a   'influx_count_all(*)', 'text'
- a   'influx_count(text)', 'text'
- a   'influx_distinct(anyelement)', 'anyelement'
- a   'integral(bigint)', 'bigint'
- a   'integral(float8)', 'float8'
- a   'integral(bigint, interval)', 'bigint'
- a   'integral(float8, interval)', 'float8'
- a   'integral_all(*)', 'text'
- a   'integral(text)', 'text'
- a   'mean(bigint)', 'bigint'
- a   'mean(float8)', 'float8'
- a   'mean_all(*)', 'text'
- a   'mean(text)', 'text'
- a   'median(bigint)', 'bigint'
- a   'median(float8)', 'float8'
- a   'median_all(*)', 'text'
- a   'median(text)', 'text'
- a   'influx_mode(anyelement)', 'anyelement'
- a   'influx_mode_all(*)', 'text'
- a   'influx_mode(text)', 'text'
- a   'spread(bigint)', 'bigint'
- a   'spread(float8)', 'float8'
- a   'spread_all(*)', 'text'
- a   'spread(text)', 'text'
- a   'stddev_all(*)', 'text'
- a   'stddev(text)', 'text'
- a   'influx_sum_all(*)', 'text'
- a   'influx_sum(text)', 'text'

### Selectors
- f   'bottom(bigint, int)', 'float8'
- f   'bottom(float8, int)', 'float8'
- f   'bottom(bigint, text, int)', 'float8'
- f   'bottom(float8, text, int)', 'float8'
- a   'first(timestamp with time zone, anyelement)', 'anyelement'
- a   'first_all(*)', 'text'
- a   'first(text)', 'text'
- a   'last(timestamp with time zone, anyelement)', 'anyelement'
- a   'last_all(*)', 'text'
- a   'last(text)', 'text'
- a   'influx_max_all(*)', 'text'
- a   'influx_max(text)', 'text'
- a   'influx_min_all(*)', 'text'
- a   'influx_min(text)', 'text'
- f   'percentile(bigint, int)', 'float8'
- f   'percentile(float8, int)', 'float8'
- f   'percentile(bigint, float8)', 'float8'
- f   'percentile(float8, float8)', 'float8'
- sf  'percentile_all(int)', 'text'
- sf  'percentile_all(float8)', 'text'
- sf  'percentile(text, int)', 'text'
- sf  'percentile(text, float8)', 'text'
- a   'sample(anyelement, int)', 'anyelement'
- sf  'sample_all(int)', 'text'
- sf  'sample(text, int)', 'text'
- f   'top(bigint, int)', 'float8'
- f   'top(float8, int)', 'float8'
- f   'top(bigint, text, int)', 'float8'
- f   'top(float8, text, int)', 'float8'

### Transformations
- sf  'abs_all()', 'text'
- sf  'acos_all()', 'text'
- sf  'asin_all()', 'text'
- sf  'atan_all()', 'text'
- sf  'atan2_all(bigint)', 'text'
- sf  'atan2_all(float8)', 'text'
- sf  'ceil_all()', 'text'
- sf  'cos_all()', 'text'
- f   'cumulative_sum(bigint)', 'bigint'
- f   'cumulative_sum(float8)', 'float8'
- sf  'cumulative_sum_all()', 'text'
- sf  'cumulative_sum(text)', 'text'
- f   'derivative(anyelement)', 'anyelement'
- f   'derivative(anyelement, interval)', 'anyelement'
- sf  'derivative_all()', 'text'
- sf  'derivative(text)', 'text'
- f   'difference(bigint)', 'bigint'
- f   'difference(float8)', 'float8'
- sf  'difference_all()', 'text'
- sf  'difference(text)', 'text'
- f   'elapsed(anyelement)', 'bigint'
- sf  'elapsed_all()', 'text'
- sf  'elapsed(text)', 'text'
- f   'elapsed(anyelement, interval)', 'bigint'
- sf  'exp_all()', 'text'
- sf  'floor_all()', 'text'
- sf  'ln_all()', 'text'
- sf  'log_all(bigint)', 'text'
- sf  'log_all(float8)', 'text'
- sf  'log2_all()', 'text'
- sf  'log10_all()', 'text'
- f   'moving_average(bigint, int)', 'float8'
- f   'moving_average(float8, int)', 'float8'
- sf  'moving_average_all(int)', 'text'
- sf  'moving_average(text, int)', 'text'
- f   'non_negative_derivative(anyelement)', 'anyelement'
- f   'non_negative_derivative(anyelement, interval)', 'anyelement'
- sf  'non_negative_derivative_all()', 'text'
- sf  'non_negative_derivative(text)', 'text'
- f   'non_negative_difference(bigint)', 'bigint'
- f   'non_negative_difference(float8)', 'float8'
- sf  'non_negative_difference_all()', 'text'
- sf  'non_negative_difference(text)', 'text'
- sf  'pow_all(int)', 'text'
- sf  'round_all()', 'text'
- sf  'sin_all()', 'text'
- sf  'sqrt_all()', 'text'
- sf  'tan_all()', 'text'

### Predictors
- f   'holt_winters(anyelement, int, int)', 'anyelement'
- f   'holt_winters_with_fit(anyelement, int, int)', 'anyelement'

### Technical Analysis
- f   'chande_momentum_oscillator(bigint, int)', 'float8'
- f   'chande_momentum_oscillator(float8, int)', 'float8'
- f   'chande_momentum_oscillator(bigint, int, int)', 'float8'
- f   'chande_momentum_oscillator(float8, int, int)', 'float8'
- f   'chande_momentum_oscillator(double precision, int)', 'float8'
- f   'chande_momentum_oscillator(double precision, int, int)', 'float8'
- sf  'chande_momentum_oscillator_all(int)', 'text'
- sf  'chande_momentum_oscillator(text, int)', 'text'
- f   'exponential_moving_average(bigint, int)', 'float8'
- f   'exponential_moving_average(float8, int)', 'float8'
- f   'exponential_moving_average(bigint, int, int)', 'float8'
- f   'exponential_moving_average(float8, int, int)', 'float8'
- sf  'exponential_moving_average_all(int)', 'text'
- sf  'exponential_moving_average(text, int)', 'text'
- f   'double_exponential_moving_average(bigint, int)', 'float8'
- f   'double_exponential_moving_average(float8, int)', 'float8'
- f   'double_exponential_moving_average(bigint, int, int)', 'float8'
- f   'double_exponential_moving_average(float8, int, int)', 'float8'
- sf  'double_exponential_moving_average_all(int)', 'text'
- sf  'double_exponential_moving_average(text, int)', 'text'
- f   'kaufmans_efficiency_ratio(bigint, int)', 'float8'
- f   'kaufmans_efficiency_ratio(float8, int)', 'float8'
- f   'kaufmans_efficiency_ratio(bigint, int, int)', 'float8'
- f   'kaufmans_efficiency_ratio(float8, int, int)', 'float8'
- sf  'kaufmans_efficiency_ratio_all(int)', 'text'
- sf  'kaufmans_efficiency_ratio(text, int)', 'text'
- f   'kaufmans_adaptive_moving_average(bigint, int)', 'float8'
- f   'kaufmans_adaptive_moving_average(float8, int)', 'float8'
- f   'kaufmans_adaptive_moving_average(bigint, int, int)', 'float8'
- f   'kaufmans_adaptive_moving_average(float8, int, int)', 'float8'
- sf  'kaufmans_adaptive_moving_average_all(int)', 'text'
- sf  'kaufmans_adaptive_moving_average(text, int)', 'text'
- f   'triple_exponential_moving_average(bigint, int)', 'float8'
- f   'triple_exponential_moving_average(float8, int)', 'float8'
- f   'triple_exponential_moving_average(bigint, int, int)', 'float8'
- f   'triple_exponential_moving_average(float8, int, int)', 'float8'
- sf  'triple_exponential_moving_average_all(int)', 'text'
- sf  'triple_exponential_moving_average(text, int)', 'text'
- f   'triple_exponential_derivative(bigint, int)', 'float8'
- f   'triple_exponential_derivative(float8, int)', 'float8'
- f   'triple_exponential_derivative(bigint, int, int)', 'float8'
- f   'triple_exponential_derivative(float8, int, int)', 'float8'
- sf  'triple_exponential_derivative_all(int)', 'text'
- sf  'triple_exponential_derivative(text, int)', 'text'
- f   'relative_strength_index(bigint, int)', 'float8'
- f   'relative_strength_index(float8, int)', 'float8'
- f   'relative_strength_index(bigint, int, int)', 'float8'
- f   'relative_strength_index(float8, int, int)', 'float8'
- sf  'relative_strength_index_all(int)', 'text'
- sf  'relative_strength_index(text, int)', 'text'

### Special time functions
- f   'influx_time(timestamp with time zone, interval, interval)', 'timestamp with time zone'
- f   'influx_time(timestamp with time zone, interval)', 'timestamp with time zone'
- f   'influx_time(timestamp with time zone, interval, interval, anyelement)', 'timestamp with time zone'
- f   'influx_time(timestamp with time zone, interval, anyelement)', 'timestamp with time zone'
- sf  'influx_fill_option(influx_fill_enum)', 'int'
- sf  'influx_fill_numeric(float8)', 'float8'
- sf  'influx_fill_numeric(int)', 'int'

Identifier case handling
------------------------

PostgreSQL folds identifiers to lower case by default.
Rules and problems with InfluxDB identifiers **yet not tested and described**.

Generated columns
-----------------

Behavoiur within generated columns **yet not tested and described**.

For more details on generated columns see:

- [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)
- [CREATE FOREIGN TABLE](https://www.postgresql.org/docs/current/sql-createforeigntable.html)


Character set handling
----------------------

**Yet not described**. Strongly recommended to use any of Unicode encodings for PostgreSQL with `influxdb_fdw`.

Examples
--------

### Install the extension:

Once for a database you need, as PostgreSQL superuser.

```sql
	CREATE EXTENSION influxdb_fdw;
```

### Create a foreign server with appropriate configuration:

Once for a foreign datasource you need, as PostgreSQL superuser. Please specify database name using `dbname` option.

#### Go Client connect to InfluxDB ver 1.x
```sql
	CREATE SERVER influxdb_svr
	FOREIGN DATA WRAPPER influxdb_fdw
	OPTIONS (
          dbname 'mydb',
	  host 'http://localhost',
	  port '8086'
	);
```
#### `Influxdb_cxx` Client connect to InfluxDB ver 1.x
```sql
	CREATE SERVER influxdb_svr
	FOREIGN DATA WRAPPER influxdb_fdw
	OPTIONS (
          dbname 'mydb',
	  host 'http://localhost',
	  port '8086',
	  version '1'
	);
```
#### `Influxdb_cxx` Client connect to InfluxDB ver 2.x
```sql
	CREATE SERVER influxdb_svr
	FOREIGN DATA WRAPPER influxdb_fdw
	OPTIONS (
          dbname 'mydb',
	  host 'http://localhost',
	  port '8086',
	  version '2',
	  retention_policy ''
	);
```

### Grant usage on foreign server to normal user in PostgreSQL:

Once for a normal user (non-superuser) in PostgreSQL, as PostgreSQL superuser. It is a good idea to use a superuser only where really necessary, so let's allow a normal user to use the foreign server (this is not required for the example to work, but it's secirity recomedation).

```sql
	GRANT USAGE ON FOREIGN SERVER influxdb_svr TO pguser;
```
Where `pguser` is a sample user for works with foreign server (and foreign tables).

### User mapping

Create an appropriate user mapping:

#### Go Client connect to InfluxDB ver 1.x

```sql
    	CREATE USER MAPPING
	FOR pguser
	SERVER influxdb_svr
    	OPTIONS (
	  user 'username',
	  password 'password'
	);
```
Where `pguser` is a sample user for works with foreign server (and foreign tables).

#### `Influxdb_cxx` Client connect to InfluxDB ver 1.x

```sql
    	CREATE USER MAPPING
	FOR pguser
	SERVER influxdb_svr
    	OPTIONS (
	  user 'username',
	  password 'password'
	);
```
Where `pguser` is a sample user for works with foreign server (and foreign tables).

#### `Influxdb_cxx` Client connect to InfluxDB ver 2.x

```sql
    	CREATE USER MAPPING
	FOR pguser
	SERVER influxdb_svr
    	OPTIONS (
	  auth_token 'token'
	);
```
Where `pguser` is a sample user for works with foreign server (and foreign tables).

### Create foreign table
All `CREATE FOREIGN TABLE` SQL commands can be executed as a normal PostgreSQL user if there were correct `GRANT USAGE ON FOREIGN SERVER`. No need PostgreSQL supersuer for security reasons but also works with PostgreSQL supersuer.

Create a foreign table referencing the InfluxDB table:
You need to declare a column named `time` to access InfluxDB time column.
```sql
	CREATE FOREIGN TABLE t1(
	  time timestamp with time zone,
	  tag1 text,
	  field1 integer
	)
	SERVER influxdb_svr
	OPTIONS (
	  table 'measurement1'
	);
```
You can use `tags` option to specify tag keys of a foreign table.
```sql
	CREATE FOREIGN TABLE t2(
	  tag1 text,
	  field1 integer,
	  tag2 text,
	  field2 integer
	)
	SERVER influxdb_svr
	OPTIONS (
	  tags 'tag1, tag2'
	);
```
You can import foreign schema
```sql
	IMPORT FOREIGN SCHEMA public
	FROM SERVER influxdb_svr
	INTO public;
```
Access foreign table
```sql
	SELECT * FROM t1;
```
Limitations
-----------

- `UPDATE` is not supported.
- `WITH CHECK OPTION` constraints is not supported.

### Limitations originate from data model and query language of *InfluxDB*

- Result sets have different number of rows depending on specified target list.
For example, `SELECT field1 FROM t1` and `SELECT field2 FROM t1` returns different number of rows if
the number of points with field1 and field2 are different in *InfluxDB* database.
- Timestamp precision may be lost because timestamp resolution of PostgreSQL is microseconds while that of *InfluxDB* is nanoseconds.
- Conditions like `WHERE time + interval '1 day' < now()` do not work. Please use `WHERE time < now() - interval '1 day'`.
- InfluxDB FDW does not return an error even if it is overflow.
- `EXP` function of *InfluxDB* may return different precision number for different PC.
- InfluxDB only supports some basic types for tags (string only) and fields (string, float, integer or boolean) => most Postgres types cannot be supported.
- `IMPORT FOREIGN SCHEMA` should be used to identify foreign tables.
  - If the user defines it manually, it is necessary to use the correct mapping type in the foreign table to avoid some unexpected behavior because of type mismatch or unsupported in InfluxDB.
  - If a user wants to use an unsupported type with InfluxDB data, PostgreSQL's explicit cast functions should be used instead of define column type in foreign table directly.

When a query to foreign tables fails, you can find why it fails by seeing a query executed in *InfluxDB* with `EXPLAIN VERBOSE`.

Contributing
------------
Opening issues and pull requests on GitHub are welcome. Test scripts is multiversional for PostgreSQL, works in POSIX context and based on comparing output of SQL commands in psql with expected output text files.
Current test expected results are generated based on results in `Rocky Linux 8` and its default `glibc 2.28`. Test results may fail with other version of `glibc` due to string collation changes.

Useful links
------------

### Source code

Reference FDW realisation, `postgres_fdw`
 - https://git.postgresql.org/gitweb/?p=postgresql.git;a=tree;f=contrib/postgres_fdw;hb=HEAD

### General FDW Documentation

 - https://www.postgresql.org/docs/current/ddl-foreign-data.html
 - https://www.postgresql.org/docs/current/sql-createforeigndatawrapper.html
 - https://www.postgresql.org/docs/current/sql-createforeigntable.html
 - https://www.postgresql.org/docs/current/sql-importforeignschema.html
 - https://www.postgresql.org/docs/current/fdwhandler.html
 - https://www.postgresql.org/docs/current/postgres-fdw.html

### Other FDWs

 - https://wiki.postgresql.org/wiki/Fdw
 - https://pgxn.org/tag/fdw/
 
License
-------

Copyright (c) 2018, TOSHIBA CORPORATION

Copyright (c) 2011-2016, EnterpriseDB Corporation

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`](LICENSE) file for full details.
