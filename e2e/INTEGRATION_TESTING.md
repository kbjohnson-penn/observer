# Integration Testing Guide

This guide covers how to write and run **integration tests** for the Observer project using Playwright.

## Testing Pyramid

| | Unit Tests | Integration Tests | E2E Tests |
|---|---|---|---|
| **Tool** | Jest (frontend) / pytest (backend) | Playwright | Playwright |
| **Backend** | Not involved (mocked imports) | Mocked via `page.route()` | Real Django + MariaDB |
| **Frontend** | JSDOM (no real browser) | Real Next.js + real browser | Real Next.js + real browser |
| **Speed** | Fastest (~seconds) | Fast (~8s for 19 tests) | Slowest (needs Docker) |
| **Setup** | `npm run test` / `make test` | `npm run dev` in frontend | `docker compose up` + frontend |
| **Scope** | Single function/component | Full page UI flows | Full stack workflows |
| **Use case** | Logic, utils, component rendering | Form validation, navigation, UI states | Auth cookies, API contracts, DB writes |
| **Location** | `observer_frontend/src/**/*.test.ts` / `observer_backend/**/tests/` | `e2e/tests/integration/` | `e2e/tests/e2e/` |

**Which to use:**

- **Unit tests** — pure logic, utility functions, individual component rendering (no browser needed)
- **Integration tests** (default choice for new browser tests) — page-level UI flows with mocked APIs
- **E2E tests** — only when you need to verify real backend behavior (actual DB writes, cross-origin cookies)

## Playwright Quickstart

> **Official docs:** [playwright.dev/docs/intro](https://playwright.dev/docs/intro)

### Key concepts used in our tests

**Locators** — how you find elements on the page ([docs](https://playwright.dev/docs/locators)):

```typescript
page.getByRole('button', { name: 'Sign In' })  // Best — uses ARIA roles
page.getByRole('tab', { name: 'Cohorts' })      // Tabs, links, headings, etc.
page.getByPlaceholder('Enter your email')        // Form inputs by placeholder
page.getByText('Welcome back')                   // Text content (use sparingly)
page.getByTestId('submit-btn')                   // data-testid attribute (last resort)
```

**Assertions** — how you verify things ([docs](https://playwright.dev/docs/test-assertions)):

```typescript
await expect(page.getByRole('button')).toBeVisible()      // Element exists and is visible
await expect(page.getByRole('button')).toBeDisabled()      // Element is disabled
await expect(page).toHaveURL(/\/dashboard/)                // URL matches pattern
await expect(page.getByText('Error')).not.toBeVisible()    // Element is NOT visible
```

**Route mocking** — how we intercept API calls ([docs](https://playwright.dev/docs/mock#mock-api-requests)):

```typescript
// Intercept a GET request and return fake data
await page.route('**/api/v1/accounts/profile/', (route) =>
  route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ user: { username: 'test' } }),
  })
);

// Use regex when the URL has query params (e.g., ?page=1)
await page.route(/\/api\/v1\/search\//, (route) => route.fulfill({ ... }));
```

**Fixtures** — reusable test setup ([docs](https://playwright.dev/docs/test-fixtures)):

```typescript
// Our project defines custom fixtures in fixtures/mock-auth.fixture.ts
// They provide pre-configured pages:
test('my test', async ({ authenticatedPage }) => {
  // authenticatedPage already has cookies + auth API mocks set up
  await authenticatedPage.goto('/dashboard');
});
```

**Important Playwright behaviors in our project:**

- Routes are matched in **LIFO order** (last registered wins). Fixture routes are registered before test routes, so test-specific mocks take priority.
- `page.route()` only intercepts **browser-side** requests. Server-side rendering (SSR) fetches are not intercepted. Our dashboard is `'use client'`, so all API calls happen browser-side.
- Glob patterns (`**/api/v1/foo/`) match path segments only. Use **regex** for URLs with query strings.

## Running Tests

### Prerequisites

```bash
# 1. Start the frontend dev server
cd observer_frontend
NEXT_PUBLIC_BACKEND_API=http://localhost:8000/api/v1 npm run dev

# 2. Install Playwright (first time only)
cd e2e
npm install
npx playwright install chromium
```

### Commands

```bash
cd e2e

# Run all integration tests
npm run test:integration

# Run a specific test file
npx playwright test --project=integration tests/integration/auth/login-form.spec.ts

# Run in headed mode (see the browser)
npx playwright test --project=integration --headed

# Run with Playwright UI (interactive debugger)
npx playwright test --project=integration --ui

# Debug a specific test
npx playwright test --project=integration --debug tests/integration/auth/login-form.spec.ts

# Check for flakiness (run 3 times)
npx playwright test --project=integration --repeat-each=3

# View HTML report after a run
npm run report
```

## Project Structure

```
e2e/
├── fixtures/
│   ├── mock-auth.fixture.ts    # authenticatedPage / unauthenticatedPage
│   └── auth.fixture.ts         # E2E fixtures (real backend, ignore for integration)
├── helpers/
│   └── mock-api.ts             # All mock functions (mockLoginSuccess, etc.)
├── tests/
│   └── integration/
│       ├── smoke/              # Basic page-load tests
│       ├── auth/               # Login, register, forgot-password
│       └── dashboard/          # Dashboard tabs, data display
├── playwright.config.ts
└── global-setup.integration.ts # Verifies frontend is running
```

## Writing a New Test

### Step 1: Create the test file

Place it under `tests/integration/` in a folder matching the feature area:

```
tests/integration/settings/profile.spec.ts
```

### Step 2: Choose your fixture

**For pages that require authentication** (dashboard, settings, profile):

```typescript
import { test, expect } from '../../../fixtures/mock-auth.fixture';

test('shows profile page', async ({ authenticatedPage }) => {
  // authenticatedPage already has:
  // - access_token + refresh_token cookies set
  // - token/refresh and /profile API calls mocked
  await authenticatedPage.goto('/settings/profile');
  // ...assertions
});
```

**For public pages** (login, register, forgot-password):

```typescript
import { test, expect } from '@playwright/test';
import { mockUnauthenticated } from '../../../helpers/mock-api';

test.describe('Login form', () => {
  test.beforeEach(async ({ page }) => {
    // Mock the auth check that runs on every page load
    await mockUnauthenticated(page);
  });

  test('renders login form', async ({ page }) => {
    await page.goto('/login');
    // ...assertions
  });
});
```

### Step 3: Mock API calls

Any API call your page makes must be mocked. If you don't mock it, the request hits `localhost:8000` (which isn't running), causing a network error.

```typescript
test('loads user settings', async ({ authenticatedPage }) => {
  // Mock the API endpoint this page calls
  await authenticatedPage.route('**/api/v1/accounts/settings/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        notifications_enabled: true,
        theme: 'light',
      }),
    })
  );

  await authenticatedPage.goto('/settings');
  await expect(authenticatedPage.getByText('Notifications')).toBeVisible();
});
```

### Step 4: Write assertions

Use Playwright's **role-based locators** (preferred) or text locators:

```typescript
// Preferred — uses ARIA roles, resilient to text changes
await expect(page.getByRole('button', { name: 'Save' })).toBeVisible();
await expect(page.getByRole('tab', { name: 'Cohorts' })).toBeVisible();
await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();

// OK for unique text
await expect(page.getByPlaceholder('Enter your email')).toBeVisible();

// Avoid — can match multiple elements and cause strict mode violations
// await expect(page.getByText('Cohorts')).toBeVisible(); // BAD — matches tab + content
```

## Available Mock Helpers

Import from `../../../helpers/mock-api`:

| Function | What it mocks |
|---|---|
| `mockAuthenticated(page)` | Token refresh success + profile fetch |
| `mockUnauthenticated(page)` | Token refresh failure (user not logged in) |
| `mockLoginSuccess(page)` | CSRF + login + profile (full login flow) |
| `mockLoginFailure(page)` | CSRF + login returns 401 |
| `mockLogoutSuccess(page)` | CSRF + logout endpoint |
| `mockRegistrationSuccess(page)` | CSRF + registration returns 201 |
| `mockForgotPasswordSuccess(page)` | CSRF + password reset endpoint |
| `mockCsrfToken(page)` | Just the CSRF token endpoint |
| `mockTokenRefreshSuccess(page)` | Token refresh + profile |
| `mockTokenRefreshFailure(page)` | Token refresh returns 401 |

### Default test data

```typescript
import { DEFAULT_USER, DEFAULT_PROFILE } from '../../../helpers/mock-api';

// DEFAULT_USER = { id: 1, username: 'testuser', email: 'testuser@example.com' }
// DEFAULT_PROFILE = {
//   user: DEFAULT_USER,
//   tier: { tier_name: 'Tier 5', level: 5 },
//   organization: { name: 'Test Hospital' },
// }
```

You can override defaults:

```typescript
await mockLoginSuccess(page, customUser, customProfile);
```

## Common Patterns

### Testing form submission

```typescript
test('submits form successfully', async ({ page }) => {
  await mockUnauthenticated(page);
  await mockLoginSuccess(page);

  await page.goto('/login');
  await page.getByPlaceholder('Enter your username or email').fill('testuser');
  await page.getByPlaceholder('Enter your password').fill('password123');
  await page.getByRole('button', { name: /sign in/i }).click();

  await expect(page).toHaveURL(/\/dashboard/);
});
```

### Testing error states

```typescript
test('shows error on invalid credentials', async ({ page }) => {
  await mockUnauthenticated(page);
  await mockLoginFailure(page);

  await page.goto('/login');
  await page.getByPlaceholder('Enter your username or email').fill('wrong');
  await page.getByPlaceholder('Enter your password').fill('wrong');
  await page.getByRole('button', { name: /sign in/i }).click();

  await expect(page.getByText(/invalid/i)).toBeVisible();
});
```

### Testing loading states

```typescript
test('shows loading spinner', async ({ page }) => {
  await mockUnauthenticated(page);
  await mockCsrfToken(page);

  // Delay the API response
  await page.route('**/api/v1/accounts/auth/token/', async (route) => {
    await new Promise((r) => setTimeout(r, 1000));
    await route.fulfill({ status: 200, body: JSON.stringify({}) });
  });

  await page.goto('/login');
  await page.getByRole('button', { name: /sign in/i }).click();

  // Assert loading state is visible during the delay
  await expect(page.getByRole('button', { name: /signing in/i })).toBeVisible();
});
```

### Mocking dashboard APIs

The dashboard requires several API mocks to render. Use this pattern:

```typescript
async function mockDashboardApis(page: Page) {
  // 1. Filter options (required by ResearchTab)
  await page.route('**/api/v1/research/private/filter-options/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        demographics: {
          genders: ['Male', 'Female'],
          races: [],
          ethnicities: [],
          year_of_birth_range: { min: 1940, max: 2000 },
        },
        visit_options: {
          tiers: [1, 2, 3],
          visit_sources: ['Hospital'],
          date_range: { earliest: '2020-01-01', latest: '2024-12-31' },
        },
        clinical_options: {
          conditions: { available_codes: [], available_values: [], total_visits: 0 },
          labs: { procedure_names: [], result_flags: [], order_statuses: [], total_visits: 0 },
          drugs: { common_drugs: [], total_visits: 0 },
          procedures: { common_names: [], future_or_stand_options: [], total_visits: 0 },
          notes: { note_types: [], note_statuses: [], total_visits: 0 },
          observations: { file_types: [], total_visits: 0 },
          measurements: {
            total_visits: 0,
            bp_systolic_range: { min: 90, max: 180 },
            weight_range: { min: 40, max: 150 },
          },
        },
        total_accessible_visits: 42,
      }),
    })
  );

  // 2. Visit search (required by ResearchTab — use regex for query params)
  await page.route(/\/api\/v1\/research\/private\/visits-search\//, (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        results: [],
        count: 0,
        next: null,
        previous: null,
        filter_summary: {
          total_visits: 42,
          filtered_visits: 42,
          active_filters: 0,
        },
      }),
    })
  );

  // 3. Cohorts list
  await page.route('**/api/v1/accounts/cohorts/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ cohorts: [], count: 0 }),
    })
  );
}
```

## Troubleshooting

### "strict mode violation: resolved to N elements"

Your locator matches multiple elements. Use a more specific locator:

```typescript
// BAD — "Cohorts" appears in tab name AND tab content
page.getByText('Cohorts')

// GOOD — targets only the tab element
page.getByRole('tab', { name: 'Cohorts' })

// GOOD — targets a specific button
page.getByRole('button', { name: 'Sign In' })

// OK — use .first() as a last resort
page.getByText(/check your email/i).first()
```

### Dashboard crashes with "Cannot read properties of undefined"

Your API mock is missing required fields. The dashboard expects complete response objects. Check:

- `filter-options` must include `visit_options.visit_sources`, `demographics`, `clinical_options`, and `total_accessible_visits`
- `visits-search` must include `filter_summary` with `total_visits`, `filtered_visits`, `active_filters`
- `cohorts` must return `{ cohorts: [], count: 0 }` (not `{ results: [] }`)

### Route pattern doesn't match

- **Glob patterns** (`**/api/v1/accounts/cohorts/`) match path segments only, not query strings
- **Regex patterns** (`/\/api\/v1\/research\/private\/visits-search\//`) match the full URL including query strings
- Use regex when the URL has query parameters (e.g., `?page=1`)

### Playwright route priority (LIFO)

Routes registered **later** take priority over earlier ones. If your test mock doesn't seem to work:

1. Check if a fixture already registered a route for the same URL pattern
2. Routes from the test body (registered after fixture) have higher priority
3. Never use a broad catch-all route (`/\/api\/v1\//`) — it will shadow fixture routes

### Test passes locally but fails in CI

- Add explicit timeouts for slow operations: `{ timeout: 10000 }`
- Wait for elements to be visible before interacting: `await expect(locator).toBeVisible()`
- Check that `NEXT_PUBLIC_BACKEND_API` is set when building the frontend

## Adding Tests for a New Page

Checklist for testing a new page:

1. Identify if the page is public or authenticated
2. Find which API endpoints the page calls (check hooks, contexts, and utility functions)
3. Create mocks for each endpoint with the correct response shape
4. Write tests covering: page renders, user interactions, error states, loading states
5. Use `getByRole()` locators whenever possible
6. Run with `--repeat-each=3` to check for flakiness before committing
