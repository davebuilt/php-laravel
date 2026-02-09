# ================================================================
# Base Stage - Production Ready
# Minimal footprint, runs as www user, optimised for production
# ================================================================
ARG PHP_VERSION=8.2
FROM php:${PHP_VERSION}-fpm AS base

# Build arguments for user management
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER=www
ARG GROUP=www

# Set working directory early
WORKDIR /var/www

# Install system dependencies, PHP extensions, and Redis
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    # Database clients
    mariadb-client \
    # Image processing libraries
    libpng-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    libfreetype6-dev \
    # Compression
    libzip-dev \
    # String processing
    libonig-dev \
    # XML processing
    libxml2-dev \
    # Localisation
    locales \
    # Utilities
    zip \
    unzip \
    git \
    curl \
    # Image optimisation tools
    jpegoptim optipng pngquant gifsicle webp \
    # SQLite for testing
    sqlite3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        zip \
        exif \
        pcntl \
        mbstring \
        xml \
        soap \
        dom \
        gd \
    && pecl install -o -f redis \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create www user, configure PHP-FPM, and set ownership
RUN groupadd -g ${GROUP_ID} ${GROUP} \
    && useradd -u ${USER_ID} -ms /bin/bash -g ${GROUP} ${USER} \
    && sed -i 's/user = www-data/user = www/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/group = www-data/group = www/g' /usr/local/etc/php-fpm.d/www.conf \
    && chown -R ${USER}:${GROUP} /var/www \
    && chmod 1777 /tmp

# PHP-FPM runs on port 9000
EXPOSE 9000

# Switch to www user for security
USER ${USER}

# Default command (can be overridden)
CMD ["php-fpm"]

# ================================================================
# Dev Stage - Full Development Environment
# Includes Claude Code, code-server, and all development tools
# ================================================================
FROM base AS dev

# Build argument for locale (default to British English)
ARG LOCALE=en_GB.UTF-8

# Switch back to root for installations
USER root

# Generate locale and set as default
RUN sed -i "s/# ${LOCALE}/${LOCALE}/" /etc/locale.gen \
    && locale-gen ${LOCALE} \
    && update-locale LANG=${LOCALE}

ENV LANG=${LOCALE} \
    LANGUAGE=${LOCALE} \
    LC_ALL=${LOCALE}

# Install Node.js 20.x, supervisor, and development tools
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y \
    nodejs \
    # Process management
    supervisor \
    sudo \
    # Editors
    vim \
    nano \
    less \
    # Bash Completion
    bash-completion \
    # System monitoring
    htop \
    # Terminal multiplexer
    tmux \
    # Modern search tools
    ripgrep \
    fd-find \
    jq \
    tree \
    fzf \
    # Git tools
    tig \
    bat \
    lazygit \
    # Network tools
    netcat-openbsd \
    iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "www ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

# Install Claude Code using the official installation method
# This installs to ~/.local/bin which is why we need that directory in PATH
RUN su - www -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Install code-server and just command runner
RUN curl -fsSL https://code-server.dev/install.sh | sh \
    && curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Create directories, set permissions, and configure shell
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d \
    && mkdir -p /home/www/.local/bin \
    && mkdir -p /home/www/.claude/projects \
               /home/www/.claude/cache \
               /home/www/.local/share/code-server \
    && chown -R www:www /home/www \
    && chmod -R 755 /home/www/.claude /home/www/.local \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/www/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/www/.profile \
    && cat >> /home/www/.bashrc <<'BASHRC'

# Source Laravel .env if in project directory
if [ -f /var/www/.env ]; then
    set -a
    source /var/www/.env
    set +a
fi
BASHRC

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
# 9000 - PHP-FPM
# 8080 - code-server
EXPOSE 9000 8080

# Stay as root (required for supervisor and development tasks)
USER root

# Run supervisor (manages all processes)
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
