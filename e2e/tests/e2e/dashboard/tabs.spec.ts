import { test, expect } from '../../../fixtures/auth.fixture';

test.describe('Dashboard tabs (E2E)', () => {
  test('shows Research Data and Cohorts tabs when authenticated', async ({
    adminPage,
  }) => {
    await adminPage.goto('/dashboard');

    await expect(adminPage.getByRole('tab', { name: 'Research Data' })).toBeVisible({
      timeout: 15000,
    });
    await expect(adminPage.getByRole('tab', { name: 'Cohorts' })).toBeVisible();
  });

  test('defaults to research tab', async ({ adminPage }) => {
    await adminPage.goto('/dashboard');

    await expect(adminPage.getByRole('tab', { name: 'Research Data' })).toBeVisible({
      timeout: 15000,
    });
    await expect(adminPage).toHaveURL(/tab=research/);
  });

  test('clicking Cohorts tab updates URL', async ({ adminPage }) => {
    await adminPage.goto('/dashboard');
    await expect(adminPage.getByRole('tab', { name: 'Cohorts' })).toBeVisible({
      timeout: 15000,
    });

    await adminPage.getByRole('tab', { name: 'Cohorts' }).click();
    await expect(adminPage).toHaveURL(/tab=cohorts/);
  });

  test('?tab=cohorts in URL activates Cohorts tab directly', async ({
    adminPage,
  }) => {
    await adminPage.goto('/dashboard?tab=cohorts');

    await expect(adminPage.getByRole('tab', { name: 'Cohorts' })).toBeVisible({
      timeout: 15000,
    });
    await expect(adminPage).toHaveURL(/tab=cohorts/);
  });
});
