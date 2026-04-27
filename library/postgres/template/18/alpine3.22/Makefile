.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:18.3-alpine3.22 -t lcr.loongnix.cn/library/postgres:18-alpine3.22 .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:18.3-alpine3.22
	docker push lcr.loongnix.cn/library/postgres:18-alpine3.22
