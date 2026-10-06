#!/bin/sh

set -e

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"
INIT_MARKER="$DATADIR/.inception_initialized"

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

chown -R mysql:mysql "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB data directory..."

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR"
fi

if [ ! -f "$INIT_MARKER" ]; then
    echo "Configuring MariaDB..."

    DB_PASSWORD="$(cat /run/secrets/db_password)"
    DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

    mariadbd \
        --user=mysql \
        --skip-networking \
        --socket="$SOCKET" &

    TEMP_PID=$!

    until mariadb-admin \
        --user=root \
        --socket="$SOCKET" \
        ping --silent
    do
        if ! kill -0 "$TEMP_PID" 2>/dev/null; then
            echo "Temporary MariaDB server failed to start."
            exit 1
        fi

        sleep 1
    done

    mariadb \
        --user=root \
        --socket="$SOCKET" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;

CREATE USER IF NOT EXISTS '${DB_USER}'@'%'
IDENTIFIED BY '${DB_PASSWORD}';

ALTER USER '${DB_USER}'@'%'
IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${DB_NAME}\`.*
TO '${DB_USER}'@'%';

SET PASSWORD FOR 'root'@'localhost'
= PASSWORD('${DB_ROOT_PASSWORD}');
SQL

    mariadb-admin \
        --user=root \
        --socket="$SOCKET" \
        shutdown

    wait "$TEMP_PID"

    touch "$INIT_MARKER"

    echo "MariaDB configuration complete."
fi

exec "$@"
