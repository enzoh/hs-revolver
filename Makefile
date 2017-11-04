# File       : Makefile
# Copyright  : Copyright (c) 2017 DFINITY Stiftung. All rights reserved.
# License    : GPL-3
# Maintainer : Enzo Haussecker <enzo@dfinity.org>
# Stability  : Experimental

LIB_DIR = lib
OBJ_DIR = obj

CFLAGS  = -I$(PWD)/include
LDFLAGS = -L$(PWD)/lib -lpreambles

PREFIX  = /usr/local

.PHONY: all
all: $(LIB_DIR)/librevolver.a

$(LIB_DIR)/librevolver.a: gbits/hs-revolver.go | $(LIB_DIR)/libpreambles.a
	CGO_CFLAGS='$(CFLAGS)' CGO_LDFLAGS='$(LDFLAGS)' go build -buildmode c-archive -o $@ -race $<

$(LIB_DIR)/libpreambles.a: $(OBJ_DIR)/hs-revolver.o | $(LIB_DIR)
	ar cr $@ $<

$(LIB_DIR):
	mkdir -p $@

$(OBJ_DIR)/hs-revolver.o: cbits/hs-revolver.c | $(OBJ_DIR)
	gcc $(CFLAGS) -c -o $@ $<

$(OBJ_DIR):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(LIB_DIR)
	rm -rf $(OBJ_DIR)

.PHONY: install
install: $(LIB_DIR)/librevolver.a
	cp include/hs-revolver.h $(PREFIX)/include
	cp $(LIB_DIR)/librevolver.a $(PREFIX)/lib

.PHONY: uninstall
uninstall:
	rm -f $(PREFIX)/include/hs-revolver.h
	rm -f $(PREFIX)/lib/librevolver.a
