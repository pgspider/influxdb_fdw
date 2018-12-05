######################################################################-------------------------------------------------------------------------
#
# InfluxDB Foreign Data Wrapper for PostgreSQL
#
# Portions Copyright (c) 2018, TOSHIBA CORPORATION
#
# IDENTIFICATION
# 		Makefile
#
##########################################################################

MODULE_big = influxdb_fdw
OBJS = option.o deparse.o influxdb_query.o influxdb_fdw.o query.a

EXTENSION = influxdb_fdw
DATA = influxdb_fdw--1.0.sql

REGRESS = influxdb_fdw

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
ifeq (,$(findstring $(MAJORVERSION), 9.6 10 11))
$(error PostgreSQL 9.6, 10 or 11 is required to compile this extension)
endif

else
subdir = contrib/influxdb_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

query.a: query.go
	go build -buildmode=c-archive query.go
$(OBJS):  _obj/_cgo_export.h
_obj/_cgo_export.h: query.go
	go tool cgo query.go