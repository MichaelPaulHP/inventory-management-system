# Etapa base con dependencias del sistema
FROM php:8.2-cli AS base
WORKDIR /var/www/html

# Instalar dependencias del sistema
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
        git \
        unzip \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring gd xml zip intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Etapa para desarrollo
FROM base AS development
WORKDIR /var/www/html

# Copiar archivos de dependencias primero (para mejor cache)
# COPY composer.json composer.lock ./
# COPY package.json package-lock.json ./

# Instalar dependencias PHP y Node.js
RUN composer install --no-interaction --no-scripts --no-autoloader
RUN npm install

# Copiar el resto del código
COPY . .

# Completar instalación de Composer con autoloader
RUN composer dump-autoload --optimize

# Configurar permisos
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

EXPOSE 8000
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]

# Etapa para construcción de assets (producción)
FROM base AS asset-builder
WORKDIR /var/www/html

# Copiar archivos necesarios para build
COPY package.json package-lock.json ./
COPY vite.config.js tailwind.config.js ./
COPY resources/ resources/

# Instalar dependencias y compilar assets
RUN npm ci --only=production
RUN npm run build

# Etapa final para producción (PHP-FPM)
FROM php:8.2-fpm AS production

WORKDIR /var/www/html

# Instalar dependencias del sistema (mismas que base)
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
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo_mysql mbstring gd xml zip intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copiar archivos de dependencias
COPY composer.json composer.lock ./

# Instalar dependencias de producción
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# Copiar código de la aplicación
COPY . .
# Copiar assets compilados desde asset-builder
COPY --from=asset-builder /var/www/html/public/build ./public/build

# Completar instalación
RUN composer dump-autoload --optimize

# Configurar permisos
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Crear usuario no-root
USER www-data

EXPOSE 9000
CMD ["php-fpm"]
