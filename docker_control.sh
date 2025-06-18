#!/bin/bash

# Function to clean the Docker environment
clean_docker_env() {
  echo "Stopping and removing containers..."
  $DOCKER_COMPOSE down || { echo "Failed to stop and remove containers"; exit 1; }

  echo "Removing volumes..."
  docker volume rm observer_dev_mariadb_data 2>/dev/null || echo "Some volumes were not found."

  echo "Pruning unused volumes..."
  docker volume prune -f || { echo "Failed to prune volumes"; exit 1; }

  echo "Removing Docker images for the project..."
  docker rmi observer_backend observer_frontend mariadb:latest 2>/dev/null || echo "Some images were not found or couldn't be removed."

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

# Function to restart the Docker environment
restart_docker_env() {
  echo "Restarting the Docker environment in $ENVIRONMENT mode..."
  stop_docker_env
  rebuild_docker_images
  start_docker_env
  echo "Docker environment restarted in $ENVIRONMENT mode."
}

# Function to generate mock data
generate_mock_data() {
  echo "Generating mock data using environment variables from $ENVIRONMENT mode..."
  
  # Check if backend container is running
  if ! docker-compose ps backend | grep -q "Up"; then
    echo "Backend container is not running. Starting services first..."
    start_docker_env
    echo "Waiting for services to be ready..."
    sleep 10
  fi
  
  # Run migrations first
  echo "Running database migrations..."
  docker-compose exec backend python manage.py migrate || { echo "Failed to run migrations"; exit 1; }
  
  # Generate mock data using environment variables
  echo "Generating mock data with environment settings..."
  docker-compose exec backend python manage.py generate_mock_data || { echo "Failed to generate mock data"; exit 1; }
  
  echo "Mock data generation completed successfully!"
}

# Function to show usage
show_usage() {
  echo "Usage: $0 {clean|stop|rebuild|start|restart|mockdata} [dev|test|prod]"
  echo "  clean    : Clean the Docker environment"
  echo "  stop     : Stop the Docker environment"
  echo "  rebuild  : Rebuild Docker images"
  echo "  start    : Start the Docker environment"
  echo "  restart  : Restart the Docker environment (stop, rebuild, start)"
  echo "  mockdata : Generate mock data using environment variables"
  echo "  Environment: dev (default), test, or prod"
  echo ""
  echo "Examples:"
  echo "  $0 start dev"
  echo "  $0 mockdata dev"
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
