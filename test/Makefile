
GEN_FILES = $(wildcard *gen*.py)

test: build_test
	python run_tests.py

build_test: $(GEN_FILES)
	python generate_tests.py



