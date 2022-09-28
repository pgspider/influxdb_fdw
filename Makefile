######################################################################-------------------------------------------------------------------------
#
# InfluxDB Foreign Data Wrapper for PostgreSQL
#
# Portions Copyright (c) 2018-2022, TOSHIBA CORPORATION
#
# IDENTIFICATION
# 		Makefile
#
##########################################################################

MODULE_big = influxdb_fdw
OBJS = option.o slvars.o deparse.o influxdb_query.o influxdb_fdw.o

ifndef GO_CLIENT
ifndef CXX_CLIENT
GO_CLIENT = 1
endif
endif

ifdef CXX_CLIENT
# remove C interface of GO client
$(shell rm -rf ./_obj)
$(shell rm -f ./query.h)

# HowardHinnant date library source dir
DATE_LIB = -I./deps/date/include

OBJS += query.o tz.o
PG_CPPFLAGS += -DCXX_CLIENT $(DATE_LIB)
SHLIB_LINK = -lm -lstdc++ -lInfluxDB

# query.cpp requires C++ 17.
override PG_CXXFLAGS += -std=c++17 -O0

# override PG_CXXFLAGS and PG_CFLAGS
ifdef CCFLAGS
	override PG_CXXFLAGS += $(CCFLAGS)
	override PG_CFLAGS += $(CCFLAGS)
endif #!CCFLAGS

else
PG_CPPFLAGS += -DGO_CLIENT
OBJS += query.a
endif #!CXX_CLIENT

EXTENSION = influxdb_fdw
DATA = influxdb_fdw--1.0.sql influxdb_fdw--1.1.sql influxdb_fdw--1.1--1.2.sql influxdb_fdw--1.2.sql influxdb_fdw--1.3.sql

REGRESS = aggregate influxdb_fdw selectfunc extra/join extra/limit extra/aggregates extra/insert extra/prepare extra/select_having extra/select extra/influxdb_fdw_post schemaless/aggregate schemaless/influxdb_fdw schemaless/selectfunc schemaless/schemaless schemaless/extra/join schemaless/extra/limit schemaless/extra/aggregates schemaless/extra/prepare schemaless/extra/select_having schemaless/extra/insert schemaless/extra/select schemaless/extra/influxdb_fdw_post schemaless/add_fields schemaless/add_tags schemaless/add_multi_key

UNAME = uname
OS := $(shell $(UNAME))
ifeq ($(OS), Darwin)
DLSUFFIX = .dylib
else
DLSUFFIX = .so
endif

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
ifndef MAJORVERSION
MAJORVERSION := $(basename $(VERSION))
endif

else
subdir = contrib/influxdb_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
ifndef MAJORVERSION
MAJORVERSION := $(basename $(VERSION))
endif
endif

ifeq (,$(findstring $(MAJORVERSION), 11 12 13 14 15))
$(error PostgreSQL 11, 12, 13, 14 or 15 is required to compile this extension)
endif

ifdef REGRESS_PREFIX
REGRESS_PREFIX_SUB = $(REGRESS_PREFIX)
else
REGRESS_PREFIX_SUB = $(VERSION)
endif

REGRESS := $(addprefix $(REGRESS_PREFIX_SUB)/,$(REGRESS))
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/extra)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/schemaless)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/schemaless/extra)

ifdef GO_CLIENT
query.a: query.go
	go build -buildmode=c-archive query.go
$(OBJS):  _obj/_cgo_export.h
_obj/_cgo_export.h: query.go
	go tool cgo query.go
endif	#!GO_CLIENT

ifdef CXX_CLIENT
# PostgreSQL uses link time optimization option which may break compilation
# (this happens on travis-ci). Redefine COMPILE.cxx.bc without this option.
COMPILE.cxx.bc = $(CLANG) -xc++ -Wno-ignored-attributes $(BITCODE_CXXFLAGS) $(CPPFLAGS) -emit-llvm -c

# A hurdle to use common compiler flags when building bytecode from C++
# files. should be not unnecessary, but src/Makefile.global omits passing those
# flags for an unnknown reason.
%.bc : %.cpp
	$(COMPILE.cxx.bc) $(CXXFLAGS) $(CPPFLAGS)  -o $@ $<

# Using OS timezone data base for date library
DATE_DEF = -DUSE_OS_TZDB
CURL_LIB = -lcurl

tz.o: deps/date/src/tz.cpp
	g++ -fPIC $(PG_CXXFLAGS) $(CXXFLAGS) $(CPPFLAGS) $(DATE_LIB) -I. $(CURL_LIB) $(DATE_DEF) -c $<

.PHONY: clean
clean: deps_clean
# clean deps object
deps_clean:
	rm -f ./tz.o
endif #!CXX_CLIENT
