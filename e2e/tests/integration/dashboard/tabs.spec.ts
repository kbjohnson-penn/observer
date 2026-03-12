// import { test, expect } from '../../../fixtures/mock-auth.fixture';

// /**
//  * Mock the dashboard's API dependencies.
//  */
// async function mockDashboardApis(page: import('@playwright/test').Page) {
//   // Mock filter options
//   await page.route('**/api/v1/research/private/filter-options/', (route) =>
//     route.fulfill({
//       status: 200,
//       contentType: 'application/json',
//       body: JSON.stringify({
//         demographics: {
//           genders: ['Male', 'Female'],
//           races: ['White', 'Black'],
//           ethnicities: ['Hispanic', 'Non-Hispanic'],
//           year_of_birth_range: { min: 1940, max: 2000 },
//         },
//         visit_options: {
//           tiers: [1, 2, 3],
//           visit_sources: ['Hospital', 'Clinic'],
//           date_range: { earliest: '2020-01-01', latest: '2024-12-31' },
//         },
//         clinical_options: {
//           conditions: { available_codes: [], available_values: [], total_visits: 0 },
//           labs: { procedure_names: [], result_flags: [], order_statuses: [], total_visits: 0 },
//           drugs: { common_drugs: [], total_visits: 0 },
//           procedures: { common_names: [], future_or_stand_options: [], total_visits: 0 },
//           notes: { note_types: [], note_statuses: [], total_visits: 0 },
//           observations: { file_types: [], total_visits: 0 },
//           measurements: {
//             total_visits: 0,
//             bp_systolic_range: { min: 90, max: 180 },
//             weight_range: { min: 40, max: 150 },
//           },
//         },
//         total_accessible_visits: 42,
//       }),
//     })
//   );

//   // Mock visit search — use regex to handle query params like ?page=1
//   await page.route(/\/api\/v1\/research\/private\/visits-search\//, (route) =>
//     route.fulfill({
//       status: 200,
//       contentType: 'application/json',
//       body: JSON.stringify({
//         results: [],
//         count: 0,
//         next: null,
//         previous: null,
//         filter_summary: {
//           total_visits: 42,
//           filtered_visits: 42,
//           active_filters: 0,
//         },
//       }),
//     })
//   );

//   // Mock cohort list API (getCohorts reads response.data.cohorts)
//   await page.route('**/api/v1/accounts/cohorts/', (route) =>
//     route.fulfill({
//       status: 200,
//       contentType: 'application/json',
//       body: JSON.stringify({ cohorts: [], count: 0 }),
//     })
//   );
// }

// test.describe('Dashboard tabs', () => {
//   test('shows Research Data and Cohorts tabs when authenticated', async ({
//     authenticatedPage,
//   }) => {
//     await mockDashboardApis(authenticatedPage);
//     await authenticatedPage.goto('/dashboard');

//     await expect(authenticatedPage.getByRole('tab', { name: 'Research Data' })).toBeVisible({
//       timeout: 10000,
//     });
//     await expect(
//       authenticatedPage.getByRole('tab', { name: 'Cohorts' })
//     ).toBeVisible();
//   });

//   test('defaults to research tab with ?tab=research in URL', async ({
//     authenticatedPage,
//   }) => {
//     await mockDashboardApis(authenticatedPage);
//     await authenticatedPage.goto('/dashboard');

//     // Wait for dashboard to fully render first
//     await expect(authenticatedPage.getByRole('tab', { name: 'Research Data' })).toBeVisible({
//       timeout: 10000,
//     });
//     // The tab param is set client-side via router.replace after hydration
//     await expect(authenticatedPage).toHaveURL(/tab=research/, {
//       timeout: 15000,
//     });
//   });

//   test('clicking Cohorts tab updates URL', async ({ authenticatedPage }) => {
//     await mockDashboardApis(authenticatedPage);
//     await authenticatedPage.goto('/dashboard');

//     // Wait for the dashboard to fully render before clicking
//     await expect(authenticatedPage.getByRole('tab', { name: 'Research Data' })).toBeVisible({
//       timeout: 10000,
//     });
//     await authenticatedPage.getByRole('tab', { name: 'Cohorts' }).click();
//     await expect(authenticatedPage).toHaveURL(/tab=cohorts/, {
//       timeout: 10000,
//     });
//   });

//   test('?tab=cohorts in URL activates Cohorts tab', async ({
//     authenticatedPage,
//   }) => {
//     await mockDashboardApis(authenticatedPage);
//     await authenticatedPage.goto('/dashboard?tab=cohorts');

//     // Cohorts tab should be active (green color)
//     await expect(authenticatedPage).toHaveURL(/tab=cohorts/);
//   });
// });
