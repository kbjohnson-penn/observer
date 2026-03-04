/**
 * Global setup for E2E tests.
 * Verifies both backend and frontend are running, and seed data exists.
 */
import type { FullConfig } from '@playwright/test';

const BACKEND = process.env.BACKEND_API_URL || 'http://localhost:8000/api/v1';
const FRONTEND = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';

async function globalSetup(_config: FullConfig) {
  console.log('[E2E Setup] Verifying backend health...');
  await waitForUrl(`${BACKEND}/health/`, 60_000);

  console.log('[E2E Setup] Verifying frontend health...');
  await waitForUrl(FRONTEND, 60_000);

  console.log('[E2E Setup] Verifying E2E seed data...');
  await verifySeededUser();

  console.log('[E2E Setup] All services ready.');
}

async function waitForUrl(url: string, timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok || res.status < 500) return;
    } catch {
      // service not up yet
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
  throw new Error(`Service not ready after ${timeoutMs}ms: ${url}`);
}

async function verifySeededUser(): Promise<void> {
  // Get CSRF token
  const csrfRes = await fetch(`${BACKEND}/accounts/auth/csrf-token/`);
  if (!csrfRes.ok) {
    throw new Error(`CSRF endpoint returned ${csrfRes.status}`);
  }

  const csrfData = await csrfRes.json();
  const csrfToken: string = csrfData.csrfToken;

  // Extract csrftoken cookie
  const setCookieHeader = csrfRes.headers.get('set-cookie') || '';
  const csrfCookieMatch = setCookieHeader.match(/csrftoken=([^;]+)/);
  const csrfCookieValue = csrfCookieMatch?.[1] || '';

  // Attempt login with e2e_admin
  const loginRes = await fetch(`${BACKEND}/accounts/auth/token/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRFToken': csrfToken,
      Cookie: `csrftoken=${csrfCookieValue}`,
    },
    body: JSON.stringify({ username: 'e2e_admin', password: 'E2eTestPass123!' }),
  });

  if (!loginRes.ok) {
    throw new Error(
      'E2E seed user e2e_admin cannot log in. ' +
        'Run: python manage.py seed_e2e_data'
    );
  }
}

export default globalSetup;
