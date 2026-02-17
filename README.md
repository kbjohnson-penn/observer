# Observer

Healthcare platform for collecting, analyzing, and visualizing medical encounter data with multimodal capabilities.

## Quick Start

### Container Development (Recommended)

Works with both **Docker** and **Podman**.

```bash
git clone --recurse-submodules https://github.com/kbjohnson-penn/observer.git
cd observer

# Copy observer_backend/.env.docker to observer_backend/.env
cp observer_backend/.env.docker observer_backend/.env

# Start all services (auto-detects docker or podman)
./scripts/container_control.sh start

# Or specify the runtime explicitly
./scripts/container_control.sh start docker
./scripts/container_control.sh start podman
```

### Local Development

#### CRITICAL: Domain Configuration

**Authentication requires consistent domain usage between frontend and backend.**

Frontend runs on: `http://localhost:3000`
Backend must be accessed via: `http://localhost:8000`

**DO NOT MIX `localhost` and `127.0.0.1`** - they are treated as different domains by browsers, which will break httpOnly cookie authentication.

#### Setup Steps

1. Update paths in `scripts/clean_db.sh`

```bash
ENV_FILE="/path/to/observer/observer_backend/.env"
PYTHON_PATH="/path/to/miniconda3/envs/observer/bin/python"
PROJECT_DIR="/path/to/Workspace/projects/observer/observer_backend/"
```

2. **Configure frontend environment variables**

Copy and verify `observer_frontend/.env.local`:
```bash
# CORRECT - use localhost consistently
NEXT_PUBLIC_BACKEND_API=http://localhost:8000/api/v1
INTERNAL_BACKEND_API=http://localhost:8000/api/v1

# WRONG - will break authentication
# NEXT_PUBLIC_BACKEND_API=http://127.0.0.1:8000/api/v1
```

3. Run the services

```bash
# Set up databases
./scripts/db_control.sh clean

# Import SQL data (optional - if you have data dumps)
./scripts/db_control.sh import

# Run backend locally
cd observer_backend
pip install -r requirements.txt
python manage.py runserver 0.0.0.0:8000

# Run frontend locally
cd observer_frontend
npm install
npm run dev
```

**Access:**
- Backend API: http://localhost:8000/api
- Admin: http://localhost:8000/admin
- Frontend: http://localhost:3000

#### Authentication Troubleshooting

If login redirects to login page (redirect loop):

1. **Check domain consistency** in `.env.local` files
2. **Clear browser cookies** for both localhost:3000 and 127.0.0.1:8000
3. **Verify backend CORS settings** include `http://localhost:3000`
4. **Check browser Network tab** for `Set-Cookie` headers in login response

**Note for development:** While containers are excellent for production deployments, consider using local development (npm run dev) instead during development on Mac and Windows for better performance.

## Architecture

- **Frontend**: Next.js 15 + TypeScript (see `observer_frontend/README.md`)
- **Backend**: Django 5.0.1 + DRF + JWT Auth (see `observer_backend/README.md`)
- **Database**: Multi-database MariaDB setup (accounts, clinical, research)
- **Storage**: Azure Storage
- **Containerization**: Docker/Podman with Compose

## Prerequisites

- Docker or Podman (with Compose)
- For local development: Python 3.10+, Node.js 18+, MariaDB

## Container Configuration

The setup uses a single `docker-compose.yml` (compatible with both Docker and Podman) with three MariaDB containers:

- **accounts_db**: Port 3306 → `observer_accounts` database
- **clinical_db**: Port 3307 → `observer_clinical` database  
- **research_db**: Port 3308 → `observer_research` database

Environment variables are configured in `observer_backend/.env`.

## Container Commands

Use `./scripts/container_control.sh` to manage the environment. It auto-detects your runtime, or you can specify it explicitly.

```bash
# Start all services
./scripts/container_control.sh start
./scripts/container_control.sh start docker    # force docker
./scripts/container_control.sh start podman    # force podman

# Stop services
./scripts/container_control.sh stop

# Rebuild images
./scripts/container_control.sh rebuild

# Restart (stop + rebuild + start)
./scripts/container_control.sh restart

# Clean everything (containers, volumes, images)
./scripts/container_control.sh clean

# Run migrations and generate mock data
./scripts/container_control.sh mockdata
```

### Manual Operations

Replace `docker` with `podman` if using Podman.

```bash
# View logs
docker compose logs -f
docker compose logs -f backend

# Access containers
docker compose exec backend bash
docker compose exec accounts_db mysql -u observer -pobserver_password observer_accounts

# Create admin user
docker compose exec backend python manage.py createsuperuser --database=accounts
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
