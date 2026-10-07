# Inception Developer Documentation

This document explains how to set up, build, inspect, debug, and maintain the complete Inception infrastructure.

# Architecture

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

```text
NGINX
WordPress + PHP-FPM
MariaDB
```

The bonus services are:

```text
Redis
FTP
Adminer
Static Website
Health Dashboard
```

The main application flow is:

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
   | MariaDB protocol :3306
   v
MariaDB
```

WordPress also uses Redis:

```text
WordPress
   |
   | Redis :6379
   v
Redis
```

The bonus web services are:

```text
Adminer           :8080
Static Website    :8081
Health Dashboard  :9001
```

The FTP service uses:

```text
21
21100-21110
```

---

# Prerequisites

The project runs inside a Virtual Machine.

Required tools:

```text
Docker
Docker Compose
GNU Make
```

Verify them:

```bash
docker --version
docker compose version
make --version
```

Check that the Docker daemon is available:

```bash
docker info
```

---

# Repository Structure

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
│   ├── wp_user_password.txt
│   └── ftp_password.txt
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
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/
        │       └── init.sh
        │
        ├── redis/
        │   ├── Dockerfile
        │   └── conf/
        │       └── redis.conf
        │
        ├── adminer/
        │   └── Dockerfile
        │
        ├── ftp/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── vsftpd.conf
        │   └── tools/
        │       └── init.sh
        │
        ├── static-site/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── default.conf
        │   └── site/
        │       ├── index.html
        │       └── style.css
        │
        └── health-dashboard/
            ├── Dockerfile
            └── app/
                └── server.py
```

---

# Environment Configuration

Non-sensitive configuration is stored in:

```text
srcs/.env
```

Current variables include:

```env
DB_NAME=wordpress
DB_USER=wpuser

WP_URL=https://mdaghouj.42.fr
WP_TITLE=Inception

WP_ADMIN_USER=mdaghouj
WP_ADMIN_EMAIL=mdaghouj@student.1337.ma

WP_USER=editor
WP_USER_EMAIL=editor@example.com

FTP_USER=ftpuser
```

Passwords must not be stored in `.env`.

---

# Secrets

Sensitive credentials are stored under:

```text
secrets/
```

Required files:

```text
db_password.txt
db_root_password.txt
wp_admin_password.txt
wp_user_password.txt
ftp_password.txt
```

Docker Compose mounts the required secrets inside containers under:

```text
/run/secrets/
```

Examples:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
/run/secrets/ftp_password
```

Verify that secrets remain ignored:

```bash
git status --ignored
```

Check one explicitly:

```bash
git check-ignore secrets/db_password.txt
```

Neither:

```text
srcs/.env
```

nor:

```text
secrets/*.txt
```

must be committed to Git.

---

# Domain Configuration

The WordPress domain is:

```text
mdaghouj.42.fr
```

Inside the VM, `/etc/hosts` should contain:

```text
127.0.0.1 mdaghouj.42.fr
```

Verify:

```bash
grep mdaghouj.42.fr /etc/hosts
```

---

# Persistent Storage

Persistent application data is stored under:

```text
/home/mdaghouj/data
```

The two mandatory directories are:

```text
/home/mdaghouj/data/mariadb
/home/mdaghouj/data/wordpress
```

The Makefile creates them automatically.

They can also be created manually:

```bash
mkdir -p \
  /home/mdaghouj/data/mariadb \
  /home/mdaghouj/data/wordpress
```

Only MariaDB and WordPress require persistent volumes.

Redis is used only as a cache and does not require persistent storage.

Adminer, the static site, and the health dashboard are stateless.

---

# Build and Launch

From the repository root:

```bash
make
```

or:

```bash
make up
```

This:

1. creates persistent data directories
2. builds the images
3. creates the Docker network
4. creates named volumes
5. starts all containers

---

# Build Only

```bash
make build
```

Equivalent command:

```bash
docker compose -f srcs/docker-compose.yml build
```

---

# Stop the Infrastructure

```bash
make down
```

Equivalent:

```bash
docker compose -f srcs/docker-compose.yml down
```

Persistent WordPress and MariaDB data remain intact.

---

# Full Cleanup

```bash
make fclean
```

This removes:

- containers
- Compose network
- named volumes
- locally built project images
- WordPress persistent files
- MariaDB persistent files

This operation is destructive.

---

# Rebuild From Scratch

```bash
make re
```

A full `make re` should recreate all eight services successfully.

This is an important final reproducibility test.

---

# Docker Images

The complete project uses:

```text
mariadb:1.0
wordpress:1.0
nginx:1.0
redis:1.0
adminer:1.0
ftp:1.0
static-site:1.0
health-dashboard:1.0
```

List them:

```bash
docker image ls
```

All project images are built from custom Dockerfiles.

---

# Container Status

Check the complete stack:

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

All should normally be:

```text
Up
```

---

# Logs

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

Static site:

```bash
docker logs static-site
```

Health dashboard:

```bash
docker logs health-dashboard
```

Follow logs continuously:

```bash
docker logs -f wordpress
```

---

# Container Inspection

List containers:

```bash
docker ps
```

Include stopped containers:

```bash
docker ps -a
```

Inspect a container:

```bash
docker inspect wordpress
```

Enter a container:

```bash
docker exec -it wordpress sh
```

The same pattern works with the other services.

---

# PID 1

Each container should run its real service process as PID 1.

Check:

```bash
for c in \
  mariadb \
  wordpress \
  nginx \
  redis \
  adminer \
  ftp \
  static-site \
  health-dashboard
do
    echo "=== $c ==="

    docker exec "$c" sh -c \
      'tr "\0" " " < /proc/1/cmdline; echo'
done
```

Examples include:

```text
mariadbd --user=mysql

php-fpm: master process

nginx: master process nginx -g daemon off;

redis-server ...

php -S 0.0.0.0:8080

/usr/sbin/vsftpd /etc/vsftpd.conf

nginx: master process nginx -g daemon off;

python3 /app/server.py
```

---

# Networking

All services communicate through the custom Docker bridge network:

```text
srcs_inception
```

List networks:

```bash
docker network ls
```

Inspect:

```bash
docker network inspect srcs_inception
```

Docker service names act as DNS names.

Examples:

```text
nginx
wordpress
mariadb
redis
adminer
ftp
static-site
health-dashboard
```

---

# Docker DNS Tests

NGINX to WordPress:

```bash
docker exec nginx getent hosts wordpress
```

WordPress to MariaDB:

```bash
docker exec wordpress getent hosts mariadb
```

WordPress to Redis:

```bash
docker exec wordpress getent hosts redis
```

Adminer to MariaDB:

```bash
docker exec adminer getent hosts mariadb
```

The health dashboard also uses these service names for its checks.

Container IP addresses must not be hardcoded.

---

# Published Ports

Check all published ports:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected host-facing ports:

```text
443             NGINX / WordPress
8080            Adminer
8081            Static Website
9001            Health Dashboard
21              FTP control
21100-21110     FTP passive mode
```

Internal-only ports:

```text
9000    WordPress / PHP-FPM
3306    MariaDB
6379    Redis
```

---

# NGINX

Check configuration:

```bash
docker exec nginx nginx -t
```

Inspect active listeners:

```bash
docker exec nginx nginx -T 2>/dev/null \
  | grep -E '^[[:space:]]*listen'
```

The mandatory NGINX container should listen only on:

```text
443
```

Check TLS protocols:

```bash
docker exec nginx nginx -T 2>/dev/null \
  | grep ssl_protocols
```

Only:

```text
TLSv1.2 TLSv1.3
```

should be enabled.

---

# WordPress / PHP-FPM

Check WordPress installation:

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

Expected accounts include:

```text
mdaghouj   administrator
editor     editor
```

Check PHP:

```bash
docker exec wordpress php -v
```

Check PHP-FPM:

```bash
docker exec wordpress php-fpm8.2 -v
```

PHP-FPM listens internally on:

```text
9000
```

---

# Redis

Redis provides the WordPress object cache.

Redis configuration disables persistent storage:

```text
save ""
appendonly no
```

The service remains internal on:

```text
redis:6379
```

Check Redis:

```bash
docker exec redis redis-cli ping
```

Expected:

```text
PONG
```

Check WordPress Redis status:

```bash
docker exec wordpress \
  wp redis status \
  --path=/var/www/html \
  --allow-root
```

Expected:

```text
Status: Connected
```

Check cached objects:

```bash
docker exec redis redis-cli DBSIZE
```

Inspect cache statistics:

```bash
docker exec redis redis-cli INFO stats \
  | grep -E 'keyspace_hits|keyspace_misses'
```

The WordPress container includes the `php-redis` extension and Redis Object Cache plugin.

---

# MariaDB

Check availability:

```bash
docker exec mariadb \
  mariadb-admin ping
```

Inspect the configured database and users:

```bash
docker exec mariadb sh -c '
mariadb \
  --user=root \
  --password="$(cat /run/secrets/db_root_password)" \
  -e "
    SHOW DATABASES;
    SELECT User, Host FROM mysql.user;
  "
'
```

MariaDB listens internally on:

```text
3306
```

It must not be published directly to the host.

---

# Adminer

Adminer runs using PHP's built-in HTTP server:

```text
php -S 0.0.0.0:8080
```

Test:

```bash
curl -I http://127.0.0.1:8080
```

Expected:

```text
HTTP/1.1 200 OK
```

Adminer connects to MariaDB using:

```text
mariadb:3306
```

Database login:

```text
System:   MySQL
Server:   mariadb
Username: DB_USER
Password: db_password secret
Database: DB_NAME
```

---

# FTP

The FTP service uses `vsftpd`.

Configuration:

```text
srcs/requirements/ftp/conf/vsftpd.conf
```

FTP control port:

```text
21
```

Passive range:

```text
21100-21110
```

Anonymous access is disabled.

The FTP container mounts:

```text
srcs_wordpress
```

at:

```text
/var/www/html
```

which is the same WordPress volume used by the WordPress container.

Check the mount:

```bash
docker inspect ftp \
  --format '{{range .Mounts}}{{println .Type .Name .Destination}}{{end}}'
```

Expected application mount:

```text
volume srcs_wordpress /var/www/html
```

Check the FTP user:

```bash
docker exec ftp id ftpuser
```

Its UID/GID should match `www-data`.

---

# FTP Transfer Test

Load credentials:

```bash
FTP_USER="$(grep '^FTP_USER=' srcs/.env | cut -d= -f2-)"
FTP_PASSWORD="$(cat secrets/ftp_password.txt)"
```

Create a file:

```bash
echo "FTP test" > /tmp/ftp-test.txt
```

Upload:

```bash
curl --fail --show-error \
  --ftp-pasv \
  --user "$FTP_USER:$FTP_PASSWORD" \
  -T /tmp/ftp-test.txt \
  ftp://127.0.0.1/ftp-test.txt
```

Verify from WordPress:

```bash
docker exec wordpress \
  cat /var/www/html/ftp-test.txt
```

Check ownership:

```bash
docker exec wordpress \
  ls -ln /var/www/html/ftp-test.txt
```

Expected UID/GID:

```text
33 33
```

Clean up:

```bash
docker exec wordpress rm -f /var/www/html/ftp-test.txt
rm -f /tmp/ftp-test.txt
unset FTP_PASSWORD
```

---

# Static Website

The static site is served by its own NGINX container.

Test:

```bash
curl -s http://127.0.0.1:8081 \
  | grep '<title>'
```

Expected:

```html
<title>Inception</title>
```

Inspect listeners:

```bash
docker exec static-site nginx -T 2>/dev/null \
  | grep -E '^[[:space:]]*listen'
```

Expected:

```text
listen 80;
listen [::]:80;
```

The static-site container exposes host port:

```text
8081
```

---

# Health Dashboard

The custom health dashboard is implemented with Python's standard library.

It checks:

```text
nginx:443
wordpress:9000
mariadb:3306
redis:6379
ftp:21
adminer:8080
static-site:80
```

It does not mount:

```text
/var/run/docker.sock
```

and does not require privileged access.

Test:

```bash
curl -s http://127.0.0.1:9001 \
  | grep -oE 'UP|DOWN' \
  | sort | uniq -c
```

With every monitored service running:

```text
7 UP
```

To test failure detection:

```bash
docker stop adminer
```

Check again:

```bash
curl -s http://127.0.0.1:9001 \
  | grep -oE 'UP|DOWN' \
  | sort | uniq -c
```

Expected:

```text
1 DOWN
6 UP
```

Restore Adminer:

```bash
docker start adminer
```

The dashboard should return to:

```text
7 UP
```

---

# Volumes

List project volumes:

```bash
docker volume ls | grep srcs_
```

Expected:

```text
srcs_mariadb
srcs_wordpress
```

Inspect:

```bash
docker volume inspect srcs_mariadb
docker volume inspect srcs_wordpress
```

Backing directories:

```text
/home/mdaghouj/data/mariadb
/home/mdaghouj/data/wordpress
```

---

# Persistence Test

Start:

```bash
make up
```

Remove containers:

```bash
make down
```

Start again:

```bash
make up
```

WordPress and MariaDB state should remain intact.

The WordPress initialization script should not reinstall WordPress when persistent data already exists.

---

# Restart Policy

All project services use:

```text
restart: on-failure
```

Check one:

```bash
docker inspect wordpress \
  --format '{{.HostConfig.RestartPolicy.Name}}'
```

Expected:

```text
on-failure
```

---

# Service-Specific Rebuilds

A single service can be rebuilt without rebuilding everything.

Example:

```bash
docker compose -f srcs/docker-compose.yml \
  build redis
```

Then recreate it:

```bash
docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate redis
```

The same workflow works for:

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

---

# Development Workflow

When changing one service:

1. edit its Dockerfile, configuration, or source
2. validate syntax where applicable
3. rebuild only that image
4. recreate its container
5. inspect logs
6. verify the service directly
7. verify dependent services
8. run a complete `make re` before final validation

Example for WordPress:

```bash
sh -n srcs/requirements/wordpress/tools/init.sh

docker compose -f srcs/docker-compose.yml \
  build wordpress

docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate wordpress

docker logs wordpress
```

Example for FTP:

```bash
sh -n srcs/requirements/ftp/tools/init.sh

docker compose -f srcs/docker-compose.yml \
  build ftp

docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate ftp
```

Example for the health dashboard:

```bash
python3 -m py_compile \
  srcs/requirements/health-dashboard/app/server.py

docker compose -f srcs/docker-compose.yml \
  build health-dashboard

docker compose -f srcs/docker-compose.yml \
  up -d --force-recreate health-dashboard
```

---

# Fedora Host Access

The VM uses VirtualBox NAT.

Services exposed by the VM can be forwarded to the Fedora host using VirtualBox NAT rules.

Examples:

```text
Host :443   -> VM :443
Host :8080  -> VM :8080
Host :8081  -> VM :8081
Host :9001  -> VM :9001
```

For WordPress, the Fedora host `/etc/hosts` contains:

```text
127.0.0.1 mdaghouj.42.fr
```

The website can then be opened using:

```text
https://mdaghouj.42.fr
```

Admin panel:

```text
https://mdaghouj.42.fr/wp-admin
```

Adminer:

```text
http://127.0.0.1:8080
```

Static website:

```text
http://127.0.0.1:8081
```

Health dashboard:

```text
http://127.0.0.1:9001
```

FTP additionally requires forwarding the FTP control and passive ports when accessed from the host.

---

# Important Development Rules

Do not:

- use `latest`
- use ready-made service images instead of the project Dockerfiles
- use host networking
- use Docker links
- hardcode container IP addresses
- commit `.env`
- commit passwords
- store passwords in Dockerfiles
- expose mandatory internal service ports unnecessarily
- run fake infinite loops to keep containers alive
- mount the Docker socket into the health dashboard
- use `chmod 777` on the WordPress volume

Each service should run its real process in the foreground.

---

# Final Verification

Before submission, verify:

```text
[ ] make re completes successfully

Mandatory:
[ ] mariadb is running
[ ] wordpress is running
[ ] nginx is running
[ ] NGINX is the only mandatory public entrypoint
[ ] HTTPS works on port 443
[ ] TLS 1.2 works
[ ] TLS 1.3 works
[ ] WordPress loads correctly
[ ] both WordPress users exist
[ ] WordPress connects to MariaDB
[ ] persistent volumes survive container recreation
[ ] secrets are excluded from Git
[ ] Docker DNS works
[ ] restart-on-failure works

Bonus:
[ ] redis is running
[ ] WordPress Redis status is Connected
[ ] Redis records cache hits/misses
[ ] FTP authentication works
[ ] FTP uploads reach the WordPress volume
[ ] adminer is running
[ ] Adminer can access MariaDB
[ ] static-site is running
[ ] static website loads on port 8081
[ ] health-dashboard is running
[ ] dashboard reports 7 UP
[ ] stopping a monitored service reports DOWN
[ ] restarting it returns to UP
```
