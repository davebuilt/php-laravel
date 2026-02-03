# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker base images for Laravel development. Multi-stage Dockerfile produces:
- **base** stage: Production-ready PHP-FPM with Laravel extensions
- **dev** stage: Full development environment with Claude Code, code-server, Node.js, and dev tools

Images are published to `ghcr.io/davebuilt/php-laravel` for PHP versions 8.2, 8.3, and 8.4.

## Build Commands

```bash
# Build all PHP versions (8.2, 8.3, 8.4) - both base and dev stages
./build.sh

# Build specific version only
./build.sh 8.4

# Rebuild without cache
./build.sh --no-cache

# Build specific version without cache
./build.sh 8.3 --no-cache
```

## Architecture

### Dockerfile Structure
- **base stage**: PHP-FPM, common extensions (pdo_mysql, zip, exif, pcntl, mbstring, xml, soap, dom, gd, redis), Composer 2, image optimisation tools, runs as `www` user
- **dev stage**: Extends base with Node.js 20.x, Claude Code CLI, code-server, supervisor, dev tools (ripgrep, fd, fzf, jq, vim, htop, tmux)

### Supervisor Configuration (`supervisord.conf`)
Manages processes in dev stage:
- `php-fpm` - Always runs (priority 1)
- `code-server` - Controlled by `CODE_SERVER_ENABLED` env var (priority 2)
- `queue-worker` - Controlled by `QUEUE_WORKER_ENABLED` env var (priority 10)
- `scheduler` - Controlled by `SCHEDULER_ENABLED` env var (priority 11)

### CI/CD (`.github/workflows/build.yml`)
- Triggers on: push to main (Dockerfile/supervisord.conf changes), weekly schedule (Sundays 4am UTC), manual dispatch
- Builds matrix of PHP versions × targets, pushes to GitHub Container Registry
- Weekly builds pull upstream PHP security patches

## Key Build Arguments

| Argument | Default | Purpose |
|----------|---------|---------|
| `PHP_VERSION` | 8.2 | PHP version to build |
| `USER_ID` | 1000 | UID for www user (match host for dev) |
| `GROUP_ID` | 1000 | GID for www group |

## Environment Variables (Dev Stage)

| Variable | Default | Description |
|----------|---------|-------------|
| `CODE_SERVER_ENABLED` | `true` | Enable/disable code-server |
| `CODE_AUTH` | `password` | `none` for no auth, or `password` |
| `PASSWORD` | (none) | Password for code-server |
| `QUEUE_WORKER_ENABLED` | `false` | Run `php artisan queue:work` |
| `SCHEDULER_ENABLED` | `false` | Run Laravel scheduler (checks every 60s) |

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
