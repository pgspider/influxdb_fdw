#! /bin/bash
# script for performance testing
# Usage: ./test_perfomance.sh [-n <data_size>] [-t <string>]
# Example:
#   Cxx-client v1: ./test_perfomance.sh -n 1000 -t CXX_V1
#   Cxx-client v2: ./test_perfomance.sh -n 1000 -t CXX_V2
#   Go-client: ./test_perfomance.sh -n 1000 -t GO

usage() { echo "Usage: $0 [-n <data_size>] [-t <CXX_V1|CXX_V2|GO>]" 1>&2; exit 1; }

while getopts ":n:t:" o; do
    case "${o}" in
        n)
            n=${OPTARG}
            ;;
        t)
            t=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${n}" ]; then
    echo "data_size required!"
    usage
fi

sed -i 's/REGRESS =.*/REGRESS = influxdb_performance /' Makefile
sed -i "s/set DATA_SIZE.*/set DATA_SIZE '${n}'/" sql/performance/influxdb_performance.sql

# build default with go-client.
BUILD_FLAG='GO_CLIENT=1'

# init data
./init_performance.sh -t ${t}
if [ $? -ne 0 ]; then
    echo "init data failed."
    exit 2
fi

# prepare test param
if [[ "CXX_V1" == $t ]]; then
    # Cxx-client with InfluxDB 1.x
    cp sql/parameters_cxx_v1.conf sql/parameters.conf
    BUILD_FLAG='CXX_CLIENT=1'
elif [[ "CXX_V2" == $t ]]; then
    # Cxx-client with InfluxDB 2.x
    cp sql/parameters_cxx_v2.conf sql/parameters.conf
    BUILD_FLAG='CXX_CLIENT=1'
elif [[ "GO" == $t ]]; then
    # GO-client
    cp sql/parameters_go.conf sql/parameters.conf
    BUILD_FLAG='GO_CLIENT=1'
else
    echo "Does not support target client: $t"
    usage
fi

# exec test
make clean ${BUILD_FLAG}
make REGRESS_PREFIX=performance ${BUILD_FLAG}
make check REGRESS_PREFIX=performance ${BUILD_FLAG} | tee make_check.out
