import { test, expect } from '@playwright/test';
import {
  mockUnauthenticated,
  mockForgotPasswordSuccess,
} from '../../../helpers/mock-api';

test.describe('Forgot password form', () => {
  test.beforeEach(async ({ page }) => {
    await mockUnauthenticated(page);
  });

  test('renders form elements', async ({ page }) => {
    await page.goto('/forgot-password');

    await expect(page.getByText('Forgot Password')).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your email address')
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /send reset link/i })
    ).toBeVisible();
  });

  test('successful submission shows confirmation', async ({ page }) => {
    await mockForgotPasswordSuccess(page);

    await page.goto('/forgot-password');
    await page
      .getByPlaceholder('Enter your email address')
      .fill('user@example.edu');
    await page.getByRole('button', { name: /send reset link/i }).click();

    await expect(
      page.getByText(/if an account exists/i)
    ).toBeVisible();
    await expect(page.getByText('Back to Sign In')).toBeVisible();
  });

  test('has link back to sign in', async ({ page }) => {
    await page.goto('/forgot-password');
    await expect(page.getByText('Sign In')).toBeVisible();
  });
});
