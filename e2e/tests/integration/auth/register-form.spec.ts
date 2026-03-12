// registration.spec.ts
import { test, expect } from '../../../fixtures/mock-auth.fixture';
import type { Page } from '@playwright/test';
import { mockRegistrationSuccess } from '../../../helpers/mock-api';

test.describe('Registration form', () => {
  // Apply unauthenticated fixture to all tests in this suite
  test.use({ authState: 'unauthenticated' });

  /**
   * Helper function to fill registration form.
   */
  const fillRegistrationForm = async (page: Page) => {
    await page.getByPlaceholder('Enter your first name').fill('Jane');
    await page.getByPlaceholder('Enter your last name').fill('Doe');
    await page
      .getByPlaceholder('Enter your email address')
      .fill('jane@example.edu');
    await page.getByPlaceholder('Enter your organization').fill('MIT');
  };

  test('Renders all required fields', async ({ page }) => {
    await page.goto('/register');

    // Check that all fields and buttons are visible
    await expect(
      page.getByPlaceholder('Enter your first name')
    ).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your last name')
    ).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your email address')
    ).toBeVisible();
    await expect(
      page.getByPlaceholder('Enter your organization')
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /create account/i })
    ).toBeVisible();
    await expect(page.getByText('Sign in here')).toBeVisible();
  });

  test('Successful registration shows success message', async ({ page }) => {
    await mockRegistrationSuccess(page); // Mock backend success

    await page.goto('/register');
    await fillRegistrationForm(page); // Fill the form
    await page.getByRole('button', { name: /create account/i }).click();

    // Verify success messages
    await expect(
      page.getByText(/registration successful/i)
    ).toBeVisible();
    await expect(
      page.getByText(/check your email/i).first()
    ).toBeVisible();
  });

  test('Cannot submit registration with missing fields', async ({ page }) => {
    await mockRegistrationSuccess(page); // Even with mock, missing fields prevent submission

    await page.goto('/register');
    await page.getByRole('button', { name: /create account/i }).click();

    // Form fields should still be visible (no redirect)
    await expect(
      page.getByPlaceholder('Enter your first name')
    ).toBeVisible();
    await expect(page).toHaveURL('/register');
  });
});
