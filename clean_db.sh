#!/bin/bash

# Observer Database Reset and Migration Script
# This script will reset all databases and apply migrations for the Observer project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MYSQL_ROOT_USER="root"
MYSQL_OBSERVER_USER="observer"
MYSQL_OBSERVER_PASSWORD="observer_password"  # Update this with your actual password
PYTHON_PATH="/path/to/env" # Update this with your environment path
PROJECT_DIR="/path/to/backend" # Update this with your actual project directory

echo -e "${GREEN}Starting Observer Database and User Reset...${NC}"

# Change to project directory
echo -e "${YELLOW}Changing to project directory: $PROJECT_DIR${NC}"
cd "$PROJECT_DIR" || {
    echo -e "${RED}✗ Failed to change to project directory${NC}"
    exit 1
}

# Step 1: Reset MySQL databases and user
echo -e "${YELLOW}Step 1: Resetting MySQL databases and user...${NC}"

mysql -u $MYSQL_ROOT_USER -p << 'EOF'
-- Drop existing databases
DROP DATABASE IF EXISTS observer_accounts;
DROP DATABASE IF EXISTS observer_clinical;
DROP DATABASE IF EXISTS observer_research;

-- Drop existing user (ignore errors if user doesn't exist)
DROP USER IF EXISTS 'observer'@'localhost';
DROP USER IF EXISTS 'observer'@'%';

-- Create new databases
CREATE DATABASE observer_accounts;
CREATE DATABASE observer_clinical;
CREATE DATABASE observer_research;

-- Create new user with password
CREATE USER 'observer'@'localhost' IDENTIFIED BY 'observer_password';
CREATE USER 'observer'@'%' IDENTIFIED BY 'observer_password';

-- Grant privileges to the new user
GRANT ALL PRIVILEGES ON observer_accounts.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON observer_accounts.* TO 'observer'@'%';
GRANT ALL PRIVILEGES ON observer_clinical.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON observer_clinical.* TO 'observer'@'%';
GRANT ALL PRIVILEGES ON observer_research.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON observer_research.* TO 'observer'@'%';

-- Grant CREATE and DROP permissions for test databases
GRANT CREATE ON *.* TO 'observer'@'localhost';
GRANT CREATE ON *.* TO 'observer'@'%';
GRANT DROP ON *.* TO 'observer'@'localhost';
GRANT DROP ON *.* TO 'observer'@'%';

-- Grant permissions on test databases for Django testing
GRANT ALL PRIVILEGES ON test_observer_default.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON test_observer_default.* TO 'observer'@'%';
GRANT ALL PRIVILEGES ON test_observer_accounts.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON test_observer_accounts.* TO 'observer'@'%';
GRANT ALL PRIVILEGES ON test_observer_clinical.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON test_observer_clinical.* TO 'observer'@'%';
GRANT ALL PRIVILEGES ON test_observer_research.* TO 'observer'@'localhost';
GRANT ALL PRIVILEGES ON test_observer_research.* TO 'observer'@'%';

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
echo "Migrating accounts app to observer_accounts database..."
$PYTHON_PATH manage.py migrate --database=accounts

echo "Migrating clinical app to observer_clinical database..."
$PYTHON_PATH manage.py migrate --database=clinical

echo "Migrating research app to observer_research database..."
$PYTHON_PATH manage.py migrate --database=research

echo -e "${GREEN}✓ All migrations applied successfully${NC}"

# Step 4: Verify everything worked
echo -e "${YELLOW}Step 4: Verifying database setup...${NC}"

echo "Checking observer_accounts tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE observer_accounts; SHOW TABLES;"

echo -e "\nChecking observer_clinical tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE observer_clinical; SHOW TABLES;"

echo -e "\nChecking observer_research tables:"
mysql -u $MYSQL_OBSERVER_USER -p$MYSQL_OBSERVER_PASSWORD -e "USE observer_research; SHOW TABLES;"

echo -e "${GREEN}✓ Database setup verification complete${NC}"
echo -e "${GREEN}🎉 Observer database reset completed successfully!${NC}"