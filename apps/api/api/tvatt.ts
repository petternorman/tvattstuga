import { login } from '../src/login.js';
import { scrape } from '../src/scrape.js';
import type { ResourceGroup } from '../src/types.js';

const COOKIE_TTL_MS = 10 * 60 * 1000;
const DATA_TTL_MS = 10 * 1000;

const cookieCache = new Map<string, { cookie: string; timestamp: number }>();
const dataCache = new Map<string, { data: ResourceGroup[]; timestamp: number }>();

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
	.split(',')
	.map((origin) => origin.trim())
	.filter(Boolean);

function setCorsHeaders(req: any, res: any) {
	const origin = req.headers.origin;
	if (!origin) return;

	if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
		res.setHeader('Access-Control-Allow-Origin', origin);
		res.setHeader('Vary', 'Origin');
		res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
		res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
	}
}

async function readJsonBody(req: any): Promise<any> {
	if (req.body && typeof req.body === 'object') {
		return req.body;
	}

	const chunks: Buffer[] = [];
	for await (const chunk of req) {
		chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
	}

	const raw = Buffer.concat(chunks).toString('utf8');
	if (!raw) return {};
	return JSON.parse(raw);
}

async function getValidCookie(username: string, password: string): Promise<string> {
	const key = username;
	const cached = cookieCache.get(key);
	const now = Date.now();

	if (cached && now - cached.timestamp < COOKIE_TTL_MS) {
		return cached.cookie;
	}

	const cookie = await login(username, password);
	cookieCache.set(key, { cookie, timestamp: now });
	return cookie;
}

function getCachedData(username: string): ResourceGroup[] | null {
	const cached = dataCache.get(username);
	if (!cached) return null;
	if (Date.now() - cached.timestamp > DATA_TTL_MS) {
		dataCache.delete(username);
		return null;
	}
	return cached.data;
}

function setCachedData(username: string, data: ResourceGroup[]) {
	dataCache.set(username, { data, timestamp: Date.now() });
}

export default async function handler(req: any, res: any) {
	setCorsHeaders(req, res);
	res.setHeader('Cache-Control', 'no-store');

	if (req.method === 'OPTIONS') {
		res.statusCode = 204;
		res.end();
		return;
	}

	if (req.method !== 'POST') {
		res.statusCode = 405;
		res.setHeader('Content-Type', 'application/json');
		res.end(JSON.stringify({ error: 'Method Not Allowed' }));
		return;
	}

	try {
		const body = await readJsonBody(req);
		const username = typeof body.username === 'string' ? body.username.trim() : '';
		const password = typeof body.password === 'string' ? body.password : '';

		if (!username || !password) {
			res.statusCode = 400;
			res.setHeader('Content-Type', 'application/json');
			res.end(JSON.stringify({ error: 'Missing credentials' }));
			return;
		}

		const cached = getCachedData(username);
		if (cached) {
			res.statusCode = 200;
			res.setHeader('Content-Type', 'application/json');
			res.end(JSON.stringify(cached));
			return;
		}

		let cookie = await getValidCookie(username, password);
		let data: ResourceGroup[];

		try {
			data = await scrape(cookie);
		} catch {
			cookieCache.delete(username);
			cookie = await getValidCookie(username, password);
			data = await scrape(cookie);
		}

		setCachedData(username, data);

		res.statusCode = 200;
		res.setHeader('Content-Type', 'application/json');
		res.end(JSON.stringify(data));
	} catch (error) {
		const message = error instanceof Error ? error.message : 'Unknown error';
		const statusCode = message === 'LOGIN_FAILED' ? 401 : 500;
		res.statusCode = statusCode;
		res.setHeader('Content-Type', 'application/json');
		res.end(
			JSON.stringify({
				error: message === 'LOGIN_FAILED' ? 'Login failed' : message
			})
		);
	}
}
