image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.21.1-trixie-slim \
		-t lcr.loongnix.cn/library/node:22.21-trixie-slim \
		-t lcr.loongnix.cn/library/node:22-trixie-slim \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.21.1-trixie-slim
	docker push lcr.loongnix.cn/library/node:22.21-trixie-slim
	docker push lcr.loongnix.cn/library/node:22-trixie-slim

