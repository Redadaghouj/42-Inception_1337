#!/bin/sh
set -e

WP_DIR="/var/www/html"

# Copy WordPress files on first startup

if [ ! -f "$WP_DIR/wp-settings.php" ]; then
    echo "Installing WordPress files..."
    cp -a /usr/src/wordpress/. "$WP_DIR/"
fi

# Create wp-config.php once

if [ ! -f "$WP_DIR/wp-config.php" ]; then
    echo "Creating wp-config.php..."

    cat > "$WP_DIR/wp-config.php" <<'EOF'
<?php

define('DB_NAME', getenv('DB_NAME'));
define('DB_USER', getenv('DB_USER'));
define('DB_PASSWORD', trim(file_get_contents('/run/secrets/db_password')));
define('DB_HOST', 'mariadb:3306');

define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

$table_prefix = 'wp_';

define('WP_DEBUG', false);

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
EOF
fi

chown -R www-data:www-data "$WP_DIR"

# Wait for MariaDB

echo "Waiting for MariaDB..."

attempt=0

until php -r '
$db = @new mysqli(
    "mariadb",
    getenv("DB_USER"),
    trim(file_get_contents("/run/secrets/db_password")),
    getenv("DB_NAME"),
    3306
);

exit($db->connect_errno ? 1 : 0);
'
do
    attempt=$((attempt + 1))

    if [ "$attempt" -ge 30 ]; then
        echo "MariaDB did not become ready."
        exit 1
    fi

    sleep 2
done

echo "MariaDB is ready."

# Install WordPress once

if ! wp core is-installed \
    --path="$WP_DIR" \
    --allow-root 2>/dev/null
then
    echo "Installing WordPress..."

    wp core install \
        --path="$WP_DIR" \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root \
        --prompt=admin_password \
        < /run/secrets/wp_admin_password \
	> /dev/null

    echo "WordPress installed successfully."
fi

# Create second user once

if ! wp user get "$WP_USER" \
    --path="$WP_DIR" \
    --allow-root \
    >/dev/null 2>&1
then
    echo "Creating WordPress user: $WP_USER"

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --role=editor \
        --path="$WP_DIR" \
        --allow-root \
        --prompt=user_pass \
        < /run/secrets/wp_user_password
    	> /dev/null

    echo "WordPress user created: $WP_USER"
fi

chown -R www-data:www-data "$WP_DIR"

exec "$@"
