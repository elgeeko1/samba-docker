FROM ubuntu:groovy
LABEL maintainer="https://github.com/elgeeko1"

USER root

EXPOSE 137/udp
EXPOSE 138/udp
EXPOSE 139/tcp
EXPOSE 445/tcp

# install samba: samba samba-common samba-client samba-vfs-modules
# install elasticsearch: fscrawner elasticsearch
RUN apt-get update -q \
  && apt-get install -y -q \
       samba \
       samba-common \
       samba-client \
       samba-vfs-modules \
  && apt-get -q -y clean \
  && rm -rf /var/lib/apt/lists/*

# create default configuration
RUN mkdir -p /opt/samba
RUN mkdir -p /opt/samba/shares
RUN mkdir -p /opt/samba/shares/public \
	&& chmod 0666 /opt/samba/shares/public
COPY app/smb.conf /etc/samba/smb.conf
COPY app/smb-users /opt/samba/

# entrypoint
WORKDIR /opt/samba/shares
COPY app/samba-entrypoint.sh /opt/samba
RUN chmod +x /opt/samba/samba-entrypoint.sh
ENTRYPOINT ["/opt/samba/samba-entrypoint.sh"]
