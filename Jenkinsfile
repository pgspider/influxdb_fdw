def NODE_NAME = 'AWS_Instance_CentOS'
def MAIL_TO = '$DEFAULT_RECIPIENTS'
def BRANCH_NAME = 'Branch [' + env.BRANCH_NAME + ']'
def BUILD_INFO = 'Jenkins job: ' + env.BUILD_URL + '\n'

def INFLUXDB_DOCKER_PATH = '/home/jenkins/Docker/Server/Influx'
def BRANCH_PGSPIDER = 'port15beta2'
def make_check_test(String target, String version) {
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
            docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/influxdb_existed_test.sh ${env.GIT_BRANCH} ${target}${version}'
            docker exec -u postgres -w /home/postgres/${target}${version}/contrib/influxdb_fdw postgresserver_multi_for_influxdb_existed_test /bin/bash -c 'export PATH=$PATH:/usr/local/go/bin && go env -w GO111MODULE=auto && go get github.com/influxdata/influxdb1-client/v2 && export LANGUAGE="en_US.UTF-8" && export LANG="en_US.UTF-8" && export LC_ALL="en_US.UTF-8" && make ${prefix} && export NO_PROXY=172.23.0.3 && make check ${prefix} | tee make_check.out'
            docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/make_check.out make_check_existed_test.out
            docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/results/ results_${target}${version}
        """
    }
    script {
        status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_existed_test.out'")
        if (status != 0) {
            unstable(message: "Set UNSTABLE result")
            sh "docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/regression.diffs regression.diffs"
            sh 'cat regression.diffs || true'
            updateGitlabCommitStatus name: 'make_check', state: 'failed'
        } else {
            updateGitlabCommitStatus name: 'make_check', state: 'success'
        }
    }
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
                        docker-compose up -d
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
        stage('Init_data_InfluxDB_For_Testing_Postgres_11_16') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with v11.16 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_11_16') {
            steps {
                catchError() {
                    make_check_test("postgresql", "11.16")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on v11.16 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDB_For_Testing_Postgres_12_11') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with v12.11 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_12_11') {
            steps {
                catchError() {
                    make_check_test("postgresql", "12.11")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on v12.11 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDB_For_Testing_Postgres_13_7') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with v13.7 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_13_7') {
            steps {
                catchError() {
                    make_check_test("postgresql", "13.7")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on v13.7 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDB_For_Testing_Postgres_14_4') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with v14.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_14_4') {
            steps {
                catchError() {
                    make_check_test("postgresql", "14.4")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on v14.4 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Init_data_InfluxDB_For_Testing_Postgres_15beta2') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data with v15beta2 FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false 
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_15beta2') {
            steps {
                catchError() {
                    make_check_test("postgresql", "15beta2")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on v15beta2 FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        stage('Build_PGSpider_InitDataInfluxDB_For_FDW_Test') {
            steps {
                catchError() {
                    sh """
                        docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/home/test/initialize_pgspider_existed_test.sh $BRANCH_PGSPIDER'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'systemctl stop influxd'
                        docker exec -d influxserver_multi_for_existed_test /bin/bash -c 'influxd -config /etc/influxdb/influxdb.conf'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/home/test/start_existed_test.sh ${env.GIT_BRANCH}'
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
        stage('make_check_FDW_Test_With_PGSpider') {
            steps {
                catchError() {
                    make_check_test("PGSpider", "")
                }
            }
            post {
                unstable {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on PGSpider FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
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
                docker-compose down
            """
        }
    }
}
