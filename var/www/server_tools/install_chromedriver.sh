#!/bin/bash
set -euo pipefail

# --- Detect current installed versions ---
echo "=== ChromeDriver Installer ==="

# Current chromedriver version (if any)
if command -v chromedriver >/dev/null 2>&1; then
  CURR_DRV_VER="$(chromedriver --version | awk '{print $2}')"
  echo "Current ChromeDriver: $CURR_DRV_VER ($(command -v chromedriver))"
else
  CURR_DRV_VER="none"
  echo "Current ChromeDriver: not installed"
fi

# Installed Chrome version
if command -v google-chrome >/dev/null 2>&1; then
  CHROME_VER="$(google-chrome --version | awk '{print $3}')"
  echo "Installed Google Chrome: $CHROME_VER"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_VER="$(chromium --version | awk '{print $2}')"
  echo "Installed Chromium: $CHROME_VER"
else
  echo "ERROR: No Chrome/Chromium browser detected!"
  exit 1
fi

# --- Determine target version ---
VER="${CHROME_VERSION:-$CHROME_VER}"
echo "Target ChromeDriver to install: $VER"

# --- Compare versions ---
if [[ "$CURR_DRV_VER" == "$VER" ]]; then
  echo "ChromeDriver is already at the correct version ($VER). Reinstalling..."
else
  echo "Updating ChromeDriver from $CURR_DRV_VER to $VER ..."
fi

# --- Build download URL ---
URL="https://storage.googleapis.com/chrome-for-testing-public/${VER}/linux64/chromedriver-linux64.zip"

# --- Download & install ---
TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

echo "Downloading ChromeDriver $VER ..."
wget -q "$URL" -O chromedriver-linux64.zip

unzip -q chromedriver-linux64.zip
cd chromedriver-linux64

DEST="/usr/local/bin/chromedriver${VER%%.*}"
install -m 755 chromedriver "$DEST"
ln -sfn "$DEST" /usr/local/bin/chromedriver

# --- Final check ---
echo "Installed:"
ls -l /usr/local/bin/chromedriver /usr/local/bin/chromedriver${VER%%.*}
chromedriver --version

echo "=== Installation complete ==="
