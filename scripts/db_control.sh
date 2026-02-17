#!/bin/bash

# Observer Database Control Script
# Manages database operations inside Docker/Podman containers
#
# Usage: ./scripts/db_control.sh <action> [runtime]
#
# Actions:
#   clean   - Reset all databases, recreate user, run migrations
#   import  - Import SQL dumps into clinical and research databases
#   reset   - Clean + import in sequence

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root (needed for compose commands and dump paths)
cd "$PROJECT_ROOT"

# ============================================================================
# USAGE
# ============================================================================

show_usage() {
    echo "Usage: $0 <action> [runtime]"
    echo ""
    echo "Actions:"
    echo "  clean   : Reset all databases, recreate user, run migrations"
    echo "  import  : Import SQL dumps into clinical and research databases"
    echo "  reset   : Clean + import in sequence"
    echo ""
    echo "Runtime (optional): docker | podman  (auto-detected if omitted)"
    echo ""
    echo "Examples:"
    echo "  $0 clean"
    echo "  $0 import podman"
    echo "  $0 reset docker"
    exit 1
}

# ============================================================================
# RUNTIME DETECTION
# ============================================================================

if [[ -n "$2" ]]; then
    case "$2" in
        docker|podman)
            CONTAINER_RUNTIME="$2"
            if ! command -v "$CONTAINER_RUNTIME" &> /dev/null; then
                echo -e "${RED}$CONTAINER_RUNTIME is not installed. Please install it and try again.${NC}"
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
        echo -e "${RED}Neither Docker nor Podman is installed. Please install one and try again.${NC}"
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
        echo -e "${RED}No Podman Compose found. Please install podman-compose.${NC}"
        exit 1
    fi
else
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${RED}No Docker Compose found. Please install Docker Compose.${NC}"
        exit 1
    fi
fi

# Suppress podman compose external provider warning
export PODMAN_COMPOSE_WARNING_LOGS=false

echo -e "Using runtime: ${GREEN}$CONTAINER_RUNTIME${NC} ($COMPOSE_CMD)"

# ============================================================================
# CONSTANTS
# ============================================================================

# Container names (from docker-compose.yml)
ACCOUNTS_CONTAINER="observer_accounts_db"
CLINICAL_CONTAINER="observer_clinical_db"
RESEARCH_CONTAINER="observer_research_db"

# Database credentials (from docker-compose.yml)
MYSQL_ROOT_PASSWORD="rootpassword"
DB_USER="observer"
DB_PASSWORD="observer_password"

# Database names
ACCOUNTS_DB="observer_accounts"
CLINICAL_DB="observer_clinical"
RESEARCH_DB="observer_research"

# ============================================================================
# HELPERS
# ============================================================================

# Verify that all required containers are running
check_containers() {
    local containers=("$@")
    for container in "${containers[@]}"; do
        if ! $CONTAINER_RUNTIME ps | grep -q "$container"; then
            echo -e "${RED}Container $container is not running. Start your compose services first.${NC}"
            echo -e "${YELLOW}Run: ./container_control.sh start${NC}"
            exit 1
        fi
    done
}

# Run SQL in a container as root
run_sql() {
    local container="$1"
    local sql="$2"
    $CONTAINER_RUNTIME exec -i "$container" mariadb -u root -p"$MYSQL_ROOT_PASSWORD" <<< "$sql"
}

# ============================================================================
# CLEAN: Reset databases, recreate user, run migrations
# ============================================================================

clean_db() {
    check_containers "$ACCOUNTS_CONTAINER" "$CLINICAL_CONTAINER" "$RESEARCH_CONTAINER"

    echo -e "${GREEN}Starting Observer Database Reset...${NC}"

    # Step 1: Reset databases and user in each container
    echo -e "${YELLOW}Step 1: Resetting databases and user...${NC}"

    echo "Resetting $ACCOUNTS_DB..."
    run_sql "$ACCOUNTS_CONTAINER" "
DROP DATABASE IF EXISTS $ACCOUNTS_DB;
CREATE DATABASE $ACCOUNTS_DB;
DROP USER IF EXISTS '$DB_USER'@'%';
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $ACCOUNTS_DB.* TO '$DB_USER'@'%';
GRANT CREATE ON *.* TO '$DB_USER'@'%';
GRANT DROP ON *.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
"

    echo "Resetting $CLINICAL_DB..."
    run_sql "$CLINICAL_CONTAINER" "
DROP DATABASE IF EXISTS $CLINICAL_DB;
CREATE DATABASE $CLINICAL_DB;
DROP USER IF EXISTS '$DB_USER'@'%';
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $CLINICAL_DB.* TO '$DB_USER'@'%';
GRANT CREATE ON *.* TO '$DB_USER'@'%';
GRANT DROP ON *.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
"

    echo "Resetting $RESEARCH_DB..."
    run_sql "$RESEARCH_CONTAINER" "
DROP DATABASE IF EXISTS $RESEARCH_DB;
CREATE DATABASE $RESEARCH_DB;
DROP USER IF EXISTS '$DB_USER'@'%';
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $RESEARCH_DB.* TO '$DB_USER'@'%';
GRANT CREATE ON *.* TO '$DB_USER'@'%';
GRANT DROP ON *.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
"

    echo -e "${GREEN}Databases and user reset successfully${NC}"

    # Step 2: Create fresh migrations
    echo -e "${YELLOW}Step 2: Creating fresh migrations...${NC}"

    echo "Creating migrations for accounts app..."
    $COMPOSE_CMD exec backend python manage.py makemigrations accounts

    echo "Creating migrations for clinical app..."
    $COMPOSE_CMD exec backend python manage.py makemigrations clinical

    echo "Creating migrations for research app..."
    $COMPOSE_CMD exec backend python manage.py makemigrations research

    echo -e "${GREEN}Fresh migrations created${NC}"

    # Step 3: Apply migrations to correct databases
    echo -e "${YELLOW}Step 3: Applying migrations...${NC}"

    echo "Migrating accounts app to accounts database..."
    $COMPOSE_CMD exec backend python manage.py migrate --database=accounts

    echo "Migrating clinical app to clinical database..."
    $COMPOSE_CMD exec backend python manage.py migrate --database=clinical

    echo "Migrating research app to research database..."
    $COMPOSE_CMD exec backend python manage.py migrate --database=research

    echo -e "${GREEN}All migrations applied successfully${NC}"

    # Step 4: Verify everything worked
    echo -e "${YELLOW}Step 4: Verifying database setup...${NC}"

    echo "Checking $ACCOUNTS_DB tables:"
    $CONTAINER_RUNTIME exec "$ACCOUNTS_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $ACCOUNTS_DB; SHOW TABLES;"

    echo ""
    echo "Checking $CLINICAL_DB tables:"
    $CONTAINER_RUNTIME exec "$CLINICAL_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $CLINICAL_DB; SHOW TABLES;"

    echo ""
    echo "Checking $RESEARCH_DB tables:"
    $CONTAINER_RUNTIME exec "$RESEARCH_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $RESEARCH_DB; SHOW TABLES;"

    echo -e "${GREEN}Database reset completed successfully!${NC}"
}

# ============================================================================
# IMPORT: Import SQL dumps into databases
# ============================================================================

# SQL dump file lists (order matters for foreign keys)
CLINICAL_DUMP_DIR="dumps/observer_clinical"
CLINICAL_FILES=(
    "clinical_department"
    "clinical_encountersource"
    "clinical_patient"
    "clinical_provider"
    "clinical_multimodaldata"
    "clinical_encounter"
    "clinical_encounterfile"
)

RESEARCH_DUMP_DIR="dumps/observer_research"
RESEARCH_FILES=(
    "concept"
    "provider"
    "person"
    "visit_occurrence"
    "note"
    "condition_occurrence"
    "drug_exposure"
    "procedure_occurrence"
    "observation"
    "measurement"
    "audit_logs"
    "patient_survey"
    "provider_survey"
    "labs"
)

import_files() {
    local container="$1"
    local database="$2"
    local dump_dir="$3"
    shift 3
    local files=("$@")

    for i in "${!files[@]}"; do
        file="${files[$i]}"
        filepath="$dump_dir/${file}.sql"

        if [ -f "$filepath" ]; then
            echo "  [$((i+1))/${#files[@]}] Importing ${file}.sql..."
            $CONTAINER_RUNTIME exec -i "$container" mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$database" < "$filepath"
            echo "  ${file}.sql imported"
        else
            echo -e "  ${RED}File not found: $filepath${NC}"
            exit 1
        fi
    done
}

import_data() {
    check_containers "$CLINICAL_CONTAINER" "$RESEARCH_CONTAINER"

    echo -e "${GREEN}Importing SQL dumps to Observer databases...${NC}"

    echo -e "${YELLOW}Importing Clinical database...${NC}"
    import_files "$CLINICAL_CONTAINER" "$CLINICAL_DB" "$CLINICAL_DUMP_DIR" "${CLINICAL_FILES[@]}"
    echo ""

    echo -e "${YELLOW}Importing Research database...${NC}"
    import_files "$RESEARCH_CONTAINER" "$RESEARCH_DB" "$RESEARCH_DUMP_DIR" "${RESEARCH_FILES[@]}"

    echo ""
    echo -e "${GREEN}All imports completed successfully!${NC}"
}

# ============================================================================
# RESET: Clean + Import
# ============================================================================

reset_db() {
    clean_db
    echo ""
    import_data
}

# ============================================================================
# DISPATCH
# ============================================================================

case "$1" in
    clean)
        clean_db
        ;;
    import)
        import_data
        ;;
    reset)
        reset_db
        ;;
    *)
        show_usage
        ;;
esac
