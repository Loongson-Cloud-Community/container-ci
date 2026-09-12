image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.8.1-forky \
		-t lcr.loongnix.cn/library/node:26.8-forky \
		-t lcr.loongnix.cn/library/node:26-forky \
		-t lcr.loongnix.cn/library/node:26.8.1 \
		-t lcr.loongnix.cn/library/node:26.8 \
		-t lcr.loongnix.cn/library/node:26 \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.8.1-forky
	docker push lcr.loongnix.cn/library/node:26.8-forky
	docker push lcr.loongnix.cn/library/node:26-forky
	docker push lcr.loongnix.cn/library/node:26.8.1
	docker push lcr.loongnix.cn/library/node:26.8
	docker push lcr.loongnix.cn/library/node:26

