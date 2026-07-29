FROM lcr.loongnix.cn/library/alpine:3.23 AS build

ARG VERSION=0.60.1

# Download pre-built cAdvisor binary for loongarch64
RUN apk --no-cache add wget ca-certificates && \
    wget -O /usr/bin/cadvisor https://github.com/loongarch64-releases/cadvisor/releases/download/v${VERSION}/cadvisor && \
    chmod +x /usr/bin/cadvisor

FROM lcr.loongnix.cn/library/alpine:3.23
MAINTAINER dengnan@google.com vmarmol@google.com vishnuk@google.com jimmidyson@gmail.com stclair@google.com

RUN apk --no-cache add libc6-compat device-mapper findutils ndctl thin-provisioning-tools zfs && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
    rm -rf /var/cache/apk/*

# Grab pre-built cAdvisor binary from "build" container
COPY --from=build /usr/bin/cadvisor /usr/bin/cadvisor

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

COPY healthcheck.sh /usr/bin/healthcheck.sh
RUN chmod +x /usr/bin/healthcheck.sh

# Default port is 8080, but can be changed with -port flag
# Users should expose their custom port with: docker run -p <custom>:<custom>
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD /usr/bin/healthcheck.sh

# Use entrypoint wrapper
ENTRYPOINT ["/usr/bin/entrypoint.sh"]

