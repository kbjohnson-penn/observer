#!/bin/bash

# Observer Database Control Script
# Manages database operations inside Docker/Podman containers
#
# Usage: ./scripts/db_control.sh <action> [--db=<db>] [--table=<table>] [runtime]
#
# Actions:
#   clean   - Reset all databases, recreate user, run migrations
#   import  - Import SQL dumps into clinical and/or research databases
#   reset   - Clean + import + sync Elasticsearch in sequence
#   es-sync - Sync (or re-index) Elasticsearch from current database state

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
# ARG PARSING — strip --db= and --table= flags before runtime detection
# ============================================================================

TARGET_DB=""
TARGET_TABLE=""
CLEANED_ARGS=()

for arg in "${@:2}"; do
    case "$arg" in
        --db=*)
            TARGET_DB="${arg#--db=}"
            ;;
        --table=*)
            TARGET_TABLE="${arg#--table=}"
            ;;
        *)
            CLEANED_ARGS+=("$arg")
            ;;
    esac
done

# Validate --db value if supplied
if [[ -n "$TARGET_DB" && "$TARGET_DB" != "clinical" && "$TARGET_DB" != "research" && "$TARGET_DB" != "accounts" ]]; then
    echo -e "${RED}Unknown database: '$TARGET_DB'. Valid values: accounts, clinical, research${NC}"
    exit 1
fi

# ============================================================================
# USAGE
# ============================================================================

show_usage() {
    echo "Usage: $0 <action> [--db=<db>] [--table=<table>] [runtime]"
    echo ""
    echo "Actions:"
    echo "  clean    : Reset all databases, recreate user, run migrations"
    echo "  import   : Import SQL dumps into clinical and/or research databases"
    echo "  reset    : Clean + import + sync Elasticsearch in sequence"
    echo "  es-sync  : Sync (or re-index) Elasticsearch from current database state"
    echo ""
    echo "Flags (clean and import actions):"
    echo "  --db=<db>        : Limit to one database: accounts | clinical | research"
    echo "  --table=<table>  : (import only) Import a single table (auto-detects DB if --db omitted)"
    echo ""
    echo "Runtime (optional): docker | podman  (auto-detected if omitted)"
    echo ""
    echo "Examples:"
    echo "  $0 clean                               # reset all three databases"
    echo "  $0 clean --db=research                 # reset only the research database"
    echo "  $0 import                              # all tables in both DBs"
    echo "  $0 import --db=research                # all research tables only"
    echo "  $0 import --table=visit_occurrence     # one table (DB auto-detected)"
    echo "  $0 import --db=research --table=note   # explicit DB + table"
    echo "  $0 import podman"
    echo "  $0 reset docker"
    echo "  $0 es-sync"
    exit 1
}

# ============================================================================
# RUNTIME DETECTION
# ============================================================================

if [[ -n "${CLEANED_ARGS[0]}" ]]; then
    case "${CLEANED_ARGS[0]}" in
        docker|podman)
            CONTAINER_RUNTIME="${CLEANED_ARGS[0]}"
            if ! command -v "$CONTAINER_RUNTIME" &> /dev/null; then
                echo -e "${RED}$CONTAINER_RUNTIME is not installed. Please install it and try again.${NC}"
                exit 1
            fi
            ;;
        *)
            echo "Unknown runtime: ${CLEANED_ARGS[0]}. Use 'docker' or 'podman'."
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
    # Determine which DBs to clean (default: all three)
    local do_accounts=1 do_clinical=1 do_research=1
    if [[ -n "$TARGET_DB" ]]; then
        do_accounts=0 do_clinical=0 do_research=0
        case "$TARGET_DB" in
            accounts)  do_accounts=1 ;;
            clinical)  do_clinical=1 ;;
            research)  do_research=1 ;;
        esac
    fi

    # Check only the containers we need
    local containers_to_check=()
    [[ $do_accounts -eq 1 ]] && containers_to_check+=("$ACCOUNTS_CONTAINER")
    [[ $do_clinical -eq 1 ]] && containers_to_check+=("$CLINICAL_CONTAINER")
    [[ $do_research -eq 1 ]] && containers_to_check+=("$RESEARCH_CONTAINER")
    check_containers "${containers_to_check[@]}"

    if [[ -n "$TARGET_DB" ]]; then
        echo -e "${GREEN}Starting reset of '$TARGET_DB' database...${NC}"
    else
        echo -e "${GREEN}Starting Observer Database Reset...${NC}"
    fi

    # Step 1: Reset selected database(s) and user
    echo -e "${YELLOW}Step 1: Resetting databases and user...${NC}"

    if [[ $do_accounts -eq 1 ]]; then
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
    fi

    if [[ $do_clinical -eq 1 ]]; then
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
    fi

    if [[ $do_research -eq 1 ]]; then
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
    fi

    echo -e "${GREEN}Databases and user reset successfully${NC}"

    # Step 2: Create fresh migrations for selected app(s)
    echo -e "${YELLOW}Step 2: Creating fresh migrations...${NC}"

    if [[ $do_accounts -eq 1 ]]; then
        echo "Creating migrations for accounts app..."
        $COMPOSE_CMD exec backend python manage.py makemigrations accounts
    fi
    if [[ $do_clinical -eq 1 ]]; then
        echo "Creating migrations for clinical app..."
        $COMPOSE_CMD exec backend python manage.py makemigrations clinical
    fi
    if [[ $do_research -eq 1 ]]; then
        echo "Creating migrations for research app..."
        $COMPOSE_CMD exec backend python manage.py makemigrations research
    fi

    echo -e "${GREEN}Fresh migrations created${NC}"

    # Step 3: Apply migrations to selected database(s)
    echo -e "${YELLOW}Step 3: Applying migrations...${NC}"

    if [[ $do_accounts -eq 1 ]]; then
        echo "Migrating accounts app to accounts database..."
        $COMPOSE_CMD exec backend python manage.py migrate --database=accounts
    fi
    if [[ $do_clinical -eq 1 ]]; then
        echo "Migrating clinical app to clinical database..."
        $COMPOSE_CMD exec backend python manage.py migrate --database=clinical
    fi
    if [[ $do_research -eq 1 ]]; then
        echo "Migrating research app to research database..."
        $COMPOSE_CMD exec backend python manage.py migrate --database=research
    fi

    echo -e "${GREEN}All migrations applied successfully${NC}"

    # Step 4: Verify selected databases
    echo -e "${YELLOW}Step 4: Verifying database setup...${NC}"

    if [[ $do_accounts -eq 1 ]]; then
        echo "Checking $ACCOUNTS_DB tables:"
        $CONTAINER_RUNTIME exec "$ACCOUNTS_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $ACCOUNTS_DB; SHOW TABLES;"
        echo ""
    fi
    if [[ $do_clinical -eq 1 ]]; then
        echo "Checking $CLINICAL_DB tables:"
        $CONTAINER_RUNTIME exec "$CLINICAL_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $CLINICAL_DB; SHOW TABLES;"
        echo ""
    fi
    if [[ $do_research -eq 1 ]]; then
        echo "Checking $RESEARCH_DB tables:"
        $CONTAINER_RUNTIME exec "$RESEARCH_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $RESEARCH_DB; SHOW TABLES;"
        echo ""
    fi

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
    # Resolve which DB(s) and table(s) to import
    # If TARGET_TABLE is set and TARGET_DB is not, auto-detect DB from the known arrays
    if [[ -n "$TARGET_TABLE" && -z "$TARGET_DB" ]]; then
        local in_clinical=0 in_research=0
        for f in "${CLINICAL_FILES[@]}"; do [[ "$f" == "$TARGET_TABLE" ]] && in_clinical=1; done
        for f in "${RESEARCH_FILES[@]}"; do [[ "$f" == "$TARGET_TABLE" ]] && in_research=1; done

        if [[ $in_clinical -eq 1 && $in_research -eq 1 ]]; then
            echo -e "${RED}Table '$TARGET_TABLE' exists in both databases. Use --db= to specify which one.${NC}"
            exit 1
        elif [[ $in_clinical -eq 1 ]]; then
            TARGET_DB="clinical"
        elif [[ $in_research -eq 1 ]]; then
            TARGET_DB="research"
        else
            echo -e "${RED}Table '$TARGET_TABLE' not found in any database.${NC}"
            echo "Clinical tables: ${CLINICAL_FILES[*]}"
            echo "Research tables: ${RESEARCH_FILES[*]}"
            exit 1
        fi
    fi

    # If TARGET_TABLE + TARGET_DB are both set, validate the table belongs to that DB
    if [[ -n "$TARGET_TABLE" && -n "$TARGET_DB" ]]; then
        local found=0
        if [[ "$TARGET_DB" == "clinical" ]]; then
            for f in "${CLINICAL_FILES[@]}"; do [[ "$f" == "$TARGET_TABLE" ]] && found=1; done
        else
            for f in "${RESEARCH_FILES[@]}"; do [[ "$f" == "$TARGET_TABLE" ]] && found=1; done
        fi
        if [[ $found -eq 0 ]]; then
            echo -e "${RED}Table '$TARGET_TABLE' not found in the '$TARGET_DB' database.${NC}"
            if [[ "$TARGET_DB" == "clinical" ]]; then
                echo "Clinical tables: ${CLINICAL_FILES[*]}"
            else
                echo "Research tables: ${RESEARCH_FILES[*]}"
            fi
            exit 1
        fi
    fi

    # Determine which containers we need
    local need_clinical=0 need_research=0
    if [[ -z "$TARGET_DB" || "$TARGET_DB" == "clinical" ]]; then need_clinical=1; fi
    if [[ -z "$TARGET_DB" || "$TARGET_DB" == "research" ]]; then need_research=1; fi

    # Check only the containers we actually need
    local containers_to_check=()
    [[ $need_clinical -eq 1 ]] && containers_to_check+=("$CLINICAL_CONTAINER")
    [[ $need_research -eq 1 ]] && containers_to_check+=("$RESEARCH_CONTAINER")
    check_containers "${containers_to_check[@]}"

    # Summary line
    if [[ -n "$TARGET_TABLE" ]]; then
        echo -e "${GREEN}Importing table '$TARGET_TABLE' into $TARGET_DB database...${NC}"
    elif [[ -n "$TARGET_DB" ]]; then
        echo -e "${GREEN}Importing all tables into $TARGET_DB database...${NC}"
    else
        echo -e "${GREEN}Importing SQL dumps to Observer databases...${NC}"
    fi

    if [[ $need_clinical -eq 1 ]]; then
        echo -e "${YELLOW}Importing Clinical database...${NC}"
        if [[ -n "$TARGET_TABLE" ]]; then
            import_files "$CLINICAL_CONTAINER" "$CLINICAL_DB" "$CLINICAL_DUMP_DIR" "$TARGET_TABLE"
        else
            import_files "$CLINICAL_CONTAINER" "$CLINICAL_DB" "$CLINICAL_DUMP_DIR" "${CLINICAL_FILES[@]}"
        fi
        echo ""
    fi

    if [[ $need_research -eq 1 ]]; then
        echo -e "${YELLOW}Importing Research database...${NC}"
        if [[ -n "$TARGET_TABLE" ]]; then
            import_files "$RESEARCH_CONTAINER" "$RESEARCH_DB" "$RESEARCH_DUMP_DIR" "$TARGET_TABLE"
        else
            import_files "$RESEARCH_CONTAINER" "$RESEARCH_DB" "$RESEARCH_DUMP_DIR" "${RESEARCH_FILES[@]}"
        fi
        echo ""
    fi

    echo -e "${GREEN}All imports completed successfully!${NC}"
}

# ============================================================================
# ES-SYNC: Sync Elasticsearch indexes from current database state
# ============================================================================

sync_elasticsearch() {
    echo -e "${YELLOW}Syncing Elasticsearch indexes (full reindex)...${NC}"
    $COMPOSE_CMD exec backend python manage.py sync_elasticsearch --full-reindex || {
        echo -e "${RED}Failed to sync Elasticsearch${NC}"
        exit 1
    }
    echo -e "${GREEN}Elasticsearch sync completed successfully!${NC}"
}

# ============================================================================
# RESET: Clean + Import + ES Sync
# ============================================================================

reset_db() {
    clean_db
    echo ""
    import_data
    echo ""
    sync_elasticsearch
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
    es-sync)
        sync_elasticsearch
        ;;
    *)
        show_usage
        ;;
esac
