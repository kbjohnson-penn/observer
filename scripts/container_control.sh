#!/bin/bash

# Function to clean the container environment
clean_env() {
  echo "Stopping and removing containers and volumes..."
  $COMPOSE_CMD down -v --remove-orphans || { echo "Failed to stop and remove containers"; exit 1; }

  echo "Force removing any remaining project volumes..."
  $CONTAINER_RUNTIME volume rm observer_accounts_data observer_clinical_data observer_research_data observer_elasticsearch_data 2>/dev/null || echo "All project volumes already removed."

  echo "Pruning unused volumes..."
  $CONTAINER_RUNTIME volume prune -f || { echo "Failed to prune volumes"; exit 1; }

  echo "Removing project images..."
  $CONTAINER_RUNTIME rmi observer-backend mariadb:latest elasticsearch:8.17.0 2>/dev/null || echo "Some images were not found or couldn't be removed."

  echo "Pruning unused images..."
  $CONTAINER_RUNTIME image prune -f || { echo "Failed to prune images"; exit 1; }

  echo "Container environment cleaned."
}

# Function to stop the container environment
stop_env() {
  echo "Stopping the container environment..."
  $COMPOSE_CMD stop || { echo "Failed to stop container environment"; exit 1; }
  echo "Container environment stopped."
}

# Function to rebuild container images
rebuild_images() {
  echo "Rebuilding container images..."
  $COMPOSE_CMD build || { echo "Failed to rebuild images"; exit 1; }
  echo "Container images rebuilt."
}

# Function to start the container environment
start_env() {
  echo "Starting the container environment..."
  $COMPOSE_CMD up -d --build || { echo "Failed to start container environment"; exit 1; }
  echo "Container environment started successfully."
}

# Function to restart the container environment
restart_env() {
  echo "Restarting the container environment..."
  stop_env
  rebuild_images
  start_env
  echo "Container environment restarted successfully."
}

# Function to generate mock data
generate_mock_data() {
  echo "Generating mock data..."
  
  # Check if backend container is running
  if ! $COMPOSE_CMD ps backend | grep -q "Up"; then
    echo "Backend container is not running. Starting services first..."
    start_env
    echo "Waiting for services to be ready..."
    sleep 15
  fi
  
  # Run migrations for all databases
  echo "Running database migrations..."
  $COMPOSE_CMD exec backend python manage.py migrate --database=accounts || { echo "Failed to run accounts migrations"; exit 1; }
  $COMPOSE_CMD exec backend python manage.py migrate --database=clinical || { echo "Failed to run clinical migrations"; exit 1; }
  $COMPOSE_CMD exec backend python manage.py migrate --database=research || { echo "Failed to run research migrations"; exit 1; }
  
  # Generate mock data
  echo "Generating mock data..."
  $COMPOSE_CMD exec backend python manage.py generate_mock_data || { echo "Failed to generate mock data"; exit 1; }

  # Sync Elasticsearch indexes
  echo "Syncing Elasticsearch indexes..."
  $COMPOSE_CMD exec backend python manage.py sync_elasticsearch --full-reindex || { echo "Failed to sync Elasticsearch"; exit 1; }

  echo "Mock data generation completed successfully!"
}

# Function to start Kibana (dev only)
start_kibana() {
  echo "Starting Kibana (dev tool)..."
  $COMPOSE_CMD --profile dev up -d kibana || { echo "Failed to start Kibana"; exit 1; }
  echo "Kibana available at http://localhost:5601"
}

# Function to stop Kibana
stop_kibana() {
  echo "Stopping Kibana..."
  $COMPOSE_CMD --profile dev stop kibana || { echo "Failed to stop Kibana"; exit 1; }
  echo "Kibana stopped."
}

# Function to show usage
show_usage() {
  echo "Usage: $0 <action> [runtime]"
  echo ""
  echo "Actions:"
  echo "  clean    : Clean the container environment (remove containers and volumes)"
  echo "  stop     : Stop the container environment"
  echo "  rebuild  : Rebuild container images"
  echo "  start    : Start the container environment"
  echo "  restart  : Restart the container environment (stop, rebuild, start)"
  echo "  mockdata : Run migrations, generate mock data, and sync Elasticsearch"
  echo "  kibana   : Start Kibana for dev ES inspection (http://localhost:5601)"
  echo "  kibana-stop : Stop Kibana"
  echo ""
  echo "Runtime (optional): docker | podman  (auto-detected if omitted)"
  echo ""
  echo "Examples:"
  echo "  $0 start"
  echo "  $0 start docker"
  echo "  $0 start podman"
  echo "  $0 clean podman"
  exit 1
}

# Set container runtime from argument or auto-detect
if [[ -n "$2" ]]; then
  case "$2" in
    docker|podman)
      CONTAINER_RUNTIME="$2"
      if ! command -v "$CONTAINER_RUNTIME" &> /dev/null; then
        echo "$CONTAINER_RUNTIME is not installed. Please install it and try again."
        exit 1
      fi
      ;;
    *)
      echo "Unknown runtime: $2. Use 'docker' or 'podman'."
      show_usage
      ;;
  esac
else
  if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
  elif command -v docker &> /dev/null; then
    CONTAINER_RUNTIME="docker"
  else
    echo "Neither Docker nor Podman is installed. Please install one and try again."
    exit 1
  fi
fi

# Detect compose command based on runtime
if [[ "$CONTAINER_RUNTIME" == "podman" ]]; then
  if command -v podman compose &> /dev/null; then
    COMPOSE_CMD="podman compose"
  elif command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
  else
    echo "No Podman Compose found. Please install podman-compose."
    exit 1
  fi
else
  if command -v docker compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo "No Docker Compose found. Please install Docker Compose."
    exit 1
  fi
fi

# Suppress podman compose external provider warning
export PODMAN_COMPOSE_WARNING_LOGS=false

echo "Using runtime: $CONTAINER_RUNTIME ($COMPOSE_CMD)"

# Check the first argument for the action
case "$1" in
  clean)
    clean_env
    ;;
  stop)
    stop_env
    ;;
  rebuild)
    rebuild_images
    ;;
  start)
    start_env
    ;;
  restart)
    restart_env
    ;;
  mockdata)
    generate_mock_data
    ;;
  kibana)
    start_kibana
    ;;
  kibana-stop)
    stop_kibana
    ;;
  *)
    show_usage
    ;;
esac
