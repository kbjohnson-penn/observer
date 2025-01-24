#!/bin/bash

# Function to clean the Docker environment
clean_docker_env() {
  echo "Stopping and removing containers..."
  $DOCKER_COMPOSE down || { echo "Failed to stop and remove containers"; exit 1; }

  echo "Removing volumes..."
  docker volume rm observer_mariadb_data observer_neo4j_data 2>/dev/null || echo "Some volumes were not found."

  echo "Pruning unused volumes..."
  docker volume prune -f || { echo "Failed to prune volumes"; exit 1; }

  echo "Removing Docker images for the project..."
  docker rmi observer_backend observer_frontend mariadb:latest neo4j:latest 2>/dev/null || echo "Some images were not found or couldn't be removed."

  echo "Pruning unused images..."
  docker image prune -f || { echo "Failed to prune images"; exit 1; }

  echo "Docker environment cleaned."
}

# Function to stop the Docker environment
stop_docker_env() {
  echo "Stopping the Docker environment..."
  $DOCKER_COMPOSE stop || { echo "Failed to stop Docker environment"; exit 1; }
  echo "Docker environment stopped."
}

# Function to rebuild Docker images
rebuild_docker_images() {
  echo "Rebuilding Docker images..."
  $DOCKER_COMPOSE build || { echo "Failed to rebuild images"; exit 1; }
  echo "Docker images rebuilt."
}

# Function to start the Docker environment
start_docker_env() {
  echo "Starting the Docker environment in $ENVIRONMENT mode..."
  $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.$ENVIRONMENT.yml up -d || { echo "Failed to start Docker environment"; exit 1; }
  echo "Docker environment started in $ENVIRONMENT mode."
}

# Function to show usage
show_usage() {
  echo "Usage: $0 {clean|stop|rebuild|start} [dev|test|prod]"
  exit 1
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker and try again."
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
  echo "Docker Compose is not installed. Please install Docker Compose and try again."
  exit 1
fi

# Assign the correct Docker Compose command
DOCKER_COMPOSE="docker-compose"
if command -v docker compose &> /dev/null; then
  DOCKER_COMPOSE="docker compose"
fi

# Default environment to development
ENVIRONMENT="dev"

# Parse the second argument (optional environment)
if [[ $# -eq 2 ]]; then
  case "$2" in
    dev|test|prod)
      ENVIRONMENT="$2"
      ;;
    *)
      echo "Invalid environment: $2. Allowed values are dev, test, or prod."
      exit 1
      ;;
  esac
fi

# Check the first argument for the action
case "$1" in
  clean)
    clean_docker_env
    ;;
  stop)
    stop_docker_env
    ;;
  rebuild)
    rebuild_docker_images
    ;;
  start)
    start_docker_env
    ;;
  *)
    show_usage
    ;;
esac
