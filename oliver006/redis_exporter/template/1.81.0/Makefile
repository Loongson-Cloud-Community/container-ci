image:
	docker build \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/oliver006/redis_exporter:1.81.0 \
		.

push:
	docker push lcr.loongnix.cn/oliver006/redis_exporter:1.81.0
