SRCDIR:=$(shell pwd)/
BUILDDIR:=$(shell pwd)/

LLVM_URL=https://github.com/llvm/llvm-project.git
LLVM_REV=df1a53ae242418f5ac22adb5bb2178d3f931565f
LLVM_SRCDIR=$(BUILDDIR)llvm-project/
LLVM_BUILDDIR=$(BUILDDIR)llvm-project-build/

TESTS_URL=https://github.com/llvm/llvm-test-suite.git
TESTS_REV=27d20d98b98db45217ec9a81d5b09c91d6f4370e
TESTS_SRCDIR=llvm-test-suite/
TESTS_BUILDDIR=llvm-test-suite-build/
TESTS_CONFIGS=fast basic greedy pbqp
CONFIGURE_TESTS=$(TESTS_CONFIGS:%=configure-tests-%)
BUILD_TESTS=$(TESTS_CONFIGS:%=build-tests-%)
RUN_TESTS=$(TESTS_CONFIGS:%=results-tests-%.json)

.PHONY: all clean distclean

all: run-tests

clean:
	rm -f \
		checkout-llvm checkout-tests \
		configure-llvm $(CONFIGURE_TESTS) \
		build-llvm $(BUILD_TESTS)

distclean:
	rm -rf $(LLVM_SRCDIR) $(LLVM_BUILDDIR) $(TESTS_SRCDIR) $(TESTS_BUILDDIR)

%/:
	mkdir -p $(@)

checkout-llvm:
	git clone --revision=$(LLVM_REV) $(LLVM_URL) $(LLVM_SRCDIR) || \
	( \
		git clone --depth=1 $(LLVM_URL) $(LLVM_SRCDIR) && \
		git -C $(LLVM_SRCDIR) fetch --depth=1 origin $(LLVM_REV) && \
		git -C $(LLVM_SRCDIR) checkout $(LLVM_REV) \
	)
	touch $(@)

configure-llvm: checkout-llvm | $(LLVM_BUILDDIR)
	cmake \
		-G Ninja \
		-DCMAKE_LINKER_TYPE=MOLD \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_ENABLE_ASSERTIONS=ON \
		-DLLVM_FORCE_ENABLE_STATS=ON \
		-DLLVM_ENABLE_PROJECTS=clang \
		-DLLVM_ENABLE_RUNTIMES=all \
		-S $(LLVM_SRCDIR)llvm \
		-B $(LLVM_BUILDDIR)
	touch $(@)

build-llvm: configure-llvm
	ninja -C $(LLVM_BUILDDIR) -j1
	touch $(@)

checkout-tests:
	git clone --revision=$(TESTS_REV) $(TESTS_URL) $(TESTS_SRCDIR) || \
	( \
		git clone --depth=1 $(TESTS_URL) $(TESTS_SRCDIR) && \
		git -C $(TESTS_SRCDIR) fetch --depth=1 origin $(TESTS_REV) && \
		git -C $(TESTS_SRCDIR) checkout $(TESTS_REV) \
	)
	touch $(@)

.PHONY: configure-tests build-tests run-tests

configure-tests: $(CONFIGURE_TESTS)
build-tests: $(BUILD_TESTS)
run-tests: $(RUN_TESTS)

$(CONFIGURE_TESTS): configure-tests-%: build-llvm checkout-tests | $(TESTS_BUILDDIR)%/
	cmake \
		-G Ninja \
		-DCMAKE_C_COMPILER=$(LLVM_BUILDDIR)bin/clang \
		-DTEST_SUITE_COLLECT_STATS=ON \
		-DTEST_SUITE_BENCHMARKING_ONLY=ON \
		-C $(SRCDIR)cmake/caches/Release-$(@:configure-tests-%=%).cmake \
		-S $(TESTS_SRCDIR) \
		-B $(TESTS_BUILDDIR)$(@:configure-tests-%=%)/
	touch $(@)

$(BUILD_TESTS): build-tests-%: configure-tests-%
	ninja -C $(TESTS_BUILDDIR)$(@:build-tests-%=%)/
	touch $(@)

$(RUN_TESTS): results-tests-%.json: build-tests-%
	$(LLVM_BUILDDIR)bin/llvm-lit -v -j 1 --ignore-fail -o $(@) $(TESTS_BUILDDIR)$(@:results-tests-%.json=%)/
