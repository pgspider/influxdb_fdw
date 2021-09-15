# InfluxDB Foreign Data Wrapper for PostgreSQL
This PostgreSQL extension is a Foreign Data Wrapper (FDW) for InfluxDB.

The current version can work with PostgreSQL 9.6, 10, 11, 12 and 13.

Go version should be 1.10.4 or later.
## Installation
Install InfluxDB Go client library
<pre>
go get github.com/influxdata/influxdb1-client/v2
</pre>

Add a directory of pg_config to PATH and build and install influxdb_fdw.
<pre>
make USE_PGXS=1 with_llvm=no
make install USE_PGXS=1 with_llvm=no
</pre>
with_llvm=no is necessary to disable llvm bit code generation when PostgreSQL is configured with --with-llvm because influxdb_fdw use go code and cannot be compiled to llvm bit code.

If you want to build influxdb_fdw in a source tree of PostgreSQL instead, use
<pre>
make with_llvm=no
make install  with_llvm=no
</pre>

## Usage
### Load extension
<pre>
CREATE EXTENSION influxdb_fdw;
</pre>

### Create server
<pre>
CREATE SERVER influxdb_server FOREIGN DATA WRAPPER influxdb_fdw OPTIONS
(dbname 'mydb', host 'http://localhost', port '8086') ;
</pre>

### Create user mapping
<pre>
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_server OPTIONS(user 'user', password 'pass');
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

### Others
- InfluxDB FDW supports pushed down some aggregate functions: count, stddev, sum, max, min.
- InfluxDB FDW supports INSERT, DELETE statements.
  - `time` and `time_text` column can used for INSERT, DELETE statements.
  - `time` column can express timestamp with precision down to microseconds.
  - `time_text` column can express timestamp with precision down to nanoseconds.
- WHERE clauses including timestamp, interval and `now()` functions are pushed down.
- LIMIT...OFFSET clauses are pushed down when there is LIMIT clause only or both LIMIT and OFFSET.<br>

For PGSpider, influxdb_fdw can support some different features. For details, please refer to [`README_PGSpider.md`][5] file.
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

## Contributing
Opening issues and pull requests on GitHub are welcome.

## License
Copyright (c) 2018 - 2020, TOSHIBA Corporation

Copyright (c) 2011 - 2016, EnterpriseDB Corporation

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][4] file for full details.

[4]: LICENSE
[5]: README_PGSpider.md
