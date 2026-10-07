*This project has been created as part of the 42 curriculum by mdaghouj.*

# Inception

## Description

Inception is a system administration project whose goal is to build and manage a small containerized infrastructure using Docker Compose inside a Virtual Machine.

The project contains three mandatory services:

- NGINX
- WordPress with PHP-FPM
- MariaDB

Each service runs inside its own dedicated container and is built from a custom Dockerfile.

The mandatory service images are based on Debian 12.

The infrastructure follows this architecture:

```text
Browser
   |
   | HTTPS :443
   v
NGINX
   |
   | FastCGI
   v
WordPress + PHP-FPM :9000
   |
   | MariaDB protocol
   v
MariaDB :3306
```

NGINX is the only entrypoint exposed to the host.

WordPress/PHP-FPM and MariaDB are reachable only through the internal Docker network.

The project uses:

- Docker Compose for orchestration
- custom Dockerfiles for every service
- a custom Docker bridge network
- Docker named volumes for persistent data
- environment variables for non-sensitive configuration
- secret files for passwords
- TLS for HTTPS
- foreground service processes
- idempotent initialization scripts

---

## Architecture

### Request flow

When a client requests the website:

```text
Client
   |
   | HTTPS
   v
NGINX :443
   |
   | FastCGI
   v
PHP-FPM :9000
   |
   | executes WordPress PHP
   v
WordPress
   |
   | SQL / MariaDB protocol
   v
MariaDB :3306
```

NGINX does not execute PHP itself.

Instead, PHP requests are forwarded to PHP-FPM through the FastCGI protocol.

WordPress then communicates with MariaDB to retrieve and modify application data.

---

## Services

### NGINX

NGINX is the only public entrypoint into the infrastructure.

Its responsibilities are:

- listening on port `443`
- handling HTTPS
- terminating TLS
- accepting only TLS 1.2 and TLS 1.3
- serving static WordPress files
- forwarding PHP requests to PHP-FPM using FastCGI

NGINX reaches PHP-FPM through:

```text
wordpress:9000
```

The hostname `wordpress` is resolved by Docker's internal DNS.

NGINX runs in the foreground using:

```text
nginx -g daemon off;
```

This allows NGINX to remain the main container process instead of daemonizing into the background.

---

### WordPress + PHP-FPM

The WordPress container contains:

- WordPress
- PHP 8.2
- PHP-FPM
- WP-CLI
- the PHP extensions required by WordPress

PHP-FPM listens internally on:

```text
0.0.0.0:9000
```

Port `9000` is not published to the host.

NGINX communicates with PHP-FPM using:

```text
wordpress:9000
```

over the custom Docker bridge network.

The WordPress container startup script performs the following initialization:

1. Checks whether WordPress files are already present.
2. Copies WordPress files into `/var/www/html` on first startup.
3. Creates `wp-config.php` when necessary.
4. Waits for MariaDB to become reachable.
5. Checks whether WordPress is already installed.
6. Installs WordPress using WP-CLI if necessary.
7. Creates the required second WordPress user if it does not already exist.
8. Fixes the WordPress file ownership.
9. Starts PHP-FPM in the foreground.

The initialization is idempotent.

Restarting or recreating the WordPress container does not reinstall WordPress or duplicate users when persistent data already exists.

---

### MariaDB

MariaDB runs inside its own dedicated container.

It does not contain NGINX or WordPress.

MariaDB listens internally on:

```text
0.0.0.0:3306
```

Port `3306` is not published to the host.

Its initialization script:

1. Creates the required runtime directories.
2. Initializes the MariaDB data directory when it has not been initialized before.
3. Starts a temporary MariaDB server without network access.
4. Creates the WordPress database.
5. Creates the WordPress database user.
6. Grants the required privileges.
7. Configures the root password.
8. Stops the temporary server.
9. Marks initialization as completed.
10. Starts MariaDB normally in the foreground.

The initialization is designed to run only when required.

Existing database data is preserved across container recreation.

---

## Docker Images

The mandatory Docker image names match their corresponding service names:

```text
nginx:1.0
wordpress:1.0
mariadb:1.0
```

Each image is built locally from its own Dockerfile.

No ready-made NGINX, WordPress, or MariaDB service image is used.

The service Dockerfiles use:

```text
debian:12-slim
```

as their base image.

The `latest` tag is not used.

---

## Networking

The three mandatory containers communicate through a custom Docker bridge network:

```text
srcs_inception
```

The network contains:

```text
nginx
wordpress
mariadb
```

Docker provides internal DNS resolution for service names.

Therefore NGINX can reach WordPress using:

```text
wordpress:9000
```

and WordPress can reach MariaDB using:

```text
mariadb:3306
```

No container IP address is hardcoded.

Container IP addresses can change when containers are recreated, while service names remain stable.

The project does not use:

```text
network_mode: host
```

and does not use:

```text
links:
```

or the legacy `--link` mechanism.

---

## Ports

Only NGINX publishes a port to the VM host:

```text
Host :443
   |
   v
NGINX :443
```

PHP-FPM port `9000` remains internal:

```text
NGINX
   |
   v
wordpress:9000
```

MariaDB port `3306` also remains internal:

```text
WordPress
   |
   v
mariadb:3306
```

Therefore:

```text
443   exposed to host
9000  internal only
3306  internal only
```

---

## TLS

NGINX uses HTTPS on port `443`.

The NGINX configuration allows:

```text
TLS 1.2
TLS 1.3
```

Older TLS versions are rejected.

The project uses a locally generated self-signed certificate for:

```text
mdaghouj.42.fr
```

Because the certificate is self-signed, browsers and tools may display a trust warning unless the certificate is manually trusted.

---

## Domain

The website domain is:

```text
mdaghouj.42.fr
```

Inside the VM, it is mapped locally using `/etc/hosts`:

```text
127.0.0.1 mdaghouj.42.fr
```

The website is therefore available at:

```text
https://mdaghouj.42.fr
```

The WordPress administration panel is available at:

```text
https://mdaghouj.42.fr/wp-admin
```

---

## Persistent Storage

The project uses two Docker named volumes:

```text
srcs_wordpress
srcs_mariadb
```

The WordPress volume is mounted inside the WordPress and NGINX containers at:

```text
/var/www/html
```

The MariaDB volume is mounted inside the MariaDB container at:

```text
/var/lib/mysql
```

The physical data is stored on the VM under:

```text
/home/mdaghouj/data/wordpress
/home/mdaghouj/data/mariadb
```

The resulting storage flow is:

```text
/home/mdaghouj/data/wordpress
        |
        v
Docker named volume
srcs_wordpress
        |
        v
/var/www/html
```

and:

```text
/home/mdaghouj/data/mariadb
        |
        v
Docker named volume
srcs_mariadb
        |
        v
/var/lib/mysql
```

Deleting a container does not delete its persistent data.

When containers are recreated, they mount the same named volumes and recover the existing WordPress and MariaDB state.

---

## Environment Variables and Secrets

Non-sensitive configuration is stored using environment variables.

The project uses a `.env` file located at:

```text
srcs/.env
```

Examples of non-sensitive configuration include:

```text
DB_NAME
DB_USER

WP_URL
WP_TITLE

WP_ADMIN_USER
WP_ADMIN_EMAIL

WP_USER
WP_USER_EMAIL
```

Passwords are not stored in `.env`.

Sensitive values are stored in separate secret files under:

```text
secrets/
```

The project currently uses secret files for:

```text
db_password.txt
db_root_password.txt
wp_admin_password.txt
wp_user_password.txt
```

Inside the appropriate containers, these secrets are available under:

```text
/run/secrets/
```

For example:

```text
/run/secrets/db_password
```

The secret files are mounted read-only.

The `.env` file and secret files are excluded from Git.

No password is stored in the Dockerfiles.

---

## WordPress Users

The WordPress database contains two users.

The administrator account is:

```text
mdaghouj
```

Its username does not contain:

```text
admin
administrator
```

The second WordPress user is:

```text
editor
```

with the WordPress `editor` role.

The users are created automatically during the initial WordPress setup.

---

## Project Structure

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

The `.env` file and files inside `secrets/` are required locally but must not be committed to Git.

---

# Instructions

## Prerequisites

The project must run inside a Virtual Machine.

The VM requires:

- Docker
- Docker Compose
- GNU Make

The project expects the following persistent storage location:

```text
/home/mdaghouj/data
```

The Makefile automatically creates:

```text
/home/mdaghouj/data/mariadb
/home/mdaghouj/data/wordpress
```

when the infrastructure is started.

Before starting the project, the local `.env` and secret files must be configured.

---

## Build and Start

From the root of the repository:

```bash
make
```

The default target starts the project.

The equivalent explicit command is:

```bash
make up
```

This:

1. creates the required data directories
2. builds the Docker images when necessary
3. creates the Docker network
4. creates the Docker named volumes
5. creates and starts the containers

---

## Build Only

To build the images without starting the infrastructure:

```bash
make build
```

---

## Stop the Infrastructure

```bash
make down
```

This removes:

- the project containers
- the project Docker network

It preserves:

- Docker named volumes
- WordPress files
- MariaDB data
- locally built images

---

## Clean

```bash
make clean
```

The current `clean` target performs the same safe runtime cleanup as `make down`.

Persistent data is preserved.

---

## Full Cleanup

```bash
make fclean
```

This is destructive.

It removes:

- project containers
- project network
- Docker named volumes
- locally built project images
- `/home/mdaghouj/data/mariadb`
- `/home/mdaghouj/data/wordpress`

After `fclean`, the WordPress website and database persistent state are deleted.

---

## Complete Rebuild

```bash
make re
```

This performs a full cleanup and starts the infrastructure again from zero.

The process recreates:

- images
- containers
- network
- named volumes
- MariaDB database
- WordPress installation
- WordPress users

---

## Check Running Containers

```bash
docker compose -f srcs/docker-compose.yml ps
```

The mandatory services should be:

```text
mariadb
wordpress
nginx
```

---

## View Logs

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

---

## Access the Website

Open:

```text
https://mdaghouj.42.fr
```

Administration panel:

```text
https://mdaghouj.42.fr/wp-admin
```

A certificate warning may appear because the TLS certificate is self-signed.

---

# Technical Comparisons

## Virtual Machines vs Docker

A Virtual Machine virtualizes an entire machine environment.

A VM contains:

- virtual hardware
- its own operating system
- its own userspace
- its own kernel environment

Docker containers work differently.

Containers isolate processes using Linux technologies such as:

- namespaces
- cgroups
- filesystem isolation
- network namespaces

Containers on the same Docker host share the host kernel.

In this project the hierarchy is:

```text
Physical Computer
       |
       v
Virtual Machine
       |
       v
Docker Engine
       |
       +-- NGINX container
       |
       +-- WordPress container
       |
       +-- MariaDB container
```

The VM provides an isolated environment for the complete Inception project.

Docker then provides lightweight isolation between the individual services inside that VM.

---

## Secrets vs Environment Variables

Environment variables are useful for runtime configuration.

Examples include:

```text
database name
database username
website URL
WordPress site title
WordPress usernames
email addresses
```

However, container environment variables can easily be inspected using Docker metadata.

Therefore passwords should not be stored there.

This project uses:

```text
Non-sensitive configuration
        |
        v
environment variables

Sensitive credentials
        |
        v
secret files
        |
        v
/run/secrets/*
```

This separates configuration from confidential credentials.

---

## Docker Network vs Host Network

A Docker bridge network creates an isolated network namespace for containers.

Containers receive their own network interfaces and IP addresses.

Docker also provides internal DNS, allowing services to communicate using names such as:

```text
wordpress
mariadb
nginx
```

instead of hardcoded IP addresses.

For example:

```text
nginx
  |
  v
wordpress:9000
```

and:

```text
wordpress
   |
   v
mariadb:3306
```

Host networking behaves differently.

With host networking, the container directly uses the host network namespace.

That reduces network isolation and bypasses the normal Docker bridge model.

This project uses a custom Docker bridge network and does not use host networking.

---

## Docker Volumes vs Bind Mounts

A Docker named volume is a Docker-managed storage object.

For example:

```text
srcs_wordpress
srcs_mariadb
```

A container references the volume by name instead of directly referencing a host filesystem path.

A direct bind mount instead maps a specific host path directly into the container.

For example:

```text
/host/path:/container/path
```

For the mandatory persistent WordPress and MariaDB storage, this project uses Docker named volumes.

The named volumes are configured with Docker's local volume driver so their physical storage ends up under:

```text
/home/mdaghouj/data
```

This provides:

- Docker-managed named volume resources
- predictable host-side data locations
- persistence independent of container lifetime

---

# Validation

The mandatory infrastructure has been tested for the following behavior.

## Images

- custom Dockerfiles are used
- image names match service names
- Debian 12 is used as the service base
- the `latest` tag is not used

## Containers

- NGINX runs in its own container
- WordPress/PHP-FPM runs in its own container
- MariaDB runs in its own container
- real service processes run in the foreground
- fake keep-alive commands are not used

## Networking

- a custom Docker bridge network is used
- Docker service-name DNS works
- NGINX reaches WordPress through `wordpress:9000`
- WordPress reaches MariaDB through `mariadb:3306`
- host networking is not used
- Docker links are not used

## Ports

- port `443` is exposed
- port `9000` remains internal
- port `3306` remains internal
- NGINX is the only external entrypoint

## TLS

- TLS 1.2 works
- TLS 1.3 works
- older TLS versions are rejected

## WordPress

- WordPress installs automatically
- the administrator account is created
- the second user is created
- the administrator username follows the project restriction
- PHP-FPM serves WordPress correctly through FastCGI

## MariaDB

- MariaDB initializes automatically
- the WordPress database is created
- the WordPress database user is created
- WordPress can authenticate to MariaDB
- MariaDB runs as the container's foreground service

## Persistence

The following state survives container deletion and recreation:

- WordPress website files
- WordPress users
- WordPress database
- MariaDB data

## Restart Behaviour

The containers use a restart-on-failure policy.

Crash recovery has been tested by deliberately terminating a service process and verifying that Docker restarts the container.

## Security

The project has been checked to ensure:

- `.env` is ignored by Git
- secret files are ignored by Git
- passwords are not stored in Dockerfiles
- passwords are not stored in container environment variables
- current secret values are not present in tracked repository files

## Reproducibility

The complete infrastructure has been deleted and rebuilt from zero using:

```bash
make re
```

The rebuilt stack successfully recreates:

- MariaDB
- WordPress
- both WordPress users
- Docker volumes
- Docker network
- NGINX
- HTTPS website access

---

# Bonus Services

The project also implements all bonus services defined by the Inception subject.

## Redis Object Cache

Redis is used as an object cache for WordPress.

```text
WordPress
    |
    | Redis :6379
    v
Redis
```

Redis runs in its own dedicated container and is accessible only through the internal Docker network.

WordPress uses:

- the PHP Redis extension
- the Redis Object Cache plugin
- the Docker hostname `redis`
- port `6379`

Redis is used only as a cache. Persistence is disabled because MariaDB remains the persistent source of truth.

The Redis port is not exposed to the host.

---

## FTP Server

A dedicated FTP container provides access to the WordPress website files.

The FTP container and WordPress container share the same Docker named volume:

```text
FTP
 |
 v
srcs_wordpress
 ^
 |
WordPress
```

The FTP server uses `vsftpd`.

It exposes:

```text
21
21100-21110
```

Port `21` is used for the FTP control connection.

Ports `21100-21110` are used for passive FTP data connections.

The FTP user uses the same filesystem UID and GID as `www-data`, allowing uploaded files to remain accessible to WordPress without using unsafe permissions such as `chmod 777`.

Anonymous FTP access is disabled.

---

## Adminer

Adminer provides a lightweight web interface for MariaDB.

It runs in its own dedicated container and is exposed on:

```text
http://localhost:8080
```

Adminer connects to MariaDB through the internal Docker network using:

```text
mariadb:3306
```

Adminer does not require its own database or persistent volume.

---

## Static Website

A separate static showcase website is provided as a bonus service.

It uses:

- HTML
- CSS
- NGINX

The static website runs in its own container and is exposed on:

```text
http://localhost:8081
```

NGINX runs in the foreground as PID 1.

The static website does not require a database or persistent volume.

---

## Health Dashboard

The additional service chosen for the final bonus is a custom infrastructure health dashboard.

It is implemented in Python using only the standard library.

The dashboard monitors:

```text
NGINX
WordPress / PHP-FPM
MariaDB
Redis
FTP
Adminer
Static Website
```

It checks the services through the internal Docker network using Docker service-name DNS.

Examples:

```text
nginx:443
wordpress:9000
mariadb:3306
redis:6379
ftp:21
adminer:8080
static-site:80
```

The dashboard is exposed on:

```text
http://localhost:9001
```

Each request performs live network checks and reports every service as either:

```text
UP
DOWN
```

The dashboard does not use the Docker socket and does not require privileged access.

I chose this service because the infrastructure contains several independent services. The dashboard provides a single place to check their availability while also demonstrating Docker networking and service-name DNS.

---

# Complete Architecture

With all bonus services enabled, the project contains eight containers:

```text
                         Browser
                            |
          +-----------------+-----------------+
          |                 |                 |
        :443              :8080             :8081
          |                 |                 |
          v                 v                 v
        NGINX            Adminer         Static Site
          |                 |
          | FastCGI         |
          v                 |
   WordPress + PHP-FPM      |
      |          |          |
      |          |          |
      v          v          |
   MariaDB     Redis <------+
      ^
      |
    Adminer


WordPress Volume
       ^
       |
      FTP


Health Dashboard :9001
       |
       +--> NGINX
       +--> WordPress
       +--> MariaDB
       +--> Redis
       +--> FTP
       +--> Adminer
       +--> Static Site
```

The complete service list is:

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

All services run in dedicated containers.

Services communicate through the custom Docker bridge network where required.

---

# Bonus Validation

The complete bonus infrastructure was tested after a clean rebuild using:

```bash
make re
```

All eight containers successfully started from a clean state.

## Redis

Redis caching was verified using:

```bash
docker exec wordpress \
  wp redis status \
  --path=/var/www/html \
  --allow-root
```

Redis was confirmed to contain cached WordPress objects.

Cache activity was also verified using:

```bash
docker exec redis redis-cli INFO stats \
  | grep -E 'keyspace_hits|keyspace_misses'
```

Both cache hits and misses increased while WordPress requests were performed.

---

## FTP

FTP authentication and file transfer were tested successfully.

A file uploaded through FTP appeared immediately inside:

```text
/var/www/html
```

in the WordPress container because both containers use the same `srcs_wordpress` volume.

Uploaded files retained UID and GID:

```text
33:33
```

corresponding to `www-data`.

Anonymous FTP access was also verified to be rejected.

---

## Adminer

Adminer was verified to return:

```text
HTTP 200
```

It successfully resolves the MariaDB service using Docker DNS:

```text
mariadb
```

The WordPress database and its tables can be accessed through the Adminer interface.

---

## Static Website

The static website was verified through:

```bash
curl http://127.0.0.1:8081
```

Its NGINX process runs as PID 1:

```text
nginx -g daemon off;
```

The website is served on:

```text
http://localhost:8081
```

---

## Health Dashboard

The health dashboard was tested with all services running:

```text
7 UP
```

One service was then stopped manually.

The dashboard immediately changed to:

```text
6 UP
1 DOWN
```

After restarting the service, the dashboard returned to:

```text
7 UP
```

The dashboard process runs as PID 1:

```text
python3 /app/server.py
```

This confirms that the dashboard performs real live network checks rather than displaying static service states.

---

# Resources

The following documentation and references were used while learning, implementing, and validating the project:

- Docker documentation
  - container lifecycle
  - Dockerfiles
  - image layers
  - volumes
  - networking
  - restart policies

- Docker Compose documentation
  - services
  - networks
  - volumes
  - secrets
  - build configuration

- Debian documentation
  - package management
  - Debian release information
  - service configuration

- NGINX documentation
  - server configuration
  - TLS
  - FastCGI
  - foreground execution

- PHP documentation
  - PHP-FPM
  - FPM pools
  - FastCGI configuration
  - PHP extensions

- MariaDB documentation
  - database initialization
  - users
  - privileges
  - server configuration

- WordPress documentation
  - WordPress installation
  - configuration
  - users and roles

- WP-CLI documentation
  - `wp core install`
  - `wp core is-installed`
  - `wp user create`
  - `wp user get`
  - `wp user list`

- OpenSSL documentation
  - X.509 certificates
  - private keys
  - self-signed certificates

- Linux documentation
  - processes
  - PID 1
  - signals
  - sockets
  - namespaces

---

## Use of AI

AI was used mainly as a learning, debugging, and review tool during the project.

AI was used to:

- clarify Docker, networking, FastCGI, PHP-FPM, TLS, and persistence concepts
- discuss architecture and implementation decisions
- review configuration files and initialization scripts
- help analyze build and runtime errors
- suggest useful validation and debugging commands
- review the final implementation against the project subject

All commands, configuration changes, tests, and validation were performed manually.

AI suggestions were treated as guidance. The official Inception subject and the actual runtime behavior of the project were used as the final source of truth.
