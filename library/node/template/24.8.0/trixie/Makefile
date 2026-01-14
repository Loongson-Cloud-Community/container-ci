image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.8.0-trixie \
		-t lcr.loongnix.cn/library/node:24.8-trixie \
		-t lcr.loongnix.cn/library/node:24-trixie \
		-t lcr.loongnix.cn/library/node:24.8.0 \
		-t lcr.loongnix.cn/library/node:24.8 \
		-t lcr.loongnix.cn/library/node:24 \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.8.0-trixie
	docker push lcr.loongnix.cn/library/node:24.8-trixie
	docker push lcr.loongnix.cn/library/node:24-trixie
	docker push lcr.loongnix.cn/library/node:24.8.0
	docker push lcr.loongnix.cn/library/node:24.8
	docker push lcr.loongnix.cn/library/node:24

