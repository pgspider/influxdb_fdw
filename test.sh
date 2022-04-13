./init.sh
sed -i 's/REGRESS =.*/REGRESS = aggregate influxdb_fdw selectfunc extra\/join extra\/limit extra\/aggregates extra\/insert extra\/prepare extra\/select_having extra\/select extra\/influxdb_fdw_post schemaless\/aggregate schemaless\/influxdb_fdw schemaless\/selectfunc schemaless\/schemaless schemaless\/extra\/join schemaless\/extra\/limit schemaless\/extra\/aggregates schemaless\/extra\/prepare schemaless\/extra\/select_having schemaless\/extra\/insert schemaless\/extra\/select schemaless\/extra\/influxdb_fdw_post schemaless\/add_fields schemaless\/add_tags schemaless\/add_multi_key /' Makefile
make clean
make
make check | tee make_check.out
