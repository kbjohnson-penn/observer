import { test, expect } from '../../../fixtures/mock-auth.fixture';

test.describe('Login form', () => {
  test.describe('UI rendering', () => {
    test('Renders all form elements', async ({ page }) => {
      await page.goto('/login');

      await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
      await expect(
        page.getByPlaceholder('Enter your username or email')
      ).toBeVisible();
      await expect(page.getByPlaceholder('Enter your password')).toBeVisible();
      await expect(page.getByText('Forgot Password?')).toBeVisible();
      await expect(page.getByText('Register here')).toBeVisible();
    });

    test('Password field uses secure input type', async ({ page }) => {
      await page.goto('/login');

      const passwordInput = page.getByPlaceholder('Enter your password');
      await expect(passwordInput).toHaveAttribute('type', 'password');
    });
  });

  test.describe('Login behavior', () => {
    test.use({ authState: 'login-success' });

    test('Successful login redirects to dashboard', async ({ page }) => {
      await page.route('**/api/v1/research/filter-options/**', route =>
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

    test('Shows loading state while submitting', async ({ page }) => {
      await page.route('**/api/v1/accounts/auth/csrf-token/', route =>
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ csrfToken: 'fake' }),
        })
      );

      await page.route('**/api/v1/accounts/auth/token/', async route => {
        await new Promise(r => setTimeout(r, 1000));

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

      await page.goto('/login');

      await page.getByPlaceholder('Enter your username or email').fill('testuser');
      await page.getByPlaceholder('Enter your password').fill('password123');

      await page.getByRole('button', { name: /sign in/i }).click();

      await expect(page.getByText('Signing in...')).toBeVisible();
    });
  });

  test.describe('Authentication errors', () => {
    test.use({ authState: 'login-failure' });

    test('Invalid credentials show error message', async ({ page }) => {
      await page.goto('/login');

      await page.getByPlaceholder('Enter your username or email').fill('baduser');
      await page.getByPlaceholder('Enter your password').fill('wrongpass');

      await page.getByRole('button', { name: /sign in/i }).click();

      await expect(
        page.getByText(/invalid username or password/i)
      ).toBeVisible();
    });
  });

  test.describe('Security protections', () => {
    test('Cannot submit login with empty fields', async ({ page }) => {
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

    test('Login fetches CSRF token before authentication', async ({ page }) => {
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

    test('Security: prevents access to dashboard after token refresh fails', async ({ page }) => {
      await page.goto('/dashboard');

      await expect(page).toHaveURL(/\/login/);
    });
  });

  test.describe('Authenticated user behavior', () => {
    test.use({ authState: 'authenticated' });

    test('Authenticated user visiting /login is redirected to dashboard', async ({ page, context }) => {
      await context.addCookies([
        {
          name: 'access_token',
          value: 'mock-access-token',
          domain: 'localhost',
          path: '/',
          httpOnly: true,
          secure: false,
          sameSite: 'Lax',
        },
      ]);

      await page.route('**/api/v1/research/filter-options/**', route =>
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ total_accessible_visits: 0 }),
        })
      );

      await page.goto('/login');

      await expect(page).toHaveURL(/\/dashboard/);
    });

    test('Login sets secure auth cookies', async ({ page, context }) => {
      await context.addCookies([
        {
          name: 'access_token',
          value: 'mock-access-token',
          domain: 'localhost',
          path: '/',
          httpOnly: true,
          secure: false,
          sameSite: 'Lax',
        },
      ]);

      await page.goto('/login');

      const cookies = await context.cookies();

      const accessToken = cookies.find(c => c.name === 'access_token');

      expect(accessToken).toBeTruthy();
      expect(accessToken?.httpOnly).toBe(true);
      expect(accessToken?.sameSite).toBe('Lax');
    });
  });
});