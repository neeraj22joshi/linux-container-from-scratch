#!/bin/bash

set +e

PROJECT_DIR="$HOME/raw-container"
PID_FILE="$PROJECT_DIR/container.pid"
CGROUP="/sys/fs/cgroup/raw-container"

echo "======================================"
echo " Cleaning Up Container"
echo "======================================"

if [ -f "$PID_FILE" ]; then

    CONTAINER_PID=$(cat "$PID_FILE")

    echo "Container PID: $CONTAINER_PID"

    if sudo kill -0 "$CONTAINER_PID" 2>/dev/null; then

        echo "Stopping Nginx..."

        sudo nsenter -t "$CONTAINER_PID" -m \
            chroot "$PROJECT_DIR/merged" \
            /bin/sh -c 'nginx -s stop' 2>/dev/null || true

        echo "Stopping container..."

        sudo kill "$CONTAINER_PID" 2>/dev/null || true

        sleep 2

    fi

    rm -f "$PID_FILE"
fi

echo "Removing veth interface..."

sudo ip link delete veth-host 2>/dev/null || true

echo "Removing NAT rule..."

WAN_IF=$(ip route | awk '/default/ {print $5; exit}')

if [ -n "$WAN_IF" ]; then

    sudo iptables -t nat -D POSTROUTING \
        -s 10.200.0.0/24 \
        -o "$WAN_IF" \
        -j MASQUERADE 2>/dev/null || true

fi

echo "Removing cgroup..."

if [ -d "$CGROUP" ]; then

    # Try to terminate remaining processes in the cgroup
    for PID in $(sudo cat "$CGROUP/cgroup.procs" 2>/dev/null); do
        sudo kill "$PID" 2>/dev/null || true
    done

    sleep 1

    sudo rmdir "$CGROUP" 2>/dev/null || true
fi

echo "Unmounting OverlayFS..."

if mountpoint -q "$PROJECT_DIR/merged"; then
    sudo umount "$PROJECT_DIR/merged"
fi

echo
echo "Cleanup completed."
