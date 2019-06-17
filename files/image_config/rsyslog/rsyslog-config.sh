#!/bin/bash

sonic-cfggen -s /var/run/redis$1/redis.sock -d -t /usr/share/sonic/templates/rsyslog.conf.j2 >/etc/rsyslog$1.conf
systemctl restart rsyslog
