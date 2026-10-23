COMPOSE := docker compose -f srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs --follow --tail=100

ps:
	$(COMPOSE) ps

re:
	$(MAKE) down
	$(MAKE) up

.PHONY: all up build down stop restart logs ps re
