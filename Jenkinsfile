def NODE_NAME = 'AWS_Instance_CentOS'
def MAIL_TO = 'db-jenkins@swc.toshiba.co.jp'
def BRANCH_NAME = 'Branch [' + env.BRANCH_NAME + ']'
def BUILD_INFO = 'Jenkins job: ' + env.BUILD_URL + '\n'

def INFLUXDB_DOCKER_PATH = '/home/jenkins/Docker/Server/Influx'
def ENHANCE_TEST_DOCKER_PATH = '/home/jenkins/Docker'
def TEST_TYPE = 'INFLUX'

START_EXISTED_TEST = ''
INIT_EXISTED_TEST = ''
START_ENHANCE_TEST = ''
INIT_ENHANCE_TEST = ''


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
                        docker-compose up --build -d
                    """
                }
            }
            post {
                failure {
                    script {
                        START_EXISTED_TEST = 'FAILED'
                    }
                    updateGitlabCommitStatus name: 'Build', state: 'failed'
                }
                success {
                    script {
                        START_EXISTED_TEST = 'SUCCESS'   
                    }
                    updateGitlabCommitStatus name: 'Build', state: 'success'
                }
            }
        }
        stage('Initialize_for_Existed_Test') {
            steps {
                catchError() {
                    sh """
                        docker exec influxserver_for_existed_test /bin/bash -c '/tmp/start_existed_test.sh ${env.GIT_BRANCH}'
                    """
                }
            }
            post {
                failure {
                    script {
                        INIT_EXISTED_TEST = 'FAILED'
                    }
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    script {
                        INIT_EXISTED_TEST = 'SUCCESS'
                    }
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_Existed_Test') {
            steps {
                catchError() {
                    sh """
                        rm -rf make_check_existed_test.out || true
                        docker exec -u postgres postgresserver_for_influxdb_existed_test /bin/bash -c '/tmp/influxdb_existed_test.sh ${env.GIT_BRANCH}'
                        docker exec -w /home/postgres/postgresql-13beta2/contrib/influxdb_fdw postgresserver_for_influxdb_existed_test /bin/bash -c 'su -c "export http_proxy=http://133.199.251.110:8080 && export https_proxy=http://133.199.251.110:8080 && export PATH=$PATH:/usr/local/go/bin && go get github.com/influxdata/influxdb1-client/v2 && make && export NO_PROXY=172.23.0.3 && make check | tee make_check.out" postgres'
                        docker cp postgresserver_for_influxdb_existed_test:/home/postgres/postgresql-13beta2/contrib/influxdb_fdw/make_check.out make_check_existed_test.out
                    """
                }
                script {
                    status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_existed_test.out'")
                    if (status != 0) {
                        unstable(message: "Set UNSTABLE result")
                        sh 'docker cp postgresserver_for_influxdb_existed_test:/home/postgres/postgresql-13beta2/contrib/influxdb_fdw/regression.diffs regression.diffs'
                        sh 'cat regression.diffs || true'
                        updateGitlabCommitStatus name: 'make_check', state: 'failed'
                    } else {
                        updateGitlabCommitStatus name: 'make_check', state: 'success'
                    }
                }
            }
        }
        stage('Start_containers_Enhance_Test') {
            steps {
                catchError() {
                   sh """
                        cd ${ENHANCE_TEST_DOCKER_PATH}
                        docker-compose up --build -d 
                    """ 
                }
            }
            post {
                failure {
                    script {
                        START_ENHANCE_TEST = 'FAILED'
                    }
                    updateGitlabCommitStatus name: 'Build', state: 'failed'
                }
                success {
                    script {
                        START_ENHANCE_TEST = 'SUCCESS'
                    }
                    updateGitlabCommitStatus name: 'Build', state: 'success'
                }
            }
        }
        stage('Initialize_for_Enhance_Test') {
            steps {
                catchError() {
                    sh """
                        docker exec mysqlserver1_enhance_test /bin/bash -c '/tmp/start_enhance_test.sh'
                        docker exec mysqlserver2_enhance_test /bin/bash -c '/tmp/start_enhance_test.sh'
                        docker exec postgresserver1_enhance_test /bin/bash -c '/tmp/start_enhance_test_1.sh'
                        docker exec postgresserver2_enhance_test /bin/bash -c '/tmp/start_enhance_test_2.sh'
                        docker exec tinybraceserver1_enhance_test /bin/bash -c '/tmp/start_enhance_test_1.sh'
                        docker exec -d -w /usr/local/tinybrace tinybraceserver1_enhance_test /bin/bash -c 'bin/tbserver &' 
                        docker exec tinybraceserver2_enhance_test /bin/bash -c '/tmp/start_enhance_test_2.sh'
                        docker exec -d -w /usr/local/tinybrace tinybraceserver2_enhance_test /bin/bash -c 'bin/tbserver &' 
                        docker exec influxserver1_enhance_test /bin/bash -c '/tmp/start_enhance_test.sh'
                        docker exec influxserver2_enhance_test /bin/bash -c '/tmp/start_enhance_test.sh'
                        docker exec -d gridserver1_enhance_test /bin/bash -c '/tmp/start_enhance_test_1.sh'
                        sleep 10
                        docker exec -d gridserver2_enhance_test /bin/bash -c '/tmp/start_enhance_test_2.sh'
                        sleep 10
                        docker exec pgspiderserver1_enhance_test /bin/bash -c 'su -c "/tmp/start_enhance_test.sh ${env.GIT_BRANCH} ${TEST_TYPE}" pgspider'
                    """
                }
            }
            post {
                failure {
                    script {
                        INIT_ENHANCE_TEST = 'FAILED'
                    }
                    updateGitlabCommitStatus name: 'Init_Data', state: 'failed'
                }
                success {
                    script {
                        INIT_ENHANCE_TEST = 'SUCCESS'
                    }
                    updateGitlabCommitStatus name: 'Init_Data', state: 'success'
                }
            }
        }
        stage('make_check_Enhance_Test') {
            steps {
                catchError() {
                    sh """
                        rm -rf make_check_enhance_test.out regression.diffs || true
                        docker exec -w /home/pgspider/GIT/PGSpider/contrib/pgspider_core_fdw pgspiderserver1_enhance_test /bin/bash -c 'su -c "chmod a+x *.sh" pgspider'
                        docker exec -w /home/pgspider/GIT/PGSpider/contrib/pgspider_core_fdw pgspiderserver1_enhance_test /bin/bash -c "sed -i 's/enhance\\\\\\\\\\/BasicFeature1_File_4ARG enhance\\\\\\\\\\/BasicFeature1_File_AllARG enhance\\\\\\\\\\/BasicFeature1_GridDB_4ARG enhance\\\\\\\\\\/BasicFeature1_GridDB_AllARG enhance\\\\\\\\\\/BasicFeature1_InfluxDB_4ARG enhance\\\\\\\\\\/BasicFeature1_InfluxDB_AllARG enhance\\\\\\\\\\/BasicFeature1_MySQL_4ARG enhance\\\\\\\\\\/BasicFeature1_MySQL_AllARG enhance\\\\\\\\\\/BasicFeature1_PostgreSQL_4ARG enhance\\\\\\\\\\/BasicFeature1_PostgreSQL_AllARG enhance\\\\\\\\\\/BasicFeature1_SQLite_4ARG enhance\\\\\\\\\\/BasicFeature1_SQLite_AllARG enhance\\\\\\\\\\/BasicFeature1_TinyBrace_4ARG enhance\\\\\\\\\\/BasicFeature1_TinyBrace_AllARG enhance\\\\\\\\\\/BasicFeature1_t_max_range enhance\\\\\\\\\\/BasicFeature1_tmp_t15_4ARG enhance\\\\\\\\\\/BasicFeature1_tmp_t15_AllARG enhance\\\\\\\\\\/BasicFeature2_JOIN_Multi_Tbl enhance\\\\\\\\\\/BasicFeature2_SELECT_Muli_Tbl enhance\\\\\\\\\\/BasicFeature2_UNION_Multi_Tbl enhance\\\\\\\\\\/BasicFeature_Additional_Test enhance\\\\\\\\\\/BasicFeature_ComplexCommand enhance\\\\\\\\\\/BasicFeature_For_Bug_54 enhance\\\\\\\\\\/BasicFeature_For_Bug_60/enhance\\\\\\\\\\/BasicFeature1_InfluxDB_4ARG enhance\\\\\\\\\\/BasicFeature1_InfluxDB_AllARG/g' test_enhance.sh"
                        docker exec -w /home/pgspider/GIT/PGSpider/contrib/pgspider_core_fdw pgspiderserver1_enhance_test /bin/bash -c 'su -c "./test_enhance.sh" pgspider'
                        docker cp pgspiderserver1_enhance_test:/home/pgspider/GIT/PGSpider/contrib/pgspider_core_fdw/make_check.out make_check_enhance_test.out
                    """
                }
                script {
                    status = sh(returnStatus: true, script: "grep -q 'All [0-9]* tests passed' 'make_check_enhance_test.out'")
                    if (status != 0) {
                        unstable(message: "Set UNSTABLE result")
                        sh 'docker cp pgspiderserver1_enhance_test:/home/pgspider/GIT/PGSpider/contrib/pgspider_core_fdw/regression.diffs regression.diffs'
                        sh 'cat regression.diffs || true'
                        updateGitlabCommitStatus name: 'make_check', state: 'failed'
                    } else {
                        updateGitlabCommitStatus name: 'make_check', state: 'success'
                    }
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
                    emailext subject: '[CI INFLUXDB_FDW] InfluxDB_Test BACK TO NORMAL on ' + BRANCH_NAME, body: BUILD_INFO + '\n---------EXISTED_TEST---------\n' + '${FILE,path="make_check_existed_test.out"}' + '\n---------ENHANCE_TEST---------\n' + '${FILE,path="make_check_enhance_test.out"}', to: "${MAIL_TO}", attachLog: false
                }
            }
        }
        unsuccessful {
            script {
                if (START_EXISTED_TEST == 'FAILED') {
                    if (START_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Start Containers FAILED | ENHANCE_TEST: Start Containers FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    } else if (INIT_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Start Containers FAILED | ENHANCE_TEST: Initialize FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    } else {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Start Containers FAILED | ENHANCE_TEST: Result make check ' + BRANCH_NAME, body: BUILD_INFO + '${FILE,path="make_check_enhance_test.out"}', to: "${MAIL_TO}", attachLog: false
                    }
                } else if (INIT_EXISTED_TEST == 'FAILED') {
                    if (START_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize FAILED | ENHANCE_TEST: Start Containers FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    } else if (INIT_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize FAILED | ENHANCE_TEST: Initialize FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${BUILD_LOG, maxLines=200, escapeHtml=false}', to: "${MAIL_TO}", attachLog: false
                    } else {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Initialize FAILED | ENHANCE_TEST: Result make check ' + BRANCH_NAME, body: BUILD_INFO + '${FILE,path="make_check_enhance_test.out"}', to: "${MAIL_TO}", attachLog: false
                    }
                } else {
                     if (START_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check | ENHANCE_TEST: Start Containers FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                    } else if (INIT_ENHANCE_TEST == 'FAILED') {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check | ENHANCE_TEST: Initialize FAILED ' + BRANCH_NAME, body: BUILD_INFO + '${FILE,path="make_check_existed_test.out"}', to: "${MAIL_TO}", attachLog: false
                    } else {
                        emailext subject: '[CI INFLUXDB_FDW] EXISTED_TEST: Result make check | ENHANCE_TEST: Result make check ' + BRANCH_NAME, body: BUILD_INFO + '\n---------EXISTED_TEST---------\n' + '${FILE,path="make_check_existed_test.out"}' + '\n---------ENHANCE_TEST---------\n' + '${FILE,path="make_check_enhance_test.out"}', to: "${MAIL_TO}", attachLog: false
                    }
                }
            }
        }
        always {
            sh """
                cd ${INFLUXDB_DOCKER_PATH}
                docker-compose down
                cd ${ENHANCE_TEST_DOCKER_PATH}
                docker-compose down
            """
        }
    }
}
