PREFIX ?= /usr/local/bin
BIN_DIR = bin
TARGET = $(BIN_DIR)/richcopy

.PHONY: all build install link test clean

all: build

build:
	@mkdir -p $(BIN_DIR)
	swiftc -O -o $(TARGET) main.swift

link: build
	@mkdir -p $(PREFIX)
	ln -sf $(CURDIR)/$(TARGET) $(PREFIX)/richcopy
	@echo "Linked $(PREFIX)/richcopy -> $(CURDIR)/$(TARGET)"

install: build
	@mkdir -p $(PREFIX)
	cp $(TARGET) $(PREFIX)/richcopy
	@echo "Installed $(TARGET) to $(PREFIX)/richcopy"

test: build
	@swift Tests/RichcopyTests.swift

clean:
	rm -rf $(BIN_DIR)
