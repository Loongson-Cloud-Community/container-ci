#!/usr/bin/env bash
set -Eeuo pipefail

main(){
	# 1. 获取版本号
    local otp_version=$(jq -cr '.otp_version' versions.json | cut -d. -f1)

	# 2. alpine3.21
    mkdir -p ${otp_version}/alpine
    cat versions.json | jinja2 Dockerfile-alpine.template - >${otp_version}/alpine/Dockerfile
	jinja2 Makefile.template -D tags="$otp_version-alpine" >"${otp_version}/alpine/Makefile"

	# 3. slim
    mkdir -p ${otp_version}/slim
    cat versions.json | jinja2 Dockerfile-slim.template - >${otp_version}/slim/Dockerfile
	jinja2 Makefile.template -D tags="$otp_version-slim" >"${otp_version}/slim/Makefile"

	# 4. 
    mkdir -p ${otp_version}
    cat versions.json | jinja2 Dockerfile.template - >${otp_version}/Dockerfile
	jinja2 Makefile.template -D tags="$otp_version" >"${otp_version}/Makefile"

}

main
