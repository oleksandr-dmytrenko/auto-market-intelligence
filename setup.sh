#!/bin/bash

set -e

echo "Setting up Auto Market Intelligence..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "Please edit .env and add your TELEGRAM_BOT_TOKEN"
    exit 1
fi

# Build and start services
echo "Building Docker images..."
docker-compose build

echo "Starting services..."
docker-compose up -d postgres redis

echo "Waiting for PostgreSQL to be ready..."
sleep 5

echo "Setting up Rails database..."
docker-compose exec -T rails_api rails db:create || true
docker-compose exec -T rails_api rails db:migrate

echo "Setup complete!"
echo ""
echo "To start all services:"
echo "  docker-compose up"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop services:"
echo "  docker-compose down"







