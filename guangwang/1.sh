#!/bin/bash
set -e

DEPLOY_DIR="/www/wwwroot/vpn.wangwei.tech"
APP_NAME="web"

echo "Starting deploy..."

cd "$DEPLOY_DIR"
echo "Deploy dir: $(pwd)"

echo "Checking uploaded files..."
if [ -f public/logo.png ]; then
  echo "OK: public/logo.png exists"
else
  echo "ERROR: public/logo.png missing. The domain is probably pointing at another website root, or the upload did not overwrite this directory."
  exit 1
fi

if grep -q "config.vpn_apk" lib/clientCrypto.ts; then
  echo "OK: lib/clientCrypto.ts supports new response fields"
else
  echo "ERROR: lib/clientCrypto.ts is still old. Upload the latest source files before deploying."
  exit 1
fi

echo "Stopping old PM2 process..."
pm2 delete "$APP_NAME" 2>/dev/null || true

echo "Removing old Next build cache..."
rm -rf .next
rm -rf node_modules/.cache

echo "Installing dependencies..."
npm install

echo "Building project..."
npm run build

if [ -d ".next" ]; then
  echo "OK: .next generated"
  ls -lh .next/static/chunks/app/*.js 2>/dev/null | head -3 || true
else
  echo "ERROR: build failed, .next does not exist"
  exit 1
fi

echo "Starting new PM2 process..."
pm2 start npm --name "$APP_NAME" --cwd "$DEPLOY_DIR" -- run start

pm2 save

echo "Deploy finished."
echo "Check PM2 cwd and status:"
pm2 describe "$APP_NAME" | grep -E "name|status|cwd|script path|exec cwd" || true
pm2 list
