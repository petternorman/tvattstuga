#!/bin/bash
echo "Building frontend..."
npm install
npm run build

echo "Starting server..."
deno run --allow-net --allow-read --allow-env src/server/server.ts
