.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:16.13-alpine3.23 -t lcr.loongnix.cn/library/postgres:16-alpine3.23 .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:16.13-alpine3.23
	docker push lcr.loongnix.cn/library/postgres:16-alpine3.23
