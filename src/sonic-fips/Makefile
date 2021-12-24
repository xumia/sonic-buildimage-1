.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

include ../../rules/sonic-fips.mk

MAIN_TARGET = $(SYMCRYPT_OPENSSL)

$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :
	for target in $(FIPS_PACKAGE_ALL); do
	  filename=$$(basename $$target)
	  url=$(FIPS_URL_PREFIX)/$$filename
	  mkdir -p "$$(dirname $(DEST)/$$target)"
	  wget -O "$(DEST)/$$target" "$$url"
	done

$(addprefix $(DEST)/, $(FIPS_DERIVED_TARGET)): $(DEST)/% : $(DEST)/$(MAIN_TARGET)
