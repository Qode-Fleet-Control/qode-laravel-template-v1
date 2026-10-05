#!/bin/sh
# Container start: make the app runnable on a fresh workspace, then serve on $PORT.
set -e

# No APP_KEY from the fleet (a fresh workspace) -> make one for this container rather
# than fail every request with "No application encryption key has been specified".
# Set APP_KEY in the environment to keep sessions across restarts.
if [ -z "${APP_KEY:-}" ]; then
  APP_KEY="base64:$(php -r 'echo base64_encode(random_bytes(32));')"
  export APP_KEY
  echo "entrypoint: APP_KEY was empty; generated one for this container"
fi

# The fleet's Postgres when it injects DATABASE_URL; otherwise the stock SQLite file.
if [ -n "${DATABASE_URL:-}" ] && [ -z "${DB_URL:-}" ]; then
  export DB_CONNECTION=pgsql DB_URL="$DATABASE_URL"
fi
if [ "${DB_CONNECTION:-sqlite}" = sqlite ]; then
  touch database/database.sqlite
fi

php artisan migrate --force
php artisan optimize

export SERVER_NAME=":${PORT:-8000}"
exec frankenphp run --config /etc/frankenphp/Caddyfile
