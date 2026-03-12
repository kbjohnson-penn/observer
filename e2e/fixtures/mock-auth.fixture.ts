import { test as base } from '@playwright/test';
import {
  mockAuthenticated,
  mockUnauthenticated,
  mockLoginSuccess,
  mockLoginFailure,
} from '../helpers/mock-api';

type AuthState =
  | 'authenticated'
  | 'unauthenticated'
  | 'login-success'
  | 'login-failure'
  | 'none';

type AuthFixtures = {
  authState: AuthState;
};

export const test = base.extend<AuthFixtures>({
  authState: ['none', { option: true }],

  page: async ({ page, authState }, use) => {
    switch (authState) {
      case 'authenticated':
        await mockAuthenticated(page);
        break;

      case 'unauthenticated':
        await mockUnauthenticated(page);
        break;

      case 'login-success':
        await mockLoginSuccess(page);
        break;

      case 'login-failure':
        await mockLoginFailure(page);
        break;

      case 'none':
      default:
        break;
    }

    await use(page);
  },
});

export { expect } from '@playwright/test';
