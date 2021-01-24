###############################################################################
## Presettings
###############################################################################

# Select bash for commands
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

%::
ifneq ($(PLATFORMS), )
	@echo "Make platforms: $(PLATFORMS) for target $@"
	@unset PLATFORM
	$(eval i=0)
	$(foreach platform,$(PLATFORMS), \
	    { $(eval i=$(shell echo $$(($(i)+1)))) \
        $(eval targets=$(shell echo $(PLATFORM_TARGETS) | sed 's/\s\+/\n/g' | sed "$(i)q;d" | sed 's/,/ /g' )) \
	    echo $(platform) > .platform; \
	    touch -d "2000-01-01" .platform; \
	    make -f slave.mk EXTRA_DOCKER_TARGETS='$(targets)' $@; } ;)
else
	make -f slave.mk $@
endif

multiple_platforms:
	@echo "make platforms: $(PLATFORMS)"
	$(eval i=0)
	$(foreach platform,$(PLATFORMS), \
	    { $(eval i=$(shell echo $$(($(i)+1)))) \
	    $(eval targets=$(shell echo $(PLATFORM_TARGETS) | sed 's/\s\+/\n/g' | sed "$(i)q;d" | sed 's/,/ /g' )) \
	    echo $(platform) > .platform; \
	    touch -d "2000-01-01" .platform; \
	    sudo mount proc /proc -t proc 2>/dev/null || true; \
	    make -f slave.mk $(targets); } ;)
