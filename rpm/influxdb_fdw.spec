%global sname influxdb_fdw

Summary:	InfluxDB Foreign Data Wrapper for PGSpider
Name:		%{sname}_%{pgmajorversion}
Version:	%{release_version}
Release:	%{?package_release_version}.%{?dist}
License:	TOSHIBA CORPORATION
Source0:	influxdb_fdw.tar.bz2
URL:		https://github.com/pgspider/influxdb_fdw
BuildRequires:	pgspider%{pgmajorversion}-devel pgdg-srpm-macros 
BuildRequires:  influxdb-cxx >= 0.0.1
Requires:	pgspider%{pgmajorversion}-server

%description
This PGSpider extension implements a Foreign Data Wrapper (FDW) for InfluxDB.

%prep
%setup -q -n %{sname}-%{version}

%build
USE_PGXS=1 PATH=%{pginstdir}/bin/:$PATH %{__make} with_llvm=no CXX_CLIENT=1 %{?_smp_mflags}

%install
%{__rm} -rf %{buildroot}

USE_PGXS=1 PATH=%{pginstdir}/bin/:$PATH %{__make} with_llvm=no CXX_CLIENT=1 %{?_smp_mflags} install DESTDIR=%{buildroot}

# Install README file under PGSpider installation directory:
%{__install} -d %{buildroot}%{pginstdir}/share/extension
%{__install} -m 755 README.md %{buildroot}%{pginstdir}/share/extension/README-%{sname}
%{__rm} -f %{buildroot}%{_docdir}/pgsql/extension/README.md

%clean
%{__rm} -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(755,root,root,755)
%doc %{pginstdir}/share/extension/README-%{sname}
%{pginstdir}/lib/%{sname}.so
%{pginstdir}/share/extension/%{sname}--*.sql
%{pginstdir}/share/extension/%{sname}.control

%changelog
* Tue Mar 28 2023 weiting1lee - 2.0.0
- Support PosgreSQL 15.0
- Support InfluxDB v1.x: with pgspider/influxdb-cxx client.
- Support InfluxDB v2.x: with pgspider/influxdb-cxx client via InfluxDB v1 compatibility API.
- Bug fixes:
-   Fix Error parsing query influxdb_fdw with boolean data type
-   Fix limit-orderby test suite crash on debug mode
-   Fix cannot insert timestamp value into field column

* Tue Jun 21 2022 hrkuma - 1.2.1
- Support schemaless feature

* Thu Dec 23 2021 hrkuma - 1.1.1
- Support PostgreSQL 14.0

* Mon Dec 6 2021 hrkuma - 1.1.0
- Support bulk INSERT by using batch_size option for PostgreSQL 14
- Support GROUP By times(), fill() feature of InfluxDB
- Fix memory leaking

* Wed May 26 2021 hrkuma - 1.0.0
- Support INSERT/DELETE features
- Support add more functions to pushdown
- Support LIMIT OFFSET clause pushdown
- Support pushdown scalar operator ANY/ALL (ARRAY)
- Refactored tests

* Thu Jan 14 2021 hrkuma - 0.3.0
- Support PostgreSQL 13.0
- Support function pushdown in the target list (for PGSpider)
- Support new "tags" option for specifing tag keys
- Bug fixes
-   Fix influxdb not support compare time column with OR
-   Fix influxdb not support IN/NOT IN
-   Fix invalid input syntax for type integer
-   Fix error GROUP BY only works with time and tag dimensions
-   Fix time argument and having clause
-   Fix influxdb does not support DISTINCT within aggregate except count()
-   Fix error parsing with LIKE operator
-   Fix InfluxDB return 0 rows when related tag key operation
-   fix build on macOS
-   fix WHERE string comparision other than = and != operators
-   fix mix usage of aggregate function and arithmetic

* Tue Apr 28 2020 hrkuma - 0.2.0
- PostgreSQL 12 Support
- GROUP BY push down Support
- column_name option Support
- Bug fixes

* Thu Dec 6 2018 hrkuma - 0.1.0
- This first release supports PostgreSQL 9.6, 10 and 11.
- Features
-   WHERE clauses including timestamp, interval are pushed down
-   Simple aggregation without GROUP BY are pushed down
- Limitations
-   INSERT, UPDATE and DELETE are not supported.
-   There are some limitations coming from data model and query language of InfluxDB. Please see README.md for detail.
