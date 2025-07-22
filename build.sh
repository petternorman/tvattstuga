#!/bin/bash

# Build script for Tvätt app deployment on Raspberry Pi

set -e  # Exit on any error

echo "🔨 Building SvelteKit app..."

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed. Please install Node.js and npm first."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install
fi

# Build the SvelteKit app
echo "🏗️  Building SvelteKit frontend..."
npm run build

echo "✅ SvelteKit build complete!"

# Create .env template if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env template..."
    cat > .env << EOF
# Configuration for Tvätt app
BASE_URL=your_booking_system_url_here
USERNAME=your_username_here
PASSWORD=your_password_here
PORT=3000
EOF
    echo "⚠️  Please edit .env file with your actual credentials before running!"
fi

# Check if Deno is available
if command -v deno &> /dev/null; then
    echo "🦕 Deno found, installing dependencies..."
    deno install --allow-scripts
    echo "✅ Dependencies installed!"
else
    echo "ℹ️  Deno not found locally. Make sure it's installed on your target system."
fi

# Create deployment package
DEPLOY_DIR="deploy-$(date +%Y%m%d-%H%M%S)"
echo "📦 Creating deployment package: $DEPLOY_DIR"

mkdir -p "$DEPLOY_DIR"
cp -r build "$DEPLOY_DIR/"  # Copy build directory itself, not just contents
cp -r server "$DEPLOY_DIR/"  # Copy server directory itself, not just contents
cp deno.json "$DEPLOY_DIR/"
cp .env "$DEPLOY_DIR/"

cp tvattstuga.service "$DEPLOY_DIR/"

# ln -sfn "$DEPLOY_DIR" current

# Create deployment README
cat > "$DEPLOY_DIR/DEPLOY.md" << EOF
# Deployment Package

This package contains everything needed to run the Tvätt app on your Raspberry Pi.

## Quick Start

1. **Edit .env file** with your actual credentials
2. **Install Deno** (if not already installed):
   \`\`\`bash
   curl -fsSL https://deno.land/install.sh | sh
   echo 'export PATH="\$HOME/.deno/bin:\$PATH"' >> ~/.bashrc
   source ~/.bashrc
   \`\`\`
3. **Install Deno dependencies**:
   \`\`\`bash
   deno install --allow-scripts
   \`\`\`
4. **Run the app**:
   \`\`\`bash
   deno task serve
   \`\`\`

## System Service Setup

To run as a system service, follow these steps:

### First-time Setup

1. **Create the application directory structure**:
   \`\`\`bash
   mkdir -p ~/tvattstuga
   \`\`\`

2. **Copy this deployment to your Raspberry Pi** (if not already there):
   \`\`\`bash
   scp -r deploy-YYYYMMDD-HHMMSS/ pi@your-pi-ip:~/tvattstuga/
   \`\`\`

3. **Edit tvattstuga.service** - update paths and user if needed (default uses 'pi' user)

4. **Create symlink to this deployment**:
   \`\`\`bash
   cd ~/tvattstuga
   ln -sfn deploy-YYYYMMDD-HHMMSS current
   \`\`\`

5. **Install and start the service**:
   \`\`\`bash
   sudo cp ~/tvattstuga/current/tvattstuga.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable tvattstuga
   sudo systemctl start tvattstuga
   \`\`\`

6. **Check status**:
   \`\`\`bash
   sudo systemctl status tvattstuga
   sudo journalctl -u tvattstuga -f  # Follow logs
   \`\`\`

### Updating to a New Version

When you have a new deployment package:

1. **Stop the service**:
   \`\`\`bash
   sudo systemctl stop tvattstuga
   \`\`\`

2. **Copy new deployment to Raspberry Pi**:
   \`\`\`bash
   scp -r deploy-YYYYMMDD-HHMMSS/ pi@your-pi-ip:~/tvattstuga/
   \`\`\`

3. **Update the symlink to point to new deployment**:
   \`\`\`bash
   cd ~/tvattstuga
   ln -sfn deploy-YYYYMMDD-HHMMSS current
   \`\`\`

4. **Copy updated .env settings** (if needed):
   \`\`\`bash
   # Copy settings from previous deployment if they changed
   cp deploy-YYYYMMDD-HHMMSS-old/.env current/.env
   \`\`\`

5. **Restart the service**:
   \`\`\`bash
   sudo systemctl start tvattstuga
   sudo systemctl status tvattstuga
   \`\`\`

6. **Clean up old deployments** (optional):
   \`\`\`bash
   # Keep only the last few deployments
   ls -t deploy-* | tail -n +4 | xargs rm -rf
   \`\`\`

The app will be available at http://localhost:3000
EOF

echo "✅ Deployment package created: $DEPLOY_DIR"
echo ""
echo "🚀 Next steps:"
echo "1. Edit $DEPLOY_DIR/.env with your actual credentials"
echo "2. Copy $DEPLOY_DIR/ to your Raspberry Pi"
echo "3. Follow instructions in $DEPLOY_DIR/DEPLOY.md"
echo ""
echo "📋 Files ready for deployment:"
ls -la "$DEPLOY_DIR/"
