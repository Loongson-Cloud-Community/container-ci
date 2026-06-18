image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.3.1-trixie \
		-t lcr.loongnix.cn/library/node:26.3-trixie \
		-t lcr.loongnix.cn/library/node:26-trixie \
		-t lcr.loongnix.cn/library/node:26.3.1 \
		-t lcr.loongnix.cn/library/node:26.3 \
		-t lcr.loongnix.cn/library/node:26 \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.3.1-trixie
	docker push lcr.loongnix.cn/library/node:26.3-trixie
	docker push lcr.loongnix.cn/library/node:26-trixie
	docker push lcr.loongnix.cn/library/node:26.3.1
	docker push lcr.loongnix.cn/library/node:26.3
	docker push lcr.loongnix.cn/library/node:26

