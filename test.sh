./init.sh
sed -i 's/REGRESS =.*/REGRESS = aggregate influxdb_fdw selectfunc extra\/join extra\/limit extra\/aggregates extra\/insert extra\/prepare extra\/select_having extra\/select extra\/influxdb_fdw_post/' Makefile
make clean
make
make check | tee make_check.out
