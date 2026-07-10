FROM lcr.loongnix.cn/library/alpine:3.24

# 智能换源：尝试官方源，若失败则切换为中科大源重试
RUN apk update || \
    (sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && apk update)

# 安装所需包（此时源已可用）
RUN apk add --no-cache --no-progress ca-certificates tzdata

ARG TARGETPLATFORM
COPY ./dist/$TARGETPLATFORM/traefik /

EXPOSE 80
VOLUME ["/tmp"]

ENTRYPOINT ["/traefik"]
