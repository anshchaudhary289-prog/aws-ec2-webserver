#!/usr/bin/env bash
# Set up an nginx web server on a fresh EC2 Linux instance.
#
# Works on:
#   - Ubuntu / Debian   (apt)
#   - Amazon Linux / RHEL-family (yum or dnf)
#
# What it does:
#   1. Updates packages and installs nginx
#   2. Enables nginx to start on boot and starts it now
#   3. Deploys this repo's index.html as the served page
#      (falls back to a built-in status page if index.html is not found)
#   4. Prints the instance public IP (via the EC2 metadata endpoint)
#
# Usage (on the instance, after copying/cloning this repo):
#   chmod +x scripts/setup-webserver.sh
#   ./scripts/setup-webserver.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
WEB_ROOT="/var/www/html"

# Use sudo when not already root (user-data runs as root; SSH sessions do not).
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi

echo "==> Detecting package manager"
if command -v apt-get >/dev/null 2>&1; then
  PKG="apt"
  $SUDO apt-get update -y
  $SUDO apt-get install -y nginx curl
elif command -v dnf >/dev/null 2>&1; then
  PKG="dnf"
  $SUDO dnf install -y nginx curl
elif command -v yum >/dev/null 2>&1; then
  PKG="yum"
  $SUDO yum install -y nginx curl
else
  echo "Error: no supported package manager found (apt, dnf or yum expected)." >&2
  exit 1
fi
echo "    Using: $PKG"

echo "==> Enabling and starting nginx"
$SUDO systemctl enable nginx
$SUDO systemctl start nginx || $SUDO systemctl restart nginx

echo "==> Deploying web page to $WEB_ROOT"
$SUDO mkdir -p "$WEB_ROOT"
if [[ -f "$REPO_DIR/index.html" ]]; then
  $SUDO cp "$REPO_DIR/index.html" "$WEB_ROOT/index.html"
  echo "    Deployed index.html from this repo."
else
  # Fallback: generate a minimal status page so the server never serves a blank site.
  HOST_NAME="$(hostname)"
  cat <<EOF | $SUDO tee "$WEB_ROOT/index.html" >/dev/null
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Deployed on AWS EC2</title></head>
<body>
  <h1>Deployed on AWS EC2</h1>
  <p>Web server is running on host: ${HOST_NAME}</p>
  <p>Setup by Ansh Chaudhary — Cloud &amp; DevOps.</p>
</body>
</html>
EOF
  echo "    index.html not found next to the script — wrote a built-in status page instead."
fi

echo "==> Verifying nginx is responding locally"
if curl -fsS http://127.0.0.1/ >/dev/null; then
  echo "    Local check OK: nginx returned the page on port 80."
else
  echo "    Warning: nginx did not respond on http://127.0.0.1/ — check 'systemctl status nginx'." >&2
fi

echo "==> Public address"
# IMDSv2 first (token), then IMDSv1 fallback. Short timeouts so the script
# never hangs when run outside EC2.
PUBLIC_IP=""
TOKEN="$(curl -fsS -m 2 -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' http://169.254.169.254/latest/api/token 2>/dev/null || true)"
if [[ -n "$TOKEN" ]]; then
  PUBLIC_IP="$(curl -fsS -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
fi
if [[ -z "$PUBLIC_IP" ]]; then
  PUBLIC_IP="$(curl -fsS -m 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
fi

if [[ -n "$PUBLIC_IP" ]]; then
  echo "    Open your site at: http://${PUBLIC_IP}"
else
  echo "    Could not read the public IP from the metadata endpoint."
  echo "    Find it in the EC2 console (Instance -> Public IPv4 address),"
  echo "    and make sure Security Group inbound allows TCP 80 from 0.0.0.0/0."
fi

echo "Done."
