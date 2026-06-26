image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.18.0-forky \
		-t lcr.loongnix.cn/library/node:24.18-forky \
		-t lcr.loongnix.cn/library/node:24-forky \
		-t lcr.loongnix.cn/library/node:24.18.0 \
		-t lcr.loongnix.cn/library/node:24.18 \
		-t lcr.loongnix.cn/library/node:24 \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.18.0-forky
	docker push lcr.loongnix.cn/library/node:24.18-forky
	docker push lcr.loongnix.cn/library/node:24-forky
	docker push lcr.loongnix.cn/library/node:24.18.0
	docker push lcr.loongnix.cn/library/node:24.18
	docker push lcr.loongnix.cn/library/node:24

