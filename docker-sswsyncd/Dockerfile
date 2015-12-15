FROM debian:jessie

## Set the apt source
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
## TODO: sswsyncd depends on ifupdown
## TODO: sswsyncd depends on rsyslog
RUN apt-get -y install  \
    libhiredis0.10      \
    libtinyxml2-2       \
    socat               \
    libnl-3-200         \
    libnl-route-3-200   \
    ifupdown            \
    rsyslog

COPY deps /deps
RUN dpkg -i /deps/libopennsl_*.deb
RUN dpkg -i /deps/libsaibcm_*.deb
RUN dpkg -i /deps/libsswsdk_*.deb
RUN dpkg -i /deps/sswsyncd_*.deb

ENTRYPOINT service rsyslog start    \
    && service sswsyncd start       \
    && /bin/bash
