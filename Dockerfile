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

# Install system dependencies and PHP extensions
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
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
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

# Create www user with matching host UID/GID
RUN groupadd -g ${GROUP_ID} ${GROUP} \
    && useradd -u ${USER_ID} -ms /bin/bash -g ${GROUP} ${USER}

# Configure PHP-FPM to run as www user instead of www-data
RUN sed -i 's/user = www-data/user = www/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/group = www-data/group = www/g' /usr/local/etc/php-fpm.d/www.conf

# Set ownership and ensure /tmp is writable (required by tools like Laravel Pint)
RUN chown -R ${USER}:${GROUP} /var/www \
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

# Switch back to root for installations
USER root

# Install Node.js 20.x (useful for frontend builds and tooling)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code using the official installation method
# This installs to ~/.local/bin which is why we need that directory in PATH
RUN su - www -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Install code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install just command runner (not in Debian stable repos yet)
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# Install supervisor and development tools in one layer
RUN apt-get update && apt-get install -y \
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
    && echo "www ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create symlinks for fd and bat (it's called fdfind and batcat on Debian/Ubuntu)
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true

# Create supervisor directories
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d

# Create home directory for www user (separate from project workspace)
# Also create .local/bin for Claude Code and add to PATH
RUN mkdir -p /home/www/.local/bin && chown -R www:www /home/www

# Create .claude directory structure with proper ownership
# This ensures mounted volume inherits correct permissions
RUN mkdir -p /home/www/.claude/projects \
             /home/www/.claude/cache \
             /home/www/.local/share/code-server \
    && chown -R www:www /home/www/.claude /home/www/.local \
    && chmod -R 755 /home/www/.claude /home/www/.local

# Add .local/bin to PATH for www user
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/www/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/www/.profile

# Auto-source Laravel .env for convenient database access and other env vars
# set -a exports all variables, set +a turns it off after sourcing
RUN cat >> /home/www/.bashrc <<'EOF'

# Source Laravel .env if in project directory
if [ -f /var/www/.env ]; then
    set -a
    source /var/www/.env
    set +a
fi
EOF

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
