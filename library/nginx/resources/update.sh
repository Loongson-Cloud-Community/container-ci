#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

declare branches=(
    "stable"
)

# Current nginx versions
# Remember to update pkgosschecksum when changing this.
declare -A nginx=(
    [mainline]='1.27.5'
    [stable]='1.27.5'
)

# Current njs versions
declare -A njs=(
    [mainline]='0.8.10'
    [stable]='0.8.10'
)

# Current njs patchlevel version
# Remember to update pkgosschecksum when changing this.
declare -A njspkg=(
    [mainline]='1'
    [stable]='1'
)

# Current otel versions
declare -A otel=(
    [mainline]='0.1.2'
    [stable]='0.1.2'
)

# Current nginx package patchlevel version
# Remember to update pkgosschecksum when changing this.
declare -A pkg=(
    [mainline]=1
    [stable]=1
)

# Current built-in dynamic modules package patchlevel version
# Remember to update pkgosschecksum when changing this
declare -A dynpkg=(
    [mainline]=1
    [stable]=1
)

declare -A debian=(
    [mainline]='bookworm'
    [stable]='trixie'
)

declare -A alpine=(
    [mainline]='3.21'
    [stable]='3.21'
)

# When we bump njs version in a stable release we don't move the tag in the
# pkg-oss repo.  This setting allows us to specify a revision to check out
# when building packages on architectures not supported by nginx.org
# Remember to update pkgosschecksum when changing this.
declare -A rev=(
    [mainline]='${NGINX_VERSION}-${PKG_RELEASE}'
    [stable]='${NGINX_VERSION}-${PKG_RELEASE}'
)

# Holds SHA512 checksum for the pkg-oss tarball produced by source code
# revision/tag in the previous block
# Used in builds for architectures not packaged by nginx.org
declare -A pkgosschecksum=(
    [mainline]='c773d98b567bd585c17f55702bf3e4c7d82b676bfbde395270e90a704dca3c758dfe0380b3f01770542b4fd9bed1f1149af4ce28bfc54a27a96df6b700ac1745'
    [stable]='517bc18954ccf4efddd51986584ca1f37966833ad342a297e1fe58fd0faf14c5a4dabcb23519dca433878a2927a95d6bea05a6749ee2fa67a33bf24cdc41b1e4'
)

# Usage: get_github_latest $org $proj
# Return: (latest_tag)
get_github_latest()
{
    local org=$1
    local proj=$2
    curl -s https://api.github.com/repos/$org/$proj/tags | jq -r '.[].name'
}


get_nginx_latest_version()
{
    # tags: release-1.21.7
    get_github_latest "nginx" "nginx" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -rV \
    | head -1
}

get_nginx-otel_latest_version()
{
    get_github_latest "nginxinc" "nginx-otel" \
    | grep -E '^v' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -rV \
    | head -1
}

get_nginx-njs_latest_version()
{
    get_github_latest "nginx" "njs" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -rV \
    | head -1
}

get_packages() {
    local distro="$1"
    shift
    local branch="$1"
    shift
    local bn=""
    local otel=
    local perl=
    local r=
    local sep=

    case "$distro:$branch" in
    alpine*:*)
        r="r"
        sep="."
        ;;
    debian*:*)
        sep="+"
        ;;
    esac

    case "$distro" in
    *-perl)
        perl="nginx-module-perl"
        ;;
    *-otel)
        otel="nginx-module-otel"
        bn="\n"
        ;;
    esac

    echo -n ' \\\n'
    case "$distro" in
    *-slim)
        for p in nginx; do
            echo -n '        '"$p"'=${NGINX_VERSION}-'"$r"'${PKG_RELEASE} \\'
        done
        ;;
    *)
        for p in nginx; do
            echo -n '        '"$p"'=${NGINX_VERSION}-'"$r"'${PKG_RELEASE} \\\n'
        done
        for p in nginx-module-xslt nginx-module-geoip nginx-module-image-filter $perl; do
            echo -n '        '"$p"'=${NGINX_VERSION}-'"$r"'${DYNPKG_RELEASE} \\\n'
        done
        for p in nginx-module-njs; do
            echo -n '        '"$p"'=${NGINX_VERSION}'"$sep"'${NJS_VERSION}-'"$r"'${NJS_RELEASE} \\'"$bn"
        done
        for p in $otel; do
            echo -n '        '"$p"'=${NGINX_VERSION}'"$sep"'${OTEL_VERSION}-'"$r"'${PKG_RELEASE} \\'
        done
        ;;
    esac
}

get_packagerepo() {
    local distro="$1"
    shift
    distro="${distro%-perl}"
    distro="${distro%-otel}"
    distro="${distro%-slim}"
    local branch="$1"
    shift

    [ "$branch" = "mainline" ] && branch="$branch/" || branch=""

    echo "https://nginx.org/packages/${branch}${distro}/"
}

get_packagever() {
    local distro="$1"
    shift
    distro="${distro%-perl}"
    distro="${distro%-otel}"
    distro="${distro%-slim}"
    local branch="$1"
    shift
    local package="$1"
    shift
    local suffix=

    [ "${distro}" = "debian" ] && suffix="~${debianver}"

    case "${package}" in
        "njs")
            echo ${njspkg[$branch]}${suffix}
            ;;
        "dyn")
            echo ${dynpkg[$branch]}${suffix}
            ;;
        *)
            echo ${pkg[$branch]}${suffix}
            ;;
    esac
}

get_buildtarget() {
    local distro="$1"
    shift
    case "$distro" in
        alpine-slim)
            echo base
            ;;
        alpine)
            echo module-geoip module-image-filter module-njs module-xslt
            ;;
        debian)
            echo base module-geoip module-image-filter module-njs module-xslt
            ;;
        *-perl)
            echo module-perl
            ;;
        *-otel)
            echo module-otel
            ;;
    esac
}

generated_warning() {
    cat <<__EOF__
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
__EOF__
}

# Usage: get_njsver $ngxossver
# Return: x.y.z
get_njsver()
{
    local ngxossver="$1"
    # NJS_VERSION := 0.8.10
    curl -s https://raw.githubusercontent.com/nginx/pkg-oss/refs/tags/$ngxossver/contrib/src/njs/version \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

# Usage: get_njsver $ngxossver
# Return: x.y.z
get_otelver()
{
    # NGINX_OTEL_VERSION := 0.1.2
    curl -s https://raw.githubusercontent.com/nginx/pkg-oss/refs/tags/$ngxossver/contrib/src/nginx-otel/version \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

update_versions()
{

    if [[ -z "$1" ]]; then
        echo "Error: expecte ngxoss version"
    fi
    # 1.28.0-1
    local ngxossver="$1"

    local ngxver=${ngxossver%-*}
    local pkgver=${ngxossver#*-}

    nginx["stable"]="$ngxver"
    njs["stable"]="$(get_njsver $ngxossver)"
    otel["stable"]="$(get_otelver $ngxossver)"

    # 这个变量用于 apk/deb 包版本
    dynpkg["stable"]="$pkgver"
    njspkg["stable"]="$pkgver"

    echo "Nginx Version: ${nginx["stable"]}"
    echo "Njs Version: ${njs["stable"]}"
    echo "Otel Version: ${otel["stable"]}"
    echo "Dynamic Version: ${dynpkg["stable"]}"

}

update_versions "$1"

for branch in "${branches[@]}"; do
    for variant in \
        alpine{,-perl,-otel,-slim} \
        debian{,-perl,-otel}; do
        echo "$branch: $variant dockerfiles"
        dir="$branch/$variant"
        variant="$(basename "$variant")"

        [ -d "$dir" ] || continue

        template="Dockerfile-${variant}.template"
        {
            generated_warning
            cat "$template"
        } >"$dir/Dockerfile"

        debianver="${debian[$branch]}"
        alpinever="${alpine[$branch]}"
        nginxver="${nginx[$branch]}"
        njsver="${njs[${branch}]}"
        otelver="${otel[${branch}]}"
        revver="${rev[${branch}]}"
        pkgosschecksumver="${pkgosschecksum[${branch}]}"

        packagerepo=$(get_packagerepo "$variant" "$branch")
        packages=$(get_packages "$variant" "$branch")
        packagever=$(get_packagever "$variant" "$branch" "any")
        njspkgver=$(get_packagever "$variant" "$branch" "njs")
        dynpkgver=$(get_packagever "$variant" "$branch" "dyn")
        buildtarget=$(get_buildtarget "$variant")

        sed -i.bak \
            -e 's,%%ALPINE_VERSION%%,'"$alpinever"',' \
            -e 's,%%DEBIAN_VERSION%%,'"$debianver"',' \
            -e 's,%%DYNPKG_RELEASE%%,'"$dynpkgver"',' \
            -e 's,%%NGINX_VERSION%%,'"$nginxver"',' \
            -e 's,%%NJS_VERSION%%,'"$njsver"',' \
            -e 's,%%NJS_RELEASE%%,'"$njspkgver"',' \
            -e 's,%%OTEL_VERSION%%,'"$otelver"',' \
            -e 's,%%PKG_RELEASE%%,'"$packagever"',' \
            -e 's,%%PACKAGES%%,'"$packages"',' \
            -e 's,%%PACKAGEREPO%%,'"$packagerepo"',' \
            -e 's,%%REVISION%%,'"$revver"',' \
            -e 's,%%PKGOSSCHECKSUM%%,'"$pkgosschecksumver"',' \
            -e 's,%%BUILDTARGET%%,'"$buildtarget"',' \
            "$dir/Dockerfile"

    done

    for variant in \
        alpine-slim \
        debian; do \
        echo "$branch: $variant entrypoint scripts"
        dir="$branch/$variant"
        cp -a entrypoint/*.sh "$dir/"
        cp -a entrypoint/*.envsh "$dir/"
    done
done
