import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '.env') });

const { default: handler } = await import('./api/tvatt.ts');

const port = Number(process.env.PORT) || 3001;

const server = http.createServer((req, res) => {
	if (req.url?.startsWith('/api/tvatt')) {
		void handler(req, res);
		return;
	}

	res.statusCode = 404;
	res.setHeader('Content-Type', 'application/json');
	res.end(JSON.stringify({ error: 'Not Found' }));
});

server.listen(port, () => {
	console.log(`API dev server running on http://localhost:${port}`);
});
