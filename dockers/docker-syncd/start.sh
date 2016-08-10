#!/bin/bash

[ -a /var/run/rsyslog.d ] && rm /var/run/rsyslog.d

service rsyslog start
service syncd start
