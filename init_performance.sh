#! /bin/bash

# InfluxDB systemtest config
container_name_v2='influxdb_server_v2'
influxdbV2_image='influxdb:2.7.6'
container_name_v1='influxdb_server_v1'
influxdbV1_image='influxdb:1.8.10'
container_name_go='influxdb_server_go'

usage() { echo "Usage: $0 [-t <CXX_V1|CXX_V2|GO>]" 1>&2; exit 1; }

while getopts ":t:" o; do
    case "${o}" in
        t)
            t=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${t}" ]; then
    echo "target client required!"
    usage
fi

function docker_cleanup()
{
    if [ "$(docker ps -aq -f name=^/${1}$)" ]; then
        if [ "$(docker ps -aq -f status=exited -f status=created -f name=^/${1}$)" ]; then
            docker rm ${1}
        else
            docker rm $(docker stop ${1})
        fi
    fi
}

if [[ "CXX_V2" == $t ]]; then
    docker_cleanup $container_name_v2
    docker run  -d --name ${container_name_v2} -it -p 38086:8086 \
                -e "DOCKER_INFLUXDB_INIT_MODE=setup" \
                -e "DOCKER_INFLUXDB_INIT_USERNAME=root" \
                -e "DOCKER_INFLUXDB_INIT_PASSWORD=rootroot" \
                -e "DOCKER_INFLUXDB_INIT_ORG=myorg" \
                -e "DOCKER_INFLUXDB_INIT_BUCKET=mybucket" \
                -e "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=mytoken" \
                -e "INFLUXD_STORAGE_WRITE_TIMEOUT=100s" \
                -v $(pwd)/init_v2:/tmp \
                ${influxdbV2_image}

    # If timeout occurs, please increase this time
    sleep 10
    # create buket and database mapping for v2
    PER_MEASURE=$(docker exec ${container_name_v2} influx bucket create -n performance_test | grep performance_test | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $PER_MEASURE --db performance_test -rp autogen --default

elif [[ "CXX_V1" == $t ]]; then
    docker_cleanup $container_name_v1
    docker run  -d --name ${container_name_v1} -it -p 18086:8086 \
                -e "INFLUXDB_HTTP_AUTH_ENABLED=true" \
                -e "INFLUXDB_ADMIN_ENABLED=true" \
                -e "INFLUXDB_ADMIN_USER=user" \
                -e "INFLUXDB_ADMIN_PASSWORD=pass" \
                -v $(pwd)/init:/tmp \
                ${influxdbV1_image}

    # If timeout occurs, please increase this time
    sleep 10

    # Init data V1
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/init_performance.txt -precision=s

elif [[ "GO" == $t ]]; then
    docker_cleanup $container_name_go
    # run server
    docker run  -d --name ${container_name_go} -it -p 8086:8086 \
            -v $(pwd)/init:/tmp \
            ${influxdbV1_image}
    # If timeout occurs, please increase this time
    sleep 10
    docker exec ${container_name_go} influx -import -path=/tmp/init_performance.txt -precision=s
else
    usage
fi
