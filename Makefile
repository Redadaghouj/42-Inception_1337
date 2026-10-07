COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = $(HOME)/data
MARIADB_DIR = $(DATA_DIR)/mariadb
WORDPRESS_DIR = $(DATA_DIR)/wordpress

all: up

up:
	mkdir -p $(MARIADB_DIR) $(WORDPRESS_DIR)
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

clean: down

fclean:
	$(COMPOSE) down -v --rmi local --remove-orphans
	sudo rm -rf $(MARIADB_DIR) $(WORDPRESS_DIR)

re: fclean
	$(MAKE) up

.PHONY: all up build down clean fclean re
