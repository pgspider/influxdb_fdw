# InfluxDB Foreign Data Wrapper Additional Notes for PGSpider.
## 1. Features

- InfluxDB FDW supports pushed down functions in SELECT clause:
  - Common functions of Postgres and InfluxDB:
    - Normal functions: abs, acos, asin, atan, atan2, ceil, cos, exp, floor, ln, log, log2, log10, pow, round, sin, sqrt, tan.
  - Unique functions of InfluxDB:
    - Aggregate functions: integral, mean, median, mode, spread
    - Normal functions: bottom, first, last, percentile, sample, top, cumulative_sum, derivative, difference, elapsed, moving_average, non_negative_derivative, non_negative_difference, holt_winters, holt_winters_with_fit, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index.
  - Unique functions of InfluxDB with different name and syntax.
    - Regular expression support functions: integral, mean, median, spread, stddev, first, last, percentile, sample, cumulative_sum, derivative, difference, elapsed, moving_average, non_negative_derivative, non_negative_difference, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index.<br>
      When using regular expression, user needs to put the regular expression between single quotes.<br>
      Example: Select integral('/value[1,4]/').
    - Regular expression support functions: count, sum, min, max, mode.<br>
      User needs to append prefix with influx_ and put the regular expression between single quotes.<br>
      Example: count(/regular_expression/) -> influx_count('/regular_expression/')
    - Aggregate functions with argument star(\*): integral, mean, median, spread, stddev<br>
      User needs to append suffix with _all.<br>
      Example: integral(*) -> integral_all()
    - Aggregate functions with argument star(\*) : count, sum, min, max, mode<br>
      User needs to append both prefix with influx_ and suffix with _all. <br>
      Example: count(\*) -> influx_count_all(\*) 
    - Normal functions with argument star : percentile, sample, atan2, log, moving_average, pow, chande_momentum_oscillator, exponential_moving_average, double_exponential_moving_average, double_exponential_moving_average, kaufmans_efficiency_ratio, kaufmans_adaptive_moving_average, triple_exponential_moving_average, triple_exponential_derivative, relative_strength_index<br>
      User needs to append suffix with _all and remove its argument *.<br>
      Example: log(\*, argument) -> log_all(argument)
    - Other unique functions: distinct, time<br>
      User needs to append prefix with influx_.<br>
      Example: time() -> influx_time()
## 2. Limitations
- If we want to treat individual values from the result of influxdb functions specified by star or regular expression and the result does not have the same type as foreign table, we can execute by influxdb functions with individual columns instead of star or regular expression.<br>
  Example: SELECT log2(c1), log2(c2), log2(c3), log2(c4), ... FROM s3;
- If we want to get values of influxdb functions specified by star or regular expression and group by tag, we can select influxdb functions with individual columns and tag without using group by.<br>
  Example: SELECT sqrt(c1), sqrt(c2), tag1 FROM s3;
- For functions with star (\*) or regular expression, only support push down when select one function. Do not support selecting multiple targets including those types of functions.<br>
