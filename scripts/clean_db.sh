#!/bin/bash

# Observer Database Reset and Migration Script
# This script will reset all databases and apply migrations for the Observer project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths and environment
ENV_FILE="/Users/mopidevi/Workspace/projects/observer/observer_backend/.env"
PYTHON_PATH="/Users/mopidevi/miniconda3/envs/observer/bin/python"
PROJECT_DIR="/Users/mopidevi/Workspace/projects/observer/observer_backend/"


# Load environment variables from .env
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}✗ .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Load only required variables from .env file
source "$ENV_FILE"

# Configuration
MYSQL_ROOT_USER="root"
MYSQL_OBSERVER_USER="$DB_USER"
MYSQL_OBSERVER_PASSWORD="$DB_PASSWORD"

# Export only the variables we need for MySQL commands
export ACCOUNTS_DB_NAME
export CLINICAL_DB_NAME
export RESEARCH_DB_NAME
export TEST_ACCOUNTS_DB
export TEST_CLINICAL_DB
export TEST_RESEARCH_DB
export TEST_DEFAULT_DB
export MYSQL_OBSERVER_USER
export MYSQL_OBSERVER_PASSWORD

echo -e "${GREEN}Starting Observer Database and User Reset...${NC}"

# Change to project directory
echo -e "${YELLOW}Changing to project directory: $PROJECT_DIR${NC}"
cd "$PROJECT_DIR" || {
    echo -e "${RED}✗ Failed to change to project directory${NC}"
    exit 1
}

# Step 1: Reset MySQL databases and user
echo -e "${YELLOW}Step 1: Resetting MySQL databases and user...${NC}"

mysql -u $MYSQL_ROOT_USER -p << EOF
-- Drop existing databases
DROP DATABASE IF EXISTS $ACCOUNTS_DB_NAME;
DROP DATABASE IF EXISTS $CLINICAL_DB_NAME;
DROP DATABASE IF EXISTS $RESEARCH_DB_NAME;

-- Drop existing user (ignore errors if user doesn't exist)
DROP USER IF EXISTS '$MYSQL_OBSERVER_USER'@'localhost';
DROP USER IF EXISTS '$MYSQL_OBSERVER_USER'@'%';

-- Create new databases
CREATE DATABASE $ACCOUNTS_DB_NAME;
CREATE DATABASE $CLINICAL_DB_NAME;
CREATE DATABASE $RESEARCH_DB_NAME;

-- Create new user with password
CREATE USER '$MYSQL_OBSERVER_USER'@'localhost' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';
CREATE USER '$MYSQL_OBSERVER_USER'@'%' IDENTIFIED BY '$MYSQL_OBSERVER_PASSWORD';

-- Grant privileges to the new user
GRANT ALL PRIVILEGES ON $ACCOUNTS_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $ACCOUNTS_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $CLINICAL_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $CLINICAL_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $RESEARCH_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $RESEARCH_DB_NAME.* TO '$MYSQL_OBSERVER_USER'@'%';

-- Grant CREATE and DROP permissions for test databases
GRANT CREATE ON *.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT CREATE ON *.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT DROP ON *.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT DROP ON *.* TO '$MYSQL_OBSERVER_USER'@'%';

-- Grant permissions on test databases for Django testing
GRANT ALL PRIVILEGES ON $TEST_ACCOUNTS_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_ACCOUNTS_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_CLINICAL_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_CLINICAL_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_RESEARCH_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_RESEARCH_DB.* TO '$MYSQL_OBSERVER_USER'@'%';
GRANT ALL PRIVILEGES ON $TEST_DEFAULT_DB.* TO '$MYSQL_OBSERVER_USER'@'localhost';
GRANT ALL PRIVILEGES ON $TEST_DEFAULT_DB.* TO '$MYSQL_OBSERVER_USER'@'%';

FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Databases and user reset successfully${NC}"
else
    echo -e "${RED}✗ Database and user reset failed${NC}"
    exit 1
fi

# Step 2: Create fresh migrations
echo -e "${YELLOW}Step 2: Creating fresh migrations...${NC}"

echo "Creating migrations for accounts app..."
$PYTHON_PATH manage.py makemigrations accounts

echo "Creating migrations for clinical app..."
$PYTHON_PATH manage.py makemigrations clinical

echo "Creating migrations for research app..."
$PYTHON_PATH manage.py makemigrations research

echo -e "${GREEN}✓ Fresh migrations created${NC}"

# Step 3: Apply migrations to correct databases
echo -e "${YELLOW}Step 3: Applying migrations...${NC}"

# Then migrate each app to its specific database
echo "Migrating accounts app to accounts database..."
$PYTHON_PATH manage.py migrate --database=accounts

echo "Migrating clinical app to clinical database..."
$PYTHON_PATH manage.py migrate --database=clinical

echo "Migrating research app to research database..."
$PYTHON_PATH manage.py migrate --database=research

echo -e "${GREEN}✓ All migrations applied successfully${NC}"

# Step 4: Verify everything worked
echo -e "${YELLOW}Step 4: Verifying database setup...${NC}"

echo "Checking $ACCOUNTS_DB_NAME tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE $ACCOUNTS_DB_NAME; SHOW TABLES;"

echo -e "\nChecking $CLINICAL_DB_NAME tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE $CLINICAL_DB_NAME; SHOW TABLES;"

echo -e "\nChecking $RESEARCH_DB_NAME tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE $RESEARCH_DB_NAME; SHOW TABLES;"

echo -e "${GREEN}✓ Database setup verification complete${NC}"
echo -e "${GREEN}🎉 Observer database reset completed successfully!${NC}"