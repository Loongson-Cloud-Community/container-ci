#!/bin/bash
set -eo pipefail

cd "$(dirname "$0")"

if [ ! -f versions.json ]; then
    echo "ERROR: versions.json not found in template/"
    exit 1
fi

declare -A base_image_map=(
    ["debian:forky"]="lcr.loongnix.cn/library/debian:forky"
    ["debian:forky-slim"]="lcr.loongnix.cn/library/debian:forky-slim"
    ["openanolis:23.4"]="openanolis/anolisos:23.4"
)

for version in $(jq -r 'keys[]' versions.json); do
    for variant in $(jq -r --arg v "$version" '.[$v].variants[]' versions.json); do
        base_image="${base_image_map[$variant]}"
        if [ -z "$base_image" ]; then
            echo "Unknown variant: $variant, skipping"
            continue
        fi

        case "$variant" in
            debian:forky)       template="Dockerfile-debian.template" ;;
            debian:forky-slim)  template="Dockerfile-debian.template" ;;
            openanolis:23.4)    template="Dockerfile-rpm.template" ;;
            *) echo "No template for $variant"; exit 1 ;;
        esac

        dir_name="${variant//[:\/]/-}"
        target_dir="$version/$dir_name"
        mkdir -p "$target_dir"

        url=$(jq -r --arg v "$version" '.[$v].url' versions.json)
        java_version=$(jq -r --arg v "$version" '.[$v].version' versions.json)
        md5=$(jq -r --arg v "$version" '.[$v].md5 // ""' versions.json)

        echo "Generating $target_dir/Dockerfile from $template"
        sed -e "s|%%BASE_IMAGE%%|$base_image|g" \
            -e "s|%%JAVA_VERSION%%|$java_version|g" \
            -e "s|%%DOWNLOAD_URL%%|$url|g" \
            -e "s|%%MD5%%|$md5|g" \
            "$template" > "$target_dir/Dockerfile"
    done
done
