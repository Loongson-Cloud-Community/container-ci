image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:23.11.1-trixie \
		-t lcr.loongnix.cn/library/node:23.11-trixie \
		-t lcr.loongnix.cn/library/node:23-trixie \
		-t lcr.loongnix.cn/library/node:23.11.1 \
		-t lcr.loongnix.cn/library/node:23.11 \
		-t lcr.loongnix.cn/library/node:23 \
		.

push:
	docker push lcr.loongnix.cn/library/node:23.11.1-trixie
	docker push lcr.loongnix.cn/library/node:23.11-trixie
	docker push lcr.loongnix.cn/library/node:23-trixie
	docker push lcr.loongnix.cn/library/node:23.11.1
	docker push lcr.loongnix.cn/library/node:23.11
	docker push lcr.loongnix.cn/library/node:23

