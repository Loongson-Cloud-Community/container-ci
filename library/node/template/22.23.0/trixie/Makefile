image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.23.0-trixie \
		-t lcr.loongnix.cn/library/node:22.23-trixie \
		-t lcr.loongnix.cn/library/node:22-trixie \
		-t lcr.loongnix.cn/library/node:22.23.0 \
		-t lcr.loongnix.cn/library/node:22.23 \
		-t lcr.loongnix.cn/library/node:22 \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.23.0-trixie
	docker push lcr.loongnix.cn/library/node:22.23-trixie
	docker push lcr.loongnix.cn/library/node:22-trixie
	docker push lcr.loongnix.cn/library/node:22.23.0
	docker push lcr.loongnix.cn/library/node:22.23
	docker push lcr.loongnix.cn/library/node:22

