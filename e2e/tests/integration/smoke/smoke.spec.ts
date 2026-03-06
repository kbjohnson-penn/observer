import { test, expect } from '@playwright/test';
import { mockUnauthenticated } from '../../../helpers/mock-api';

test.describe('Smoke tests', () => {
  test('homepage loads', async ({ page }) => {
    await mockUnauthenticated(page);
    await page.goto('/');
    await expect(page).toHaveTitle(/Observer/i);
  });

  test('/login renders sign in form', async ({ page }) => {
    await mockUnauthenticated(page);
    await page.goto('/login');
    await expect(page.getByRole('button', { name: 'Sign In' })).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your username or email')
    ).toBeVisible();
    await expect(page.getByPlaceholder('Enter your password')).toBeVisible();
  });

  test('/register renders registration form', async ({ page }) => {
    await mockUnauthenticated(page);
    await page.goto('/register');
    await expect(
      page.getByRole('button', { name: 'Create Account' })
    ).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your first name')
    ).toBeVisible();
    await expect(page.getByPlaceholder('Enter your last name')).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your email address')
    ).toBeVisible();
  });

  test('/forgot-password renders form', async ({ page }) => {
    await mockUnauthenticated(page);
    await page.goto('/forgot-password');
    await expect(page.getByText('Forgot Password')).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your email address')
    ).toBeVisible();
  });
});
