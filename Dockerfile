# Etapa base para desarrollo
FROM php:8.2-cli AS base
WORKDIR /var/www/html
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring gd xml zip intl

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copiamos solo los archivos de dependencias para aprovechar la caché de Docker
COPY composer.json composer.lock ./
COPY package.json package-lock.json ./

# Instalamos dependencias
RUN composer install --no-interaction
RUN npm install

# Copiamos el resto del código
COPY . .

EXPOSE 8000

# Comando por defecto (se sobreescribe en docker-compose.yml)
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]

# Etapa final para producción (PHP-FPM + Nginx)
FROM php:8.2-fpm AS final_app
WORKDIR /var/www/html

# Instalamos las mismas extensiones y dependencias
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring gd xml zip intl

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copiamos solo los archivos de dependencias
COPY composer.json composer.lock ./
COPY package.json package-lock.json ./

# Instalamos dependencias de producción (sin dev dependencies)
RUN composer install --no-dev --optimize-autoloader --no-interaction
RUN npm install --production

# Copiamos el código de la aplicación
COPY . .

# Configuramos permisos para Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Limpiamos archivos innecesarios
RUN rm -rf /var/www/html/node_modules \
    && rm -rf /var/www/html/.git \
    && rm -rf /var/www/html/tests

# Comando por defecto para producción
CMD ["php-fpm"]