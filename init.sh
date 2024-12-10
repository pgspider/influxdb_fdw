#! /bin/bash

# InfluxDB systemtest config
container_name_v2='influxdb_server_v2'
influxdbV2_image='influxdb:2.7.6'
container_name_v1='influxdb_server_v1'
influxdbV1_image='influxdb:1.8.10'

if [[ "--CXX_V2" == $1  || "--CXX_V1" == $1 ]]; then
    # clean influxdb server if exists
    if [ "$(docker ps -aq -f name=^/${container_name_v2}$)" ]; then
        if [ "$(docker ps -aq -f status=exited -f status=created -f name=^/${container_name_v2}$)" ]; then
            docker rm ${container_name_v2}
        else
            docker rm $(docker stop ${container_name_v2})
        fi
    fi

    if [ "$(docker ps -aq -f name=^/${container_name_v1}$)" ]; then
        if [ "$(docker ps -aq -f status=exited -f status=created -f name=^/${container_name_v1}$)" ]; then
            docker rm ${container_name_v1}
        else
            docker rm $(docker stop ${container_name_v1})
        fi
    fi

    # run server
    docker run  -d --name ${container_name_v1} -it -p 18086:8086 \
                -e "INFLUXDB_HTTP_AUTH_ENABLED=true" \
                -e "INFLUXDB_ADMIN_ENABLED=true" \
                -e "INFLUXDB_ADMIN_USER=user" \
                -e "INFLUXDB_ADMIN_PASSWORD=pass" \
                -v $(pwd)/init:/tmp \
                ${influxdbV1_image}

    # If timeout occurs, please increase this time
    sleep 10

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
fi


if [[ "--CXX_V2" == $1 ]]; then
    # create buket and database mapping for v2
    COREDB_ID=$(docker exec ${container_name_v2} influx bucket create -n coredb | grep coredb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $COREDB_ID --db coredb -rp autogen --default
    SCHEMALESS_ID=$(docker exec ${container_name_v2} influx bucket create -n schemalessdb | grep schemalessdb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $SCHEMALESS_ID --db schemalessdb -rp autogen --default --org myorg
    POST_ID=$(docker exec ${container_name_v2} influx bucket create -n postdb | grep postdb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $POST_ID --db postdb -rp autogen --default --org myorg
    MYDB_ID=$(docker exec ${container_name_v2} influx bucket create -n mydb | grep mydb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $MYDB_ID --db mydb -rp autogen --default --org myorg
    MYDB2_ID=$(docker exec ${container_name_v2} influx bucket create -n mydb2 | grep mydb2 | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $MYDB2_ID --db mydb2 -rp autogen --default --org myorg
    OPTIONDB_ID=$(docker exec ${container_name_v2} influx bucket create -n optiondb | grep optiondb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $OPTIONDB_ID --db optiondb -rp autogen --default

    # Init data V2
    docker exec ${container_name_v2} influx write --bucket mydb --precision s --file /tmp/init.txt
    docker exec ${container_name_v2} influx write --bucket mydb2 --precision s --file /tmp/selectfunc.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/agg.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/emp.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/join.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/others.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/person.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/select.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/stud_emp.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/student.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/onek.txt
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/streets.txt
    sleep 5
    docker exec ${container_name_v2} influx write --bucket coredb --precision ns --file /tmp/tenk.txt
    docker exec ${container_name_v2} influx write --bucket schemalessdb --precision ns --file /tmp/schemaless.txt
    docker exec ${container_name_v2} influx write --bucket optiondb --precision ns --file /tmp/option.txt

    # Init data V1
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/option.txt -precision=ns

elif [[ "--CXX_V1" == $1 ]]; then
    # Init data V1
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/init.txt -precision=s
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/selectfunc.txt -precision=s
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/others.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/join.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/select.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/onek.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/tenk.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/agg.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/student.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/person.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/streets.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/emp.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/stud_emp.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/init_post.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/schemaless.txt -precision=ns
    docker exec ${container_name_v1} influx -username=user -password=pass -import -path=/tmp/option.txt -precision=ns

    # Init data V2
    OPTIONDB_ID=$(docker exec ${container_name_v2} influx bucket create -n optiondb | grep optiondb | cut -f 1)
    docker exec ${container_name_v2} influx v1 dbrp create --bucket-id $OPTIONDB_ID --db optiondb -rp autogen --default
    docker exec ${container_name_v2} influx write --bucket optiondb --precision ns --file /tmp/option.txt

else
    influx -import -path=init/init.txt -precision=s
    influx -import -path=init/selectfunc.txt -precision=s
    influx -import -path=init/others.txt -precision=ns
    influx -import -path=init/join.txt -precision=ns
    influx -import -path=init/select.txt -precision=ns
    influx -import -path=init/onek.txt -precision=ns
    influx -import -path=init/tenk.txt -precision=ns
    influx -import -path=init/agg.txt -precision=ns
    influx -import -path=init/student.txt -precision=ns
    influx -import -path=init/person.txt -precision=ns
    influx -import -path=init/streets.txt -precision=ns
    influx -import -path=init/emp.txt -precision=ns
    influx -import -path=init/stud_emp.txt -precision=ns
    influx -import -path=init/init_post.txt -precision=ns
    influx -import -path=init/schemaless.txt -precision=ns
fi