FROM debian:jessie

## Set the apt source
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list
RUN apt-get clean && apt-get update

COPY deps /deps
RUN dpkg -i /deps/quagga_*.deb;         \
    apt-get -y install -f
    
ENTRYPOINT    \
    && /bin/bash
