FROM php:8.2-fpm-alpine

ARG user=developer
ARG UID=1000
ARG GID=1000

# Install necessary packages and PHP dependencies
RUN apk update && apk add --no-cache \
    bash \
    curl \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxml2-dev \
    libzip-dev \
    nodejs \
    npm \
    pcre-dev \
    shadow \
    unzip \
    zip \
    ${PHPIZE_DEPS}

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        gd \
        opcache \
        pdo \
        pdo_mysql \
        soap \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del pcre-dev ${PHPIZE_DEPS} \
    && rm -rf /var/cache/apk/* /tmp/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Set up user and permissions
RUN delgroup www-data || true \
    && deluser www-data || true \
    && addgroup -g ${GID} www-data \
    && adduser -u ${UID} -G www-data -h /home/${user} -s /bin/bash -D ${user} \
    && adduser ${user} www-data

# Set working directory
WORKDIR /var/www

# Copy configuration files
COPY docker-compose/php/custom.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker-compose/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Create necessary directories and set permissions
RUN mkdir -p /var/www/storage /var/www/bootstrap/cache \
    && chown -R ${user}:www-data /var/www \
    && chmod -R 775 /var/www

# Copy application files
COPY --chown=${user}:www-data . .

# Final permission setup
RUN find /var/www -type f -exec chmod 664 {} \; \
    && find /var/www -type d -exec chmod 775 {} \; \
    && chmod -R ug+rwx storage bootstrap/cache \
    && chown -R ${user}:www-data /home/${user} \
    && chmod -R 775 /home/${user}

USER ${user}

EXPOSE 9000

CMD ["php-fpm"]