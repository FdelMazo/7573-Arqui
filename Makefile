
default: up logs

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
