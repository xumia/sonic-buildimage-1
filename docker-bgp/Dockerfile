FROM debian:jessie

## Set the apt source
COPY files/sources.list /etc/sources.list
RUN apt-get clean && apt-get update

COPY deps /deps
RUN dpkg -i /deps/quagga_*.deb;         \
    apt-get -y install -f
