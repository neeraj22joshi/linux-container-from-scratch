#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"
MERGED="$PROJECT_DIR/merged"
PID_FILE="$PROJECT_DIR/container.pid"

echo "======================================"
echo " Creating Linux Container"
echo "======================================"

if ! mountpoint -q "$MERGED"; then
    echo "ERROR: OverlayFS is not mounted."
    echo "Run:"
    echo "./02-setup-overlayfs.sh"
    exit 1
fi

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")

    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Container is already running."
        echo "Host PID: $OLD_PID"
        exit 0
    fi

    rm -f "$PID_FILE"
fi

echo "Starting container..."

sudo unshare \
    --mount \
    --uts \
    --ipc \
    --net \
    --pid \
    --fork \
    --mount-proc \
    chroot "$MERGED" \
    /bin/sh -c '
        hostname raw-container
        exec /bin/sh
    ' &

CONTAINER_PID=$!

echo "$CONTAINER_PID" > "$PID_FILE"

sleep 2

echo
echo "Container started."

echo "Host PID: $CONTAINER_PID"

echo
echo "Process tree:"
sudo pstree -ap "$CONTAINER_PID" || true

echo
echo "Container network namespace:"
sudo lsns -t net -p "$CONTAINER_PID"
