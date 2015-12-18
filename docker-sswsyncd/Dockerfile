FROM debian:jessie

## Set the apt source
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
## TODO: sswsyncd depends on ifupdown
## TODO: sswsyncd depends on rsyslog
RUN apt-get -y install  \
    ifupdown            \
    rsyslog

COPY deps /deps
RUN dpkg -i /deps/libopennsl_*.deb;         \
    dpkg -i /deps/libsaibcm_*.deb;          \
    dpkg -i /deps/libsswsdk_*.deb;          \
    dpkg -i /deps/sswsyncd_*.deb;           \
    apt-get -y install -f

ENTRYPOINT service rsyslog start    \
    && service sswsyncd start       \
    && /bin/bash
