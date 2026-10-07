# Inception Developer Documentation

This document explains how to set up, build, inspect, debug, and maintain the Inception infrastructure.

## Architecture

The mandatory infrastructure contains three services:

```text
Browser
   |
   | HTTPS :443
   v
NGINX
   |
   | FastCGI :9000
   v
WordPress + PHP-FPM
   |
   | MariaDB :3306
   v
MariaDB
```

Each service runs in its own container.

The mandatory images are:

```text
nginx:1.0
wordpress:1.0
mariadb:1.0
```

All three are built locally from custom Dockerfiles based on:

```text
debian:12-slim
```

---

## Prerequisites

The project is intended to run inside a Virtual Machine.

Required tools:

```text
Docker
Docker Compose
GNU Make
```

Verify them with:

```bash
docker --version
docker compose version
make --version
```

The Docker daemon must be running.

Check:

```bash
docker info
```

---

## Repository Structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── 99-inception.cnf
        │   └── tools/
        │       └── init.sh
        │
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/
        │       └── default.conf
        │
        └── wordpress/
            ├── Dockerfile
            └── tools/
                └── init.sh
```

---

## Configuration

Non-sensitive configuration is stored in:

```text
srcs/.env
```

Example structure:

```env
DB_NAME=wordpress
DB_USER=wpuser

WP_URL=https://mdaghouj.42.fr
WP_TITLE=Inception

WP_ADMIN_USER=mdaghouj
WP_ADMIN_EMAIL=mdaghouj@student.1337.ma

WP_USER=editor
WP_USER_EMAIL=editor@example.com
```

Do not store passwords in `.env`.

---

## Secrets

Sensitive credentials are stored in:

```text
secrets/
```

Required files:

```text
db_password.txt
db_root_password.txt
wp_admin_password.txt
wp_user_password.txt
```

These files are referenced by Docker Compose and mounted inside the containers under:

```text
/run/secrets/
```

For example:

```text
/run/secrets/db_password
```

Both:

```text
srcs/.env
secrets/*.txt
```

must remain excluded from Git.

Check:

```bash
git status --ignored
```

You can also verify that a secret is ignored with:

```bash
git check-ignore secrets/db_password.txt
```

---

## Domain Configuration

The project domain is:

```text
mdaghouj.42.fr
```

Inside the VM, `/etc/hosts` should contain:

```text
127.0.0.1 mdaghouj.42.fr
```

Check:

```bash
grep mdaghouj.42.fr /etc/hosts
```

---

## Persistent Data Directories

Persistent data is stored under:

```text
/home/mdaghouj/data
```

The project uses:

```text
/home/mdaghouj/data/mariadb
/home/mdaghouj/data/wordpress
```

The Makefile creates these directories automatically before starting the stack.

They can also be created manually:

```bash
mkdir -p \
  /home/mdaghouj/data/mariadb \
  /home/mdaghouj/data/wordpress
```

---

# Build and Launch

## Start the Complete Infrastructure

From the repository root:

```bash
make
```

or:

```bash
make up
```

This executes Docker Compose with the project configuration and starts all services.

---

## Build Images Only

```bash
make build
```

Equivalent Compose command:

```bash
docker compose -f srcs/docker-compose.yml build
```

---

## Stop the Infrastructure

```bash
make down
```

Equivalent command:

```bash
docker compose -f srcs/docker-compose.yml down
```

This removes containers and the Compose network while preserving persistent volumes and data.

---

## Full Cleanup

```bash
make fclean
```

This removes:

- project containers
- project network
- named volumes
- local project images
- MariaDB persistent data
- WordPress persistent data

This operation is destructive.

---

## Rebuild from Scratch

```bash
make re
```

This performs a full cleanup and rebuilds the entire infrastructure.

It is useful for validating that the project works from a clean environment.

---

# Docker Compose Commands

The Compose file is:

```text
srcs/docker-compose.yml
```

To avoid repeatedly typing the full path, the Makefile uses:

```text
docker compose -f srcs/docker-compose.yml
```

Useful commands follow.

---

## Show Container Status

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
```

---

## Show Resolved Compose Configuration

```bash
docker compose -f srcs/docker-compose.yml config
```

This is useful for checking:

- environment variable expansion
- service configuration
- volume declarations
- networks
- secrets
- ports

Be careful when inspecting configuration on systems where sensitive values may be present.

---

## Rebuild One Service

Example:

```bash
docker compose -f srcs/docker-compose.yml build wordpress
```

Then recreate it:

```bash
docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate wordpress
```

The same pattern can be used for `nginx` or `mariadb`.

---

# Container Inspection

## List Containers

```bash
docker ps
```

Include stopped containers:

```bash
docker ps -a
```

---

## Inspect a Container

```bash
docker inspect wordpress
```

or:

```bash
docker inspect mariadb
```

or:

```bash
docker inspect nginx
```

---

## Enter a Running Container

WordPress:

```bash
docker exec -it wordpress sh
```

MariaDB:

```bash
docker exec -it mariadb sh
```

NGINX:

```bash
docker exec -it nginx sh
```

---

## Check PID 1

Example:

```bash
docker exec wordpress sh -c \
  'tr "\0" " " < /proc/1/cmdline; echo'
```

For WordPress, PID 1 should be the PHP-FPM master process.

MariaDB should run `mariadbd` as PID 1.

NGINX should run in foreground mode as PID 1.

---

# Logs

View logs for each service:

```bash
docker logs nginx
```

```bash
docker logs wordpress
```

```bash
docker logs mariadb
```

Follow logs continuously:

```bash
docker logs -f wordpress
```

Show only recent logs:

```bash
docker logs --tail 50 wordpress
```

---

# Networking

The services communicate through a custom Docker bridge network.

List networks:

```bash
docker network ls
```

Inspect the Inception network:

```bash
docker network inspect srcs_inception
```

This should show:

```text
nginx
wordpress
mariadb
```

attached to the same bridge network.

---

## Test Docker DNS

From NGINX to WordPress:

```bash
docker exec nginx getent hosts wordpress
```

From WordPress to MariaDB:

```bash
docker exec wordpress getent hosts mariadb
```

Docker resolves service names dynamically.

No container IP addresses should be hardcoded.

---

## Published Ports

Check published ports:

```bash
docker port nginx
docker port wordpress
docker port mariadb
```

Expected behavior:

```text
nginx       -> 443 published
wordpress   -> no published ports
mariadb     -> no published ports
```

Only NGINX should be externally reachable.

---

# Volumes

List Docker volumes:

```bash
docker volume ls
```

The project creates:

```text
srcs_wordpress
srcs_mariadb
```

Inspect them:

```bash
docker volume inspect srcs_wordpress
```

```bash
docker volume inspect srcs_mariadb
```

The volume configuration points to:

```text
/home/mdaghouj/data/wordpress
/home/mdaghouj/data/mariadb
```

---

## Persistence Model

WordPress data:

```text
/home/mdaghouj/data/wordpress
        |
        v
srcs_wordpress
        |
        v
/var/www/html
```

MariaDB data:

```text
/home/mdaghouj/data/mariadb
        |
        v
srcs_mariadb
        |
        v
/var/lib/mysql
```

Containers are disposable.

The persistent data must survive container recreation.

---

## Test Persistence

Create the infrastructure:

```bash
make up
```

Stop and remove containers:

```bash
make down
```

Start again:

```bash
make up
```

The existing WordPress installation and MariaDB database should still be present.

---

# WordPress Debugging

Check whether WordPress is installed:

```bash
docker exec wordpress \
  wp core is-installed \
  --path=/var/www/html \
  --allow-root
```

List users:

```bash
docker exec wordpress \
  wp user list \
  --fields=ID,user_login,roles \
  --path=/var/www/html \
  --allow-root
```

Expected users include:

```text
mdaghouj   administrator
editor     editor
```

---

## PHP-FPM

Check PHP version:

```bash
docker exec wordpress php -v
```

Check PHP-FPM:

```bash
docker exec wordpress php-fpm8.2 -v
```

PHP-FPM listens internally on:

```text
0.0.0.0:9000
```

It is not published to the host.

---

# MariaDB Debugging

Check the MariaDB process:

```bash
docker exec mariadb ps aux
```

Check server availability:

```bash
docker exec mariadb \
  mariadb-admin ping
```

View logs:

```bash
docker logs mariadb
```

MariaDB listens internally on:

```text
3306
```

and must not publish this port to the host.

---

# NGINX Debugging

Check the NGINX configuration:

```bash
docker exec nginx nginx -t
```

Check its process:

```bash
docker exec nginx ps aux
```

View logs:

```bash
docker logs nginx
```

Test the website:

```bash
curl -ks https://mdaghouj.42.fr/
```

Check the page title:

```bash
curl -ks https://mdaghouj.42.fr/ \
  | grep -i '<title>'
```

Expected:

```html
<title>Inception</title>
```

---

# TLS Validation

Test TLS 1.2:

```bash
openssl s_client \
  -connect mdaghouj.42.fr:443 \
  -tls1_2
```

Test TLS 1.3:

```bash
openssl s_client \
  -connect mdaghouj.42.fr:443 \
  -tls1_3
```

Older TLS versions should not be accepted by NGINX.

---

# Image Inspection

List project images:

```bash
docker image ls
```

Expected images:

```text
nginx:1.0
wordpress:1.0
mariadb:1.0
```

Inspect an image:

```bash
docker image inspect wordpress:1.0
```

Verify the operating system inside each running container:

```bash
for c in mariadb wordpress nginx; do
    echo "=== $c ==="
    docker exec "$c" sh -c \
      'grep -E "^(PRETTY_NAME|VERSION_ID)=" /etc/os-release'
done
```

All mandatory containers should report Debian 12.

---

# Restart Policy

The services use:

```text
restart: on-failure
```

Inspect it with:

```bash
docker inspect wordpress \
  --format '{{.HostConfig.RestartPolicy.Name}}'
```

Expected:

```text
on-failure
```

The same can be checked for:

```text
nginx
mariadb
```

---

# Development Workflow

When modifying one service:

1. Edit its Dockerfile, configuration, or initialization script.
2. Validate shell syntax when applicable.
3. Rebuild only that service.
4. Recreate the container.
5. Inspect logs.
6. Test the affected functionality.
7. Run a complete `make re` before considering the implementation final.

Example for WordPress:

```bash
sh -n srcs/requirements/wordpress/tools/init.sh

docker compose -f srcs/docker-compose.yml \
  build wordpress

docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate wordpress

docker logs wordpress
```

---

# Important Development Rules

Do not:

- use the `latest` image tag
- use ready-made service images
- use `network_mode: host`
- use Docker `links`
- hardcode container IP addresses
- store passwords in Dockerfiles
- commit `.env`
- commit secret files
- expose WordPress port `9000`
- expose MariaDB port `3306`
- use fake infinite-loop commands to keep containers alive

Each container should run its real service process in the foreground.

---

# Final Verification

Before considering the mandatory part complete, verify:

```text
[ ] all three images build successfully
[ ] all three containers remain running
[ ] all containers use Debian 12
[ ] NGINX is the only externally exposed service
[ ] HTTPS works on port 443
[ ] TLS 1.2 works
[ ] TLS 1.3 works
[ ] WordPress loads correctly
[ ] both WordPress users exist
[ ] WordPress connects to MariaDB
[ ] Docker DNS works
[ ] named volumes persist data
[ ] secrets are not committed
[ ] passwords are not present in Docker environment metadata
[ ] restart-on-failure works
[ ] make re rebuilds the entire project successfully
```
