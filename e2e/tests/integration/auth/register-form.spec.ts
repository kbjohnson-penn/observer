import { test, expect } from '@playwright/test';
import {
  mockUnauthenticated,
  mockRegistrationSuccess,
} from '../../../helpers/mock-api';

test.describe('Registration form', () => {
  test.beforeEach(async ({ page }) => {
    await mockUnauthenticated(page);
  });

  test('renders all required fields', async ({ page }) => {
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
    await expect(
      page.getByPlaceholder('Enter your organization')
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /create account/i })
    ).toBeVisible();
  });

  test('successful registration shows success message', async ({ page }) => {
    await mockRegistrationSuccess(page);

    await page.goto('/register');
    await page.getByPlaceholder('Enter your first name').fill('Jane');
    await page.getByPlaceholder('Enter your last name').fill('Doe');
    await page.getByPlaceholder('Enter your email address').fill('jane@example.edu');
    await page.getByPlaceholder('Enter your organization').fill('MIT');
    await page.getByRole('button', { name: /create account/i }).click();

    await expect(
      page.getByText(/registration successful/i)
    ).toBeVisible();
    await expect(
      page.getByText(/check your email/i).first()
    ).toBeVisible();
  });

  test('has link to sign in page', async ({ page }) => {
    await page.goto('/register');
    await expect(page.getByText('Sign in here')).toBeVisible();
  });
});
