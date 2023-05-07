##################
## base stage
##################
FROM ubuntu:jammy AS BASE

USER root

# Preconfigure debconf for non-interactive installation - otherwise complains about terminal
# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
ARG DEBIAN_FRONTEND=noninteractive
ARG DISPLAY localhost:0.0
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# configure apt
RUN apt-get update -q
RUN apt-get install --no-install-recommends -y -q apt-utils 2>&1 \
	| grep -v "debconf: delaying package configuration"
RUN apt-get install --no-install-recommends -y -q ca-certificates

# install samba: samba samba-common samba-client samba-vfs-modules
RUN apt-get install --no-install-recommends -y -q samba
RUN apt-get install --no-install-recommends -y -q samba-common
RUN apt-get install --no-install-recommends -y -q samba-client
RUN apt-get install --no-install-recommends -y -q samba-vfs-modules

# apt cleanup
RUN apt-get autoremove -y -q
RUN apt-get -y -q clean
RUN rm -rf /var/lib/apt/lists/*

####################
## application stage
####################
FROM scratch
COPY --from=BASE / /
LABEL maintainer="elgeeko1"
LABEL source="https://github.com/elgeeko1/samba-docker"

EXPOSE 137/udp
EXPOSE 138/udp
EXPOSE 139/tcp
EXPOSE 445/tcp

USER root

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

HEALTHCHECK --interval=30s --timeout=10s \
  CMD smbclient -L \\localhost -U % -m SMB3
