/**
 * API mock helpers for integration tests.
 * Uses Playwright's page.route() to intercept backend API calls.
 */
import type { Page } from '@playwright/test';

export const DEFAULT_USER = {
  id: 1,
  username: 'testuser',
  email: 'testuser@example.com',
};

export const DEFAULT_PROFILE = {
  user: DEFAULT_USER,
  tier: { tier_name: 'Tier 5', level: 5 },
  organization: { name: 'Test Hospital' },
};

const FUTURE_EXPIRY = Math.floor(Date.now() / 1000) + 60 * 60 * 4; // 4 hours

/**
 * Mock the CSRF token endpoint.
 */
export async function mockCsrfToken(page: Page) {
  await page.route('**/api/v1/accounts/auth/csrf-token/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        csrfToken: 'fake-csrf-token',
        detail: 'CSRF token generated successfully',
      }),
    })
  );
}

/**
 * Mock a successful login flow (CSRF + token + profile).
 */
export async function mockLoginSuccess(
  page: Page,
  userData = DEFAULT_USER,
  profileData = DEFAULT_PROFILE
) {
  await mockCsrfToken(page);

  await page.route('**/api/v1/accounts/auth/token/', (route) => {
    if (route.request().method() === 'POST') {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: {
          'Set-Cookie': [
            'access_token=fake-access-token; HttpOnly; Path=/; SameSite=Lax',
            'refresh_token=fake-refresh-token; HttpOnly; Path=/; SameSite=Lax',
          ].join(', '),
        },
        body: JSON.stringify({
          detail: 'Login successful',
          user: userData,
          expires_at: FUTURE_EXPIRY,
        }),
      });
    }
    return route.continue();
  });

  await page.route('**/api/v1/accounts/profile/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(profileData),
    })
  );
}

/**
 * Mock a failed login (invalid credentials).
 */
export async function mockLoginFailure(page: Page) {
  await mockCsrfToken(page);

  await page.route('**/api/v1/accounts/auth/token/', (route) => {
    if (route.request().method() === 'POST') {
      return route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          detail: 'No active account found with the given credentials',
        }),
      });
    }
    return route.continue();
  });
}

/**
 * Mock token refresh (used by AuthContext on page load to check auth state).
 */
export async function mockTokenRefreshSuccess(
  page: Page,
  profileData = DEFAULT_PROFILE
) {
  await page.route('**/api/v1/accounts/auth/token/refresh/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        detail: 'Token refresh successful',
        expires_at: FUTURE_EXPIRY,
      }),
    })
  );

  await page.route('**/api/v1/accounts/profile/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(profileData),
    })
  );
}

/**
 * Mock token refresh failure (user not authenticated).
 */
export async function mockTokenRefreshFailure(page: Page) {
  await page.route('**/api/v1/accounts/auth/token/refresh/', (route) =>
    route.fulfill({
      status: 401,
      contentType: 'application/json',
      body: JSON.stringify({
        detail: 'Refresh token not found in cookies',
      }),
    })
  );
}

/**
 * Mock a successful logout.
 */
export async function mockLogoutSuccess(page: Page) {
  await mockCsrfToken(page);

  await page.route('**/api/v1/accounts/auth/logout/', (route) =>
    route.fulfill({
      status: 205,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'Logout successful.' }),
    })
  );
}

/**
 * Mock registration endpoint.
 */
export async function mockRegistrationSuccess(page: Page) {
  await mockCsrfToken(page);

  await page.route('**/api/v1/accounts/auth/register/', (route) =>
    route.fulfill({
      status: 201,
      contentType: 'application/json',
      body: JSON.stringify({
        detail:
          'Registration successful. Please check your email to verify your account.',
        email: 'test@example.edu',
      }),
    })
  );
}

/**
 * Mock forgot password endpoint.
 */
export async function mockForgotPasswordSuccess(page: Page) {
  await mockCsrfToken(page);

  await page.route('**/api/v1/accounts/auth/password-reset/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        detail:
          'If an account exists with this email, you will receive a password reset link.',
      }),
    })
  );
}

/**
 * Mock token verify endpoint.
 */
export async function mockTokenVerifySuccess(page: Page) {
  await page.route('**/api/v1/accounts/auth/token/verify/', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({}),
    })
  );
}

/**
 * Mock all unauthenticated state routes (refresh fails, no profile).
 * Use this for pages that should show the unauthenticated state.
 */
export async function mockUnauthenticated(page: Page) {
  await mockTokenRefreshFailure(page);
  await mockCsrfToken(page);
}

/**
 * Mock authenticated state for pages that need it.
 * Sets up refresh success + profile so AuthContext resolves as logged in.
 */
export async function mockAuthenticated(
  page: Page,
  profileData = DEFAULT_PROFILE
) {
  await mockTokenRefreshSuccess(page, profileData);
  await mockCsrfToken(page);
}
