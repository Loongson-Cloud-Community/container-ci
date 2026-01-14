image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:25.3.0-trixie \
		-t lcr.loongnix.cn/library/node:25.3-trixie \
		-t lcr.loongnix.cn/library/node:25-trixie \
		-t lcr.loongnix.cn/library/node:25.3.0 \
		-t lcr.loongnix.cn/library/node:25.3 \
		-t lcr.loongnix.cn/library/node:25 \
		.

push:
	docker push lcr.loongnix.cn/library/node:25.3.0-trixie
	docker push lcr.loongnix.cn/library/node:25.3-trixie
	docker push lcr.loongnix.cn/library/node:25-trixie
	docker push lcr.loongnix.cn/library/node:25.3.0
	docker push lcr.loongnix.cn/library/node:25.3
	docker push lcr.loongnix.cn/library/node:25

