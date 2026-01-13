image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.21.1-trixie \
		-t lcr.loongnix.cn/library/node:22.21-trixie \
		-t lcr.loongnix.cn/library/node:22-trixie \
		-t lcr.loongnix.cn/library/node:22.21.1 \
		-t lcr.loongnix.cn/library/node:22.21 \
		-t lcr.loongnix.cn/library/node:22 \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.21.1-trixie
	docker push lcr.loongnix.cn/library/node:22.21-trixie
	docker push lcr.loongnix.cn/library/node:22-trixie
	docker push lcr.loongnix.cn/library/node:22.21.1
	docker push lcr.loongnix.cn/library/node:22.21
	docker push lcr.loongnix.cn/library/node:22

