# CLAUDE.md - AI Context Reference

## Project Status

**Observer**: Healthcare platform with Django 5.0.1 backend + Next.js 14 frontend
**Authentication**: ENABLED (JWT, login at `/login`)
**Database**: MariaDB
**Environment**: Centralized in `/env/` directory
**Submodules**: `observer_backend`, `observer_frontend`

## Quick Commands

```bash
# Start dev with mock data
./docker_control.sh start dev
./docker_control.sh mockdata dev

# Common tasks
docker-compose exec backend python manage.py migrate
docker-compose exec backend python manage.py createsuperuser
docker-compose logs -f backend
```

## Access

- Frontend: http://localhost:3000
- API: http://localhost:8000/api
- Admin: http://localhost:8000/admin

## Key Paths

- **Auth URLs**: `dashboard/api/urls/v1/__init__.py`
- **Middleware**: `observer_frontend/src/middleware.ts`
- **Mock Data**: `dashboard/management/commands/generate_mock_data.py`
- **Environment**: `/env/dev.env`, `/env/test.env`, `/env/prod.env`

## API Endpoints

- **Auth**: `/api/v1/auth/token/` (login), `/api/v1/auth/logout/`
- **Public**: `/api/v1/public/patients/`, `/api/v1/public/encounters/`
- **Private**: `/api/v1/private/patients/`, `/api/v1/private/encounterfiles/`

## Project Architecture

### Backend (Django 5.0.1)
- **Structure**: `dashboard/` app with `api/`, `models/`, `management/commands/`
- **Authentication**: JWT via `djangorestframework-simplejwt`
- **Database**: MariaDB with proper relationships
- **Storage**: Azure Storage integration (optional dev, required prod)
- **APIs**: Public (`/public/`) and Private (`/private/`) endpoints

### Frontend (Next.js 14)
- **Architecture**: App Router with TypeScript
- **Styling**: Chakra UI v3 + TailwindCSS hybrid
- **Auth**: JWT tokens with automatic refresh via axios interceptors
- **State**: React Context for authentication (`AuthContext`)
- **Protected Routes**: Middleware protects `/dashboard/*` and `/profile/*`

### Docker Setup
- **Services**: backend, frontend, mariadb
- **Environments**: dev/test/prod with separate configs
- **Environment**: Centralized in `/env/` directory

## Coding Standards

### Backend (Django)
- **Models**: Use descriptive field names, proper relationships
- **API Views**: DRF ViewSets with proper serializers
- **Permissions**: Separate public/private endpoints
- **Mock Data**: Environment-driven generation with realistic data

### Frontend (Next.js)
- **Components**: Functional components with TypeScript
- **Styling**: Chakra UI props + TailwindCSS classes
- **API Calls**: Type-safe with interfaces, proper error handling
- **Authentication**: Use AuthContext, protect routes via middleware

### General
- **Git**: Conventional commits, feature branches in submodules
- **Environment**: All config in `/env/`, not in submodules
- **Testing**: Backend tests via Django, frontend tests via npm

## Common Workflows

### Authentication Changes
1. Backend: Update `dashboard/api/urls/v1/__init__.py`
2. Frontend: Update `observer_frontend/src/middleware.ts`
3. Test login flow at `/login`

### Adding API Endpoints
1. Create/update models in `dashboard/models/`
2. Create serializers in `dashboard/api/serializers/`
3. Create views in `dashboard/api/views/`
4. Update URLs in `dashboard/api/urls/v1/`
5. Run migrations: `docker-compose exec backend python manage.py makemigrations`

### Environment Updates
1. Update variables in `/env/dev.env` (or test/prod)
2. Restart containers: `./docker_control.sh restart dev`
3. No rebuild needed unless new variables added

### Mock Data Updates
1. Modify `dashboard/management/commands/generate_mock_data.py`
2. Update environment variables in `/env/` files
3. Regenerate: `./docker_control.sh mockdata dev`

### Submodule Updates
1. Work in feature branch within submodule
2. Commit and push changes in submodule
3. Update pointer in main repo: `git add observer_backend && git commit`

## Important Notes

- **Authentication**: ENABLED (JWT auth, login functional)
- **Database**: MariaDB (not PostgreSQL)
- **Environment**: All variables in `/env/` directory, not submodules
- **Ports**: 3000 (frontend), 8000 (backend), 3306 (database)
- **Mock Data**: Clinic (1-200 IDs, 3-6 files), SimCenter (5M-6M IDs, 1-2 files)
- **File Consistency**: Multimodal data flags match encounter files

## Recent Changes

- Authentication enabled in backend (`dashboard/api/urls/v1/__init__.py`) and frontend (`middleware.ts`)
- Environment variables consolidated to `/env/` directory
- Mock data generation improved with environment variable support
- Multimodal data flags now match encounter files consistently