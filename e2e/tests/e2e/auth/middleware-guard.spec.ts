import { test, expect } from '@playwright/test';

test.describe('Middleware auth guard (E2E)', () => {
  test('unauthenticated /dashboard redirects to /login', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });

  test('unauthenticated /settings redirects to /login', async ({ page }) => {
    await page.goto('/settings');
    await expect(page).toHaveURL(/\/login/);
  });

  test('unauthenticated /profile redirects to /login', async ({ page }) => {
    await page.goto('/profile');
    await expect(page).toHaveURL(/\/login/);
  });

  test('/login is accessible without auth', async ({ page }) => {
    await page.goto('/login');
    await expect(page).toHaveURL(/\/login/);
    await expect(
      page.getByRole('button', { name: /sign in/i })
    ).toBeVisible();
  });

  test('/register is accessible without auth', async ({ page }) => {
    await page.goto('/register');
    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.getByText('Create Account')).toBeVisible();
  });

  test('/forgot-password is accessible without auth', async ({ page }) => {
    await page.goto('/forgot-password');
    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.getByText('Forgot Password')).toBeVisible();
  });
});
