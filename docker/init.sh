#!/bin/bash

# Script de inicialización para Laravel
set -e

echo "🚀 Iniciando aplicación Laravel..."

# Generar APP_KEY si no existe
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "base64:CHANGE_ME" ]; then
    echo "📝 Generando APP_KEY..."
    php artisan key:generate --no-interaction
else
    echo "✅ APP_KEY ya está configurada"
fi

# Ejecutar el comando principal (CMD del Dockerfile)
echo "🎯 Ejecutando comando principal: $@"
exec "$@"