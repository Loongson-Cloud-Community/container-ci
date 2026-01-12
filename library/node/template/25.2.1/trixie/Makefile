image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:25.2.1-trixie \
		-t lcr.loongnix.cn/library/node:25.2-trixie \
		-t lcr.loongnix.cn/library/node:25-trixie \
		-t lcr.loongnix.cn/library/node:25.2.1 \
		-t lcr.loongnix.cn/library/node:25.2 \
		-t lcr.loongnix.cn/library/node:25 \
		.

push:
	docker push lcr.loongnix.cn/library/node:25.2.1-trixie
	docker push lcr.loongnix.cn/library/node:25.2-trixie
	docker push lcr.loongnix.cn/library/node:25-trixie
	docker push lcr.loongnix.cn/library/node:25.2.1
	docker push lcr.loongnix.cn/library/node:25.2
	docker push lcr.loongnix.cn/library/node:25

