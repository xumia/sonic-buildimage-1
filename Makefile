# SONiC make file
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

.SECONDEXPANSION:

include rules/common

NOSTRETCH ?= 1

override Q := @
ifeq ($(QUIET),n)
  override Q := 
endif
override SONIC_OVERRIDE_BUILD_VARS += $(SONIC_BUILD_VARS)
override SONIC_OVERRIDE_BUILD_VARS += Q=$(Q)
export Q SONIC_OVERRIDE_BUILD_VARS

$(foreach dist, $(DISTRIBUTIONS), $(eval $(dist)_upper := $(shell echo $(dist) | tr '[:lower:]' '[:upper:]')))
$(foreach dist, $(DISTRIBUTIONS), \
  $(if $(shell echo $($(shell echo NO$(dist) | tr '[:lower:]' '[:upper:]')) | grep -iE "1|y"),, \
    $(eval $(dist)_DEPENDS := $(dist_last)) \
    $(if $(PARALLEL_BUILD_FOR_MUALT_DISTIBUTIONS),, $(eval dist_last := $(dist))) \
    $(eval BUILD_DISTRIBUTIONS += $(dist)) \
))

PLATFORM_PATH := platform/$(if $(PLATFORM),$(PLATFORM),$(CONFIGURED_PLATFORM))
PLATFORM_CHECKOUT := platform/checkout
PLATFORM_CHECKOUT_FILE := $(PLATFORM_CHECKOUT)/$(PLATFORM).ini
PLATFORM_CHECKOUT_CMD := $(shell if [ -f $(PLATFORM_CHECKOUT_FILE) ]; then PLATFORM_PATH=$(PLATFORM_PATH) j2 $(PLATFORM_CHECKOUT)/template.j2 $(PLATFORM_CHECKOUT_FILE); fi)
MAKE_WITH_RETRY := ./scripts/run_with_retry $(MAKE)

#%: $(BUILD_DISTRIBUTIONS)
%::
	@echo "+++ --- Making $@ --- +++t0"
	@echo "+++ --$(BUILD_DISTRIBUTIONS)"
	@if echo "$(BUILD_DISTRIBUTIONS)" | grep -q $(LATEST_DISTRIBUTION); then \
		$(MAKE_WITH_RETRY) BLDENV=$(LATEST_DISTRIBUTION) -f Makefile.work $@; \
	fi
	BLDENV=$(LATEST_DISTRIBUTION) $(MAKE) -f Makefile.work docker-cleanup

$(addprefix target/%, .bin .raw .swi): $(BUILD_DISTRIBUTIONS)
	@if echo "$(BUILD_DISTRIBUTIONS)" | grep -q $(LATEST_DISTRIBUTION); then
		$(MAKE_WITH_RETRY) BLDENV=$(LATEST_DISTRIBUTION) -f Makefile.work $@
	fi
	BLDENV=$(LATEST_DISTRIBUTION) $(MAKE) -f Makefile.work docker-cleanup

$(DISTRIBUTIONS):
	@echo "+++ Making $@ +++t01"
	$(MAKE_WITH_RETRY) BLDENV=$@ -f Makefile.work $@

init:
	@echo "+++ Making $@ +++"
	$(MAKE) -f Makefile.work $@

#
# Function to invoke target $@ in Makefile.work with proper BLDENV
#
define make_work
	@echo "+++ Making $@ +++"
	$(foreach dist, $(DISTRIBUTIONS),$(if $(BUILD_$($(dist)_upper)),BLDENV=$(dist) $(MAKE) -f Makefile.work $@,))
endef

.PHONY: $(PLATFORM_PATH)

$(PLATFORM_PATH):
	@echo "+++ Cheking $@ +++"
	$(PLATFORM_CHECKOUT_CMD)

$(addprefix configure/, $(BUILD_DISTRIBUTIONS)) : configure/% : $(PLATFORM_PATH) # $$(addprefix configure/,$$($$*_DEPENDS))
	echo "+++ Cheking $@ +++t1"
	$(MAKE) BLDENV=$* -f Makefile.work sonic-slave-build

configure: $(addprefix configure/, $(BUILD_DISTRIBUTIONS))
	echo "+++ Make configure"
	@$(MAKE) BLDENV=$(LATEST_DISTRIBUTION) -f Makefile.work configure

clean reset showtag docker-cleanup sonic-slave-build sonic-slave-bash :
	$(call make_work, $@)

# Freeze the versions, see more detail options: scripts/versions_manager.py freeze -h
freeze:
	@scripts/versions_manager.py freeze $(FREEZE_VERSION_OPTIONS)
