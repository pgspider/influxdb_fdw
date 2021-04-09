def NODE_NAME = 'AWS_Instance_CentOS'
def MAIL_TO = 'db-jenkins@swc.toshiba.co.jp'
def BRANCH_NAME = 'Branch [' + env.BRANCH_NAME + ']'
def BUILD_INFO = 'Jenkins job: ' + env.BUILD_URL + '\n'

def INFLUXDB_DOCKER_PATH = '/home/jenkins/Docker_ExistedMulti/Server/Influx'
def TEST_TYPE = 'INFLUX'

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
            docker exec -u postgres postgresserver_multi_for_influxdb_existed_test /bin/bash -c '/tmp/influxdb_existed_test.sh ${env.GIT_BRANCH} ${target}${version}'
            docker exec -w /home/postgres/${target}${version}/contrib/influxdb_fdw postgresserver_multi_for_influxdb_existed_test /bin/bash -c 'su -c "export http_proxy=http://133.199.251.110:8080 && export https_proxy=http://133.199.251.110:8080 && export PATH=$PATH:/usr/local/go/bin && go get github.com/influxdata/influxdb1-client/v2 && export LANGUAGE="en_US.UTF-8" && export LANG="en_US.UTF-8" && export LC_ALL="en_US.UTF-8" && make ${prefix} && export NO_PROXY=172.23.0.3 && make check ${prefix} | tee make_check.out" postgres'
            docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/make_check.out make_check_existed_test.out
            docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/results/ results_${target}${version}
        """
    }
    script {
        status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_existed_test.out'")
        if (status != 0) {
            unstable(message: "Set UNSTABLE result")
            sh 'docker cp postgresserver_multi_for_influxdb_existed_test:/home/postgres/${target}${version}/contrib/influxdb_fdw/regression.diffs regression.diffs'
            sh 'cat regression.diffs || true'
            emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check on ${target}${version} FAILED ' + BRANCH_NAME, body: BUILD_INFO +  '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
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
            branchFilterType: 'All',
            secretToken: "14edd1f2fc244d9f6dfc41f093db270a"
        )
    }
    stages {
        stage('Start_containers_Existed_Test') {
            steps {
                script {
                    if (env.GIT_URL != null) {
                        BUILD_INFO = BUILD_INFO + "Git commit: " + env.GIT_URL.replace(".git", "/commit/") + env.GIT_COMMIT + "\n"
                    }
                }
                catchError() {
                    sh """
                        cd ${INFLUXDB_DOCKER_PATH}
                        docker-compose build
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
        stage('Init_data_InfluxDB') {
            steps {
                catchError() {
                    sh """
                        echo 'Influx version:'
                        docker exec influxserver_multi_for_existed_test /bin/bash -c 'influxd version'
                        rm -rf results_* || true
                        docker exec influxserver_multi_for_existed_test /bin/bash -c '/tmp/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize data FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_FDW_Test_With_Postgres_9_6_19') {
            steps {
                make_check_test("postgresql", "9.6.19")
            }
        }
        stage('make_check_FDW_Test_With_Postgres_10_14') {
            steps {
                make_check_test("postgresql", "10.14")
            }
        }
        stage('make_check_FDW_Test_With_Postgres_11_9') {
            steps {
                make_check_test("postgresql", "11.9")
            }
        }
        stage('make_check_FDW_Test_With_Postgres_12_4') {
            steps {
                make_check_test("postgresql", "12.4")
            }
        }
        stage('make_check_FDW_Test_With_Postgres_13_0') {
            steps {
                make_check_test("postgresql", "13.0")
            }
        }
        stage('Build_PGSpider_For_FDW_Test') {
            steps {
                catchError() {
                    sh """
                        docker exec postgresserver_multi_for_influxdb_existed_test /bin/bash -c 'su -c "/tmp/initialize_pgspider_existed_test.sh" postgres'
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
                make_check_test("PGSpider", "")
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
