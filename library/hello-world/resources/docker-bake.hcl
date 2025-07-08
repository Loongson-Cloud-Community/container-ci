group "default" {
  targets = ["hello-world"]
}

target "hello-amd64" {
  dockerfile = "Dockerfile"
  context = "contexts/amd64"
  platforms = ["linux/amd64"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-amd64"]
}

target "hello-arm32v5" {
  dockerfile = "Dockerfile"
  context = "contexts/arm32v5"
  platforms = ["linux/arm/v5"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-arm32v5"]
}

target "hello-arm32v6" {
  dockerfile = "Dockerfile"
  context = "contexts/arm32v6"
  platforms = ["linux/arm/v6"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-arm32v6"]
}

target "hello-arm32v7" {
  dockerfile = "Dockerfile"
  context = "contexts/arm32v7"
  platforms = ["linux/arm/v7"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-arm32v7"]
}

target "hello-arm64v8" {
  dockerfile = "Dockerfile"
  context = "contexts/arm64v8"
  platforms = ["linux/arm64/v8"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-arm64v8"]
}

target "hello-i386" {
  dockerfile = "Dockerfile"
  context = "contexts/i386"
  platforms = ["linux/386"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-i386"]
}

target "hello-loongarch64" {
  dockerfile = "Dockerfile"
  context = "contexts/loongarch64"
  platforms = ["linux/loongarch64"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-loongarch64"]
}

target "hello-ppc64le" {
  dockerfile = "Dockerfile"
  context = "contexts/ppc64le"
  platforms = ["linux/ppc64le"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-ppc64le"]
}

target "hello-riscv64" {
  dockerfile = "Dockerfile"
  context = "contexts/riscv64"
  platforms = ["linux/riscv64"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-riscv64"]
}

target "hello-s390x" {
  dockerfile = "Dockerfile"
  context = "contexts/s390x"
  platforms = ["linux/s390x"]
  tags = ["lcr.loongnix.cn/library/hello-world:temp-s390x"]
}

# 汇总 manifest
target "hello-world" {
  inherits = []
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  platforms = [
    "linux/amd64",
    "linux/arm/v5",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64/v8",
    "linux/386",
    "linux/loongarch64",
    "linux/ppc64le",
    "linux/riscv64",
    "linux/s390x"
  ]
  output = ["type=image,push=true"]
  dockerfile = "Dockerfile"
  context = "contexts/amd64" # 只需一个 context 占位
}

