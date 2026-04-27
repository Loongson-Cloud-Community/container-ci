.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:17.9-forky -t lcr.loongnix.cn/library/postgres:17-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:17.9-forky
	docker push lcr.loongnix.cn/library/postgres:17-forky
