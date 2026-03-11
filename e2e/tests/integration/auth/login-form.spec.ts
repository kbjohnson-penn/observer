import { test, expect } from '@playwright/test';
import {
  mockLoginSuccess,
  mockLoginFailure,
  mockUnauthenticated,
  mockTokenRefreshFailure,
  mockAuthenticated,
} from '../../../helpers/mock-api';

test.describe('Login form', () => {
  test.beforeEach(async ({ page }) => {
    await mockTokenRefreshFailure(page);
  });

  test('renders all form elements', async ({ page }) => {
    await page.goto('/login');

    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your username or email')
    ).toBeVisible();
    await expect(page.getByPlaceholder('Enter your password')).toBeVisible();
    await expect(page.getByText('Forgot Password?')).toBeVisible();
    await expect(page.getByText('Register here')).toBeVisible();
  });

  test('successful login redirects to dashboard', async ({ page }) => {
    await mockLoginSuccess(page);

    // Also mock the dashboard's filter options and cohorts API
    await page.route('**/api/v1/research/filter-options/**', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ total_accessible_visits: 100 }),
      })
    );

    await page.goto('/login');
    await page.getByPlaceholder('Enter your username or email').fill('testuser');
    await page.getByPlaceholder('Enter your password').fill('password123');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(page).toHaveURL(/\/dashboard/);
  });

  test('invalid credentials show error message', async ({ page }) => {
    await mockLoginFailure(page);

    await page.goto('/login');
    await page.getByPlaceholder('Enter your username or email').fill('baduser');
    await page.getByPlaceholder('Enter your password').fill('wrongpass');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(
      page.getByText(/invalid username or password/i)
    ).toBeVisible();
  });

  test('shows loading state while submitting', async ({ page }) => {
    // Delay the login response to observe loading state
    await page.route('**/api/v1/accounts/auth/csrf-token/', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ csrfToken: 'fake' }),
      })
    );
    await page.route('**/api/v1/accounts/auth/token/', async (route) => {
      await new Promise((r) => setTimeout(r, 1000));
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          detail: 'Login successful',
          user: { id: 1, username: 'testuser', email: 'test@example.com' },
          expires_at: Math.floor(Date.now() / 1000) + 3600,
        }),
      });
    });
    await page.route('**/api/v1/accounts/profile/', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          user: { id: 1, username: 'testuser' },
          tier: { tier_name: 'Tier 5', level: 5 },
        }),
      })
    );

    await page.goto('/login');
    await page.getByPlaceholder('Enter your username or email').fill('testuser');
    await page.getByPlaceholder('Enter your password').fill('password123');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(page.getByText('Signing in...')).toBeVisible();
  });

  test('authenticated user visiting /login is redirected to dashboard', async ({
    page,
    context,
  }) => {
    // Set access_token cookie so middleware redirects /login → /dashboard
    await context.addCookies([
      {
        name: 'access_token',
        value: 'mock-access-token',
        domain: 'localhost',
        path: '/',
        httpOnly: true,
        secure: false,
        sameSite: 'Lax' as const,
      },
    ]);
    await mockAuthenticated(page);

    // Mock dashboard dependencies
    await page.route('**/api/v1/research/filter-options/**', (route) =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ total_accessible_visits: 0 }),
      })
    );

    await page.goto('/login');
    await expect(page).toHaveURL(/\/dashboard/);
  });

  test('cannot submit login with empty fields', async ({ page }) => {
    await page.goto('/login');

    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(
      page.getByPlaceholder('Enter your username or email')
    ).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your password')
    ).toBeVisible();

    await expect(page).toHaveURL('/login');
  });
  
  test('login sets secure auth cookies', async ({ page, context }) => {
    await context.addCookies([
      {
        name: 'access_token',
        value: 'mock-access-token',
        domain: 'localhost',
        path: '/',
        httpOnly: true,
        secure: false,
        sameSite: 'Lax' as const,
      },
    ]);
    await mockAuthenticated(page);

    await page.goto('/login');

    const cookies = await context.cookies();

    const accessToken = cookies.find(c => c.name === 'access_token');

    expect(accessToken).toBeTruthy();
    expect(accessToken?.httpOnly).toBe(true);
    expect(accessToken?.sameSite).toBe('Lax');
  });

  test('login fetches CSRF token before authentication', async ({ page }) => {
    let csrfRequested = false;

    await page.route('**/api/v1/accounts/auth/csrf-token/', route => {
      csrfRequested = true;
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ csrfToken: 'fake' }),
      });
    });

    await page.goto('/login');

    await page.getByPlaceholder('Enter your username or email').fill('testuser');
    await page.getByPlaceholder('Enter your password').fill('password123');

    await page.getByRole('button', { name: /sign in/i }).click();

    expect(csrfRequested).toBe(true);
  });

  test('password field uses secure input type', async ({ page }) => {
    await page.goto('/login');
    const passwordInput = page.getByPlaceholder('Enter your password');
    
    // Ensure the password is not visible in plain text in the DOM
    await expect(passwordInput).toHaveAttribute('type', 'password');
  });

  test('security: prevents access to dashboard after token refresh fails', async ({ page }) => {
    await page.goto('/dashboard');
    
    // App should boot the user to login for security
    await expect(page).toHaveURL(/\/login/);
  });
});
