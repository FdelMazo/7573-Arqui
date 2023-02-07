
default: down up logs

docker-image:
	docker build -f ./app/Dockerfile -t "node-server:latest" .
.PHONY: docker-image

up: docker-image
	docker-compose up --detach
.PHONY: up

down:
	docker-compose stop --timeout 1
	docker-compose down --remove-orphans
.PHONY: down

logs:
	docker-compose logs -f
.PHONY: logs

informe:
	docker run --rm -v `pwd`:/pandoc dalibo/pandocker header.yaml README.md --output informe.pdf
.PHONY: informe
