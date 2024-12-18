#! /bin/bash

# Usage:
# ./test.sh                                     -- using GO CLIENT + Postgres versions
# ./test.sh --CXX_V1                            -- using CXX V1    + Postgres versions
# ./test.sh --CXX_V2                            -- using CXX V2    + Postgres versions
#
# *Note: If using CXX, we need to use gcc 7 (source /opt/rh/devtoolset-7/enable)

sed -i 's/REGRESS =.*/REGRESS = aggregate influxdb_fdw selectfunc extra\/join extra\/limit extra\/aggregates extra\/insert extra\/prepare extra\/select_having extra\/select extra\/influxdb_fdw_post schemaless\/aggregate schemaless\/influxdb_fdw schemaless\/selectfunc schemaless\/schemaless schemaless\/extra\/join schemaless\/extra\/limit schemaless\/extra\/aggregates schemaless\/extra\/prepare schemaless\/extra\/select_having schemaless\/extra\/insert schemaless\/extra\/select schemaless\/extra\/influxdb_fdw_post schemaless\/add_fields schemaless\/add_tags schemaless\/add_multi_key /' Makefile

if [[ "--CXX_V1" == $1 ]]; then
    ./init.sh --CXX_V1
    cp sql/parameters_cxx_v1.conf sql/parameters.conf
    sed -i 's/aggregate/option aggregate/' Makefile
    make clean CXX_CLIENT=1
    make $2 CXX_CLIENT=1
    make check $2 CXX_CLIENT=1 | tee make_check.out
elif [[ "--CXX_V2" == $1 ]]; then
    ./init.sh --CXX_V2
    cp sql/parameters_cxx_v2.conf sql/parameters.conf
    sed -i 's/aggregate/option aggregate/' Makefile
    make clean CXX_CLIENT=1
    make $2 CXX_CLIENT=1
    make check $2 CXX_CLIENT=1 | tee make_check.out
else
    ./init.sh
    cp sql/parameters_go.conf sql/parameters.conf
    make clean 
    make $1
    make check $1 | tee make_check.out
fi
