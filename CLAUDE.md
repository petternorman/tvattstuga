# CLAUDE.md

## Project Overview

Tvätt App — a real-time laundry machine status dashboard for a neighborhood. It logs into an ASP.NET booking system, scrapes machine availability, and displays status with live countdown timers. The UI is in Swedish.

## Architecture

Monorepo with two apps:

```
apps/
  web/   — SvelteKit frontend (static build)
  api/   — Node.js serverless API (Vercel functions)
server/  — Legacy Deno server (deprecated, do not modify)
```

### Web (`apps/web`)

- **SvelteKit 2** with **Svelte 5** runes (`$state`, `$derived`, `$effect`)
- **Tailwind CSS v4** for styling
- **Static adapter** — builds to `apps/web/build/`
- Routes in `src/routes/`, shared code in `src/lib/`
- Component pattern: small, focused `.svelte` files in routes directory

### API (`apps/api`)

- Single endpoint: `api/tvatt.ts` (Vercel serverless function)
- `src/login.ts` — ASP.NET form authentication with cookie caching (10-min TTL)
- `src/scrape.ts` — HTML parsing with cheerio
- `src/types.ts` — shared TypeScript types
- CORS-aware with configurable allowed origins

## Development

```bash
# Install dependencies
npm install

# Run both dev servers (in separate terminals)
npm run dev:api    # API on http://localhost:3001
npm run dev:web    # Web on http://localhost:5173 (proxies to :3001)

# Build
npm run build:web

# Lint & format
npm run lint:web
npm -w apps/web run format

# Type check
npm -w apps/web run check
```

## Code Style & Conventions

- **Tabs** for indentation, not spaces
- **Single quotes**, no trailing commas
- **Print width**: 100
- **Prettier** with `prettier-plugin-svelte` and `prettier-plugin-tailwindcss`
- **ESLint**: typescript-eslint + svelte plugin
- **Swedish** language for all UI strings and error messages
- **No test framework** configured — validate with lint, type checking, and manual testing

## Key Patterns

- **Svelte 5 runes**: Use `$state()`, `$derived()`, `$effect()` — not legacy `$:` reactive syntax
- **Props**: Use `let { prop } = $props()` pattern
- **Theme**: Dark mode via `.dark` class on `<html>`, managed by `src/lib/theme.ts`
- **State persistence**: localStorage for credentials and theme preference
- **API caching**: In-memory Maps with TTL (cookies: 10 min, data: 10 sec)
- **Discriminated unions** for `MachineState` type

## Environment Variables

### Web (`apps/web/.env`)

- `VITE_API_BASE_URL` — API base URL (e.g., `http://localhost:3001` for dev)

### API (`apps/api/.env`)

- `BASE_URL` — Target ASP.NET booking system URL
- `ALLOWED_ORIGINS` — Comma-separated CORS origins

## Deployment

Primary deployment target is **Vercel** (two separate projects for web and API). See `DEPLOY.md` for details. Legacy Raspberry Pi deployment via `build.sh` and systemd.

## Important Notes

- `engine-strict=true` in `.npmrc` — Node.js version must match `package.json` engines
- The `server/` directory is legacy Deno code; do not modify unless specifically asked
- Web app uses Vite dev proxy to forward `/api` requests to the API dev server on port 3001
