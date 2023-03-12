# SONiC make file
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

LATEST_DISTRIBUTION = bullseye
DISTRIBUTIONS = stretch buster $(LATEST_DISTRIBUTION)

NOSTRETCH ?= 1

override Q := @
ifeq ($(QUIET),n)
  override Q := 
endif
override SONIC_OVERRIDE_BUILD_VARS += $(SONIC_BUILD_VARS)
override SONIC_OVERRIDE_BUILD_VARS += Q=$(Q)
export Q SONIC_OVERRIDE_BUILD_VARS

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

%::
	@echo "+++ --- Making $@ --- +++"
ifeq ($(NOSTRETCH), 0)
	$(MAKE_WITH_RETRY) EXTRA_DOCKER_TARGETS=$(notdir $@) BLDENV=stretch -f Makefile.work stretch
endif
ifeq ($(NOBUSTER), 0)
	$(MAKE_WITH_RETRY) EXTRA_DOCKER_TARGETS=$(notdir $@) BLDENV=buster -f Makefile.work buster
endif
ifeq ($(NOBULLSEYE), 0)
	$(MAKE_WITH_RETRY) BLDENV=bullseye -f Makefile.work $@
endif
	BLDENV=bullseye $(MAKE) -f Makefile.work docker-cleanup

$(DISTRIBUTIONS):
	@echo "+++ Making $@ +++"
	@if echo "$(BUILD_DISTRIBUTIONS)" | grep -q $@; then
		echo "+++ Making $@ +++"
		$(MAKE) -f Makefile.work $@
	fi

init:
	@echo "+++ Making $@ +++"
	$(MAKE) -f Makefile.work $@

#
# Function to invoke target $@ in Makefile.work with proper BLDENV
#
define make_work
	@echo "+++ Making $@ +++"
	$(if $(BUILD_JESSIE),$(MAKE) -f Makefile.work $@,)
	$(if $(BUILD_STRETCH),BLDENV=stretch $(MAKE) -f Makefile.work $@,)
	$(if $(BUILD_BUSTER),BLDENV=buster $(MAKE) -f Makefile.work $@,)
	$(if $(BUILD_BULLSEYE),BLDENV=bullseye $(MAKE) -f Makefile.work $@,)
endef

.PHONY: $(PLATFORM_PATH)

$(PLATFORM_PATH):
	@echo "+++ Cheking $@ +++"
	$(PLATFORM_CHECKOUT_CMD)

$(addprefix configure/, $(BUILD_DISTRIBUTIONS)) : configure/% : $(PLATFORM_PATH) $$(addprefix configure/,$$($$*_DEPENDS))
	$(MAKE) -f Makefile.work $@

configure : $(addprefix configure/, $(BUILD_DISTRIBUTIONS))

clean reset showtag docker-cleanup sonic-slave-build sonic-slave-bash :
	$(call make_work, $@)

# Freeze the versions, see more detail options: scripts/versions_manager.py freeze -h
freeze:
	@scripts/versions_manager.py freeze $(FREEZE_VERSION_OPTIONS)
