version="$1"
ver_name="${version##*/}"   # 取最后一段，比如 dockerfile/1.17.1 -> 1.17.1

git clone --depth 1 -b "${version}" https://github.com/moby/buildkit "${ver_name}"
cd "${ver_name}" && python ../../scripts/modify.py \
    frontend/dockerfile/cmd/dockerfile-frontend/Dockerfile \
    > "frontend/dockerfile/cmd/dockerfile-frontend/Dockerfile.modify"

