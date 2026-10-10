#!/usr/bin/env bash

# ============================================================
# 42 INCEPTION - EVALUATION TEST SUITE
#
# Usage:
#   ./eval.sh
#       Safe/read-only evaluation checks.
#
#   ./eval.sh --full
#       Also performs:
#         - FTP upload test
#         - Health dashboard failure/recovery test
#         - WordPress persistence test using compose down/up
#
# Run from repository root.
# ============================================================

set -u

COMPOSE="docker compose -f srcs/docker-compose.yml"
COMPOSE_FILE="srcs/docker-compose.yml"
ENV_FILE="srcs/.env"

PASS=0
FAIL=0
WARN=0

FULL_MODE=false

if [[ "${1:-}" == "--full" ]]; then
    FULL_MODE=true
fi

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'

    RED='\033[31m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    BLUE='\033[34m'
    CYAN='\033[36m'
    GRAY='\033[90m'
else
    RESET=''
    BOLD=''
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    GRAY=''
fi

# ------------------------------------------------------------
# UI helpers
# ------------------------------------------------------------

header()
{
    clear 2>/dev/null || true

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 42 INCEPTION EVALUATION                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    if $FULL_MODE; then
        echo -e "Mode: ${YELLOW}${BOLD}FULL${RESET}"
    else
        echo -e "Mode: ${GREEN}${BOLD}SAFE / READ-ONLY${RESET}"
    fi

    echo
}

section()
{
    echo
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BLUE}${BOLD}  $1${RESET}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

pass()
{
    ((PASS++))
    echo -e "  ${GREEN}✔ PASS${RESET}  $1"
}

fail()
{
    ((FAIL++))
    echo -e "  ${RED}✘ FAIL${RESET}  $1"

    if [[ $# -ge 2 && -n "$2" ]]; then
        echo -e "          ${GRAY}$2${RESET}"
    fi
}

warn()
{
    ((WARN++))
    echo -e "  ${YELLOW}⚠ WARN${RESET}  $1"
}

info()
{
    echo -e "  ${CYAN}→${RESET} $1"
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

command_exists()
{
    command -v "$1" >/dev/null 2>&1
}

container_running()
{
    local name="$1"

    [[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" == "true" ]]
}

env_value()
{
    local key="$1"

    grep "^${key}=" "$ENV_FILE" 2>/dev/null \
        | head -n1 \
        | cut -d= -f2-
}

wait_for_container()
{
    local container="$1"
    local attempts=15

    while (( attempts > 0 )); do
        if container_running "$container"; then
            return 0
        fi

        sleep 1
        ((attempts--))
    done

    return 1
}

wait_for_http()
{
    local url="$1"
    local attempts=15

    while (( attempts > 0 )); do
        if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
            return 0
        fi

        sleep 1
        ((attempts--))
    done

    return 1
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

header

# ============================================================
# 1. BASIC PROJECT CHECKS
# ============================================================

section "1. PROJECT / DOCKER"

if command_exists docker; then
    pass "docker command exists"
else
    fail "docker command missing"
fi

if docker info >/dev/null 2>&1; then
    pass "Docker daemon is running"
else
    fail "Docker daemon is not reachable"
fi

if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose is available"
else
    fail "Docker Compose unavailable"
fi

if [[ -f "$COMPOSE_FILE" ]]; then
    pass "docker-compose.yml exists"
else
    fail "docker-compose.yml missing"
fi

if [[ -f "$ENV_FILE" ]]; then
    pass "srcs/.env exists"
else
    fail "srcs/.env missing"
fi

if git ls-files --error-unmatch srcs/.env >/dev/null 2>&1; then
    pass "srcs/.env is tracked by Git"
else
    fail "srcs/.env is NOT tracked"
fi

# ============================================================
# 2. SERVICES
# ============================================================

section "2. COMPOSE SERVICES"

EXPECTED_SERVICES=(
    mariadb
    nginx
    redis
    static-site
    wordpress
    adminer
    ftp
    health-dashboard
)

SERVICES="$($COMPOSE config --services 2>/dev/null)"

for service in "${EXPECTED_SERVICES[@]}"; do
    if grep -qx "$service" <<< "$SERVICES"; then
        pass "Compose service exists: $service"
    else
        fail "Missing Compose service: $service"
    fi
done

# ============================================================
# 3. CONTAINERS
# ============================================================

section "3. RUNNING CONTAINERS"

for service in "${EXPECTED_SERVICES[@]}"; do
    if container_running "$service"; then
        pass "$service is running"
    else
        fail "$service is NOT running"
    fi
done

# ============================================================
# 4. IMAGES
# ============================================================

section "4. PROJECT IMAGES"

for image in \
    mariadb:1.0 \
    nginx:1.0 \
    wordpress:1.0 \
    redis:1.0 \
    adminer:1.0 \
    ftp:1.0 \
    static-site:1.0 \
    health-dashboard:1.0
do
    if docker image inspect "$image" >/dev/null 2>&1; then
        pass "Image exists: $image"
    else
        fail "Image missing: $image"
    fi
done

# ============================================================
# 5. DOCKER NETWORK
# ============================================================

section "5. DOCKER NETWORK"

NETWORK="srcs_inception"

if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    pass "Custom network exists: $NETWORK"
else
    fail "Custom network missing: $NETWORK"
fi

for service in "${EXPECTED_SERVICES[@]}"; do

    NETWORKS="$(
        docker inspect "$service" \
            --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
            2>/dev/null
    )"

    if grep -qw "$NETWORK" <<< "$NETWORKS"; then
        pass "$service attached to $NETWORK"
    else
        fail "$service is not attached to $NETWORK"
    fi
done

# ============================================================
# 6. DOCKER DNS
# ============================================================

section "6. DOCKER DNS"

if docker exec nginx getent hosts wordpress >/dev/null 2>&1; then
    pass "nginx resolves wordpress"
else
    fail "nginx cannot resolve wordpress"
fi

if docker exec wordpress getent hosts mariadb >/dev/null 2>&1; then
    pass "wordpress resolves mariadb"
else
    fail "wordpress cannot resolve mariadb"
fi

if docker exec wordpress getent hosts redis >/dev/null 2>&1; then
    pass "wordpress resolves redis"
else
    fail "wordpress cannot resolve redis"
fi

if docker exec adminer getent hosts mariadb >/dev/null 2>&1; then
    pass "adminer resolves mariadb"
else
    fail "adminer cannot resolve mariadb"
fi

# ============================================================
# 7. PID 1
# ============================================================

section "7. PID 1 / REAL SERVICE PROCESS"

check_pid1()
{
    local container="$1"
    local expected="$2"

    local cmd

    cmd="$(
        docker exec "$container" sh -c \
            'tr "\0" " " < /proc/1/cmdline' \
            2>/dev/null
    )"

    if grep -qi "$expected" <<< "$cmd"; then
        pass "$container PID 1: $cmd"
    else
        fail "$container unexpected PID 1" "$cmd"
    fi
}

check_pid1 nginx "nginx"
check_pid1 wordpress "php-fpm"
check_pid1 mariadb "mariadbd"
check_pid1 redis "redis-server"
check_pid1 ftp "vsftpd"
check_pid1 static-site "nginx"
check_pid1 health-dashboard "python3"
check_pid1 adminer "php"

# ============================================================
# 8. HOST PORT EXPOSURE
# ============================================================

section "8. PORT EXPOSURE"

check_published_port()
{
    local container="$1"
    local port="$2"

    if docker port "$container" "$port/tcp" 2>/dev/null | grep -q .; then
        pass "$container publishes $port/tcp"
    else
        fail "$container does NOT publish $port/tcp"
    fi
}

check_not_published()
{
    local container="$1"

    if [[ -z "$(docker port "$container" 2>/dev/null)" ]]; then
        pass "$container has no published host ports"
    else
        fail "$container unexpectedly publishes host ports" \
            "$(docker port "$container" 2>/dev/null)"
    fi
}

check_published_port nginx 443
check_published_port adminer 8080
check_published_port static-site 80
check_published_port health-dashboard 9001
check_published_port ftp 21

check_not_published wordpress
check_not_published mariadb
check_not_published redis

# ============================================================
# 9. NGINX
# ============================================================

section "9. NGINX"

if docker exec nginx nginx -t >/dev/null 2>&1; then
    pass "NGINX configuration syntax valid"
else
    fail "NGINX configuration invalid"
fi

NGINX_LISTEN="$(
    docker exec nginx nginx -T 2>/dev/null \
        | grep -E '^[[:space:]]*listen'
)"

if grep -Eq 'listen[[:space:]]+443' <<< "$NGINX_LISTEN"; then
    pass "NGINX listens on 443"
else
    fail "NGINX does not listen on 443"
fi

if grep -Eq 'listen[[:space:]]+80([[:space:];]|$)' <<< "$NGINX_LISTEN"; then
    fail "NGINX unexpectedly listens on port 80"
else
    pass "Mandatory NGINX does not listen on port 80"
fi

TLS_CONFIG="$(
    docker exec nginx nginx -T 2>/dev/null \
        | grep ssl_protocols \
        | tail -n1
)"

if grep -q 'TLSv1.2' <<< "$TLS_CONFIG" \
    && grep -q 'TLSv1.3' <<< "$TLS_CONFIG"; then

    pass "TLS 1.2 and TLS 1.3 configured"
else
    fail "TLS protocol configuration incorrect" "$TLS_CONFIG"
fi

if grep -qE 'TLSv1([ ;]|$)|TLSv1\.1' <<< "$TLS_CONFIG"; then
    fail "Old TLS protocol appears enabled" "$TLS_CONFIG"
else
    pass "TLS 1.0 / 1.1 disabled"
fi

# ============================================================
# 10. HTTPS
# ============================================================

section "10. HTTPS / CERTIFICATE"

WP_URL="$(env_value WP_URL)"
DOMAIN="${WP_URL#https://}"
DOMAIN="${DOMAIN%%/*}"

if [[ -z "$DOMAIN" ]]; then
    DOMAIN="mdaghouj.42.fr"
fi

HTTP_CODE="$(
    curl \
        -ksS \
        --max-time 5 \
        --resolve "${DOMAIN}:443:127.0.0.1" \
        -o /dev/null \
        -w '%{http_code}' \
        "https://${DOMAIN}/" \
        2>/dev/null
)"

if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    pass "HTTPS website reachable: HTTP $HTTP_CODE"
else
    fail "HTTPS website not reachable" "HTTP code: $HTTP_CODE"
fi

if command_exists openssl; then

    TLS12="$(
        timeout 8 openssl s_client \
            -connect 127.0.0.1:443 \
            -servername "$DOMAIN" \
            -tls1_2 \
            </dev/null 2>&1
    )"

    if grep -q 'TLSv1.2' <<< "$TLS12"; then
        pass "TLS 1.2 handshake succeeds"
    else
        fail "TLS 1.2 handshake failed"
    fi

    TLS13="$(
        timeout 8 openssl s_client \
            -connect 127.0.0.1:443 \
            -servername "$DOMAIN" \
            -tls1_3 \
            </dev/null 2>&1
    )"

    if grep -q 'TLSv1.3' <<< "$TLS13"; then
        pass "TLS 1.3 handshake succeeds"
    else
        fail "TLS 1.3 handshake failed"
    fi

    CERT="$(
        timeout 8 openssl s_client \
            -connect 127.0.0.1:443 \
            -servername "$DOMAIN" \
            </dev/null 2>/dev/null \
            | openssl x509 \
                -noout \
                -subject \
                -issuer \
                -dates \
                2>/dev/null
    )"

    if [[ -n "$CERT" ]]; then
        pass "TLS certificate readable"

        echo "$CERT" \
            | sed 's/^/          /'
    else
        fail "Could not read TLS certificate"
    fi

else
    warn "openssl command unavailable; TLS handshake tests skipped"
fi

# ============================================================
# 11. WORDPRESS
# ============================================================

section "11. WORDPRESS"

if docker exec wordpress \
    wp core is-installed \
    --path=/var/www/html \
    --allow-root \
    >/dev/null 2>&1
then
    pass "WordPress is installed"
else
    fail "WordPress installation check failed"
fi

WP_ADMIN_USER="$(env_value WP_ADMIN_USER)"
WP_USER="$(env_value WP_USER)"

USERS="$(
    docker exec wordpress \
        wp user list \
        --fields=user_login,roles \
        --format=csv \
        --path=/var/www/html \
        --allow-root \
        2>/dev/null
)"

if [[ -n "$WP_ADMIN_USER" ]] \
    && grep -q "^${WP_ADMIN_USER}," <<< "$USERS"; then

    pass "WordPress admin user exists: $WP_ADMIN_USER"
else
    fail "WordPress admin user missing: $WP_ADMIN_USER"
fi

if [[ -n "$WP_USER" ]] \
    && grep -q "^${WP_USER}," <<< "$USERS"; then

    pass "Second WordPress user exists: $WP_USER"
else
    fail "Second WordPress user missing: $WP_USER"
fi

if grep -Ei "^${WP_ADMIN_USER},.*administrator" <<< "$USERS" >/dev/null; then
    pass "$WP_ADMIN_USER has administrator role"
else
    fail "$WP_ADMIN_USER is not administrator"
fi

if grep -Ei "^${WP_ADMIN_USER}$" <<< "$WP_ADMIN_USER" \
    | grep -qiE 'admin|administrator'; then

    fail "Administrator username contains forbidden admin wording"
else
    pass "Administrator username does not contain admin/administrator"
fi

# ============================================================
# 12. MARIADB
# ============================================================

section "12. MARIADB"

if docker exec mariadb sh -c '
    mariadb-admin \
        --user=root \
        --password="$(cat /run/secrets/db_root_password)" \
        ping
' >/dev/null 2>&1
then
    pass "MariaDB responds to ping"
else
    fail "MariaDB ping failed"
fi

DB_TABLES="$(
    docker exec mariadb sh -c '
        mariadb \
            --user="$DB_USER" \
            --password="$(cat /run/secrets/db_password)" \
            "$DB_NAME" \
            -e "SHOW TABLES;"
    ' 2>/dev/null
)"

if grep -q 'wp_' <<< "$DB_TABLES"; then
    pass "WordPress tables exist in MariaDB"
else
    fail "WordPress tables not found"
fi

# ============================================================
# 13. VOLUMES
# ============================================================

section "13. PERSISTENT VOLUMES"

if docker volume inspect srcs_wordpress >/dev/null 2>&1; then
    pass "WordPress named volume exists"
else
    fail "WordPress named volume missing"
fi

if docker volume inspect srcs_mariadb >/dev/null 2>&1; then
    pass "MariaDB named volume exists"
else
    fail "MariaDB named volume missing"
fi

WP_DEVICE="$(
    docker volume inspect srcs_wordpress \
        --format '{{index .Options "device"}}' \
        2>/dev/null
)"

DB_DEVICE="$(
    docker volume inspect srcs_mariadb \
        --format '{{index .Options "device"}}' \
        2>/dev/null
)"

if [[ "$WP_DEVICE" == "/home/mdaghouj/data/wordpress" ]]; then
    pass "WordPress volume backed by $WP_DEVICE"
else
    fail "Unexpected WordPress volume backing path" "$WP_DEVICE"
fi

if [[ "$DB_DEVICE" == "/home/mdaghouj/data/mariadb" ]]; then
    pass "MariaDB volume backed by $DB_DEVICE"
else
    fail "Unexpected MariaDB volume backing path" "$DB_DEVICE"
fi

# ============================================================
# 14. REDIS
# ============================================================

section "14. REDIS BONUS"

if docker exec redis redis-cli ping 2>/dev/null \
    | grep -qx PONG; then

    pass "Redis responds with PONG"
else
    fail "Redis PING failed"
fi

REDIS_STATUS="$(
    docker exec wordpress \
        wp redis status \
        --path=/var/www/html \
        --allow-root \
        2>/dev/null
)"

if grep -q 'Status: Connected' <<< "$REDIS_STATUS"; then
    pass "WordPress Redis object cache connected"
else
    fail "WordPress Redis cache not connected"
fi

REDIS_KEYS="$(
    docker exec redis redis-cli DBSIZE 2>/dev/null \
        | tr -dc '0-9'
)"

if [[ "$REDIS_KEYS" =~ ^[0-9]+$ ]] \
    && (( REDIS_KEYS > 0 )); then

    pass "Redis cache contains $REDIS_KEYS keys"
else
    warn "Redis currently contains no cached keys"
fi

REDIS_STATS="$(
    docker exec redis redis-cli INFO stats 2>/dev/null \
        | grep -E 'keyspace_hits|keyspace_misses'
)"

if grep -q 'keyspace_hits:' <<< "$REDIS_STATS"; then
    pass "Redis cache statistics available"

    echo "$REDIS_STATS" \
        | tr -d '\r' \
        | sed 's/^/          /'
else
    fail "Could not read Redis cache statistics"
fi

# ============================================================
# 15. ADMINER
# ============================================================

section "15. ADMINER BONUS"

ADMINER_CODE="$(
    curl \
        -sS \
        --max-time 5 \
        -o /dev/null \
        -w '%{http_code}' \
        http://127.0.0.1:8080/ \
        2>/dev/null
)"

if [[ "$ADMINER_CODE" == "200" ]]; then
    pass "Adminer responds HTTP 200"
else
    fail "Adminer HTTP check failed" "HTTP $ADMINER_CODE"
fi

if docker exec adminer getent hosts mariadb >/dev/null 2>&1; then
    pass "Adminer resolves MariaDB through Docker DNS"
else
    fail "Adminer cannot resolve MariaDB"
fi

# ============================================================
# 16. STATIC SITE
# ============================================================

section "16. STATIC WEBSITE BONUS"

STATIC_CODE="$(
    curl \
        -sS \
        --max-time 5 \
        -o /dev/null \
        -w '%{http_code}' \
        http://127.0.0.1:8081/ \
        2>/dev/null
)"

if [[ "$STATIC_CODE" == "200" ]]; then
    pass "Static website responds HTTP 200"
else
    fail "Static website failed" "HTTP $STATIC_CODE"
fi

STATIC_TITLE="$(
    curl -sS --max-time 5 \
        http://127.0.0.1:8081/ \
        2>/dev/null \
        | grep -i '<title>' \
        | head -n1
)"

if [[ -n "$STATIC_TITLE" ]]; then
    pass "Static site contains HTML title"
    echo "          $STATIC_TITLE"
else
    fail "Static site title not found"
fi

# ============================================================
# 17. HEALTH DASHBOARD
# ============================================================

section "17. HEALTH DASHBOARD BONUS"

HEALTH_RESPONSE="$(
    curl \
        -sS \
        --max-time 5 \
        http://127.0.0.1:9001/ \
        2>/dev/null
)"

UP_COUNT="$(
    grep -oE 'UP' <<< "$HEALTH_RESPONSE" \
        | wc -l \
        | tr -d ' '
)"

DOWN_COUNT="$(
    grep -oE 'DOWN' <<< "$HEALTH_RESPONSE" \
        | wc -l \
        | tr -d ' '
)"

if [[ "$UP_COUNT" == "7" && "$DOWN_COUNT" == "0" ]]; then
    pass "Health dashboard reports 7 UP"
else
    fail "Health dashboard unexpected status" \
        "UP=$UP_COUNT DOWN=$DOWN_COUNT"
fi

# ============================================================
# 18. FTP BASIC CHECK
# ============================================================

section "18. FTP BONUS"

if timeout 3 bash -c '</dev/tcp/127.0.0.1/21' \
    >/dev/null 2>&1
then
    pass "FTP control port 21 accepts TCP connections"
else
    fail "FTP port 21 unreachable"
fi

# ============================================================
# 19. SECURITY / SUBJECT AUDIT
# ============================================================

section "19. SUBJECT / SECURITY AUDIT"

if grep -RniE \
    'network_mode:[[:space:]]*host|^[[:space:]]*links:|--link' \
    Makefile srcs/ \
    >/tmp/inception_eval_grep 2>/dev/null
then
    fail "Forbidden host networking / Docker links found" \
        "$(cat /tmp/inception_eval_grep)"
else
    pass "No host network / links found"
fi

if grep -RniE \
    'FROM[[:space:]].*:latest|image:[[:space:]].*:latest' \
    srcs/ \
    >/tmp/inception_eval_grep 2>/dev/null
then
    fail "latest tag found" \
        "$(cat /tmp/inception_eval_grep)"
else
    pass "No latest image tag"
fi

if grep -RniE \
    'tail[[:space:]]+-f|sleep[[:space:]]+infinity|while[[:space:]]+true' \
    srcs/ \
    >/tmp/inception_eval_grep 2>/dev/null
then
    fail "Forbidden infinite-loop/container keepalive hack found" \
        "$(cat /tmp/inception_eval_grep)"
else
    pass "No fake container keepalive loops found"
fi

TRACKED_SECRETS="$(
    git ls-files \
        | grep '^secrets/' \
        || true
)"

if [[ -z "$TRACKED_SECRETS" ]]; then
    pass "No secret files tracked by Git"
else
    fail "Secret files are tracked by Git" "$TRACKED_SECRETS"
fi

ENV_BAD="$(
    grep -Ein \
        'password|passwd|secret|token|api[_-]?key' \
        srcs/.env \
        2>/dev/null \
        || true
)"

if [[ -z "$ENV_BAD" ]]; then
    pass "No obvious secrets inside srcs/.env"
else
    fail "Possible secret detected in srcs/.env" "$ENV_BAD"
fi

rm -f /tmp/inception_eval_grep

# ============================================================
# 20. DOCUMENTATION
# ============================================================

section "20. DOCUMENTATION"

for file in README.md USER_DOC.md DEV_DOC.md; do

    if [[ -f "$file" ]]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done

FIRST_LINE="$(head -n1 README.md 2>/dev/null)"

EXPECTED_FIRST_LINE="*This project has been created as part of the 42 curriculum by mdaghouj.*"

if [[ "$FIRST_LINE" == "$EXPECTED_FIRST_LINE" ]]; then
    pass "README mandatory first line correct"
else
    warn "README first line differs from expected text"
fi

# ============================================================
# FULL MODE
# ============================================================

if $FULL_MODE; then

    # --------------------------------------------------------
    # FTP upload test
    # --------------------------------------------------------

    section "21. FULL TEST — FTP UPLOAD"

    FTP_USER="$(env_value FTP_USER)"

    if [[ -r secrets/ftp_password.txt ]]; then

        FTP_PASSWORD="$(cat secrets/ftp_password.txt)"
        FTP_TEST="/tmp/inception-ftp-eval.txt"

        echo "Inception FTP evaluation test" > "$FTP_TEST"

        if curl \
            --fail \
            --silent \
            --show-error \
            --ftp-pasv \
            --user "${FTP_USER}:${FTP_PASSWORD}" \
            -T "$FTP_TEST" \
            ftp://127.0.0.1/inception-ftp-eval.txt \
            >/dev/null 2>&1
        then
            pass "FTP authenticated upload succeeds"

            CONTENT="$(
                docker exec wordpress \
                    cat /var/www/html/inception-ftp-eval.txt \
                    2>/dev/null
            )"

            if [[ "$CONTENT" == "Inception FTP evaluation test" ]]; then
                pass "FTP uploaded file visible inside WordPress volume"
            else
                fail "FTP upload not visible in WordPress"
            fi

            OWNER="$(
                docker exec wordpress \
                    stat -c '%u:%g' \
                    /var/www/html/inception-ftp-eval.txt \
                    2>/dev/null
            )"

            if [[ "$OWNER" == "33:33" ]]; then
                pass "FTP file ownership is 33:33 (www-data)"
            else
                fail "Unexpected FTP file ownership" "$OWNER"
            fi

            docker exec wordpress \
                rm -f /var/www/html/inception-ftp-eval.txt \
                >/dev/null 2>&1

        else
            fail "FTP authenticated upload failed"
        fi

        rm -f "$FTP_TEST"
        unset FTP_PASSWORD

    else
        warn "FTP password secret missing; upload test skipped"
    fi

    # --------------------------------------------------------
    # Health dashboard failure detection
    # --------------------------------------------------------

    section "22. FULL TEST — HEALTH FAILURE DETECTION"

    info "Temporarily stopping Adminer..."

    docker stop adminer >/dev/null 2>&1

    sleep 1

    HEALTH_RESPONSE="$(
        curl \
            -sS \
            --max-time 5 \
            http://127.0.0.1:9001/ \
            2>/dev/null
    )"

    UP_COUNT="$(
        grep -oE 'UP' <<< "$HEALTH_RESPONSE" \
            | wc -l \
            | tr -d ' '
    )"

    DOWN_COUNT="$(
        grep -oE 'DOWN' <<< "$HEALTH_RESPONSE" \
            | wc -l \
            | tr -d ' '
    )"

    if [[ "$UP_COUNT" == "6" && "$DOWN_COUNT" == "1" ]]; then
        pass "Dashboard detects stopped Adminer: 6 UP / 1 DOWN"
    else
        fail "Dashboard did not detect stopped Adminer" \
            "UP=$UP_COUNT DOWN=$DOWN_COUNT"
    fi

    info "Restarting Adminer..."

    docker start adminer >/dev/null 2>&1

    wait_for_container adminer || true
    wait_for_http http://127.0.0.1:8080 || true

    sleep 1

    HEALTH_RESPONSE="$(
        curl \
            -sS \
            --max-time 5 \
            http://127.0.0.1:9001/ \
            2>/dev/null
    )"

    UP_COUNT="$(
        grep -oE 'UP' <<< "$HEALTH_RESPONSE" \
            | wc -l \
            | tr -d ' '
    )"

    DOWN_COUNT="$(
        grep -oE 'DOWN' <<< "$HEALTH_RESPONSE" \
            | wc -l \
            | tr -d ' '
    )"

    if [[ "$UP_COUNT" == "7" && "$DOWN_COUNT" == "0" ]]; then
        pass "Dashboard recovers after Adminer restart: 7 UP"
    else
        fail "Dashboard did not recover" \
            "UP=$UP_COUNT DOWN=$DOWN_COUNT"
    fi

    # --------------------------------------------------------
    # Persistence
    # --------------------------------------------------------

    section "23. FULL TEST — WORDPRESS PERSISTENCE"

    MARKER="/var/www/html/.inception-eval-persistence"

    if docker exec wordpress \
        sh -c "echo persistence-ok > '$MARKER'" \
        >/dev/null 2>&1
    then
        pass "Created persistence marker in WordPress volume"
    else
        fail "Could not create persistence marker"
    fi

    info "Running docker compose down..."

    $COMPOSE down >/dev/null 2>&1

    info "Starting stack again..."

    $COMPOSE up -d >/dev/null 2>&1

    info "Waiting for WordPress..."

    wait_for_container wordpress || true

    ATTEMPTS=30

    while (( ATTEMPTS > 0 )); do

        if docker exec wordpress \
            test -f "$MARKER" \
            >/dev/null 2>&1
        then
            break
        fi

        sleep 1
        ((ATTEMPTS--))
    done

    CONTENT="$(
        docker exec wordpress \
            cat "$MARKER" \
            2>/dev/null \
            || true
    )"

    if [[ "$CONTENT" == "persistence-ok" ]]; then
        pass "WordPress data survived container recreation"
    else
        fail "WordPress persistence test failed"
    fi

    docker exec wordpress \
        rm -f "$MARKER" \
        >/dev/null 2>&1 \
        || true
fi

# ============================================================
# SUMMARY
# ============================================================

section "FINAL RESULT"

TOTAL=$((PASS + FAIL + WARN))

echo
printf "  %-14s %s\n" "Total checks:" "$TOTAL"
printf "  ${GREEN}%-14s %s${RESET}\n" "Passed:" "$PASS"
printf "  ${YELLOW}%-14s %s${RESET}\n" "Warnings:" "$WARN"
printf "  ${RED}%-14s %s${RESET}\n" "Failed:" "$FAIL"

echo

if (( FAIL == 0 )); then

    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║          EVALUATION CHECK PASSED         ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    exit 0
else

    echo -e "${RED}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       SOME EVALUATION CHECKS FAILED      ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    exit 1
fi

