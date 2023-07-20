TOPNAME 		:= compiler
BUILD_DIR 		:= build
BINARY 			:= $(BUILD_DIR)/$(TOPNAME)
SINGLE_TEST		:= main

# base dev
CMAKE 			:= cmake
GDB 			:= gdb
DIFF 			:= diff
ECHO			:= echo
TMP				:= /tmp


# llvm toolchain
LLDB 			:= lldb
LLLD 			:= llvm-link
LLI 			:= lli
FORMATTER		:= clang-format
CLANG			:= $(shell which clang)
CLANGXX			:= $(shell which clang++)


# make build dir
$(shell mkdir -p $(BUILD_DIR))


OS				:= $(shell uname)
NPROC			:= $(shell nproc)
ANTLR_SRC		:= $(shell find antlr -name '*.cpp' -or -name '*.h')
PROJECT_SRC		:= $(shell find 3tle3wa -name '*.cpp' -or -name '*.hh')
ALL_SRC			:= ${ANTLR_SRC} ${PROJECT_SRC}


release: $(ALL_SRC)
	$(CMAKE) -S . -B $(BUILD_DIR)
	$(MAKE) -C $(BUILD_DIR) -j$(NPROC) -s

CMAKE_BUILD_ENV	:= -DCMAKE_C_COMPILER:FILEPATH=$(CLANG) -DCMAKE_CXX_COMPILER:FILEPATH=$(CLANGXX)

debug: $(ALL_SRC)
	$(CMAKE) -DCMAKE_BUILD_TYPE="Debug" $(CMAKE_BUILD_ENV) -S . -B $(BUILD_DIR)
	$(MAKE) -C $(BUILD_DIR) -j$(NPROC) -s

.PHONY: build
build: release

.PHONY: clean
clean:
	-@rm -rf $(BUILD_DIR)

.PHONY: clean-test
clean-test:
	-@rm -rf $(OUTPUT_ASM) $(OUTPUT_LOG) $(OUTPUT_RES) $(OUTPUT_IR)

.PHONY: clean-all
clean-all: clean clean-test clean-s

# make formatter fake targets
FORMAT			:= format
FORMAT_TARGETS	:= $(addprefix $(FORMAT)/,$(PROJECT_SRC))

$(FORMAT_TARGETS): $(FORMAT)/%:%
	$(FORMATTER) $^ -i
 
.PHONY: format-all
format-all: $(FORMAT_TARGETS)