import { test, expect } from '@playwright/test';
import { mockUnauthenticated, mockAuthenticated } from '../../../helpers/mock-api';

test.describe('Security: Protected Routes', () => {
  
  test('unauthenticated user redirected to login when accessing /dashboard', async ({ page }) => {
    await mockUnauthenticated(page);
    
    // Attempt to bypass login by going straight to a protected URL
    await page.goto('/dashboard');

    // Should be redirected to login with a redirect parameter
    await expect(page).toHaveURL(/\/login/);
  });
});

