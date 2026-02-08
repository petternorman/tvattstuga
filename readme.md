# Tvätt App - SvelteKit + Vercel API

A small, private laundry status app for a neighborhood. The web UI is a static SvelteKit build, and the API logs in to the ASP.NET backend per request using credentials supplied by the user’s device.

## Architecture

- **Web**: SvelteKit (static build) in `apps/web`
- **API**: Vercel serverless functions (Node) in `apps/api`
- **Legacy**: Deno server + Raspberry Pi deployment in `server/` and `build.sh` (kept for reference)

## Project Structure

```
apps/
  web/           # SvelteKit frontend
  api/           # Vercel serverless API (Node)
server/          # Legacy Deno server (optional)
```

## Local Development

### Prerequisites

- Node.js 18+
- npm

### Install

```bash
npm install
```

### API (apps/api)

Set env vars (example in `apps/api/.env.example`):

```
BASE_URL=https://your-booking-system.com
ALLOWED_ORIGINS=http://localhost:5173
```

Run the API dev server:

```bash
npm run dev:api
```

It listens on `http://localhost:3001`.

### Web (apps/web)

You can either set `PUBLIC_API_BASE_URL=http://localhost:3001` or leave it unset and use the Vite proxy.

Run the web dev server:

```bash
npm run dev:web
```

Open `http://localhost:5173`.

## API Endpoint

`POST /api/tvatt`

Body:

```json
{ "username": "...", "password": "..." }
```

The app stores credentials locally in the browser (localStorage) to avoid repeated logins.

## Deployment (Vercel)

See `DEPLOY.md` for the step-by-step Vercel setup.

## Legacy Raspberry Pi Deployment

The previous single-process Deno deployment is still in the repo for reference:

- `server/` (Deno Oak server)
- `build.sh` (Pi packaging script)

These are not used for the Vercel split deployment.
