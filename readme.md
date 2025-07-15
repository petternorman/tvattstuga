# Tvätt App - SvelteKit + Deno

A modern laundry booking system built with SvelteKit and Deno, designed to run efficiently on a Raspberry Pi.

## Architecture

- **Frontend**: SvelteKit with Svelte 5 and TailwindCSS (built as static files)
- **Backend**: Deno server with Oak framework
- **Deployment**: Single Deno process serving both frontend and API

## Project Structure

```
tvattstuga/
├── src/                    # SvelteKit frontend source
│   ├── routes/            # App pages and components
│   └── lib/               # Shared utilities
├── server/                # Deno backend
│   ├── server.ts         # Main server file
│   ├── login.ts          # Authentication logic
│   └── scrape.ts         # Data scraping logic
├── build/                 # Generated static files (after build)
├── static/               # Static assets
├── build.sh              # Deployment build script
├── deno.json             # Deno configuration
├── package.json          # Frontend dependencies
└── tvattstuga.service    # Systemd service file
```

## Development

### Prerequisites

- Node.js and npm (for building the frontend)
- Deno (for running the server)

### Local Development

1. **Set up environment variables:**

   ```bash
   cp .env.example .env
   # Edit .env with your actual credentials
   ```

   Required environment variables:

   ```
   BASE_URL=your_booking_system_url
   USERNAME=your_username
   PASSWORD=your_password
   PORT=3000
   ```

2. **Option A - Run both servers at once (Recommended):**

   ```bash
   npm install
   npm run dev:full
   ```

   This starts:
   - SvelteKit dev server on `http://localhost:5173` (with hot reload)
   - Deno API server on `http://localhost:3001`
   - Automatic proxy from frontend to API

3. **Option B - Run servers separately:**

   Terminal 1 - Frontend:

   ```bash
   npm run dev:client
   ```

   Terminal 2 - API Server:

   ```bash
   npm run dev:server
   ```

4. **Access the app:**
   - Frontend: `http://localhost:5173`
   - API directly: `http://localhost:3001/api/tvatt`

## Production Deployment (Raspberry Pi)

### 1. Prepare the Build

Run the build script:

```bash
./build.sh
```

### 2. Copy to Raspberry Pi

Transfer the deployment package to your Raspberry Pi:

```bash
# After running ./build.sh, copy the generated deployment package
scp -r deploy-YYYYMMDD-HHMMSS/ pi@your-pi-ip:/home/pi/tvattstuga/
```

### 3. Install Deno on Raspberry Pi

```bash
curl -fsSL https://deno.land/install.sh | sh
echo 'export PATH="$HOME/.deno/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Set up Environment Variables

Create a `.env` file with your credentials:

```bash
# In your deployment directory
nano .env
```

Required variables:

```
BASE_URL=your_booking_system_url
USERNAME=your_username
PASSWORD=your_password
PORT=3000
```

### 5. Set up as System Service

Copy the service file:

```bash
sudo cp tvattstuga.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tvattstuga
sudo systemctl start tvattstuga
```

Check status:

```bash
sudo systemctl status tvattstuga
```

## API Endpoints

- `GET /api/tvatt` - Fetches laundry machine data
- `GET /*` - Serves the SvelteKit app (SPA routing)

## Migration Benefits

✅ **Modern Stack**: SvelteKit + Svelte 5 with better reactivity  
✅ **Deno Runtime**: Better security, built-in TypeScript, modern APIs
✅ **Single Process**: One Deno server handles both frontend and API
✅ **Easy Deployment**: No Node.js needed on the Pi, just Deno
✅ **Better Performance**: Static files served efficiently  
✅ **Type Safety**: Full TypeScript support throughout

## Troubleshooting

### Build Issues

- Make sure `@sveltejs/adapter-static` is installed: `npm install -D @sveltejs/adapter-static`
- Clear cache: `rm -rf node_modules package-lock.json && npm install`

### Server Issues

- Check logs: `sudo journalctl -u tvattstuga -f`
- Verify environment variables are set
- Ensure port 3000 is not already in use

### Permissions

- Make sure the pi user has read access to the app directory
- Check firewall settings if accessing from other devices

## Available Scripts

- `npm run dev:client` - Start SvelteKit dev server
- `npm run dev:server` - Start Deno API server
- `npm run dev:full` - Start both servers concurrently
- `npm run build` - Build SvelteKit for production
- `npm run preview` - Preview production build
- `npm run check` - Type checking
- `npm run lint` - Run ESLint and Prettier
- `npm run format` - Format code with Prettier

## Deno Tasks

- `deno task serve` - Run production server
- `deno task dev` - Run development server (API only)

## Building

To create a production version of your app:

```bash
npm run build
```

You can preview the production build with `npm run preview`.
