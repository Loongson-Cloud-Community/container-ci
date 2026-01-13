image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:22.21.1-alpine3.22 \
		-t lcr.loongnix.cn/library/node:22.21-alpine3.22 \
		-t lcr.loongnix.cn/library/node:22-alpine3.22 \
		.

push:
	docker push lcr.loongnix.cn/library/node:22.21.1-alpine3.22
	docker push lcr.loongnix.cn/library/node:22.21-alpine3.22
	docker push lcr.loongnix.cn/library/node:22-alpine3.22

