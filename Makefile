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
OBJS = option.o slvars.o deparse.o influxdb_query.o influxdb_fdw.o query.a

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

query.a: query.go
	go build -buildmode=c-archive query.go
$(OBJS):  _obj/_cgo_export.h
_obj/_cgo_export.h: query.go
	go tool cgo query.go
