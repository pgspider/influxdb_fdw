--Testcase 1:
SET datestyle=ISO;

--Testcase 2:
CREATE EXTENSION influxdb_fdw;

-- version not valid
--Testcase 3:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '9999', retention_policy '');
--Testcase 4:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version 'dummy', retention_policy '');
--Testcase 5:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '-1', retention_policy '');

-- host must be not NULL or not empty
--Testcase 6:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', port '38086', version '2', retention_policy '');
--Testcase 7:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 8:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 9:
SELECT * FROM optiontbl;
--Testcase 10:
DROP SERVER influxdb_svr CASCADE;

--Testcase 11:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host '', port '38086', version '2', retention_policy '');
--Testcase 12:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 13:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 14:
SELECT * FROM optiontbl;
--Testcase 15:
DROP SERVER influxdb_svr CASCADE;

-- dbname must be not NULL or not empty
--Testcase 16:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 17:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 18:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 19:
SELECT * FROM optiontbl;
--Testcase 20:
DROP SERVER influxdb_svr CASCADE;

--Testcase 21:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname '', host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 22:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 23:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 24:
SELECT * FROM optiontbl;
--Testcase 25:
DROP SERVER influxdb_svr CASCADE;


-- retention_policy can be NULL
--Testcase 26:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '2');
--Testcase 27:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 28:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 29:
SELECT * FROM optiontbl;
--Testcase 30:
DROP SERVER influxdb_svr CASCADE;

--Testcase 31:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 32:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 33:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 34:
SELECT * FROM optiontbl;
--Testcase 35:
DROP SERVER influxdb_svr CASCADE;

-- auth_token can be NULL
--Testcase 36:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 37:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr;
--Testcase 38:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 39:
SELECT * FROM optiontbl;
--Testcase 40:
DROP SERVER influxdb_svr CASCADE;

-- auth_token invalid
--Testcase 41:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 42:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'wrong_token');
--Testcase 43:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 44:
SELECT * FROM optiontbl;
--Testcase 45:
DROP SERVER influxdb_svr CASCADE;

--Testcase 46:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', version '2', retention_policy '');
--Testcase 47:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token '');
--Testcase 48:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 49:
SELECT * FROM optiontbl;
--Testcase 50:
DROP SERVER influxdb_svr CASCADE;

-- user must can be NULL
--Testcase 51:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 52:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (password 'pass');
--Testcase 53:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 54:
SELECT * FROM optiontbl;
--Testcase 55:
DROP SERVER influxdb_svr CASCADE;

--Testcase 56:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 57:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user '', password 'pass');
--Testcase 58:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 59:
SELECT * FROM optiontbl;
--Testcase 60:
DROP SERVER influxdb_svr CASCADE;

-- password can be NULL
--Testcase 61:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 62:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user');
--Testcase 63:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 65:
SELECT * FROM optiontbl;
--Testcase 65:
DROP SERVER influxdb_svr CASCADE;

--Testcase 66:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 67:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password '');
--Testcase 68:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 69:
SELECT * FROM optiontbl;
--Testcase 70:
DROP SERVER influxdb_svr CASCADE;

--Testcase 71:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 72:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user '', password '');
--Testcase 73:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 74:
SELECT * FROM optiontbl;
--Testcase 75:
DROP SERVER influxdb_svr CASCADE;

--Testcase 76:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086', version '1');
--Testcase 77:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password 'pass');
--Testcase 78:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 79:
SELECT * FROM optiontbl;
--Testcase 80:
DROP SERVER influxdb_svr CASCADE;

-- Test if version option is not set
-- Connect to InfluxDB version 1
--Testcase 81:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '18086');
--Testcase 82:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (user 'user', password 'pass');
--Testcase 83:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 84:
SELECT * FROM optiontbl;
--Testcase 85:
DROP SERVER influxdb_svr CASCADE;

-- Connect to InfluxDB version 2
--Testcase 86:
CREATE SERVER influxdb_svr FOREIGN DATA WRAPPER influxdb_fdw OPTIONS (dbname 'optiondb', host 'http://localhost', port '38086', retention_policy '');
--Testcase 87:
CREATE USER MAPPING FOR CURRENT_USER SERVER influxdb_svr OPTIONS (auth_token 'mytoken');
--Testcase 88:
CREATE FOREIGN TABLE optiontbl (tag1 text, version text, value2 int) SERVER influxdb_svr;
--Testcase 89:
SELECT * FROM optiontbl;
--Testcase 90:
DROP SERVER influxdb_svr CASCADE;

--Testcase 91:
DROP EXTENSION influxdb_fdw CASCADE;
