#!/bin/bash

# VPS Setup Script
# Run this script on your VPS to set up the deployment environment

set -e

echo "🚀 Setting up VPS for Auto Market Intelligence deployment..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
else
    echo "✅ Docker is already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "✅ Docker Compose is already installed"
fi

# Create application directory
APP_DIR="/opt/auto-market-intelligence"
echo "📁 Creating application directory at $APP_DIR..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create docker-compose.prod.yml if it doesn't exist
if [ ! -f docker-compose.prod.yml ]; then
    echo "📝 Creating docker-compose.prod.yml template..."
    cat > docker-compose.prod.yml <<'EOF'
services:
  python_workers:
    image: ${DOCKER_USERNAME:-yourusername}/python_workers:latest
    container_name: car_bot_python_workers
    restart: unless-stopped
    command: python -m workers.main
    environment:
      REDIS_URL: ${REDIS_URL:-redis://redis:6379/0}
      KAFKA_BROKERS: ${KAFKA_BROKERS:-kafka:29092}
      CHROME_HEADLESS: ${CHROME_HEADLESS:-true}
      CHROME_USER_AGENT: ${CHROME_USER_AGENT:-}
      PROXY_HOST: ${PROXY_HOST:-}
      PROXY_PORT: ${PROXY_PORT:-}
      PROXY_USERNAME: ${PROXY_USERNAME:-}
      PROXY_PASSWORD: ${PROXY_PASSWORD:-}
    networks:
      - kamal
    depends_on:
      - redis
      - kafka
    shm_size: '2gb'

  telegram_bot:
    image: ${DOCKER_USERNAME:-yourusername}/telegram_bot:latest
    container_name: car_bot_telegram
    restart: unless-stopped
    environment:
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
      RAILS_API_URL: ${RAILS_API_URL:-http://rails_api:3000}
      REDIS_URL: ${REDIS_URL:-redis://redis:6379/0}
      MINI_APP_URL: ${MINI_APP_URL:-https://bidly.tech/mini-app}
    networks:
      - kamal
    depends_on:
      - rails_api
      - redis

  kafka_consumer:
    image: ${DOCKER_USERNAME:-yourusername}/rails_api:latest
    container_name: car_bot_kafka_consumer
    restart: unless-stopped
    command: sh -c "bundle exec rails db:migrate && bundle exec rake kafka:consumer"
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL:-redis://redis:6379/0}
      KAFKA_BROKERS: ${KAFKA_BROKERS:-kafka:29092}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
      RAILS_ENV: production
    networks:
      - kamal
    depends_on:
      - postgres
      - redis
      - kafka
      - rails_api

networks:
  kamal:
    external: true
EOF
    echo "✅ Created docker-compose.prod.yml"
else
    echo "✅ docker-compose.prod.yml already exists"
fi

# Create .env file template if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env template..."
    cat > .env <<'EOF'
# Docker Registry
DOCKER_USERNAME=yourusername

# Application URLs
RAILS_API_URL=http://localhost:3000
MINI_APP_URL=https://yourdomain.com/mini-app

# Redis
REDIS_URL=redis://redis:6379/0

# Kafka
KAFKA_BROKERS=kafka:29092

# Telegram Bot
TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here

# Chrome/Scraper settings
CHROME_HEADLESS=true
CHROME_USER_AGENT=

# Proxy settings (optional)
PROXY_HOST=
PROXY_PORT=
PROXY_USERNAME=
PROXY_PASSWORD=
EOF
    echo "✅ Created .env template. Please update it with your actual values."
else
    echo "✅ .env file already exists"
fi

# Create Kamal network if it doesn't exist
if ! docker network ls | grep -q kamal; then
    echo "🌐 Creating Kamal Docker network..."
    docker network create kamal
    echo "✅ Created Kamal network"
else
    echo "✅ Kamal network already exists"
fi

echo ""
echo "✅ VPS setup complete!"
echo ""
echo "Next steps:"
echo "1. Update $APP_DIR/.env with your actual configuration values"
echo "2. Configure GitHub Secrets in your repository"
echo "3. Push to GitHub to trigger automatic deployment"
echo ""
echo "To manually deploy:"
echo "  cd $APP_DIR"
echo "  docker-compose -f docker-compose.prod.yml pull"
echo "  docker-compose -f docker-compose.prod.yml up -d"

