image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.2.0-alpine3.23 \
		-t lcr.loongnix.cn/library/node:26.2-alpine3.23 \
		-t lcr.loongnix.cn/library/node:26-alpine3.23 \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.2.0-alpine3.23
	docker push lcr.loongnix.cn/library/node:26.2-alpine3.23
	docker push lcr.loongnix.cn/library/node:26-alpine3.23

