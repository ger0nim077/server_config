#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo bash install_chromedriver.sh            # installs version matching google-chrome
#   sudo CHROME_VERSION="140.0.7339.185" bash install_chromedriver.sh   # install specific

# 1) Determine version
if [[ -n "${CHROME_VERSION:-}" ]]; then
  VER="$CHROME_VERSION"
else
  if command -v google-chrome >/dev/null 2>&1; then
    VER="$(google-chrome --version | awk '{print $3}')"
  elif command -v chromium >/dev/null 2>&1; then
    VER="$(chromium --version | awk '{print $2}')"
  else
    echo "ERROR: google-chrome/chromium not found. Set CHROME_VERSION=..." >&2
    exit 1
  fi
fi

echo "Installing ChromeDriver $VER ..."

# 2) Build download URL (Chrome for Testing)
URL="https://storage.googleapis.com/chrome-for-testing-public/${VER}/linux64/chromedriver-linux64.zip"

TMPDIR="$(mktemp -d)"
cd "$TMPDIR"

# 3) Download & unpack
wget -q "$URL" -O chromedriver-linux64.zip
unzip -q chromedriver-linux64.zip
cd chromedriver-linux64

# 4) Install as versioned binary and update symlink
dest="/usr/local/bin/chromedriver${VER%%.*}" # e.g., /usr/local/bin/chromedriver140
install -m 755 chromedriver "$dest"
ln -sfn "$dest" /usr/local/bin/chromedriver

# 5) Show result
echo "Installed:"
ls -l /usr/local/bin/chromedriver /usr/local/bin/chromedriver${VER%%.*}
chromedriver --version
