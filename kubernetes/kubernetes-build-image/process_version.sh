#!/bin/bash

# Usage: process_version.sh

set -eo pipefail

source "$(dirname $0)/lib.sh"

readonly ORG='kubernetes-build-image'
readonly ARCH='loong64'
readonly REGISTRY='lcr.loongnix.cn'

# 获取上游最新 tag
# get_latest_tag $upstream_image
get_latest_tag()
{
    local upstream_image="$1"
    curl -sL "https://registry.k8s.io/v2/build-image/${upstream_image}/tags/list" \
        | jq -r '.tags[]' \
        | grep -v "^sha256-" \
        | sort -V | tail -1
}

# 标记并推送
# tag_and_push $image $tag
tag_and_push()
{
    local image="$1"
    local tag="$2"
    docker pull "${REGISTRY}/${ORG}/${image}:latest"
    docker tag "${REGISTRY}/${ORG}/${image}:latest" "${REGISTRY}/${ORG}/${image}:${tag}"
    docker push "${REGISTRY}/${ORG}/${image}:${tag}"
}

build()
{
    # kube-cross
    local kube_cross_tag=$(get_latest_tag kube-cross)
    log INFO "kube-cross latest tag: $kube_cross_tag"
    tag_and_push kube-cross "$kube_cross_tag"

    ## debian-base
    #local debian_base_tag=$(get_latest_tag debian-base)
    #log INFO "debian-base latest tag: $debian_base_tag"
    #tag_and_push debian-base "$debian_base_tag"

    ## debian-hyperkube-base
    #local debian_hyperkube_base_tag=$(get_latest_tag debian-hyperkube-base)
    #log INFO "debian-hyperkube-base latest tag: $debian_hyperkube_base_tag"
    #tag_and_push debian-hyperkube-base "$debian_hyperkube_base_tag"

    # debian-iptables
    local debian_iptables_tag=$(get_latest_tag debian-iptables)
    log INFO "debian-iptables latest tag: $debian_iptables_tag"
    tag_and_push debian-iptables "$debian_iptables_tag"

    # distroless-iptables
    local distroless_iptables_tag=$(get_latest_tag distroless-iptables)
    log INFO "distroless-iptables latest tag: $distroless_iptables_tag"
    tag_and_push distroless-iptables "$distroless_iptables_tag"

    # go-runner
    local go_runner_tag=$(get_latest_tag go-runner)
    log INFO "go-runner latest tag: $go_runner_tag"
    tag_and_push go-runner "$go_runner_tag"

    # setcap
    local setcap_tag=$(get_latest_tag setcap)
    log INFO "setcap latest tag: $setcap_tag"
    tag_and_push setcap "$setcap_tag"
}

main()
{
    build
}

main
