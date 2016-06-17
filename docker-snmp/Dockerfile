FROM docker-base

COPY deps/python-sswsdk_*.deb deps/acs-snmp-subagent_*.deb deps/snmp_*.deb deps/snmpd_*.deb /deps/

## Pre-install the fundamental packages
## Install Python SSWSDK (SNMP subagent dependancy)
## Install SNMP subagent
## Note: dpkg_apt function has the benefit to detect missing .deb file
## Clean up
RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; } &&        \
    dpkg_apt /deps/libsnmp-base_*.deb &&                                                                \
    dpkg_apt /deps/libsnmp30_*.deb &&                                                                \
    dpkg_apt /deps/snmp_*.deb &&                                                                \
	dpkg_apt /deps/snmpd_*.deb &&                                                               \
    dpkg_apt /deps/python-sswsdk_*.deb &&                                                       \
    dpkg_apt /deps/acs-snmp-subagent_*.deb &&                                                   \
    apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y &&                        \
    rm -rf /deps

## There is a known bug: agetty processes at 100% cpu
## When:
##   1. running container in --privileged mode
##   2. container runs /sbin/init
## ref: https://github.com/docker/docker/issues/4040
## Temporary solution:
##   Disable tty services permanently
RUN systemctl --no-pager list-unit-files --type=service | grep getty | awk '{print $1}' | xargs systemctl mask
## Note: getty@.service in last grep output will not mask below cases
RUN systemctl mask getty@tty1.service

## Although exposing ports is not need for host net mode, keep it for possible bridge mode
EXPOSE 161/udp 162/udp

## Specify init as CMD to enable systemd
## Note: don't provide ENTRYPOINT at the same time
CMD ["/sbin/init"]
