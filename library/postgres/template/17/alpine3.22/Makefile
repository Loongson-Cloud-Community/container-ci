.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:17.9-alpine3.22 -t lcr.loongnix.cn/library/postgres:17-alpine3.22 .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:17.9-alpine3.22
	docker push lcr.loongnix.cn/library/postgres:17-alpine3.22
