image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.17.0-trixie \
		-t lcr.loongnix.cn/library/node:24.17-trixie \
		-t lcr.loongnix.cn/library/node:24-trixie \
		-t lcr.loongnix.cn/library/node:24.17.0 \
		-t lcr.loongnix.cn/library/node:24.17 \
		-t lcr.loongnix.cn/library/node:24 \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.17.0-trixie
	docker push lcr.loongnix.cn/library/node:24.17-trixie
	docker push lcr.loongnix.cn/library/node:24-trixie
	docker push lcr.loongnix.cn/library/node:24.17.0
	docker push lcr.loongnix.cn/library/node:24.17
	docker push lcr.loongnix.cn/library/node:24

