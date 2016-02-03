FROM debian:jessie

## Set the apt source
COPY files/sources.list /etc/sources.list
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
RUN apt-get -y install                  \
    redis-server

ENTRYPOINT service redis-server start   \
    && /bin/bash
