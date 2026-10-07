# Inception User Documentation

This document explains how to run and use the Inception infrastructure.

## Services

The project provides three mandatory services:

- **NGINX**: HTTPS entrypoint for the website.
- **WordPress + PHP-FPM**: hosts and executes the WordPress application.
- **MariaDB**: stores the WordPress database.

The request flow is:

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

Only NGINX is accessible directly from outside the Docker network.

---

## Starting the Project

From the root of the repository:

```bash
make
```

or:

```bash
make up
```

This will:

- create the persistent data directories
- build the Docker images if necessary
- create the Docker network and volumes
- start all mandatory containers

---

## Stopping the Project

To stop and remove the running containers while preserving persistent data:

```bash
make down
```

The WordPress files and MariaDB database remain available for the next startup.

---

## Restarting the Project

After stopping it:

```bash
make up
```

The existing WordPress website and database should be restored automatically from the persistent volumes.

---

## Full Reset

To completely remove the infrastructure and its persistent data:

```bash
make fclean
```

This removes the containers, network, volumes, locally built images, and the project data stored under:

```text
/home/mdaghouj/data
```

To rebuild everything from scratch:

```bash
make re
```

> `make fclean` and `make re` are destructive operations. Existing WordPress and MariaDB data will be deleted.

---

## Accessing the Website

The WordPress website is available at:

```text
https://mdaghouj.42.fr
```

The WordPress administration panel is available at:

```text
https://mdaghouj.42.fr/wp-admin
```

The project uses a self-signed TLS certificate, so the browser may display a certificate warning.

---

## Credentials

Sensitive credentials are stored locally in:

```text
secrets/
```

The project uses:

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

These files contain the passwords used by MariaDB and WordPress.

They must not be committed to Git.

Non-sensitive configuration is stored in:

```text
srcs/.env
```

This includes values such as:

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

Passwords should be changed by editing the appropriate local secret file.

When changing credentials for an already initialized installation, keep in mind that changing only the secret file does not automatically change credentials already stored inside WordPress or MariaDB.

For a completely fresh installation using the new credentials, the infrastructure can be recreated with:

```bash
make re
```

This deletes the existing persistent data.

---

## Checking Service Status

To see the state of all containers:

```bash
docker compose -f srcs/docker-compose.yml ps
```

The three mandatory containers should be running:

```text
mariadb
wordpress
nginx
```

---

## Checking the Website

From inside the VM:

```bash
curl -ks https://mdaghouj.42.fr/ | grep -i '<title>'
```

A working installation should return:

```html
<title>Inception</title>
```

---

## Checking NGINX

View the NGINX logs:

```bash
docker logs nginx
```

Check its configuration:

```bash
docker exec nginx nginx -t
```

A valid configuration should report that the syntax is successful.

---

## Checking WordPress

View WordPress container logs:

```bash
docker logs wordpress
```

Check the WordPress users:

```bash
docker exec wordpress \
  wp user list \
  --fields=ID,user_login,roles \
  --path=/var/www/html \
  --allow-root
```

The installation should contain:

- the configured administrator account
- the second WordPress user

---

## Checking MariaDB

View MariaDB logs:

```bash
docker logs mariadb
```

A healthy MariaDB container should remain running and report that it is ready for connections.

The MariaDB port is internal to the Docker network and is not exposed to the host.

---

## Checking Published Ports

Run:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Only NGINX should publish a host port:

```text
443 -> 443
```

WordPress port `9000` and MariaDB port `3306` must remain internal.

---

## Persistent Data

Persistent data is stored on the VM under:

```text
/home/mdaghouj/data/wordpress
/home/mdaghouj/data/mariadb
```

This allows the website and database to survive normal container deletion and recreation.

Running:

```bash
make down
```

preserves this data.

Running:

```bash
make fclean
```

deletes it.
