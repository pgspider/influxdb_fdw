######################################################################-------------------------------------------------------------------------
#
# InfluxDB Foreign Data Wrapper for PostgreSQL
#
# Portions Copyright (c) 2018-2021, TOSHIBA CORPORATION
#
# IDENTIFICATION
# 		Makefile
#
##########################################################################

MODULE_big = influxdb_fdw
OBJS = option.o deparse.o influxdb_query.o influxdb_fdw.o query.a

EXTENSION = influxdb_fdw
DATA = influxdb_fdw--1.0.sql influxdb_fdw--1.1.sql influxdb_fdw--1.1--1.2.sql influxdb_fdw--1.2.sql influxdb_fdw--1.3.sql

REGRESS = aggregate influxdb_fdw selectfunc extra/join extra/limit extra/aggregates extra/insert extra/prepare extra/select_having extra/select extra/influxdb_fdw_post

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

ifeq (,$(findstring $(MAJORVERSION), 10 11 12 13 14))
$(error PostgreSQL 10, 11, 12, 13 or 14 is required to compile this extension)
endif

ifdef REGRESS_PREFIX
REGRESS_PREFIX_SUB = $(REGRESS_PREFIX)
else
REGRESS_PREFIX_SUB = $(VERSION)
endif

REGRESS := $(addprefix $(REGRESS_PREFIX_SUB)/,$(REGRESS))
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/extra)

query.a: query.go
	go build -buildmode=c-archive query.go
$(OBJS):  _obj/_cgo_export.h
_obj/_cgo_export.h: query.go
	go tool cgo query.go
