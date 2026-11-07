-include local.mk

PYTHON    ?= python3
CIRCT_BIN ?=
Z3_LIB    ?=

.PHONY: check check-case cex list clean

check:
	$(PYTHON) scripts/check.py --circt-bin "$(CIRCT_BIN)" --z3-lib "$(Z3_LIB)"

check-case:
	@test -n "$(CASE)" || (echo "usage: make check-case CASE=<name>"; exit 1)
	$(PYTHON) scripts/check.py --case "$(CASE)" --circt-bin "$(CIRCT_BIN)" --z3-lib "$(Z3_LIB)"

cex:
	@test -n "$(CASE)" || (echo "usage: make cex CASE=<name>"; exit 1)
	$(PYTHON) scripts/check.py --case "$(CASE)" --show-cex --circt-bin "$(CIRCT_BIN)" --z3-lib "$(Z3_LIB)"

list:
	$(PYTHON) scripts/check.py --list

clean:
	rm -rf build
