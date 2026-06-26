image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.23.1-forky \
		-t lcr.loongnix.cn/library/node:22.23-forky \
		-t lcr.loongnix.cn/library/node:22-forky \
		-t lcr.loongnix.cn/library/node:22.23.1 \
		-t lcr.loongnix.cn/library/node:22.23 \
		-t lcr.loongnix.cn/library/node:22 \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.23.1-forky
	docker push lcr.loongnix.cn/library/node:22.23-forky
	docker push lcr.loongnix.cn/library/node:22-forky
	docker push lcr.loongnix.cn/library/node:22.23.1
	docker push lcr.loongnix.cn/library/node:22.23
	docker push lcr.loongnix.cn/library/node:22

