/**
 * E2E auth fixtures — pre-authenticate browser contexts via real backend API.
 * Use these in tests under tests/e2e/ where a real backend is running.
 */
import { test as base, type BrowserContext, type Page } from '@playwright/test';
import { loginViaApi } from '../helpers/api';

export const TEST_USERS = {
  admin: { username: 'e2e_admin', password: 'E2eTestPass123!' },
  tier1: { username: 'e2e_tier1', password: 'E2eTestPass123!' },
} as const;

type AuthFixtures = {
  /** A page pre-authenticated as e2e_admin (Tier 5) */
  adminPage: Page;
  /** A page pre-authenticated as e2e_tier1 (Tier 1) */
  tier1Page: Page;
  /** A raw authenticated context for e2e_admin (for multi-tab tests) */
  adminContext: BrowserContext;
};

export const test = base.extend<AuthFixtures>({
  adminPage: async ({ browser }, use) => {
    const context = await browser.newContext();
    const { cookies } = await loginViaApi(
      TEST_USERS.admin.username,
      TEST_USERS.admin.password
    );
    await context.addCookies(cookies);
    const page = await context.newPage();
    await use(page);
    await context.close();
  },

  tier1Page: async ({ browser }, use) => {
    const context = await browser.newContext();
    const { cookies } = await loginViaApi(
      TEST_USERS.tier1.username,
      TEST_USERS.tier1.password
    );
    await context.addCookies(cookies);
    const page = await context.newPage();
    await use(page);
    await context.close();
  },

  adminContext: async ({ browser }, use) => {
    const context = await browser.newContext();
    const { cookies } = await loginViaApi(
      TEST_USERS.admin.username,
      TEST_USERS.admin.password
    );
    await context.addCookies(cookies);
    await use(context);
    await context.close();
  },
});

export { expect } from '@playwright/test';
