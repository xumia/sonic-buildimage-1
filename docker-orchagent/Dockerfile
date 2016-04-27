FROM docker-base

COPY deps /deps

RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; }; dpkg_apt /deps/libhiredis0.13*.deb
RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; }; dpkg_apt /deps/libswsscommon_*.deb
RUN dpkg_apt() { [ -f $1 ] && { dpkg -i $1 || apt-get -y install -f; } || return 1; }; dpkg_apt /deps/libsairedis_*.deb

RUN apt-get update && apt-get install -f -y libnl-3-200 libnl-route-3-200 libnl-genl-3-200 ifupdown

## Copy executable binaries
COPY ["/deps/orchagent","/deps/swssconfig","/deps/portsyncd","/deps/intfsyncd","/deps/neighsyncd","/usr/local/bin/"]

## Clean up
RUN apt-get clean -y; apt-get autoclean -y; apt-get autoremove -y
RUN rm -rf /deps

ENTRYPOINT service rsyslog start    \
    && /bin/bash
