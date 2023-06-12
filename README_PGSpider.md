# InfluxDB Foreign Data Wrapper Additional Notes for PGSpider.
## 1. Features

- InfluxDB FDW supports pushed down functions in SELECT clause:
  - Common functions of Postgres and InfluxDB:
    - Normal functions: abs, acos, asin, atan, atan2, ceil, cos, exp, floor, ln, log, log2, log10, pow, round, sin, sqrt, tan.
  - Unique functions of InfluxDB:
    - Aggregate functions: integral, mean, median, mode, spread
    - Normal functions: bottom, first, last, percentile, sample, top, cumulative_sum, derivative, difference, elapsed, moving_average, non_negative_derivative, non_negative_difference, holt_winters, holt_winters_with_fit, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index.
  - Unique functions of InfluxDB with different name and syntax.
    - Regular expression support functions: integral, mean, median, spread, stddev, first, last, percentile, sample, cumulative_sum, derivative, difference, elapsed, moving_average, non_negative_derivative, non_negative_difference, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index.   
      When using regular expression, user needs to put the regular expression between single quotes.   
      Example: Select integral('/value[1,4]/').
    - Regular expression support functions: count, sum, min, max, mode.   
      User needs to append prefix with influx_ and put the regular expression between single quotes.   
      Example: count(/regular_expression/) -> influx_count('/regular_expression/')
    - Aggregate functions with argument star(\*): integral, mean, median, spread, stddev   
      User needs to append suffix with _all.   
      Example: integral(*) -> integral_all()
    - Aggregate functions with argument star(\*) : count, sum, min, max, mode   
      User needs to append both prefix with influx_ and suffix with _all.   
      Example: count(\*) -> influx_count_all(\*)
    - Normal functions with argument star : percentile, sample, atan2, log, moving_average, pow, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index   
      User needs to append suffix with _all and remove its argument *.   
      Example: log(\*, argument) -> log_all(argument)
    - Other unique functions: distinct, time   
      User needs to append prefix with influx_.   
      Example: time() -> influx_time()

- Support DDL commands:
  - `CREATE DATASOURCE TABLE` command.
    - Creating a new datasource table without initial data.
    - The creating new datasource table on InfluxDB is depended on `IF NOT EXISTS` option:
      - If `IF NOT EXISTS` option is specified, execution of CREATE datasource command has no effect, new datasource will be created by INSERT operation.
      - Otherwise, `IF NOT EXISTS` option is not specified, an error will be raised if the target datasource is already existed.
        If target datasource is not existed, execution of CREATE datasource command has no effect, new datasource will be created by INSERT operation.

    For example:
    - Need to prepare a foreign table which will remote to new datasource.
    - Then execute `CREATE DATASOURCE TABLE` command on foreign table to create new datasource.
    ```sql
    -- Prepare foreign table
    CREATE FOREIGN TABLE tbl3 (
      c1	smallint,
      c2	int	NOT NULL,
      c3	bigint DEFAULT 10,
      c4	float,
      c5	double precision,
      c6	numeric,
      c7	bool DEFAULT 'f',
      c8	bpchar,
      c9	time DEFAULT '00:00:00',
      c10	timestamp,
      c11	timestamptz,
      c12	text,
      c13	real DEFAULT 1,
      c14	char DEFAULT 'd',
      c15	varchar(10)
    ) SERVER influx_svr OPTIONS (table 'tbl3');

    -- Create new datasource
    CREATE DATASOURCE TABLE IF NOT EXISTS tbl3;
    ```
  - `DROP DATASOURCE TABLE` command.
    - The command will remove a datasource table.
    - Name of target datasource table is name of foreign table. If the "table" option is specified, use its value instead of foreign table's name.
    - Support `IF EXIST` option. If this option is specified, do not throw an error if the target datasource table does not exist.  Otherwise, if this option is not specified, throw an error if the target datasource table does not exist.

    For example:
    ```sql
    -- Drop datasource table
    DROP DATASOURCE TABLE IF EXISTS tbl3;
    ```

## 2. Limitations
- If we want to treat individual values from the result of influxdb functions specified by star or regular expression and the result does not have the same type as foreign table, we can execute by influxdb functions with individual columns instead of star or regular expression.   
  Example: SELECT log2(c1), log2(c2), log2(c3), log2(c4), ... FROM s3;
- If we want to get values of influxdb functions specified by star or regular expression and group by tag, we can select influxdb functions with individual columns and tag without using group by.   
  Example: SELECT sqrt(c1), sqrt(c2), tag1 FROM s3;
- For functions with star (\*) or regular expression, only support push down when select one function. Do not support selecting multiple targets including those types of functions.   
