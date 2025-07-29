#!/usr/bin/env bash
set -Eeuo pipefail

declare -A ALPINE_MAP=(
	["x86_64"]="x86_64-unknown-linux-musl"
	["aarch64"]="aarch64-unknown-linux-musl"
	["loongarch64"]="loongarch64-unknown-linux-musl"
)

declare -A DEBIAN_MAP=(
	["amd64"]="x86_64-unknown-linux-gnu"
	["armhf"]="armv7-unknown-linux-gnueabihf"
	["arm64"]="aarch64-unknown-linux-gnu"
	["i386"]="i686-unknown-linux-gnu"
	["ppc64el"]="powerpc64le-unknown-linux-gnu"
	["s390x"]="s390x-unknown-linux-gnu"
	["loong64"]="loongarch64-unknown-linux-gnu"
)

rustup_sha256() {
	local rustup_version=$1
	local rust_arch=$2
	local url="https://static.rust-lang.org/rustup/archive/${rustup_version}/${rust_arch}/rustup-init.sha256"
	wget -qO- "$url" | awk '{print $1}'
}

rustup_latest_version() {
	gh api repos/rust-lang/rustup/tags --paginate --jq '.[].name' |
		head -n 1
}

alpine_arch_info() {
	local arch=$1
	local rustup_version=$2
	local rustArch=${ALPINE_MAP[$arch]}
	local rustupSha256=$(rustup_sha256 $rustup_version $rustArch)
	jq -nrc \
		--arg arch $arch \
		--arg rustArch $rustArch \
		--arg rustupSha256 $rustupSha256 \
		'{
      ($arch): {
         rustArch: ($rustArch),
         rustupSha256: ($rustupSha256),
      }
    }'
}

alpine_arches() {

	local arches='{}'
	local rustup_version=$1
	for arch_ in "${!ALPINE_MAP[@]}"; do
		local arch_info=$(alpine_arch_info $arch_ $rustup_version)
		arches=$(
			jq -ncr \
				--argjson arch_info $arch_info \
				--argjson arches $arches \
				'($arches) + ($arch_info)'
		)
	done
    jq -ncr \
		--argjson arches $arches \
		'{ alpine_arches: ($arches) }'

}

debian_arch_info() {
    local arch=$1
    local rustup_version=$2
    local rustArch=${DEBIAN_MAP[$arch]}
    local rustupSha256=$(rustup_sha256 $rustup_version $rustArch)
    jq -nrc \
        --arg arch $arch \
        --arg rustArch $rustArch \
        --arg rustupSha256 $rustupSha256 \
        '{
      ($arch): {
         rustArch: ($rustArch),
         rustupSha256: ($rustupSha256),
      }
    }'
}

debian_arches() {

    local arches='{}'
    local rustup_version=$1
    for arch_ in "${!DEBIAN_MAP[@]}"; do
        local arch_info=$(debian_arch_info $arch_ $rustup_version)
        arches=$(
            jq -ncr \
                --argjson arch_info $arch_info \
                --argjson arches $arches \
                '($arches) + ($arch_info)'
        )
    done
    jq -ncr \
        --argjson arches $arches \
        '{ debian_arches: ($arches) }'

}


main(){
	local rust_version=$1
	local rustup_version=$(rustup_latest_version)
	local alpine_arches_=$(alpine_arches $rustup_version)
	local debian_arches_=$(debian_arches $rustup_version)
	local value=$(jq -ncr \
		--argjson alpine_arches $alpine_arches_ \
		--argjson debian_arches $debian_arches_ \
		--arg rustup_version $rustup_version \
		' ($debian_arches) + ($alpine_arches) + ({rustup_version: ($rustup_version) }) ' \
	)
	jq -n \
		--arg rust_version $rust_version \
		--argjson value $value \
	'{
		($rust_version) : ($value)
	}' >versions.json
}

main $1
