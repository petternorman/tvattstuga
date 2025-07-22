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
const CACHE_DURATION = 2 * 60 * 1000; // 2 minutes

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
		const cookie = await login(USERNAME, PASSWORD);
		const data = await scrape(cookie);

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
