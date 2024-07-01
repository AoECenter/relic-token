.PHONY: unit-test
unit-test:
	test -d tests/unit || exit 0
	dune runtest tests/unit --root $$(pwd) --instrument-with bisect_ppx --force

.PHONY: integration-test
integration-test:
	test -d tests/integration || exit 0
	dune runtest tests/integration --root $$(pwd) --instrument-with bisect_ppx --force

test:
	find . -name '*.coverage' | xargs rm -f
	make integration-test || exit 1
	make unit-test || exit 1
	bisect-ppx-report merge combined.coverage _build/default/tests/**/*.coverage 
	bisect-ppx-report html combined.coverage
	bisect-ppx-report summary combined.coverage
