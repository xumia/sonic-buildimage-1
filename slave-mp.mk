###############################################################################
## Presettings
###############################################################################

# Select bash for commands
.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

define prepare_make_platform
$(eval i=$(shell echo $$(($(i)+1)))) \
$(eval targets=$(shell echo $(PLATFORM_TARGETS) | sed 's/\s\+/\n/g' | sed "$(i)q;d" | sed 's/,/ /g' )) \
echo $(platform) > .platform; \
touch -d "2000-01-01" .platform; \
package=$$(dpkg -S /usr/lib/libsai.so | cut -d: -f1); \
header_package=$$(dpkg -S /usr/include/sai/sai.h | cut -d: -f1); \
echo "package=$$package" >> test.log; \
[ -e /usr/lob/libsai.so ] && echo "0 libsai.so exist" >> test.log; \
[ ! -z "$$package" ] && sudo apt-get purge -y $$package; \
[ ! -z "$$header_package" ] && sudo apt-get purge -y $$header_package; \
[ -e /usr/lib/libsai.so ] && echo "1 libsai.so exist" >> test.log; \
package1=$$(dpkg -S /usr/lib/libsai.so | cut -d: -f1); \
echo "package=$$package; package1=$$package1" >> test.log;
endef

%::
ifneq ($(PLATFORMS), )
	@echo "Make platforms: $(PLATFORMS) for target $@"
	$(eval i=0)
	$(foreach platform,$(PLATFORMS), \
		{ $(prepare_make_platform) \
		  make -f slave.mk EXTRA_DOCKER_TARGETS='$(targets)' $@; } ;)
else
	make -f slave.mk $@
endif

multiple_platforms:
	@echo "make $@: $(PLATFORMS)"
	$(eval i=0)
	$(foreach platform,$(PLATFORMS), \
		{ $(prepare_make_platform) \
		  sudo mount proc /proc -t proc 2>/dev/null || true; \
		  make -f slave.mk $(targets); } ;)
