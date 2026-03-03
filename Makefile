SRCDIR := $(shell pwd)/

LLVM_URL=git@github.com:llvm/llvm-project.git
LLVM_REV=df1a53ae242418f5ac22adb5bb2178d3f931565f
LLVM_SRCDIR=$(SRCDIR)llvm-project/
LLVM_BUILDDIR=$(SRCDIR)llvm-project-build/

TESTS_URL=git@github.com:llvm/llvm-test-suite.git
TESTS_REV=27d20d98b98db45217ec9a81d5b09c91d6f4370e
TESTS_SRCDIR=$(SRCDIR)llvm-test-suite/
TESTS_BUILDDIR=$(SRCDIR)llvm-test-suite-build/

.PHONY: all clean distclean

all: build-tests

clean:
	rm -f checkout-llvm configure-llvm build-llvm checkout-tests configure-tests-greedy build-tests-greedy

distclean:
	rm -rf $(LLVM_SRCDIR) $(LLVM_BUILDDIR) $(TESTS_SRCDIR) $(TESTS_BUILDDIR)

%/:
	mkdir -p $(@)

checkout-llvm:
	git clone --revision=$(LLVM_REV) $(LLVM_URL) $(LLVM_SRCDIR)
	touch $(@)

configure-llvm: checkout-llvm | $(LLVM_BUILDDIR)
	cmake \
		-G Ninja \
		-DCMAKE_LINKER_TYPE=MOLD \
		-DCMAKE_BUILD_TYPE=Release \
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

.PHONY: build-tests

build-tests: build-tests-greedy

.NOTINTERMEDIATE: configure-tests-% build-tests-%

configure-tests-%: build-llvm checkout-tests | $(TESTS_BUILDDIR)%/
	cmake \
		-G Ninja \
		-DCMAKE_C_COMPILER=$(LLVM_BUILDDIR)bin/clang \
		-DTEST_SUITE_COLLECT_STATS=ON \
		-DTEST_SUITE_BENCHMARKING_ONLY=ON \
		-C $(TESTS_SRCDIR)cmake/caches/O3.cmake \
		-C $(SRCDIR)cmake/caches/tests/$(@:configure-tests-%=%).cmake \
		-S $(TESTS_SRCDIR) \
		-B $(TESTS_BUILDDIR)$(@:configure-tests-%=%)/
	touch $(@)

build-tests-%: configure-tests-%
	ninja -C $(TESTS_BUILDDIR)$(@:build-tests-%=%)/
	touch $(@)
