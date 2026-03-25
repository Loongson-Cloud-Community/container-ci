image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.22.2-trixie \
		-t lcr.loongnix.cn/library/node:22.22-trixie \
		-t lcr.loongnix.cn/library/node:22-trixie \
		-t lcr.loongnix.cn/library/node:22.22.2 \
		-t lcr.loongnix.cn/library/node:22.22 \
		-t lcr.loongnix.cn/library/node:22 \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.22.2-trixie
	docker push lcr.loongnix.cn/library/node:22.22-trixie
	docker push lcr.loongnix.cn/library/node:22-trixie
	docker push lcr.loongnix.cn/library/node:22.22.2
	docker push lcr.loongnix.cn/library/node:22.22
	docker push lcr.loongnix.cn/library/node:22

