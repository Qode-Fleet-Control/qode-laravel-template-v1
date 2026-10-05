# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry.
#
# Laravel on FrankenPHP (the Caddy-based PHP app server Laravel Octane supports):
#   - assets: Node builds the Vite bundle into public/build.
#   - runtime: PHP 8.4 + composer deps; docker/entrypoint.sh prepares the app
#     (APP_KEY, database, migrations, caches) and serves 0.0.0.0:$PORT, the PORT
#     read from the environment when the container STARTS.
FROM node:22-slim AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY vite.config.js ./
COPY resources ./resources
COPY public ./public
RUN npm run build

FROM dunglas/frankenphp:1-php8.4-bookworm AS runtime
RUN install-php-extensions pdo_pgsql intl zip pcntl
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
COPY --from=assets /app/public/build ./public/build
RUN composer dump-autoload --optimize --no-dev --no-interaction \
 && useradd -r -u 10001 -d /app app \
 && mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
 && chown -R app:app storage bootstrap/cache database /config/caddy /data/caddy \
 && chmod +x docker/entrypoint.sh
ARG BUILD_ID=""
ENV PORT=8000 SERVER_ROOT=/app/public APP_ENV=production APP_DEBUG=false LOG_CHANNEL=stderr BUILD_ID=$BUILD_ID
USER app
EXPOSE 8000
ENTRYPOINT ["docker/entrypoint.sh"]
