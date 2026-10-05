# Laravel template

Provisioned from [`Qode-Fleet-Control/fleet-template-v1`](https://github.com/Qode-Fleet-Control/fleet-template-v1) — the fleet
lifecycle contract (`bin/`, `fleet.conf`, `compose.yaml`, deploy workflows) with the
stock Laravel 13 starter laid on top, served by FrankenPHP.

## Origin

    docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w <php8.4 + composer:2 image> \
      composer create-project laravel/laravel qode-laravel-template-v1 --prefer-dist --no-interaction
    npm install --package-lock-only --ignore-scripts     # the skeleton ships no package-lock.json

Generated 2026-10-05 (laravel/laravel skeleton, laravel/framework ^13.17, PHP 8.4.26 —
the same PHP the image runs). `vendor/`, the generated `.env` (it held a dev APP_KEY) and
`database/database.sqlite` were removed; `composer.lock` and `package-lock.json` are kept.

## Run it

**On the fleet** — nothing to do: the coordinator runs `bin/run`, which (docker runtime)
does `docker compose build` then `docker compose up --remove-orphans` in the foreground.
The app listens on `0.0.0.0:$PORT` and answers `HEALTH_PATH=/up` (Laravel's built-in
health route); `/` is the stock welcome page.

**With docker**

    PORT=8000 bin/run              # or: docker compose up --build
    curl localhost:8000/up

**Without docker** (PHP 8.3+ with pdo_sqlite, composer, Node 22+):

    FLEET_RUNTIME=process PORT=8000 bin/run
    # = composer install && npm ci; npm run build; .env from .env.example + key:generate;
    #   migrate (SQLite); php artisan serve --host=0.0.0.0 --port=$PORT

| step | process runtime | docker runtime |
|---|---|---|
| install | `composer install --no-interaction && npm ci` | — |
| build | `npm run build`, `.env` + key, `migrate --force` | `docker compose build` |
| start | `php artisan serve --host=0.0.0.0 --port=$PORT` | `docker compose up --remove-orphans` |

## How the container works

- `Dockerfile`: a Node stage builds the Vite bundle; the runtime stage is
  `dunglas/frankenphp:1-php8.4-bookworm` (+ pdo_pgsql, intl, zip, pcntl) with
  `composer install --no-dev`, running as the non-root user `app`.
- `docker/entrypoint.sh`, at container start:
  - generates an `APP_KEY` when none is set (set `APP_KEY` to keep sessions across restarts);
  - uses the fleet's Postgres when `DATABASE_URL` is set (`DB_CONNECTION=pgsql`,
    `DB_URL=$DATABASE_URL`), else the stock SQLite file inside the container;
  - `php artisan migrate --force` and `php artisan optimize`;
  - serves with FrankenPHP's stock Caddyfile, `SERVER_NAME=":$PORT"` (plain HTTP on
    the runtime `$PORT`), document root `public/`.
- No database service in `compose.yaml`: SQLite needs none, and the fleet brings Postgres.

## Deviations from the stock generator output, and why

- `bootstrap/app.php`: `$middleware->trustProxies(at: '*')` — the fleet terminates TLS at
  its edge; without this, asset and redirect URLs come out `http://` on an `https://` page.
- `package-lock.json` added (generated, not hand-edited) so the image build is `npm ci`.
- Added `Dockerfile`, `docker/entrypoint.sh`, `compose.yaml`, `.dockerignore`,
  `fleet.conf`, `bin/`, `.github/workflows/`, `docs/fleet-lifecycle.md`; `.gitignore`
  gained `.fleet/` and `.fleet-deploy.log`; this README replaces the stock one.

## Verified

2026-10-05, on docker 29.8.2:

- `migrate.py audit` → READY
- `verify.sh <dir> 46301` → `run=200 restart=200 containers_after_stop=0` (exit 0)
- `/` → 200 and a built Vite asset under `/build/assets/` → 200.

See `docs/fleet-lifecycle.md` for the lifecycle scripts.
