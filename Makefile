include make/ocaml/main.mk

run: 
	make build || exit 1
	./_build/default/bin/main.exe "$$(which steam)" "$$(which tshark)"
