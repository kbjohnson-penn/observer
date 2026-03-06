import { test, expect } from '@playwright/test';
import { loginViaApi } from '../../../helpers/api';

test.describe('Login (E2E)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('successful login with valid credentials redirects to dashboard', async ({
    page,
  }) => {
    await page
      .getByPlaceholder('Enter your username or email')
      .fill('e2e_admin');
    await page.getByPlaceholder('Enter your password').fill('E2eTestPass123!');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15000 });
    await expect(page.getByText('Research Data')).toBeVisible();
  });

  test('invalid credentials show error message', async ({ page }) => {
    await page
      .getByPlaceholder('Enter your username or email')
      .fill('e2e_admin');
    await page.getByPlaceholder('Enter your password').fill('wrongpassword');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(
      page.getByText(/invalid username or password/i)
    ).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
  });

  test('login with email works', async ({ page }) => {
    await page
      .getByPlaceholder('Enter your username or email')
      .fill('e2e_admin@example.com');
    await page.getByPlaceholder('Enter your password').fill('E2eTestPass123!');
    await page.getByRole('button', { name: /sign in/i }).click();

    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15000 });
  });

  test('authenticated user visiting /login is redirected to dashboard', async ({
    browser,
  }) => {
    const context = await browser.newContext();
    const { cookies } = await loginViaApi('e2e_admin', 'E2eTestPass123!');
    await context.addCookies(cookies);
    const page = await context.newPage();

    await page.goto('/login');
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15000 });
    await context.close();
  });
});
