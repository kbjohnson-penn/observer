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
DB_USER="observer"
DB_PASSWORD="observer_password"

# --- Clinical Database ---
CLINICAL_CONTAINER="observer_clinical_db"
CLINICAL_DATABASE="observer_clinical"
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

# --- Research Database ---
RESEARCH_CONTAINER="observer_research_db"
RESEARCH_DATABASE="observer_research"
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

    if ! docker ps | grep -q "$container"; then
        echo "❌ Container $container not running. Start with: docker-compose up -d"
        exit 1
    fi

    for i in "${!files[@]}"; do
        file="${files[$i]}"
        filepath="$dump_dir/${file}.sql"

        if [ -f "$filepath" ]; then
            echo "[$((i+1))/${#files[@]}] Importing ${file}.sql..."
            docker exec -i "$container" mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$database" < "$filepath"
            echo "✅ ${file}.sql imported"
        else
            echo "❌ File not found: $filepath"
            exit 1
        fi
    done
}

echo "📦 Importing Clinical database..."
import_files "$CLINICAL_CONTAINER" "$CLINICAL_DATABASE" "$CLINICAL_DUMP_DIR" "${CLINICAL_FILES[@]}"
echo ""

echo "📦 Importing Research database..."
import_files "$RESEARCH_CONTAINER" "$RESEARCH_DATABASE" "$RESEARCH_DUMP_DIR" "${RESEARCH_FILES[@]}"

echo ""
echo "🎉 All imports completed successfully!"