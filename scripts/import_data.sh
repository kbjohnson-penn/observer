#!/bin/bash

# Simple SQL import script for Observer project
# Imports all SQL dumps in the correct order

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of scripts directory)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project root
cd "$PROJECT_ROOT"

echo "🚀 Importing SQL dumps to Observer database..."
echo "📁 Working from: $PROJECT_ROOT"

# Database connection details (Change as needed)
CONTAINER="observer_research_db"
DB_USER="observer"
DB_PASSWORD="observer_password"
DATABASE="observer_research"
DUMP_DIR="data/sql_dumps"

# Import order (as specified)
FILES=(
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

# Check if container is running
if ! docker ps | grep -q "$CONTAINER"; then
    echo "❌ Container $CONTAINER not running. Start with: docker-compose up -d"
    exit 1
fi

# Import each file
for i in "${!FILES[@]}"; do
    file="${FILES[$i]}"
    filepath="$DUMP_DIR/${file}.sql"

    if [ -f "$filepath" ]; then
        echo "[$((i+1))/${#FILES[@]}] Importing ${file}.sql..."
        docker exec -i "$CONTAINER" mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DATABASE" < "$filepath"
        echo "✅ ${file}.sql imported"
    else
        echo "❌ File not found: $filepath"
        exit 1
    fi
done

echo "🎉 All imports completed successfully!"