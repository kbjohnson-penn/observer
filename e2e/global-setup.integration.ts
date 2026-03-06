/**
 * Global setup for integration tests.
 * Only verifies the frontend is running (backend is mocked).
 */
import type { FullConfig } from '@playwright/test';

const FRONTEND = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000';

async function globalSetup(_config: FullConfig) {
  console.log('[Integration Setup] Verifying frontend health...');
  await waitForUrl(FRONTEND, 60_000);
  console.log('[Integration Setup] Frontend ready.');
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
  throw new Error(`Frontend not ready after ${timeoutMs}ms: ${url}`);
}

export default globalSetup;
