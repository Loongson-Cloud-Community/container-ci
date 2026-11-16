.PHONY: image
image:
	docker build -t lcr.loongnix.cn/library/postgres:15.20-forky -t lcr.loongnix.cn/library/postgres:15-forky .

.PHONY: push
push:
	docker push lcr.loongnix.cn/library/postgres:15.20-forky
	docker push lcr.loongnix.cn/library/postgres:15-forky
