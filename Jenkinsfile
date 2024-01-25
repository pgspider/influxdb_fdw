def NODE_NAME = 'AWS_Instance_CentOS'
def MAIL_TO = '$DEFAULT_RECIPIENTS'
def BRANCH_NAME = 'Branch [' + env.BRANCH_NAME + ']'
def BUILD_INFO = 'Jenkins job: ' + env.BUILD_URL + '\n'

def INFLUXDB_DOCKER_PATH = '/home/jenkins/Docker/Server/Influx'
def BRANCH_PGSPIDER = 'master'
def make_check_test(String target, String version, String cxx_client, String InfluxDBVersion) {
    def prefix = ""
    script {
        if (version != "") {
            version = "-" + version
        }
        if (target == "PGSpider") {
            prefix = "REGRESS_PREFIX=PGSpider"
        }
    }
    catchError() {
        sh """
            rm -rf make_check_existed_test.out || true
            docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/influxdb_existed_test.sh ${env.GIT_BRANCH} ${target}${version} ${cxx_client} ${InfluxDBVersion}'
            docker exec -u postgres -w /home/postgres/${target}${version}/contrib/influxdb_fdw postgresserver_multi_for_influxdb_existed_test /bin/bash -c 'export LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH && export PATH=$PATH:/usr/local/go/bin && go env -w GO111MODULE=auto && go get github.com/influxdata/influxdb1-client/v2 && source scl_source enable devtoolset-7 && export LANGUAGE="en_US.UTF-8" && export LANG="en_US.UTF-8" && export LC_ALL="en_US.UTF-8" && make ${prefix} ${cxx_client} && export NO_PROXY=172.23.0.3,172.23.0.4,172.23.0.5 && make check ${prefix} ${cxx_client} | tee make_check.out'
            docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/make_check.out make_check_existed_test.out
        """
    }
    script {
        status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_existed_test.out'")
        if (status != 0) {
            unstable(message: "Set UNSTABLE result")
            sh "docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/regression.diffs regression.diffs"
            sh "docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/results/ results_${target}${version}_${InfluxDBVersion}_${cxx_client}"
            sh 'cat regression.diffs || true'
            updateGitlabCommitStatus name: 'make_check', state: 'failed'
        } else {
            updateGitlabCommitStatus name: 'make_check', state: 'success'
        }
    }
}

def init_data_influxdbv1(){
    sh """
        echo 'Influx version:'
        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
    """
}

def init_data_influxdbcxx(){
    sh """
        echo 'Influx version:'
        docker exec influxserver1_multi_for_existed_test /bin/bash -c 'influxd version'
        docker exec -d influxserver1_multi_for_existed_test /bin/bash -c 'export INFLUXDB_HTTP_AUTH_ENABLED=true && influxd -config /etc/influxdb/influxdb.conf'
        docker exec influxserver1_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test_cxx.sh ${env.GIT_BRANCH}'
        docker exec influxserverv2_multi_for_existed_test /bin/bash -c 'influxd version'
        docker exec -d influxserverv2_multi_for_existed_test /bin/bash -c 'influxd --storage-write-timeout=100s --http-bind-address=:38086'
        docker exec influxserverv2_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test_v2.sh ${env.GIT_BRANCH}'
    """
}

pipeline {
    agent {
        node {
            label NODE_NAME
        }
    }
    options {
        gitLabConnection('GitLabConnection')
    }
    triggers {
        gitlab(
            triggerOnPush: true,
            triggerOnMergeRequest: false,
            triggerOnClosedMergeRequest: false,
            triggerOnAcceptedMergeRequest: true,
            triggerOnNoteRequest: false,
            setBuildDescription: true,
            branchFilterType: 'All'
        )
    }
    stages {
        stage('Start_containers_Existed_Test') {
            steps {
                script {
                    if (env.GIT_URL != null) {
                        BUILD_INFO = BUILD_INFO + "Git commit: " + env.GIT_URL.replace(".git", "/commit/") + env.GIT_COMMIT + "\n"
                    }
                    sh 'rm -rf results_* || true'
                }
                catchError() {
                    sh """
                        cd ${INFLUXDB_DOCKER_PATH}
                        docker compose up -d
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Start Containers FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build', state: 'success'
                }
            }
        }
        stage('Build_CXX_Client') {
            steps {
                catchError() {
                    sh """
                        docker exec postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/influxdb_cxx_client_build.sh'
                        docker exec influxserver1_multi_for_existed_test /bin/bash -c '/home/test/create_cxx_users.sh'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Build influxdb_cxx client FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Build', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build', state: 'success'
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_12_16_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with InfluxDBV1 v12.16 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_12_16_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("postgresql", "12.16", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 v12.16 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_13_12_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with InfluxDBV1 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_13_12_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("postgresql", "13.12", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_14_9_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with InfluxDBV1 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_14_9_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("postgresql", "14.9", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_15_4_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with InfluxDBV1 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_15_4_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("postgresql", "15.4", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_16.0_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with InfluxDBV1 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_16.0_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("postgresql", "16.0", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Build_PGSpider_InitData_InfluxDBV1_For_FDW_Test_Use_GO_CLIENT') {
            steps {
                catchError() {
                    init_data_influxdbv1()
                    sh """
                        docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/initialize_pgspider_existed_test.sh $BRANCH_PGSPIDER'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI Influx_FDW] EXISTED_TEST: Build PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_PGSpider_Use_GO_CLIENT') {
            steps {
                catchError() {
                    make_check_test("PGSpider", "", "", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on InfluxDBV1 PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        /*stage('Init_data_InfluxDBV1_For_Testing_Postgres_13_12_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV1 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_13_12_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "13.12", "CXX_CLIENT=1", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV1 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_14_9_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV1 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_14_9_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "14.9", "CXX_CLIENT=1", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV1 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_15_4_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV1 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_15_4_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "15.4", "CXX_CLIENT=1", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV1 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }*/
        stage('Init_data_InfluxDBV1_For_Testing_Postgres_16.0_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV1 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_Postgres_16.0_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "16.0", "CXX_CLIENT=1", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV1 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Build_PGSpider_InitData_InfluxDBV1_For_FDW_Test_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                    sh """
                        docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/initialize_pgspider_existed_test.sh $BRANCH_PGSPIDER'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI Influx_FDW] EXISTED_TEST: Build PGSpider with CXX Client FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV1_PGSpider_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("PGSpider", "", "CXX_CLIENT=1", "1")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV1 PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        /* stage('init_data_influxdbcxx_For_Testing_Postgres_13_12_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV2 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV2_Postgres_13_12_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "13.12", "CXX_CLIENT=1", "2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV2 v13.12 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('init_data_influxdbcxx_For_Testing_Postgres_14_9_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV2 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV2_Postgres_14_9_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "14.9", "CXX_CLIENT=1", "2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV2 v14.9 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('init_data_influxdbcxx_For_Testing_Postgres_15_4_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV2 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV2_Postgres_15_4_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "15.4", "CXX_CLIENT=1", "2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV2 v15.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }*/
        stage('init_data_influxdbcxx_For_Testing_Postgres_16.0_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with CXX Client InfluxDBV2 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV2_Postgres_16.0_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("postgresql", "16.0", "CXX_CLIENT=1", "2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV2 v16.0 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Build_PGSpider_InitData_InfluxDBV2_For_FDW_Test_Use_CXX_Client') {
            steps {
                catchError() {
                    init_data_influxdbcxx()
                    sh """
                        docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/initialize_pgspider_existed_test.sh $BRANCH_PGSPIDER'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI Influx_FDW] EXISTED_TEST: Build PGSpider with CXX Client FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Build_PGSPider', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_InfluxDBV2_PGSpider_Use_CXX_Client') {
            steps {
                catchError() {
                    make_check_test("PGSpider", "", "CXX_CLIENT=1", "2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check with CXX Client on InfluxDBV2 PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
    }
    post {
        success  {
            script {
                prevResult = 'SUCCESS'
                if (currentBuild.previousBuild != null) {
                    prevResult = currentBuild.previousBuild.result.toString()
                }
                if (prevResult != 'SUCCESS') {
                    emailext subject: '[CI INFLUXDB_FDW] InfluxDB_Test BACK TO NORMAL on ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        always {
            sh """
                cd ${INFLUXDB_DOCKER_PATH}
                docker compose down
            """
        }
    }
}
