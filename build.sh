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
cp -r build/ "$DEPLOY_DIR/"
cp -r server/ "$DEPLOY_DIR/"
cp deno.json "$DEPLOY_DIR/"
cp .env "$DEPLOY_DIR/"
cp tvattstuga.service "$DEPLOY_DIR/"

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

To run as a system service:

1. **Edit tvattstuga.service** - update paths and user
2. **Install service**:
   \`\`\`bash
   sudo cp tvattstuga.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable tvattstuga
   sudo systemctl start tvattstuga
   \`\`\`
3. **Check status**:
   \`\`\`bash
   sudo systemctl status tvattstuga
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
