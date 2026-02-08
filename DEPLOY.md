# Vercel Deployment

This repo is split into two Vercel projects that point to different subfolders.

## 1) API (apps/api)

- **Root Directory**: `apps/api`
- **Framework Preset**: Other (Node)
- **Build Command**: (leave default)
- **Output Directory**: (leave default)
- **Environment Variables**:
  - `BASE_URL` (booking system base URL, no trailing slash)
  - `ALLOWED_ORIGINS` (comma-separated list of allowed web origins)

Example `ALLOWED_ORIGINS`:

```
http://localhost:5173,https://your-web.vercel.app
```

## 2) Web (apps/web)

- **Root Directory**: `apps/web`
- **Framework Preset**: SvelteKit
- **Build Command**: `npm run build`
- **Output Directory**: `build`
- **Environment Variables**:
  - `VITE_API_BASE_URL` (the full URL of the API project)

Example:

```
VITE_API_BASE_URL=https://your-api.vercel.app
```

## Notes

- The API uses CORS and only allows the origins in `ALLOWED_ORIGINS`.
- For local dev, you can run:

```bash
npm run dev:api
npm run dev:web
```
