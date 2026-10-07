#!/bin/sh

set -e

FTP_ROOT="/var/www/html"
SECURE_CHROOT="/var/run/vsftpd/empty"

# Prepare vsftpd runtime directory

mkdir -p "$SECURE_CHROOT"

chown root:root /var/run/vsftpd
chown root:root "$SECURE_CHROOT"

chmod 755 /var/run/vsftpd
chmod 555 "$SECURE_CHROOT"


# Validate configuration

if [ -z "$FTP_USER" ]; then
    echo "FTP_USER is not set."
    exit 1
fi

if [ ! -f /run/secrets/ftp_password ]; then
    echo "FTP password secret is missing."
    exit 1
fi


# Create FTP user

if ! id "$FTP_USER" >/dev/null 2>&1; then
    echo "Creating FTP user: $FTP_USER"

    useradd \
        -M \
        -o \
        -u "$(id -u www-data)" \
        -g "$(id -g www-data)" \
        -d "$FTP_ROOT" \
        -s /bin/sh \
        "$FTP_USER"
fi


# Set FTP password

FTP_PASSWORD="$(cat /run/secrets/ftp_password)"

echo "$FTP_USER:$FTP_PASSWORD" | chpasswd

unset FTP_PASSWORD


# Start vsftpd

exec "$@"
