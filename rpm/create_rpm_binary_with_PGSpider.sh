#!/bin/bash

# Save the list of existing environment variables before sourcing the env_rpmbuild.conf file.
before_vars=$(compgen -v)

source rpm/env_rpmbuild.conf

# Save the list of environment variables after sourcing the env_rpmbuild.conf file
after_vars=$(compgen -v)

# Find new variables created from configuration file
new_vars=$(comm -13 <(echo "$before_vars" | sort) <(echo "$after_vars" | sort))

# Export variables so that scripts or child processes can access them
for var in $new_vars; do
    export "$var"
done

set -eE

# validate parameters
chmod a+x rpm/validate_parameters.sh
./rpm/validate_parameters.sh location INFLUXBB_CXX_RPM_ID PGSPIDER_RPM_ID IMAGE_TAG DOCKERFILE ARTIFACT_DIR proxy no_proxy PACKAGE_RELEASE_VERSION PGSPIDER_BASE_POSTGRESQL_VERSION PGSPIDER_RELEASE_VERSION INFLUXDB_FDW_RELEASE_VERSION INFLUXDB_CXX_PROJECT_ID INFLUXDB_CXX_PACKAGE_VERSION INFLUXDB_CXX_RELEASE_VERSION 

if [[ ${PGSPIDER_RPM_ID} ]]; then
    PGSPIDER_RPM_ID_POSTFIX="-${PGSPIDER_RPM_ID}"
fi

if [[ ${INFLUXBB_CXX_RPM_ID} ]]; then
    INFLUXBB_CXX_RPM_ID_POSTFIX="-${INFLUXBB_CXX_RPM_ID}"
fi

# create rpm on container environment
if [[ $location == [gG][iI][tT][lL][aA][bB] ]];
then 
    ./rpm/validate_parameters.sh ACCESS_TOKEN API_V4_URL PGSPIDER_PROJECT_ID INFLUXDB_FDW_PROJECT_ID
    docker build -t $IMAGE_TAG \
                 --build-arg proxy=${proxy} \
                 --build-arg no_proxy=${no_proxy} \
                 --build-arg ACCESS_TOKEN=${ACCESS_TOKEN} \
                 --build-arg PACKAGE_RELEASE_VERSION=${PACKAGE_RELEASE_VERSION} \
                 --build-arg PGSPIDER_BASE_POSTGRESQL_VERSION=${PGSPIDER_BASE_POSTGRESQL_VERSION} \
                 --build-arg PGSPIDER_RELEASE_VERSION=${PGSPIDER_RELEASE_VERSION} \
                 --build-arg PGSPIDER_RPM_ID=${PGSPIDER_RPM_ID_POSTFIX} \
                 --build-arg PGSPIDER_RPM_URL="$API_V4_URL/projects/${PGSPIDER_PROJECT_ID}/packages/generic/rpm_rhel8/${PGSPIDER_BASE_POSTGRESQL_VERSION}" \
                 --build-arg INFLUXDB_FDW_RELEASE_VERSION=${INFLUXDB_FDW_RELEASE_VERSION} \
                 --build-arg INFLUXBB_CXX_RPM_ID=${INFLUXBB_CXX_RPM_ID_POSTFIX} \
                 --build-arg INFLUXDB_CXX_RPM_URL="$API_V4_URL/projects/${INFLUXDB_CXX_PROJECT_ID}/packages/generic/rpm_rhel8/${INFLUXDB_CXX_PACKAGE_VERSION}" \
                 --build-arg INFLUXDB_CXX_RELEASE_VERSION=${INFLUXDB_CXX_RELEASE_VERSION} \
                 -f rpm/$DOCKERFILE .
else
    ./rpm/validate_parameters.sh OWNER_GITHUB PGSPIDER_PROJECT_GITHUB INFLUXDB_CXX_PROJECT_GITHUB PARQUET_S3_FDW_RELEASE_ID INFLUXDB_CXX_RELEASE_VERSION INFLUXDB_FDW_RELEASE_ID PGSPIDER_RELEASE_PACKAGE_VERSION
    docker build -t $IMAGE_TAG \
                 --build-arg proxy=${proxy} \
                 --build-arg no_proxy=${no_proxy} \
                 --build-arg PACKAGE_RELEASE_VERSION=${PACKAGE_RELEASE_VERSION} \
                 --build-arg PGSPIDER_BASE_POSTGRESQL_VERSION=${PGSPIDER_BASE_POSTGRESQL_VERSION} \
                 --build-arg PGSPIDER_RELEASE_VERSION=${PGSPIDER_RELEASE_VERSION} \
                 --build-arg PGSPIDER_RPM_URL="https://github.com/${OWNER_GITHUB}/${PGSPIDER_PROJECT_GITHUB}/releases/download/${PGSPIDER_RELEASE_PACKAGE_VERSION}" \
                 --build-arg INFLUXDB_FDW_RELEASE_VERSION=${INFLUXDB_FDW_RELEASE_VERSION} \
                 --build-arg INFLUXDB_CXX_RPM_URL="https://github.com/${OWNER_GITHUB}/${INFLUXDB_CXX_PROJECT_GITHUB}/releases/download/${INFLUXDB_CXX_RELEASE_VERSION}" \
                 --build-arg INFLUXDB_CXX_RELEASE_VERSION=${INFLUXDB_CXX_RELEASE_VERSION} \
                 -f rpm/$DOCKERFILE .
fi

# copy binary to outside
mkdir -p $ARTIFACT_DIR
docker run --rm -v $(pwd)/$ARTIFACT_DIR:/tmp \
                -u "$(id -u $USER):$(id -g $USER)" \
                -e LOCAL_UID=$(id -u $USER) \
                -e LOCAL_GID=$(id -g $USER) \
                $IMAGE_TAG /bin/sh -c "cp /home/user1/rpmbuild/RPMS/x86_64/*.rpm /tmp/"
rm -f $ARTIFACT_DIR/*-debuginfo-*.rpm

# Push binary on repo
if [[ $location == [gG][iI][tT][lL][aA][bB] ]];
then
    curl_command="curl --header \"PRIVATE-TOKEN: ${ACCESS_TOKEN}\" --insecure --upload-file"
    influxdb_fdw_package_uri="$API_V4_URL/projects/${INFLUXDB_FDW_PROJECT_ID}/packages/generic/rpm_rhel8/${PGSPIDER_BASE_POSTGRESQL_VERSION}"

    # influxdb_fdw
    eval "$curl_command ${ARTIFACT_DIR}/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm \
                        $influxdb_fdw_package_uri/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm"
    # debugsource
    eval "$curl_command ${ARTIFACT_DIR}/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-debugsource-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm \
                        $influxdb_fdw_package_uri/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-debugsource-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm"
else
    curl_command="curl -L \
                            -X POST \
                            -H \"Accept: application/vnd.github+json\" \
                            -H \"Authorization: Bearer ${ACCESS_TOKEN}\" \
                            -H \"X-GitHub-Api-Version: 2022-11-28\" \
                            -H \"Content-Type: application/octet-stream\" \
                            --retry 20 \
                            --retry-max-time 120 \
                            --insecure"
    influxdb_fdw_assets_uri="https://uploads.github.com/repos/${OWNER_GITHUB}/${INFLUXDB_FDW_PROJECT_GITHUB}/releases/${INFLUXDB_FDW_RELEASE_ID}/assets"
    binary_dir="--data-binary \"@${ARTIFACT_DIR}\""

    # influxdb_fdw
    eval "$curl_command $influxdb_fdw_assets_uri?name=influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm \
                        $binary_dir/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm"
    # debugsource
    eval "$curl_command $influxdb_fdw_assets_uri?name=influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-debugsource-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm \
                        $binary_dir/influxdb_fdw_${PGSPIDER_BASE_POSTGRESQL_VERSION}-debugsource-${INFLUXDB_FDW_RELEASE_VERSION}-${PACKAGE_RELEASE_VERSION}.rhel8.x86_64.rpm"
fi

# Clean
docker rmi $IMAGE_TAG
