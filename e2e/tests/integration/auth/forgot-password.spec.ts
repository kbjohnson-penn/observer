import { Page } from '@playwright/test';
import { test, expect } from '../../../fixtures/mock-auth.fixture';
import { mockForgotPasswordSuccess } from '../../../helpers/mock-api';

test.describe('Forgot password form', () => {
  test.use({ authState: 'unauthenticated' });

  const emailInput = (page: Page) =>
    page.getByPlaceholder('Enter your email address');

  const submitButton = (page: Page) =>
    page.getByRole('button', { name: /send reset link/i });

  test.beforeEach(async ({ page }) => {
    await page.goto('/forgot-password');
  });

  test('Renders form elements', async ({ page }) => {
    await expect(page.getByText('Forgot Password')).toBeVisible();
    await expect(emailInput(page)).toBeVisible();
    await expect(submitButton(page)).toBeVisible();
  });

  test('Successful submission shows confirmation', async ({ page }) => {
    await mockForgotPasswordSuccess(page);

    await emailInput(page).fill('user@example.edu');
    await submitButton(page).click();

    await expect(page.getByText(/If an account exists/i)).toBeVisible();
    await expect(page.getByText('Back to Sign In')).toBeVisible();
  });

  test('Has link back to sign in', async ({ page }) => {
    await expect(page.getByText('Sign In')).toBeVisible();
  });

  test('Forgot password does not reveal whether email exists', async ({ page }) => {
    await mockForgotPasswordSuccess(page);

    await emailInput(page).fill('user@example.edu');
    await submitButton(page).click();

    await expect(page.getByText(/If an account exists/i)).toBeVisible();
  });

  test('Security: forgot password does not grant an active session', async ({ page }) => {
    await mockForgotPasswordSuccess(page);

    await emailInput(page).fill('user@example.edu');
    await submitButton(page).click();

    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
  });
});