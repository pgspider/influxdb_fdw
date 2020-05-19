#export USE_PGXS=1
sed -i 's/REGRESS =.*/REGRESS = aggregate influxdb_fdw/' Makefile

./init.sh && make clean && make && make install && make check
