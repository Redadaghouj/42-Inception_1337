# Inception User Documentation

This document explains how to start, stop, access, and verify the Inception infrastructure.

# Services

The complete project contains eight services:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
health-dashboard
```

The three mandatory services are:

- NGINX
- WordPress with PHP-FPM
- MariaDB

The bonus services are:

- Redis object cache
- FTP server
- Adminer
- Static website
- Health dashboard

---

# Starting the Project

From the repository root:

```bash
make
```

or:

```bash
make up
```

This will:

- create the persistent data directories
- build the required Docker images
- create the Docker network
- create the named volumes
- start all containers

Check the running services with:

```bash
docker compose -f srcs/docker-compose.yml ps
```

All eight containers should be running.

---

# Stopping the Project

To stop the infrastructure while preserving persistent data:

```bash
make down
```

This removes the containers and Compose network but preserves:

- WordPress files
- MariaDB data
- Docker named volumes

---

# Full Reset

To completely remove the project containers, volumes, images, and persistent WordPress/MariaDB data:

```bash
make fclean
```

This operation is destructive.

To rebuild everything from scratch:

```bash
make re
```

---

# WordPress Website

The main WordPress website is available at:

```text
https://mdaghouj.42.fr
```

The WordPress administration panel is available at:

```text
https://mdaghouj.42.fr/wp-admin
```

The project uses a self-signed TLS certificate, so the browser may display a certificate warning.

The WordPress administrator account is configured through:

```text
srcs/.env
```

The administrator password is stored in:

```text
secrets/wp_admin_password.txt
```

The second WordPress user password is stored in:

```text
secrets/wp_user_password.txt
```

---

# Redis

Redis is used as the WordPress object cache.

Redis is internal to the Docker network and is not directly exposed to the host.

To check the Redis connection:

```bash
docker exec wordpress \
  wp redis status \
  --path=/var/www/html \
  --allow-root
```

A working setup should report:

```text
Status: Connected
```

To inspect the number of cached keys:

```bash
docker exec redis redis-cli DBSIZE
```

To inspect cache activity:

```bash
docker exec redis redis-cli INFO stats \
  | grep -E 'keyspace_hits|keyspace_misses'
```

---

# Adminer

Adminer provides a browser interface for MariaDB.

It is available inside the VM on:

```text
http://127.0.0.1:8080
```

When accessing it from the Fedora host, VirtualBox port forwarding must map host port `8080` to VM port `8080`.

Adminer login values:

```text
System:   MySQL
Server:   mariadb
Username: value of DB_USER from srcs/.env
Password: value of secrets/db_password.txt
Database: value of DB_NAME from srcs/.env
```

The server field must be:

```text
mariadb
```

and not:

```text
localhost
```

because Adminer and MariaDB run in different containers.

---

# FTP Server

The FTP server provides access to the WordPress website volume.

The FTP username is configured in:

```text
srcs/.env
```

using:

```text
FTP_USER
```

The FTP password is stored in:

```text
secrets/ftp_password.txt
```

The FTP server exposes:

```text
21
21100-21110
```

Port `21` is used for the FTP control connection.

Ports `21100-21110` are used for passive FTP transfers.

Anonymous FTP access is disabled.

The FTP container shares the same WordPress named volume as the WordPress container.

Files uploaded through FTP therefore appear directly under:

```text
/var/www/html
```

inside WordPress.

---

# Static Website

The bonus static website is available inside the VM at:

```text
http://127.0.0.1:8081
```

When using the Fedora host, VirtualBox port forwarding must map host port `8081` to VM port `8081`.

The static website is independent from WordPress and does not use MariaDB.

---

# Health Dashboard

The custom health dashboard is available inside the VM at:

```text
http://127.0.0.1:9001
```

When using the Fedora host, VirtualBox port forwarding must map host port `9001` to VM port `9001`.

The dashboard checks:

```text
NGINX
WordPress
MariaDB
Redis
FTP
Adminer
Static Site
```

Each service is displayed as:

```text
UP
```

or:

```text
DOWN
```

The dashboard performs fresh network checks whenever the page is requested.

---

# Credentials

Non-sensitive configuration is stored in:

```text
srcs/.env
```

Examples include:

```text
DB_NAME
DB_USER

WP_URL
WP_TITLE

WP_ADMIN_USER
WP_ADMIN_EMAIL

WP_USER
WP_USER_EMAIL

FTP_USER
```

Sensitive credentials are stored under:

```text
secrets/
```

The project uses:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
secrets/ftp_password.txt
```

These files must never be committed to Git.

Changing a secret file does not necessarily change credentials already stored in an existing WordPress or MariaDB installation.

For a completely fresh installation using updated credentials:

```bash
make re
```

This deletes the existing persistent WordPress and MariaDB state.

---

# Checking Container Status

Run:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected services:

```text
mariadb
wordpress
nginx
redis
adminer
ftp
static-site
health-dashboard
```

Each service should normally show:

```text
Up
```

---

# Checking Logs

NGINX:

```bash
docker logs nginx
```

WordPress:

```bash
docker logs wordpress
```

MariaDB:

```bash
docker logs mariadb
```

Redis:

```bash
docker logs redis
```

Adminer:

```bash
docker logs adminer
```

FTP:

```bash
docker logs ftp
```

Static website:

```bash
docker logs static-site
```

Health dashboard:

```bash
docker logs health-dashboard
```

---

# Checking the Main Website

Run:

```bash
curl -ks https://mdaghouj.42.fr/ \
  | grep -i '<title>'
```

Expected:

```html
<title>Inception</title>
```

---

# Checking Adminer

Run:

```bash
curl -I http://127.0.0.1:8080
```

A healthy service should return:

```text
HTTP/1.1 200 OK
```

---

# Checking the Static Website

Run:

```bash
curl -s http://127.0.0.1:8081 \
  | grep '<title>'
```

Expected:

```html
<title>Inception</title>
```

---

# Checking the Health Dashboard

Run:

```bash
curl -s http://127.0.0.1:9001 \
  | grep -oE 'UP|DOWN' \
  | sort | uniq -c
```

With every monitored service running, the result should be:

```text
7 UP
```

---

# Persistent Data

WordPress and MariaDB data are stored under:

```text
/home/mdaghouj/data/wordpress
/home/mdaghouj/data/mariadb
```

Normal container recreation does not delete this data.

Running:

```bash
make down
```

preserves it.

Running:

```bash
make fclean
```

deletes it.

---

# Fedora Host Access

The Virtual Machine uses VirtualBox NAT.

To access services from the Fedora host, VirtualBox NAT port-forwarding rules are required.

The ports used by the project are:

```text
443    WordPress HTTPS
8080   Adminer
8081   Static Website
9001   Health Dashboard
21     FTP control
21100-21110 FTP passive ports
```

The WordPress domain should also resolve on the host using:

```text
127.0.0.1 mdaghouj.42.fr
```

in:

```text
/etc/hosts
```

The main website can then be opened from the Fedora host at:

```text
https://mdaghouj.42.fr
```

and the administration panel at:

```text
https://mdaghouj.42.fr/wp-admin
```
