srcdir		= .
MKDIR_P		= mkdir -p
LLVM_URL	= https://github.com/llvm/llvm-project.git
LLVM_REV	= df1a53ae242418f5ac22adb5bb2178d3f931565f
TESTS_URL	= https://github.com/llvm/llvm-test-suite.git
TESTS_REV	= 27d20d98b98db45217ec9a81d5b09c91d6f4370e
TEST_CONFIGS	= fast basic greedy pbqp
CONFIGURE_TESTS	= $(TEST_CONFIGS:%=configure-tests-%)
BUILD_TESTS	= $(TEST_CONFIGS:%=build-tests-%)
TEST_RESULTS	= $(TEST_CONFIGS:%=out/results-%.json)

.PHONY: all clean distclean

all: results

clean:
	rm -rf out

distclean:
	rm -f checkout-llvm checkout-tests \
		configure-llvm $(CONFIGURE_TESTS) \
		build-llvm $(BUILD_TESTS)
	rm -rf llvm-project llvm-test-suite build

%/:
	$(MKDIR_P) $(@)

checkout-llvm:
	git clone --revision=$(LLVM_REV) $(LLVM_URL) llvm-project || \
	( \
		git clone --depth=1 $(LLVM_URL) llvm-project && \
		git -C llvm-project fetch --depth=1 origin $(LLVM_REV) && \
		git -C llvm-project checkout $(LLVM_REV) \
	)
	touch $(@)

configure-llvm: checkout-llvm | build/llvm/
	cmake \
		-G Ninja \
		-DCMAKE_LINKER_TYPE=MOLD \
		-DCMAKE_BUILD_TYPE=Release \
		-DLLVM_ENABLE_ASSERTIONS=ON \
		-DLLVM_FORCE_ENABLE_STATS=ON \
		-DLLVM_ENABLE_PROJECTS=clang \
		-DLLVM_ENABLE_RUNTIMES=all \
		-S llvm-project/llvm \
		-B build/llvm
	touch $(@)

build-llvm: configure-llvm
	ninja -C build/llvm -j1
	touch $(@)

checkout-tests:
	git clone --revision=$(TESTS_REV) $(TESTS_URL) llvm-test-suite || \
	( \
		git clone --depth=1 $(TESTS_URL) llvm-test-suite && \
		git -C llvm-test-suite fetch --depth=1 origin $(TESTS_REV) && \
		git -C llvm-test-suite checkout $(TESTS_REV) \
	)
	touch $(@)

.PHONY: configure-tests build-tests run-tests

configure-tests: $(CONFIGURE_TESTS)
build-tests: $(BUILD_TESTS)
run-tests: $(TEST_RESULTS)

$(CONFIGURE_TESTS): configure-tests-%: build-llvm checkout-tests | build/tests/%/
	cmake \
		-G Ninja \
		-DCMAKE_C_COMPILER="$${PWD}"/build/llvm/bin/clang \
		-DTEST_SUITE_COLLECT_STATS=ON \
		-DTEST_SUITE_BENCHMARKING_ONLY=ON \
		-C "$(srcdir)"/cmake/caches/Release-$(@:configure-tests-%=%).cmake \
		-S llvm-test-suite \
		-B build/tests/$(@:configure-tests-%=%)
	touch $(@)

$(BUILD_TESTS): build-tests-%: configure-tests-%
	ninja -C build/tests/$(@:build-tests-%=%)
	touch $(@)

$(TEST_RESULTS): out/results-%.json: build-tests-% | out/
	build/llvm/bin/llvm-lit -v -j 1 --ignore-fail -o $(@) build/tests/$(@:out/results-%.json=%)

.PHONY: results

results: out/results.json

out/results.json: $(TEST_RESULTS) | out/
	jq -n -f "$(srcdir)"/results-filter.jq $(^) --args $(^:out/results-%.json=%) >$(@)
