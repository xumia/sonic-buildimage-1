FROM debian:jessie

## Set the apt source
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
RUN apt-get -y install  \
    module-init-tools   \
    libhiredis0.10      \
    libtinyxml2-2       \
    redis-server        \
    socat               \
    libnl-3-200         \
    libnl-route-3-200

COPY deps /deps
RUN dpkg -i /deps/linux-image-*.deb
RUN dpkg -i /deps/opennsl-modules-*.deb
RUN dpkg -i /deps/libopennsl_*.deb
RUN dpkg -i /deps/libsaibcm_*.deb
RUN dpkg -i /deps/libsswsdk_*.deb
RUN dpkg -i /deps/sswsyncd_*.deb
