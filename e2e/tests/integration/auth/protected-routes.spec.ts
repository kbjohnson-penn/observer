import { test, expect } from '../../../fixtures/mock-auth.fixture';

test.describe('Security: Protected Routes', () => {

  test.use({ authState: 'unauthenticated' });

  test('Unauthenticated user redirected to login when accessing /dashboard', async ({ page }) => {
    // Attempt to bypass login by going straight to a protected URL
    await page.goto('/dashboard');

    // Should be redirected to login
    await expect(page).toHaveURL(/\/login/);
  });

});
