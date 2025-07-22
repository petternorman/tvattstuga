import { Application, Router, send } from 'oak';
import { load } from 'dotenv';
import { login } from './login.ts';
import { scrape } from './scrape.ts';

await load({ export: true });
const USERNAME = Deno.env.get('USERNAME') || '';
const PASSWORD = Deno.env.get('PASSWORD') || '';

// Simple cache to prevent excessive scraping
let cachedData: object | null = null;
let lastScrapeTime = 0;
const CACHE_DURATION = 10 * 1000; // 10 seconds

// Login cache to avoid re-authenticating on every request
let cachedCookie: string | null = null;
let lastLoginTime = 0;
const LOGIN_CACHE_DURATION = 10 * 60 * 1000; // 10 minutes

// Get a valid authentication cookie, using cache when possible
async function getValidCookie(): Promise<string> {
	const now = Date.now();

	// Return cached cookie if it's still fresh
	if (cachedCookie && now - lastLoginTime < LOGIN_CACHE_DURATION) {
		console.log(
			'Using cached authentication cookie (age:',
			Math.round((now - lastLoginTime) / 1000),
			'seconds)'
		);
		return cachedCookie;
	}

	// Perform fresh login
	console.log('Cached cookie expired or missing, performing fresh login...');
	const cookie = await login(USERNAME, PASSWORD);

	// Cache the new cookie
	cachedCookie = cookie;
	lastLoginTime = now;

	return cookie;
}

const router = new Router();
router.get('/api/tvatt', async (ctx) => {
	try {
		const now = Date.now();

		// Return cached data if it's still fresh
		if (cachedData && now - lastScrapeTime < CACHE_DURATION) {
			console.log(
				'Returning cached data (age:',
				Math.round((now - lastScrapeTime) / 1000),
				'seconds)'
			);
			ctx.response.body = cachedData;
			return;
		}

		console.log('Cache expired or empty, performing fresh scrape...');

		// Try to get a valid cookie (cached or fresh)
		let cookie = await getValidCookie();
		let data;

		try {
			data = await scrape(cookie);
		} catch {
			// If scraping fails, the cookie might be expired/invalid
			// Clear cache and try with a fresh login
			console.log('Scraping failed with cached cookie, trying fresh login...');
			cachedCookie = null; // Clear the cached cookie
			cookie = await getValidCookie(); // This will force a fresh login
			data = await scrape(cookie);
		}

		// Cache the results
		cachedData = data;
		lastScrapeTime = now;

		ctx.response.body = data;
	} catch (error) {
		const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
		console.error('Error in /api/tvatt:', errorMessage);
		ctx.response.status = 500;
		ctx.response.body = {
			error: errorMessage,
			timestamp: new Date().toISOString()
		};
	}
});

// Serve static files from build directory
router.get('/_app/(.*)', async (ctx) => {
	const filePath = ctx.params[0];
	await send(ctx, `_app/${filePath}`, {
		root: `${Deno.cwd()}/build`
	});
});

// Serve other static assets (favicon, etc.)
router.get('/favicon.svg', async (ctx) => {
	await send(ctx, 'favicon.svg', {
		root: `${Deno.cwd()}/build`
	});
});

// Serve index.html for all other routes (SPA routing)
router.get('/(.*)', async (ctx) => {
	await send(ctx, 'index.html', {
		root: `${Deno.cwd()}/build`
	});
});

const app = new Application();
app.use(router.routes());
app.use(router.allowedMethods());

const port = Number(Deno.env.get('PORT')) || 3000;
console.log(`Running server on http://localhost:${port}`);
await app.listen({ port });
