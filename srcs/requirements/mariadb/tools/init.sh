#!/bin/sh

set -e

DATADIR="/var/lib/mysql"

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

chown -R mysql:mysql "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB data directory..."

    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR"
fi

exec "$@"
