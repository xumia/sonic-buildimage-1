.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

include ../../rules/sonic-fips.mk

BLDENV ?= $(shell lsb_release -cs)
URL_PREFIX = https://sonicstorage.blob.core.windows.net/public/fips/$(BLDENV)/$(FIPS_VERSION)
MAIN_TARGET = $(SYMCRYPT_OPENSSL)
DERIVED_TARGET = $(FIPS_OPENSSH_ALL) \
                 $(FIPS_PYTHON_ALL) \
                 $(FIPS_GOLANG_ALL)
ALL_TARGET = $(MAIN_TARGET) $(DERIVED_TARGET)

$(addprefix $(DEST)/, $(MAIN_TARGET)): $(DEST)/% :
	for target in $(ALL_TARGET); do \
      filename=$$(basename $$target); \
      url=$(URL_PREFIX)/$$filename; \
      wget -O "$(DEST)/$$target" "$$url"; \
    done

$(addprefix $(DEST)/, $(DERIVED_TARGET)): $(DEST)/% : $(DEST)/$(MAIN_TARGET)
