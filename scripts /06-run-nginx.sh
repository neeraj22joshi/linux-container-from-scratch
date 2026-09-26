#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"
PID_FILE="$PROJECT_DIR/container.pid"
MERGED="$PROJECT_DIR/merged"

if [ ! -f "$PID_FILE" ]; then
    echo "ERROR: Container PID file not found."
    exit 1
fi

CONTAINER_PID=$(cat "$PID_FILE")

if ! sudo kill -0 "$CONTAINER_PID" 2>/dev/null; then
    echo "ERROR: Container is not running."
    exit 1
fi

echo "======================================"
echo " Installing and Running Nginx"
echo "======================================"

echo "Creating DNS configuration..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'

echo "Updating Alpine package index..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'apk update'

echo "Installing Nginx and curl..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'apk add --no-cache nginx curl'

echo "Creating web root..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'mkdir -p /var/www/localhost/htdocs'

echo "Creating web page..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'cat > /var/www/localhost/htdocs/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Raw Linux Container</title>
</head>
<body>
    <h1>Hello from my Linux container!</h1>
    <p>Built without Docker or a CRI.</p>
    <p>Running on Alpine Linux with Nginx.</p>
</body>
</html>
EOF'

echo "Starting Nginx..."

sudo nsenter -t "$CONTAINER_PID" -m \
    chroot "$MERGED" \
    /bin/sh -c 'mkdir -p /run/nginx && nginx'

echo
echo "Testing Nginx..."

sudo nsenter -t "$CONTAINER_PID" -n \
    curl -I http://127.0.0.1

echo
echo "Nginx is running inside the container."
