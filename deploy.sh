#!/bin/bash

# Deployment script for VPS
# This script sets up the initial deployment environment on the VPS

set -e

echo "🚀 Setting up deployment environment..."

# Check if running on VPS
if [ -z "$DEPLOY_HOST" ]; then
    echo "❌ DEPLOY_HOST environment variable is not set"
    exit 1
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create application directory
APP_DIR="/opt/auto-market-intelligence"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cat > .env <<EOF
# Docker Registry
DOCKER_USERNAME=${DOCKER_USERNAME:-yourusername}

# Application URLs
RAILS_API_URL=${RAILS_API_URL:-http://localhost:3000}
MINI_APP_URL=${MINI_APP_URL:-https://bidly.tech/mini-app}

# Redis
REDIS_URL=${REDIS_URL:-redis://redis:6379/0}

# Kafka
KAFKA_BROKERS=${KAFKA_BROKERS:-kafka:29092}

# Telegram Bot
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}

# Chrome/Scraper settings
CHROME_HEADLESS=true
CHROME_USER_AGENT=

# Proxy settings (optional)
PROXY_HOST=
PROXY_PORT=
PROXY_USERNAME=
PROXY_PASSWORD=
EOF
    echo "✅ Created .env file. Please update it with your actual values."
fi

echo "✅ Deployment environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Update $APP_DIR/.env with your actual configuration"
echo "2. Run 'kamal setup' from your local machine to deploy Rails API"
echo "3. The GitHub Actions workflow will handle Python workers and Telegram bot deployment"

