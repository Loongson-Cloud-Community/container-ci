image:
	docker build \
		--build-arg https_proxy=$(https_proxy) \
		--build-arg http_proxy=$(http_proxy) \
		-t lcr.loongnix.cn/library/postgres:14.11-alpine3.21 \
		.

push:
	docker push lcr.loongnix.cn/library/postgres:14.11-alpine3.21

