FROM debian:jessie

## Set the apt source
COPY files/sources.list /etc/sources.list
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
RUN apt-get update && apt-get -y install                  \
    rsyslog                             \
    lldpd

COPY deps /deps

## Install Python SSWSDK (lldpsyncd dependancy)
## Note: dpkg_apt function has the benefit to detect missing .deb file
RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; }; dpkg_apt /deps/python-sswsdk_*.deb
## Install LLDP Sync Daemon
## Note: dpkg_apt function has the benefit to detect missing .deb file
RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; }; dpkg_apt /deps/lldpsyncd_*.deb

## There is a known bug: agetty processes at 100% cpu
## When:
##   1. running container in --privileged mode
##   2. container runs /sbin/init
## ref: https://github.com/docker/docker/issues/4040
## Temporary solution:
##   Disable tty services permanently
RUN systemctl mask getty-static.service getty@tty1.service getty@tty2.service getty@tty3.service getty@tty4.service getty@tty5.service getty@tty6.service serial-getty@ttyS0.service

## Specify init as CMD to enable systemd
## Note: don't provide ENTRYPOINT at the same time
CMD ["/sbin/init"]
