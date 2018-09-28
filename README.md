# InfluxDB Foreign Data Wrapper for PostgreSQL
This PostgreSQL extension is a Foreign Data Wrapper (FDW) for InfluxDB.

The current version can work with PostgreSQL 9.6 and 10.

## Installation
Install InfluxDB Go client library
<pre>
go get github.com/influxdata/influxdb/client/v2
</pre>

Add a directory of pg_config to PATH and build and install influxdb_fdw.
<pre>
make USE_PGXS=1
make install USE_PGXS=1
</pre>

If you want to build influxdb_fdw in a source tree of PostgreSQL instead, use
<pre>
make
make install
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

### Or you can use import foreign schema
<pre>
IMPORT FOREIGN SCHEMA public FROM SERVER influxdb_server INTO public;
</pre>

### Access foregin table
<pre>
SELECT * FROM t1;
</pre>

## Features
- Only SELECT queries are supported.

## Limitations
- WHERE clauses are not pushed down to InfluxDB in current version.

## License
Copyright (c) 2018, TOSHIBA Corporation 
Copyright (c) 2011 - 2016, EnterpriseDB Corporation

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

See the [`LICENSE`][4] file for full details.

[4]: LICENSE
