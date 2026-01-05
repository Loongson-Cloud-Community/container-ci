image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/php:8.3.17-zts-alpine3.21 \
		.

push:
	docker push lcr.loongnix.cn/library/php:8.3.17-zts-alpine3.21

