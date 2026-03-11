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
      page.getByText(/If an account exists/i)
    ).toBeVisible();
    await expect(page.getByText('Back to Sign In')).toBeVisible();
  });

  test('has link back to sign in', async ({ page }) => {
    await page.goto('/forgot-password');
    await expect(page.getByText('Sign In')).toBeVisible();
  });

  test('forgot password does not reveal whether email exists', async ({ page }) => {
    await mockForgotPasswordSuccess(page);

    await page.goto('/forgot-password');
    await page
      .getByPlaceholder('Enter your email address')
      .fill('user@example.edu');
    await page.getByRole('button', { name: /send reset link/i }).click();

    await expect(page.getByText(/If an account exists/i)).toBeVisible();
  });

  test('security: forgot password does not grant an active session', async ({ page }) => {
    await mockUnauthenticated(page); // Ensure user is logged out
    await mockForgotPasswordSuccess(page);

    await page.goto('/forgot-password');
    await page.getByPlaceholder(/email address/i).fill('user@example.edu');
    await page.getByRole('button', { name: /send reset link/i }).click();

    // Verify the user is still considered unauthenticated by trying to visit dashboard
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });
});
