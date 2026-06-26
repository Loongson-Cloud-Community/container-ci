image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/node:26.4.0-forky \
		-t lcr.loongnix.cn/library/node:26.4-forky \
		-t lcr.loongnix.cn/library/node:26-forky \
		-t lcr.loongnix.cn/library/node:26.4.0 \
		-t lcr.loongnix.cn/library/node:26.4 \
		-t lcr.loongnix.cn/library/node:26 \
		.

push:
	docker push lcr.loongnix.cn/library/node:26.4.0-forky
	docker push lcr.loongnix.cn/library/node:26.4-forky
	docker push lcr.loongnix.cn/library/node:26-forky
	docker push lcr.loongnix.cn/library/node:26.4.0
	docker push lcr.loongnix.cn/library/node:26.4
	docker push lcr.loongnix.cn/library/node:26

