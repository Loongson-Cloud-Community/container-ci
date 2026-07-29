image:
	docker build \
		--build-arg ROOTFS=rootfs.tar.gz \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/google/cadvisor:0.60.0 \
		.

push:
	docker push lcr.loongnix.cn/google/cadvisor:0.60.0

