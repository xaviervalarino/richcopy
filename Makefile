PREFIX ?= $(HOME)/scripts
BIN = $(PREFIX)/richcopy

.PHONY: all build install test clean

all: install

build:
	@mkdir -p bin
	swiftc -O -o bin/richcopy main.swift

install:
	@mkdir -p $(PREFIX)
	swiftc -O -o $(BIN) main.swift
	@echo "Installed richcopy to $(BIN)"

test: install
	@$(BIN) --test

clean:
	rm -rf bin
