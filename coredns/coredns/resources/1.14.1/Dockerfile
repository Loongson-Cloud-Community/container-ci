ARG DEBIAN_IMAGE=debian:14-slim
ARG BASE=debian:14-slim

FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update \
    && apt-get -qq --no-install-recommends install libcap2-bin
COPY coredns /coredns
RUN chmod +x /coredns
RUN setcap cap_net_bind_service=+ep /coredns

FROM ${BASE}
COPY --from=build /coredns /coredns
RUN groupadd --gid 65532 nonroot &&     useradd --uid 65532 --gid 65532 --no-create-home --shell /usr/sbin/nologin nonroot
USER nonroot:nonroot
# Reset the working directory inherited from the base image back to the expected default:
# https://github.com/coredns/coredns/issues/7009#issuecomment-3124851608
WORKDIR /
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
