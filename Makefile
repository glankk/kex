SRCDIR := $(shell pwd)/

LLVM_URL=git@github.com:llvm/llvm-project.git
LLVM_REV=e0182ebd4
LLVM_SRCDIR=$(SRCDIR)llvm-project/
LLVM_BUILDDIR=$(SRCDIR)llvm-project-build/

TESTS_URL=git@github.com:llvm/llvm-test-suite.git
TESTS_REV=0007314
TESTS_SRCDIR=$(SRCDIR)llvm-test-suite/
TESTS_BUILDDIR=$(SRCDIR)llvm-test-suite-build/

.PHONY: all

all: build-tests

%/:
	mkdir -p $(@)

checkout-llvm:
	git clone --revision=$(LLVM_REV) $(LLVM_URL) $(LLVM_SRCDIR)
	touch $(@)

configure-llvm: checkout-llvm | $(LLVM_BUILDDIR)
	cmake \
		-G Ninja \
		-DCMAKE_LINKER_TYPE=MOLD \
		-DCMAKE_BUILD_TYPE=Debug \
		-DLLVM_ENABLE_ASSERTIONS=ON \
		-DLLVM_FORCE_ENABLE_STATS=ON \
		-DLLVM_ENABLE_PROJECTS=clang \
		-S $(LLVM_SRCDIR)llvm \
		-B $(LLVM_BUILDDIR)
	touch $(@)

build-llvm: configure-llvm
	ninja -C $(LLVM_BUILDDIR) -j1
	touch $(@)

checkout-tests:
	git clone --revision=$(TESTS_REV) $(TESTS_URL) $(TESTS_SRCDIR)
	touch $(@)

configure-tests: build-llvm checkout-tests | $(TESTS_BUILDDIR)
	cmake \
		-G Ninja \
		-DCMAKE_C_COMPILER=$(LLVM_BUILDDIR)bin/clang \
		-C $(TESTS_SRCDIR)cmake/caches/O3.cmake \
		-S $(TESTS_SRCDIR) \
		-B $(TESTS_BUILDDIR)
	touch $(@)

build-tests: configure-tests
	ninja -C $(TESTS_BUILDDIR) -j1
	touch $(@)
