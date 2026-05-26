image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.2.0-trixie-slim \
		-t lcr.loongnix.cn/library/node:26.2-trixie-slim \
		-t lcr.loongnix.cn/library/node:26-trixie-slim \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.2.0-trixie-slim
	docker push lcr.loongnix.cn/library/node:26.2-trixie-slim
	docker push lcr.loongnix.cn/library/node:26-trixie-slim

