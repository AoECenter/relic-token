include make/ocaml/main.mk

STEAM_BIN ?= $(shell which steam)
TSHARK_BIN ?= $(shell which tshark)
PCAPNG ?= ./relic-token.pcapng
SSLKEYLOGFILE ?= ./relic-token.sslkeylog

.PHONY: run
run: 
	make build || exit 1
	rm -rf "$(PCAPNG)" "$(SSLKEYLOGFILE)"
	touch "$(PCAPNG)" "$(SSLKEYLOGFILE)"
	chmod 666 "$(PCAPNG)" "$(SSLKEYLOGFILE)"
	./_build/default/bin/main.exe "$(SSLKEYLOGFILE)" "$(PCAPNG)" "$(STEAM_BIN)" "$(TSHARK_BIN)"
