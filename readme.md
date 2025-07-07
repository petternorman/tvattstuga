# Laundry resources UI

A nicer UI layer built of scraping a ASPX website, built with Deno and Svelte.

## Project structure

```
tvattstuga/
├── src/
│   ├── frontend/     # Svelte frontend
│   └── server/       # Deno server
├── package.json      # Frontend dependencies
└── deno.json         # Server configuration
```

## Setup

Create a `.env` file in the project root with the following variables:

- `USER` (required): Your login username for the external service.
- `PASS` (required): Your login password for the external service.
- `BASE_URL` (required): The base URL of the external service endpoint (e.g., `https://example.com`).
- `PORT` (optional): The port for the server to listen on (default is `3000`).

Example `.env`:

```
USER=your_username
PASS=your_password
BASE_URL=https://example.com
PORT=3000
```

## Start

```bash
chmod +x build.sh
./build.sh
```

Visit http://localhost:3000 in browser.

## Development

- Frontend: `npm run dev`
- Server: `deno task start`

## Project Status

This project is not actively maintained and is provided as-is for reference.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
