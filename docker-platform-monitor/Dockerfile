FROM docker-base

## Pre-install the fundamental packages
RUN apt-get update && apt-get -y install    \
    smartmontools                           \
    sensord

# Change defaults for sensord. Don't spam log with sensors values - set logging interval to 0
RUN sed -i /etc/default/sensord -e 's/# LOG_INTERVAL=30m/LOG_INTERVAL=0/'

## Clean up
RUN apt-get clean -y; apt-get autoclean -y; apt-get autoremove -y
RUN rm -rf /deps

ENTRYPOINT service rsyslog start    \
    && service lm-sensors start     \
    && service smartmontools start  \
    && service sensord start        \
    && /bin/bash
