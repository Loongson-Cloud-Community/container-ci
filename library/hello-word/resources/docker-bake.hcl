group "default" {
  targets = ["manifest"]
}

target "manifest" {
  contexts = {
    "amd64" = "target:hello-amd64",
    "arm64" = "target:hello-arm64",
    "arm32v7" = "target:hello-arm32v7",
    "loongarch64" = "target:hello-loongarch64",
    "ppc64le" = "target:hello-ppc64le",
    "s390x" = "target:hello-s390x",
    "i386" = "target:hello-i386"
  }
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
    "linux/loong64",
    "linux/ppc64le",
    "linux/s390x",
    "linux/386"
  ]
}

# 保持你原有的目标定义不变，但修改输出：
target "hello-amd64" {
  context = "./amd64/hello-world"
  platforms = ["linux/amd64"]
  output = ["type=docker"]  # 或者 "type=oci" 如果不需要加载到本地 Docker
}
# ... 其他目标类似
target "hello-arm64" {
  context = "./arm64v8/hello-world"
  platforms = ["linux/arm64"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-arm32v7" {
  context = "./arm32v7/hello-world"
  platforms = ["linux/arm/v7"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-mips64le" {
  context = "./mips64le/hello-world"
  platforms = ["linux/mips64le"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-loongarch64" {
  context = "./loongarch64/hello-world"
  platforms = ["linux/loong64"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-ppc64le" {
  context = "./ppc64le/hello-world"
  platforms = ["linux/ppc64le"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-s390x" {
  context = "./s390x/hello-world"
  platforms = ["linux/s390x"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

target "hello-i386" {
  context = "./i386/hello-world"
  platforms = ["linux/386"]
  tags = ["lcr.loongnix.cn/library/hello-world:linux"]
  output = ["type=docker"]
}

