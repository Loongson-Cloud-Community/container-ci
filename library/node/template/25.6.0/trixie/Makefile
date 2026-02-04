image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:25.6.0-trixie \
		-t lcr.loongnix.cn/library/node:25.6-trixie \
		-t lcr.loongnix.cn/library/node:25-trixie \
		-t lcr.loongnix.cn/library/node:25.6.0 \
		-t lcr.loongnix.cn/library/node:25.6 \
		-t lcr.loongnix.cn/library/node:25 \
		.

push:
	docker push lcr.loongnix.cn/library/node:25.6.0-trixie
	docker push lcr.loongnix.cn/library/node:25.6-trixie
	docker push lcr.loongnix.cn/library/node:25-trixie
	docker push lcr.loongnix.cn/library/node:25.6.0
	docker push lcr.loongnix.cn/library/node:25.6
	docker push lcr.loongnix.cn/library/node:25

