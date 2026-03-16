#!/bin/bash
set -e

echo "Starting Ephemera..."

# Template nginx config with domain from environment
if [ -z "$EPHEMERA_DOMAIN" ]; then
  echo "ERROR: EPHEMERA_DOMAIN environment variable is required"
  exit 1
fi

envsubst '${EPHEMERA_DOMAIN}' < /app/config/nginx/ephemera.conf.template > /etc/nginx/sites-available/ephemera
ln -sf /etc/nginx/sites-available/ephemera /etc/nginx/sites-enabled/ephemera
rm -f /etc/nginx/sites-enabled/default

# Start cron daemon
echo "Starting cron..."
cron

# Start nginx
echo "Starting nginx..."
nginx

# Run database migrations
echo "Running database migrations..."
bin/rails db:prepare RAILS_ENV=production

# Start Puma (foreground to keep container alive)
echo "Starting Puma on localhost:3000..."
exec bin/rails server -b 127.0.0.1 -p 3000 -e production
