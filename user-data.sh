#!/bin/bash
# EC2 user data — paste this into "Advanced details -> User data" at launch.
#
# Runs once, as root, on first boot. It performs the same steps as
# scripts/setup-webserver.sh (detect package manager -> install nginx ->
# enable + start -> write status page), inlined here because user data
# runs before this repo can be cloned onto the instance.
#
# Note: user data has no `set -e` on purpose in the header block below —
# cloud-init should attempt every step and log the outcome to
# /var/log/cloud-init-output.log either way.
exec > >(tee /var/log/user-data.log) 2>&1
set -x

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y nginx curl
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y nginx curl
elif command -v yum >/dev/null 2>&1; then
  yum install -y nginx curl
else
  echo "No supported package manager found (apt, dnf or yum expected)." >&2
  exit 1
fi

systemctl enable nginx
systemctl start nginx || systemctl restart nginx

mkdir -p /var/www/html
HOST_NAME="$(hostname)"
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Deployed on AWS EC2</title></head>
<body>
  <h1>Deployed on AWS EC2</h1>
  <p>This page is served by nginx on an EC2 instance, installed automatically by user data at launch.</p>
  <p>Host: ${HOST_NAME}</p>
  <p>Setup by Ansh Chaudhary — Final Year B.Tech CSE, MIET Meerut · Cloud &amp; DevOps.</p>
</body>
</html>
EOF

echo "User data setup finished. nginx status:"
systemctl --no-pager status nginx || true
