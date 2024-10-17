Usage of creating influxdb_fdw RPM packages
=====================================

This document is about how to create and publish rpm packages of influxdb_fdw to Benzaiten. 
- It provided 2 tools to create InfluxDB FDW RPMs.
	- One is for creating RPMs with [PGSpider](#creating-influxdb_fdw-rpm-packages-for-pgspider).
		- The PGSpider RPM package is required. It must be released on PGSpider repository first.
		- The PGSpider RPM package have released on PGSpider [package registry](https://tccloud2.toshiba.co.jp/swc/gitlab/db/PGSpider/-/packages/22).
	- Another is for creating RPMs with [PostgreSQL](#creating-influxdb_fdw-rpm-packages-for-postgresql).
- Additionally, we also provide Gitlab CI/CD pipeline for creating influxdb_fdw RPM packages for [PGSpider](#usage-of-run-cicd-pipeline).

Environment for creating rpm of influxdb_fdw
=====================================
The description below is used in the specific Linux distribution RockyLinux8.
1. Docker
	- Install Docker
		```sh
		sudo yum install -y yum-utils
		sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
		sudo yum install -y docker-ce docker-ce-cli containerd.io
		sudo systemctl enable docker
		sudo systemctl start docker
		```
	- Enable the currently logged in user to use docker commands
		```sh
		sudo gpasswd -a $(whoami) docker
		sudo chgrp docker /var/run/docker.sock
		sudo systemctl restart docker
		```
	- Proxy settings (If your network must go through a proxy)
		```sh
		sudo mkdir -p /etc/systemd/system/docker.service.d
		sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
		[Service]
		Environment="HTTP_PROXY=http://proxy:port/"
		Environment="HTTPS_PROXY=http://proxy:port/"
		Environment="NO_PROXY=localhost,127.0.0.1"
		EOF
		sudo systemctl daemon-reload
		sudo systemctl restart docker
		```
2. Get the required files  
	```sh
	git clone https://tccloud2.toshiba.co.jp/swc/gitlab/db/influxdb_fdw.git
	```

Creating influxdb_fdw rpm packages for PGSpider
=====================================
1. Preconditions
	PGSpider RPM packages are must-have packages. They need to be released first on the [pgspider](https://tccloud2.toshiba.co.jp/swc/gitlab/db/PGSpider/-/packages/22) repository.
2. File used here
	- rpm/influxdb_fdw.spec
	- rpm/env_rpmbuild.conf
	- rpm/Dockerfile_rpm
	- rpm/create_rpm_binary_with_PGSpider.sh
3. Configure `rpm/env_rpmbuild.conf` file
	- Configure proxy
		```sh
		proxy=http://username:password@proxy:port
		no_proxy=localhost,127.0.0.1
		```
	- Configure the registry location to publish the package and version of the packages
		```sh
		location=gitlab 						# Fill in <gitlab> or <github>. In this project, please use <gitlab>
		ACCESS_TOKEN=							# Fill in the Access Token for authentication purposes to publish rpm packages to Package Registry
		API_V4_URL=								# Fill in API v4 URL of this repo. In this project please use <https://tccloud2.toshiba.co.jp/swc/gitlab/api/v4>
		INFLUXDB_FDW_PROJECT_ID=				# Fill in the ID of the influxdb_fdw project.		
		PGSPIDER_PROJECT_ID=					# Fill in the ID of the PGSpider project to get PGSpider rpm packages
		PGSPIDER_RPM_ID=						# Fill in the ID of PGSpider rpm packages
		PGSPIDER_BASE_POSTGRESQL_VERSION=16 	# Base Postgres version of PGSpider
		PGSPIDER_RELEASE_VERSION=4.0.0-1		# PGSpider rpm packages version
		PGSPIDER_RELEASE_PACKAGE_VERSION=4.0.0	# PGSpider release packages version
		PACKAGE_RELEASE_VERSION=1				# The number of times this version of the influxdb_fdw has been packaged.
		INFLUXDB_CXX_PROJECT_ID=				# Fill in the ID of influxdb-cxx project to get influxdb-cxx rpm packages
		INFLUXBB_CXX_RPM_ID=					# Fill in the ID of influxdb-cxx rpm packages
		INFLUXDB_CXX_PACKAGE_VERSION=0.0.1		# Fill in the version of influxdb-cxx package registry
		INFLUXDB_CXX_RELEASE_VERSION=0.0.1-1	# Fill in the version of influxdb-cxx rpm package
		INFLUXDB_FDW_RELEASE_VERSION=2.4.0		# Version of influxdb_fdw rpm package
		```
4. Build execution
	```sh
	chmod +x rpm/create_rpm_binary_with_PGSpider.sh
	./rpm/create_rpm_binary_with_PGSpider.sh
	```
5. Confirmation after finishing executing the script
	- Terminal displays a success message. 
		```
		{"message":"201 Created"}
		...
		{"message":"201 Created"}
		```
	- RPM Packages are stored on the Package Registry of its repository
		```sh
		Menu TaskBar -> Deploy -> Package Registry
		```

Creating influxdb_fdw rpm packages for PostgreSQL
=====================================
This tool will create influxdb_fdw rpm using PostgreSQL with the difference from PGSpider:
- Use script `create_rpm_binary_with_PostgreSQL.sh` instead of `create_rpm_binary_with_PGSpider.sh`.
- Use the parameters `POSTGRESQL_VERSION`, `PACKAGE_RELEASE_VERSION`, `INFLUXDB_CXX_PROJECT_GITHUB`, `INFLUXDB_CXX_RELEASE_VERSION`, `INFLUXDB_FDW_RELEASE_VERSION`.
- The RPM packages after creation will be stored locally in the `fdw_rpm_with_postgres` directory and will not be uploaded to the repository.

1. File used here
	- rpm/influxdb_fdw.spec
	- rpm/env_rpmbuild.conf
	- rpm/Dockerfile_rpm
	- rpm/create_rpm_binary_with_PostgreSQL.sh
2. Configure `rpm/env_rpmbuild.conf` file
	- Configure proxy
		```sh
		proxy=http://username:password@proxy:port
		no_proxy=localhost,127.0.0.1
		```
	- Configure the registry location to publish the package and version of the packages
		```sh
		POSTGRESQL_VERSION=16.0-1					# PostgreSQL rpm packages version. You can check in: https://yum.postgresql.org/packages/.
		PACKAGE_RELEASE_VERSION=1					# The number of times this version of the influxdb_fdw has been packaged.
		INFLUXDB_CXX_PROJECT_GITHUB=				# Repository name of influxdb-cxx. Normally it is "influxdb-cxx". If you forked or import it into a new repository, it can be different).
		INFLUXDB_CXX_RELEASE_VERSION=0.0.1-1		# Fill in the version of influxdb-cxx rpm package
		INFLUXDB_FDW_RELEASE_VERSION=2.4.0			# Version of influxdb_fdw rpm package
		```
3. Build execution
	- Execute the script.
	```sh
	chmod +x rpm/create_rpm_binary_with_PostgreSQL.sh
	./rpm/create_rpm_binary_with_PostgreSQL.sh
	```
	- RPM Packages are stored on the `fdw_rpm_with_postgres` folder in the root directory.

Usage of Run CI/CD pipeline
=====================================
1. Go to Pipelines Screen
	```sh
	Menu TaskBar -> Build -> Pipelines
	```
2. Click `Run Pipeline` button  
![Alt text](images/BENZAITEN/pipeline_screen.PNG)
3. Choose `Branch` or `Tag` name
4. Provide `Access Token` through `Variables`
	- Input variable key: ACCESS_TOKEN
	- Input variable value: Your access token
5. Click `Run Pipeline` button  
![Alt text](images/BENZAITEN/run_pipeline.PNG)
