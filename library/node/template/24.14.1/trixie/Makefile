image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.14.1-trixie \
		-t lcr.loongnix.cn/library/node:24.14-trixie \
		-t lcr.loongnix.cn/library/node:24-trixie \
		-t lcr.loongnix.cn/library/node:24.14.1 \
		-t lcr.loongnix.cn/library/node:24.14 \
		-t lcr.loongnix.cn/library/node:24 \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.14.1-trixie
	docker push lcr.loongnix.cn/library/node:24.14-trixie
	docker push lcr.loongnix.cn/library/node:24-trixie
	docker push lcr.loongnix.cn/library/node:24.14.1
	docker push lcr.loongnix.cn/library/node:24.14
	docker push lcr.loongnix.cn/library/node:24

