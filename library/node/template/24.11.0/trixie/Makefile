image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.11.0-trixie \
		-t lcr.loongnix.cn/library/node:24.11-trixie \
		-t lcr.loongnix.cn/library/node:24-trixie \
		-t lcr.loongnix.cn/library/node:24.11.0 \
		-t lcr.loongnix.cn/library/node:24.11 \
		-t lcr.loongnix.cn/library/node:24 \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.11.0-trixie
	docker push lcr.loongnix.cn/library/node:24.11-trixie
	docker push lcr.loongnix.cn/library/node:24-trixie
	docker push lcr.loongnix.cn/library/node:24.11.0
	docker push lcr.loongnix.cn/library/node:24.11
	docker push lcr.loongnix.cn/library/node:24

