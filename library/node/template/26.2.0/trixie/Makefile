image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.2.0-trixie \
		-t lcr.loongnix.cn/library/node:26.2-trixie \
		-t lcr.loongnix.cn/library/node:26-trixie \
		-t lcr.loongnix.cn/library/node:26.2.0 \
		-t lcr.loongnix.cn/library/node:26.2 \
		-t lcr.loongnix.cn/library/node:26 \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.2.0-trixie
	docker push lcr.loongnix.cn/library/node:26.2-trixie
	docker push lcr.loongnix.cn/library/node:26-trixie
	docker push lcr.loongnix.cn/library/node:26.2.0
	docker push lcr.loongnix.cn/library/node:26.2
	docker push lcr.loongnix.cn/library/node:26

