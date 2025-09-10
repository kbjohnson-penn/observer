# Observer

Healthcare platform for collecting, analyzing, and visualizing medical encounter data with multimodal capabilities.

## Quick Start

### Docker Development (Recommended)

```bash
git clone --recurse-submodules git@github.com:kbjohnson-penn/observer.git
cd observer

# Start all services
docker-compose up --build

```

### Local Development

```bash
# Set up databases
./helpers/clean_db.sh

# Run backend locally
cd observer_backend
pip install -r requirements.txt
python manage.py runserver

# Run frontend locally  
cd observer_frontend
npm install
npm run dev
```

**Access:** Backend API: http://localhost:8000/api | Admin: http://localhost:8000/admin | Frontend: http://localhost:3000

**Note for development:** While Docker is excellent for production deployments, consider using local development (npm run dev) instead of Docker during development on Mac and Windows for better performance. Learn more about optimizing local development.

## Architecture

- **Frontend**: Next.js 15 + TypeScript (see `observer_frontend/README.md`)
- **Backend**: Django 5.0.1 + DRF + JWT Auth (see `observer_backend/README.md`)
- **Database**: Multi-database MariaDB setup (accounts, clinical, research)
- **Storage**: Azure Storage
- **Containerization**: Docker Compose with volume mounts for development

## Prerequisites

- Docker & Docker Compose
- For local development: Python 3.10+, Node.js 18+, MariaDB

## Docker Configuration

The Docker setup uses a single `docker-compose.yml` with three MariaDB containers:

- **accounts_db**: Port 3306 → `observer_accounts` database
- **clinical_db**: Port 3307 → `observer_clinical` database  
- **research_db**: Port 3308 → `observer_research` database

Environment variables are configured in `observer_backend/.env`.

## Docker Commands

```bash
# Start all services
docker-compose up --build

# Start in background
docker-compose up -d --build

# Stop services
docker-compose down

# Clean everything (containers, volumes)
docker-compose down -v --remove-orphans

# View logs
docker-compose logs -f
docker-compose logs -f backend

# Access containers
docker-compose exec backend bash
docker-compose exec accounts_db mysql -u observer -pobserver_password observer_accounts
```

### Manual Operations

```bash
# Create admin user
docker-compose exec backend python manage.py createsuperuser --database=accounts
```

## Development Workflow

### Updating Submodules

To update the submodules to the latest commit from their respective repositories:

```bash
git submodule update --remote --merge
```

To update specific submodule:

```bash
cd observer_frontend  # or observer_backend
git checkout main
git pull
cd ..
git add observer_frontend  # or observer_backend
git commit -m "chore: update submodule pointer"
```

### Working with Docker

```bash
# Stop all services
./docker_control.sh stop

# Clean everything (containers, volumes, images)
./docker_control.sh clean

# Rebuild images
./docker_control.sh rebuild

# Restart services
./docker_control.sh restart dev

# Generate mock data
./docker_control.sh mockdata dev    # or test

# View logs
docker-compose logs -f
docker-compose logs -f backend

# Access container shells
docker-compose exec frontend sh
docker-compose exec backend bash
docker-compose exec mariadb mysql -u root -p
```

## Testing

```bash
# Backend tests
docker-compose exec backend python manage.py test

# Frontend tests
docker-compose exec frontend npm test
```

## Production Deployment

1. Update `env/prod.env` with secure values
2. Run `./docker_control.sh start prod`
3. Configure reverse proxy for TLS

## Contributing

1. Work in feature branches within the respective submodules
2. Update submodule pointers in the main repository after changes
3. Follow existing code patterns and conventions
4. Ensure tests pass before committing
5. Use conventional commit messages

For detailed contributing guidelines, see the CONTRIBUTING.md files in each submodule.

## Changelog

For version details and update history, see [CHANGELOG.md](CHANGELOG.md).
4. Set up proper backup procedures for MariaDB
5. Monitor logs and performance
