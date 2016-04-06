FROM docker-base

## Pre-install the fundamental packages
RUN apt-get update && apt-get -y install    \
    redis-server

## Clean up
RUN apt-get clean -y; apt-get autoclean -y; apt-get autoremove -y
RUN rm -rf /deps

ENTRYPOINT service rsyslog start    \
    && service redis-server start   \
    && /bin/bash
