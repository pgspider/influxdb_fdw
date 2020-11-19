./init.sh
sed -i 's/REGRESS =.*/REGRESS = aggregate influxdb_fdw selectfunc extra\/join extra\/limit extra\/aggregates extra\/prepare extra\/select_having extra\/select extra\/influxdb_fdw_post/' Makefile
make clean
make
mkdir -p results/extra || true
make check | tee make_check.out
