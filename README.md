# Observer

Observer is a comprehensive platform for collecting, analyzing, and visualizing medical encounter data with multimodal capabilities.

## Project Overview

This repository contains the `observer_frontend` and `observer_backend` projects as Git submodules:

- **observer_frontend**: React/Next.js-based frontend application
- **observer_backend**: Django REST API backend service

## Table of Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Cloning the Repository](#cloning-the-repository)
  - [Environment Setup](#environment-setup)
- [Running the Project](#running-the-project)
  - [Development Mode](#development-mode)
  - [Test Mode](#test-mode)
  - [Production Mode](#production-mode)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Contributing](#contributing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/) (2.13.0+)
- [Docker](https://docs.docker.com/get-docker/) (20.10.0+)
- [Docker Compose](https://docs.docker.com/compose/install/) (1.29.0+)

### Cloning the Repository

To clone this repository along with its submodules, use the following command:

```bash
git clone --recurse-submodules git@github.com:kbjohnson-penn/observer.git
cd observer
```

If you have already cloned the repository without submodules, you can initialize and update the submodules with:

```bash
git submodule update --init --recursive
```

### Environment Setup

1. Create the environment files directory:

```bash
mkdir -p env
touch env/dev.env env/test.env env/prod.env
```

2. Configure environment variables in each file. A minimal configuration example:

```
# Backend settings
SECRET_KEY=your-secret-key
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=postgres://postgres:postgres@db:5432/observer

# Frontend settings
NEXT_PUBLIC_API_URL=http://localhost:8000/api
```

Refer to individual submodule documentation for detailed environment variable requirements.

## Running the Project

The project uses Docker Compose for containerized deployment with different configurations for development, testing, and production environments.

### Development Mode

```bash
./docker_control.sh start dev
```

Or manually:

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build -d
```

This starts:

- Frontend service at http://localhost:3000
- Backend service at http://localhost:8000
- PostgreSQL database
- Redis cache

### Test Mode

```bash
./docker_control.sh start test
```

Or manually:

```bash
docker-compose -f docker-compose.yml -f docker-compose.test.yml up --build -d
```

### Production Mode

```bash
./docker_control.sh start prod
```

Or manually:

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
```

### Initial Setup

After starting services for the first time:

1. Create a Django superuser:

```bash
docker-compose exec backend python manage.py createsuperuser
```

2. Run database migrations:

```bash
docker-compose exec backend python manage.py migrate
```

3. Generate test data (optional):

```bash
docker-compose exec backend python manage.py generate_mock_data
```

## Project Structure

```
observer/
├── docker-compose.yml              # Base Docker Compose configuration
├── docker-compose.dev.yml          # Development overrides
├── docker-compose.test.yml         # Testing overrides
├── docker-compose.prod.yml         # Production overrides
├── docker_control.sh               # Convenience script for Docker operations
├── observer_backend/               # Backend submodule
└── observer_frontend/              # Frontend submodule
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

Stop all services:

```bash
./docker_control.sh stop
```

View logs:

```bash
docker-compose logs -f
```

Access container shells:

```bash
docker-compose exec frontend sh
docker-compose exec backend bash
```

## Testing

### Backend Tests

```bash
docker-compose exec backend python manage.py test
```

### Frontend Tests

```bash
docker-compose exec frontend npm test
```

## Contributing

Please refer to the `CONTRIBUTING.md` files in each submodule for detailed contribution guidelines.

## Deployment

For production deployment, ensure:

1. Set secure environment variables in `env/prod.env`
2. Use production Docker Compose configuration: `docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
3. Configure reverse proxy (Nginx, Traefik) for TLS termination

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

3. **Database Connection Issues**: Verify PostgreSQL is running and credentials are correct:
   ```bash
   docker-compose exec db psql -U postgres
   ```

For more information, check the documentation and README files in each submodule.
