.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:17.9-alpine3.23 -t lcr.loongnix.cn/library/postgres:17-alpine3.23 .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:17.9-alpine3.23
	docker push lcr.loongnix.cn/library/postgres:17-alpine3.23
