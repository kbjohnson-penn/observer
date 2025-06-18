# Observer

Healthcare platform for collecting, analyzing, and visualizing medical encounter data with multimodal capabilities.

## Quick Start

```bash
git clone --recurse-submodules git@github.com:kbjohnson-penn/observer.git
cd observer
./docker_control.sh start dev
./docker_control.sh mockdata dev
```

**Access:** Frontend: http://localhost:3000 | API: http://localhost:8000/api | Admin: http://localhost:8000/admin

## Architecture

- **Frontend**: Next.js 14 + TypeScript (see `observer_frontend/README.md`)
- **Backend**: Django 5.0.1 + DRF + JWT Auth (see `observer_backend/README.md`)
- **Database**: MariaDB
- **Storage**: Azure Storage

## Prerequisites

- Docker & Docker Compose

## Environment Configuration

Pre-configured files in `/env/`:
- `dev.env` - Development with full mock data
- `test.env` - Testing with smaller datasets
- `prod.env` - Production (requires Azure credentials)

### Key Variables

```bash
# Backend Settings
SECRET_KEY=RR%732E$FKYgkQ*4GtyV77PJxusGY%a-dev
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,backend
CSRF_TRUSTED_ORIGINS=http://localhost,http://127.0.0.1

# Database Settings
DB_HOST=mariadb
DB_NAME=dev_observer_dashboard_database
DB_USER=observer
DB_PASSWORD=observer123
DB_PORT=3306
TEST_DB=test_dev_observer_dashboard_database

# Azure Storage Settings
AZURE_STORAGE_ACCOUNT_NAME=
AZURE_STORAGE_FILE_SYSTEM_NAME=
AZURE_SAS_TOKEN=

# Django Settings
DOCUMENTATION_URL=http://localhost:8000/docs
LOG_FILE=dev.observer.log

# Frontend Settings
NEXT_PUBLIC_BACKEND_API=http://backend:8000/api/v1

# Mock Data Generation Settings
MOCK_DATA_SEED=42
MOCK_DATA_CLINIC_PATIENTS=200
MOCK_DATA_CLINIC_PROVIDERS=200
MOCK_DATA_SIMCENTER_PATIENTS=50
MOCK_DATA_SIMCENTER_PROVIDERS=30
MOCK_DATA_CLINIC_ENCOUNTERS=150
MOCK_DATA_SIMCENTER_ENCOUNTERS=50
MOCK_DATA_CLEAR_EXISTING=True
```

**Production Setup:** Update `env/prod.env` with secure `SECRET_KEY`, set `DEBUG=False`, add Azure credentials, remove `MOCK_DATA_*` variables.

## Docker Commands

```bash
./docker_control.sh start dev|test|prod    # Start environment
./docker_control.sh mockdata dev|test      # Generate sample data
./docker_control.sh stop                   # Stop all services
./docker_control.sh clean                  # Remove containers/volumes
./docker_control.sh rebuild                # Rebuild images
```

### Manual Setup

```bash
# Run migrations
docker-compose exec backend python manage.py migrate

# Create admin user
docker-compose exec backend python manage.py createsuperuser

# Custom mock data
docker-compose exec backend python manage.py generate_mock_data --clinic-patients 100
```

## Project Structure

```
observer/
├── docker-compose.yml              # Base Docker Compose configuration
├── docker-compose.dev.yml          # Development overrides
├── docker-compose.test.yml         # Testing overrides
├── docker-compose.prod.yml         # Production overrides
├── docker_control.sh               # Convenience script for Docker operations
├── env/                           # Environment files directory
│   ├── dev.env                    # Development environment
│   ├── test.env                   # Testing environment
│   └── prod.env                   # Production environment
├── observer_backend/               # Backend submodule (Django)
│   ├── dashboard/                 # Main Django application
│   ├── backend/                   # Django settings
│   └── manage.py
└── observer_frontend/              # Frontend submodule (Next.js)
    ├── src/
    │   ├── app/                   # Next.js pages and layouts
    │   ├── components/            # Reusable components
    │   ├── contexts/             # React contexts (AuthContext)
    │   └── lib/                  # API client and utilities
    └── package.json
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

## Documentation

- **API Documentation**: See `observer_backend/README.md`
- **Frontend Components**: See `observer_frontend/README.md`
- **Development Context**: See `CLAUDE.md`

## Changelog

For version details and update history, see [CHANGELOG.md](CHANGELOG.md).
4. Set up proper backup procedures for MariaDB
5. Monitor logs and performance

## Troubleshooting

### Common Issues

1. **Submodule Updates**: If submodules are not updating correctly, try:

   ```bash
   git submodule update --init --recursive --force
   ```

2. **Docker Network Issues**: If services can't communicate, check network configuration:

   ```bash
   docker network ls
   docker network inspect observer_default
   ```

3. **Database Connection Issues**: Verify MariaDB is running and credentials are correct:
   ```bash
   docker-compose exec mariadb mysql -u observer -p
   ```

4. **Environment Variable Issues**: All environment variables are in `/env/` directory, not in submodules

5. **Authentication Issues**: Login at http://localhost:3000/login - authentication is enabled by default

For more information, check the documentation and README files in each submodule.
