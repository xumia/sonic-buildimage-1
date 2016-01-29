FROM debian:jessie

MAINTAINER Pavel Shirshov

## Set the apt source, update package cache and install necessary packages
RUN echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get upgrade -y  \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        vim-tiny \
        python \
        python-scapy \
        net-tools \
        python-setuptools \
        supervisor \
        traceroute \
        lsof \
        tcpdump \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd \
 && echo 'root:root' | chpasswd \
 && sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -i '$aUseDNS no' /etc/ssh/sshd_config \
 && mkdir /root/deps

EXPOSE 22

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deps /root/deps
RUN dpkg -i /root/deps/python-ptf*.deb

ENTRYPOINT ["/usr/bin/supervisord"]
