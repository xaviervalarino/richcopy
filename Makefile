PREFIX ?= /usr/local/bin
BIN_DIR = bin
TARGET = $(BIN_DIR)/richcopy

# Command Line Tools (no full Xcode) ship the Swift Testing macro plugin at a
# path the build system does not search by default; pass it explicitly there.
CLT_TESTING_PLUGINS = /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
SWIFT_TEST_FLAGS = $(shell test -d $(CLT_TESTING_PLUGINS) && echo -Xswiftc -plugin-path -Xswiftc $(CLT_TESTING_PLUGINS))

.PHONY: all build install link test clean

all: build

build:
	swift build -c release
	@mkdir -p $(BIN_DIR)
	cp "$$(swift build -c release --show-bin-path)/richcopy" $(TARGET)

link: build
	@mkdir -p $(PREFIX)
	ln -sf $(CURDIR)/$(TARGET) $(PREFIX)/richcopy
	@echo "Linked $(PREFIX)/richcopy -> $(CURDIR)/$(TARGET)"

install: build
	@mkdir -p $(PREFIX)
	cp $(TARGET) $(PREFIX)/richcopy
	@echo "Installed $(TARGET) to $(PREFIX)/richcopy"

test:
	swift test $(SWIFT_TEST_FLAGS)

clean:
	swift package clean
	rm -rf $(BIN_DIR)
