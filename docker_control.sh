#!/bin/bash

# Function to clean the Docker environment
clean_docker_env() {
  echo "Stopping and removing containers and volumes..."
  $DOCKER_COMPOSE down -v --remove-orphans || { echo "Failed to stop and remove containers"; exit 1; }

  echo "Force removing any remaining project volumes..."
  docker volume rm observer_accounts_data observer_clinical_data observer_research_data 2>/dev/null || echo "All project volumes already removed."

  echo "Pruning unused volumes..."
  docker volume prune -f || { echo "Failed to prune volumes"; exit 1; }

  echo "Removing project Docker images..."
  docker rmi observer-backend mariadb:latest 2>/dev/null || echo "Some images were not found or couldn't be removed."

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
  echo "Starting the Docker environment..."
  $DOCKER_COMPOSE up -d --build || { echo "Failed to start Docker environment"; exit 1; }
  echo "Docker environment started successfully."
}

# Function to restart the Docker environment
restart_docker_env() {
  echo "Restarting the Docker environment..."
  stop_docker_env
  rebuild_docker_images
  start_docker_env
  echo "Docker environment restarted successfully."
}

# Function to generate mock data
generate_mock_data() {
  echo "Generating mock data..."
  
  # Check if backend container is running
  if ! $DOCKER_COMPOSE ps backend | grep -q "Up"; then
    echo "Backend container is not running. Starting services first..."
    start_docker_env
    echo "Waiting for services to be ready..."
    sleep 15
  fi
  
  # Run migrations for all databases
  echo "Running database migrations..."
  $DOCKER_COMPOSE exec backend python manage.py migrate --database=accounts || { echo "Failed to run accounts migrations"; exit 1; }
  $DOCKER_COMPOSE exec backend python manage.py migrate --database=clinical || { echo "Failed to run clinical migrations"; exit 1; }
  $DOCKER_COMPOSE exec backend python manage.py migrate --database=research || { echo "Failed to run research migrations"; exit 1; }
  
  # Generate mock data
  echo "Generating mock data..."
  $DOCKER_COMPOSE exec backend python manage.py generate_mock_data || { echo "Failed to generate mock data"; exit 1; }
  
  echo "Mock data generation completed successfully!"
}

# Function to show usage
show_usage() {
  echo "Usage: $0 {clean|stop|rebuild|start|restart|mockdata}"
  echo "  clean    : Clean the Docker environment (remove containers and volumes)"
  echo "  stop     : Stop the Docker environment"
  echo "  rebuild  : Rebuild Docker images"
  echo "  start    : Start the Docker environment"
  echo "  restart  : Restart the Docker environment (stop, rebuild, start)"
  echo "  mockdata : Run migrations and generate mock data"
  echo ""
  echo "Examples:"
  echo "  $0 start"
  echo "  $0 mockdata"
  echo "  $0 rebuild"
  echo "  $0 clean"
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

# Check for valid number of arguments
if [[ $# -gt 1 ]]; then
  echo "Too many arguments. This script no longer requires environment parameters."
  show_usage
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
  restart)
    restart_docker_env
    ;;
  mockdata)
    generate_mock_data
    ;;
  *)
    show_usage
    ;;
esac
