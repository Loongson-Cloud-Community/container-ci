FROM lcr.loongnix.cn/library/alpine:3.23

RUN apk add --no-cache --no-progress ca-certificates tzdata

ARG TARGETPLATFORM
COPY ./dist/$TARGETPLATFORM/traefik /

EXPOSE 80
VOLUME ["/tmp"]

ENTRYPOINT ["/traefik"]
