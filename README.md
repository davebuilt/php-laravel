# PHP Laravel Base Images

Reusable Docker base images for Laravel development with Claude Code and code-server.

> **Note:** This is a personal project shared for convenience. Use at your own risk.
> No support is provided - issues and PRs may be ignored.

## Quick Start

```bash
# Build all versions
./build.sh

# Build specific version
./build.sh 8.4

# Rebuild without cache
./build.sh --no-cache
```

## Available Tags

Images are published to GitHub Container Registry:

| Tag | Description |
|-----|-------------|
| `ghcr.io/davebuilt/php-laravel:8.2-base` | PHP 8.2 production image |
| `ghcr.io/davebuilt/php-laravel:8.2-dev` | PHP 8.2 with Claude Code + code-server |
| `ghcr.io/davebuilt/php-laravel:8.3-base` | PHP 8.3 production image |
| `ghcr.io/davebuilt/php-laravel:8.3-dev` | PHP 8.3 with Claude Code + code-server |
| `ghcr.io/davebuilt/php-laravel:8.4-base` | PHP 8.4 production image |
| `ghcr.io/davebuilt/php-laravel:8.4-dev` | PHP 8.4 with Claude Code + code-server |

## What's Included

### Base Stage (`-base`)
- PHP-FPM with common Laravel extensions
- Extensions: pdo_mysql, zip, exif, pcntl, mbstring, xml, soap, dom, gd, redis
- Composer 2
- SQLite (for testing)
- Image optimisation tools (jpegoptim, optipng, pngquant, gifsicle, webp)
- Runs as `www` user (configurable UID/GID)

### Dev Stage (`-dev`)
Everything in base, plus:
- Claude Code CLI
- code-server (VS Code in browser)
- Node.js 20.x
- Supervisor (process management)
- Development tools: just, vim, nano, htop, tmux, ripgrep, fd, jq, tree, fzf
- Custom bash prompt and shell aliases (see below)

### Shell Environment (Dev Stage)

The dev container includes a custom `.bashrc` with an informative prompt, shell aliases, and tool integrations.

#### Prompt

A two-line prompt that shows your Laravel app name, working directory, and git status:

```
[MyApp] ~/app/Models (main *+?)
$
```

- **App name** (cyan): Read from your Laravel `.env` `APP_NAME`, falls back to `laravel`
- **Directory** (blue): `/var/www` is shortened to `~` since it's the project root
- **Git branch** (green=clean, yellow=dirty): `*` unstaged, `+` staged, `?` untracked
- **`$` prompt**: Green on success, red when the last command failed

#### Aliases

| Alias | Command | Category |
|-------|---------|----------|
| `art` | `php artisan` | Laravel |
| `tinker` | `php artisan tinker` | Laravel |
| `fresh` | `php artisan migrate:fresh --seed` | Laravel |
| `seed` | `php artisan db:seed` | Laravel |
| `routes` | `php artisan route:list` | Laravel |
| `serve` | `php artisan serve` | Laravel |
| `sail` | `vendor/bin/sail` | Laravel |
| `pest` | `vendor/bin/pest` | Laravel |
| `pint` | `vendor/bin/pint` | Laravel |
| `ci` | `composer install` | Composer |
| `cu` | `composer update` | Composer |
| `cr` | `composer require` | Composer |
| `cda` | `composer dump-autoload` | Composer |
| `gs` | `git status` | Git |
| `gl` | `git log --oneline -20` | Git |
| `gd` | `git diff` | Git |
| `gds` | `git diff --staged` | Git |
| `t` | `php artisan test` | Testing |
| `tf` | `php artisan test --filter` | Testing |
| `tp` | `php artisan test --parallel` | Testing |
| `dev` | `npm run dev` | npm |
| `build` | `npm run build` | npm |
| `watch` | `npm run dev -- --watch` | npm |
| `ll` | `ls -alF --color=auto` | Directory |
| `la` | `ls -A --color=auto` | Directory |
| `..` / `...` | `cd ..` / `cd ../..` | Navigation |
| `cls` | `clear` | Navigation |

#### Tool Integrations

- **bat**: Used as `MANPAGER` for syntax-highlighted man pages
- **fzf**: `Ctrl+R` for fuzzy history search, `Ctrl+T` for file search, `Alt+C` for directory navigation — all powered by `fd`
- **Coloured man pages**: `LESS_TERMCAP` variables for colour in `less`

#### Shell Options

- 10,000 line history with timestamps, no duplicates, append mode
- Case-insensitive globbing, `cd` typo correction, recursive `**` globs
- Bash completion enabled

## Usage

### Option 1: Use Pre-built Image

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/davebuilt/php-laravel:8.2-dev
    volumes:
      - ./:/var/www
    environment:
      CODE_SERVER_ENABLED: "true"
      CODE_PASSWORD: "your-password"
    ports:
      - "8080:8080"
```

### Option 2: Build with Custom UID/GID

Best for development - matches your host user to avoid permission issues:

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: ~/docker-bases/php-laravel
      target: dev
      args:
        PHP_VERSION: "8.2"
        USER_ID: ${USER_ID:-1000}
        GROUP_ID: ${GROUP_ID:-1000}
    volumes:
      - ./:/var/www
    environment:
      CODE_SERVER_ENABLED: "true"
      CODE_PASSWORD: "your-password"
```

### Option 3: Extend for Project-Specific Needs

For projects needing additional PHP extensions:

```dockerfile
# project/docker/Dockerfile
ARG PHP_VERSION=8.3
FROM ghcr.io/davebuilt/php-laravel:${PHP_VERSION}-dev

USER root

# Add project-specific extensions
RUN apt-get update && apt-get install -y \
    libc-client-dev libkrb5-dev zlib1g-dev libicu-dev g++ \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install intl bcmath imap \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

USER root
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CODE_SERVER_ENABLED` | `true` | Enable/disable code-server |
| `CODE_AUTH` | `password` | `none` for no auth, or `password` |
| `PASSWORD` | (none) | Password for code-server (when CODE_AUTH=password) |
| `QUEUE_WORKER_ENABLED` | `false` | Run `php artisan queue:work` |
| `SCHEDULER_ENABLED` | `false` | Run Laravel scheduler (checks every 60s) |

### Enabling Queue Worker & Scheduler

```yaml
# docker-compose.yml
services:
  app:
    image: ghcr.io/davebuilt/php-laravel:8.2-dev
    environment:
      QUEUE_WORKER_ENABLED: "true"   # Process queued jobs
      SCHEDULER_ENABLED: "true"       # Run scheduled tasks (cron replacement)
```

The scheduler runs `php artisan schedule:run` every 60 seconds, replacing the need for a system cron entry.

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `PHP_VERSION` | `8.2` | PHP version (8.2, 8.3, 8.4) |
| `USER_ID` | `1000` | UID for www user |
| `GROUP_ID` | `1000` | GID for www group |

## Ports

| Port | Service |
|------|---------|
| 9000 | PHP-FPM |
| 8080 | code-server |

## PHPUnit Testing in Docker

When running PHPUnit tests in Docker containers, use `<server>` tags instead of `<env>` tags in `phpunit.xml` to ensure environment variables override properly:

```xml
<php>
    <server name="APP_ENV" value="testing"/>
    <server name="DB_CONNECTION" value="sqlite"/>
    <server name="DB_DATABASE" value=":memory:"/>
</php>
```

See the Claude Code Parallel Development Workspace Spec for detailed documentation on this issue.

## Rebuilding

After modifying the Dockerfile:

```bash
cd ~/docker-bases/php-laravel
./build.sh --no-cache
```

Then rebuild your project containers:

```bash
cd ~/Sites/your-project
docker compose build --no-cache app
docker compose up -d
```
