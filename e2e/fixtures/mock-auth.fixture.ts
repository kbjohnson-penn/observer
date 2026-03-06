/**
 * Integration test fixtures — mock backend API for authenticated state.
 * Use these in tests under tests/integration/ where no backend is running.
 */
import { test as base, type Page } from '@playwright/test';
import {
  mockAuthenticated,
  mockUnauthenticated,
  DEFAULT_PROFILE,
} from '../helpers/mock-api';

type MockAuthFixtures = {
  /** A page with mocked authenticated state (token refresh succeeds) */
  authenticatedPage: Page;
  /** A page with mocked unauthenticated state (token refresh fails) */
  unauthenticatedPage: Page;
};

export const test = base.extend<MockAuthFixtures>({
  authenticatedPage: async ({ page, context }, use) => {
    // Set access_token cookie so Next.js middleware allows protected routes
    await context.addCookies([
      {
        name: 'access_token',
        value: 'mock-access-token',
        domain: 'localhost',
        path: '/',
        httpOnly: true,
        secure: false,
        sameSite: 'Lax',
      },
      {
        name: 'refresh_token',
        value: 'mock-refresh-token',
        domain: 'localhost',
        path: '/',
        httpOnly: true,
        secure: false,
        sameSite: 'Lax',
      },
    ]);
    await mockAuthenticated(page, DEFAULT_PROFILE);
    await use(page);
  },

  unauthenticatedPage: async ({ page }, use) => {
    await mockUnauthenticated(page);
    await use(page);
  },
});

export { expect } from '@playwright/test';
