#!/bin/bash

# Twilio Bulk Lookup - Startup Script

echo "🚀 Starting Twilio Bulk Lookup Application..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Create .env file from example if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your Twilio credentials before continuing."
    echo "   Required: TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN"
    read -p "Press Enter to continue once you've updated .env, or Ctrl+C to exit..."
fi

# Determine which docker compose command to use
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo "🐳 Building and starting Docker containers..."
$DOCKER_COMPOSE up --build -d

echo ""
echo "✅ Application started successfully!"
echo ""
echo "📊 Services:"
echo "   - Web Application:  http://localhost:3002"
echo "   - Admin Dashboard:  http://localhost:3002/admin"
echo "   - Sidekiq Monitor:  http://localhost:3002/sidekiq"
echo ""
echo "🔐 Default Admin Credentials:"
echo "   Email:    admin@example.com"
echo "   Password: password"
echo "   ⚠️  Change these after first login!"
echo ""
echo "📝 View logs:"
echo "   All services: $DOCKER_COMPOSE logs -f"
echo "   Web only:     $DOCKER_COMPOSE logs -f web"
echo "   Sidekiq only: $DOCKER_COMPOSE logs -f sidekiq"
echo ""
echo "🛑 Stop services: $DOCKER_COMPOSE down"
echo ""
