image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:24.18.0-forky-slim \
		-t lcr.loongnix.cn/library/node:24.18-forky-slim \
		-t lcr.loongnix.cn/library/node:24-forky-slim \
		.

push:
	docker push lcr.loongnix.cn/library/node:24.18.0-forky-slim
	docker push lcr.loongnix.cn/library/node:24.18-forky-slim
	docker push lcr.loongnix.cn/library/node:24-forky-slim

