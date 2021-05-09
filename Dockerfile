FROM ubuntu:groovy
LABEL maintainer="https://github.com/elgeeko1"

USER root

EXPOSE 137/udp
EXPOSE 138/udp
EXPOSE 139/tcp
EXPOSE 445/tcp

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ARG DEBIAN_FRONTEND=noninteractive
ENV DISPLAY localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& ln -sf /bin/true /sbin/initctl \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# install samba: samba samba-common samba-client samba-vfs-modules
# install elasticsearch: fscrawner elasticsearch
RUN apt-get update -q \
  && apt-get install --upgrade --no-install-recommends -y -q -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" \
       samba samba-common samba-client samba-vfs-modules \
  && apt-get -q -y autoremove \
  && apt-get -q -y clean \
	&& rm -rf /var/lib/apt/lists/*

# create default configuration
RUN mkdir -p /opt/samba
RUN mkdir -p /opt/samba/shares
RUN mkdir -p /opt/samba/shares/public && chmod 0666 /opt/samba/shares/public
COPY app/smb.conf /etc/samba/smb.conf
COPY app/smb-global.conf /opt/samba/
COPY app/smb-shares.conf /opt/samba/
COPY app/smb-users /opt/samba/

# entrypoint
WORKDIR /opt/samba/shares
COPY app/samba-entrypoint.sh /opt/samba
RUN chmod +x /opt/samba/samba-entrypoint.sh
ENTRYPOINT ["/opt/samba/samba-entrypoint.sh"]
