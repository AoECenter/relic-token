.PHONY: watch
build: $(BUILD_DEPS)
	dune build -j 7

.PHONY: watch
watch: $(BUILD_DEPS)
	dune build -w
