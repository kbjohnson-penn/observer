# Observer Project

Healthcare platform for clinical observation and research data management.

## Project Structure

This is a monorepo with Git submodules:

- `observer_backend/` - Django REST API
- `observer_frontend/` - Next.js web application

## Tech Stack

### Backend (Python/Django)

- **Python 3.10+** / **Django 5.2.6** / **DRF 3.16.1**
- **MariaDB** - 3 separate databases:
  - `observer_accounts` (port 3306) - Authentication
  - `observer_clinical` (port 3307) - Clinical data
  - `observer_research` (port 3308) - Research data
- **JWT auth** via djangorestframework-simplejwt (httpOnly cookie-based)
- **Azure Blob Storage** for file storage

## Authentication

The backend uses **httpOnly cookie-based JWT authentication** for security:

- **Tokens stored in cookies**: `access_token` and `refresh_token` (not in response body)
- **Cookie settings**: httpOnly, secure (production), SameSite=None (cross-subdomain)
- **CSRF protection**: Required for all state-changing endpoints
- **Rate limiting**: Configurable via `.env` files (e.g., `RATE_LIMIT_LOGIN=5/m`)
- **Audit logging**: Login/logout and major events are logged with IP and user agent

### Auth Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/accounts/auth/token/` | POST | Login (sets cookies) |
| `/api/v1/accounts/auth/token/refresh/` | POST | Refresh access token |
| `/api/v1/accounts/auth/token/verify/` | POST | Verify token validity |
| `/api/v1/accounts/auth/logout/` | POST | Logout (clears cookies) |
| `/api/v1/accounts/auth/csrf-token/` | GET | Get CSRF token |

### Key Files

- `accounts/api/views/auth_views.py` - Auth view implementations
- `shared/authentication.py` - `CookieJWTAuthentication` class
- `backend/settings/base.py` - `RATE_LIMITS` configuration

### Frontend (TypeScript/React)

- **Next.js 15.5.2** / **React 19.1.1** / **TypeScript**
- **Chakra UI 3.21.0** + **Tailwind CSS 3.3.0**
- **D3 7.9.0** + **Recharts 2.10.4** for visualization

### Infrastructure

- **Docker** with docker-compose
- **GitHub Actions** for CI/CD
- **Git hooks**: Husky, pre-commit, lint-staged

## Common Commands

### Backend (from `observer_backend/`)

```bash
make install-dev    # Install dependencies
make run            # Run dev server
make test           # Run tests with coverage
make lint           # Run all linters
make format         # Format code (Black + isort)
make migrate        # Run migrations
```

### Frontend (from `observer_frontend/`)

```bash
npm install         # Install dependencies
npm run dev         # Run dev server
npm run build       # Production build
npm run test        # Run Jest tests
npm run lint        # ESLint check
npm run format      # Prettier format
```

### Docker

```bash
docker-compose up -d          # Start all services
docker-compose down           # Stop services
docker-compose logs -f api    # View backend logs
```

## Code Standards

### Backend

- PEP 8 compliant, max line length 100
- Type hints required (mypy enforced)
- Docstrings for public functions

### Frontend

- Strict TypeScript (no `any`)
- Functional components with hooks
- Chakra UI for components, Tailwind for utilities

## Database Routing

The backend uses Django's multi-database routing:

- `accounts` app → `observer_accounts` database
- `clinical` app → `observer_clinical` database
- `research` app → `observer_research` database

Always specify `using='db_name'` for cross-database queries. And you cannot perform joins across different databases or use foreign keys spanning databases.
