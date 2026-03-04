/**
 * Direct HTTP helpers for backend API calls.
 * Used in E2E fixtures to set up auth state without going through the UI.
 */

const BACKEND_API =
  process.env.BACKEND_API_URL || 'http://localhost:8000/api/v1';

export interface PlaywrightCookie {
  name: string;
  value: string;
  domain: string;
  path: string;
  httpOnly: boolean;
  secure: boolean;
  sameSite: 'Lax' | 'Strict' | 'None';
}

export interface LoginResult {
  cookies: PlaywrightCookie[];
  csrfToken: string;
}

/**
 * Perform login against the real backend API and return cookies
 * for injection into a Playwright browser context.
 *
 * Replicates the flow in AuthContext.tsx:
 * 1. GET /accounts/auth/csrf-token/ → csrfToken + csrftoken cookie
 * 2. POST /accounts/auth/token/ with X-CSRFToken → access_token + refresh_token cookies
 */
export async function loginViaApi(
  username: string,
  password: string
): Promise<LoginResult> {
  // Step 1: Get CSRF token
  const csrfRes = await fetch(`${BACKEND_API}/accounts/auth/csrf-token/`, {
    method: 'GET',
    headers: { Accept: 'application/json' },
  });

  if (!csrfRes.ok) {
    throw new Error(`CSRF endpoint returned ${csrfRes.status}`);
  }

  const csrfSetCookie = csrfRes.headers.get('set-cookie') || '';
  const csrfCookieMatch = csrfSetCookie.match(/csrftoken=([^;]+)/);
  const csrfCookieValue = csrfCookieMatch?.[1] || '';

  const csrfData = await csrfRes.json();
  const csrfToken: string = csrfData.csrfToken;

  // Step 2: Login with CSRF token
  const loginRes = await fetch(`${BACKEND_API}/accounts/auth/token/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRFToken': csrfToken,
      Cookie: `csrftoken=${csrfCookieValue}`,
    },
    body: JSON.stringify({ username, password }),
  });

  if (!loginRes.ok) {
    const body = await loginRes.text();
    throw new Error(`Login failed for ${username}: ${loginRes.status} ${body}`);
  }

  // Parse Set-Cookie headers for access_token and refresh_token
  const setCookieHeaders = loginRes.headers.getSetCookie?.() || [];
  const cookies = parseCookies(setCookieHeaders, csrfCookieValue);

  return { cookies, csrfToken };
}

/**
 * Parse raw Set-Cookie header strings into Playwright cookie objects.
 */
function parseCookies(
  setCookieHeaders: string[],
  csrfCookieValue: string
): PlaywrightCookie[] {
  const parsed: PlaywrightCookie[] = [];

  for (const header of setCookieHeaders) {
    const parts = header.split(';').map((p) => p.trim());
    const [nameValue] = parts;
    const eqIndex = nameValue.indexOf('=');
    if (eqIndex === -1) continue;

    const name = nameValue.substring(0, eqIndex).trim();
    const value = nameValue.substring(eqIndex + 1).trim();

    const isHttpOnly = parts.some((p) => p.toLowerCase() === 'httponly');
    const isSecure = parts.some((p) => p.toLowerCase() === 'secure');
    const sameSitePart = parts.find((p) =>
      p.toLowerCase().startsWith('samesite=')
    );
    const sameSite = (sameSitePart?.split('=')?.[1] ?? 'Lax') as
      | 'Lax'
      | 'Strict'
      | 'None';

    parsed.push({
      name,
      value,
      domain: 'localhost',
      path: '/',
      httpOnly: isHttpOnly,
      secure: isSecure,
      sameSite,
    });
  }

  // Include the csrftoken cookie (readable by JavaScript, needed for POST requests)
  if (csrfCookieValue) {
    parsed.push({
      name: 'csrftoken',
      value: csrfCookieValue,
      domain: 'localhost',
      path: '/',
      httpOnly: false,
      secure: false,
      sameSite: 'Lax',
    });
  }

  return parsed;
}
