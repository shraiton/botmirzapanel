FROM php:8.2-apache

# Install required PHP extensions and tools, including MySQL client
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libssh2-1-dev \
    git \
    unzip \
    wget \
    curl \
    openssl \
    netcat-traditional \
    cron \
    default-mysql-client \
    && docker-php-ext-install pdo_mysql mysqli zip \
    && pecl install ssh2 \
    && docker-php-ext-enable ssh2


# Install dependencies for PHP extensions and MariaDB
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libxml2-dev \
    libicu-dev \
    libzip-dev \
    libcurl4-openssl-dev \
    libmcrypt-dev \
    libssl-dev \
    libpq-dev \
    libmemcached-dev \
    libmariadb-dev-compat \
    libmariadb-dev \
    libonig-dev \
    unzip \
    net-tools \
    nano

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install intl \
    && docker-php-ext-install exif \
    && docker-php-ext-install opcache \
    && docker-php-ext-install sockets \
    && docker-php-ext-install calendar \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install shmop \
    && docker-php-ext-install sysvsem \
    && docker-php-ext-install sysvshm \
    && docker-php-ext-install soap \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo_mysql

COPY docker-php-errors.ini /usr/local/etc/php/conf.d/

ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_RUN_DIR=/tmp
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_LOG_DIR=/var/log/apache2


RUN rm -f /etc/apache2/sites-enabled/000-default.conf
RUN rm -f /etc/apache2/sites-available/000-default.conf

# Enable Apache modules
RUN a2enmod rewrite ssl headers

# Set ServerName to suppress warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Clone the Mirza Bot code
RUN git clone https://github.com/shraiton/botmirzapanel.git /var/www/html/mirzabotconfig

# Set permissions
RUN chown -R www-data:www-data /var/www/html/mirzabotconfig && chmod -R 755 /var/www/html/mirzabotconfig

# Copy Apache SSL configuration template
COPY default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
#COPY default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
