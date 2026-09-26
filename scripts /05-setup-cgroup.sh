#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"
PID_FILE="$PROJECT_DIR/container.pid"

CGROUP="/sys/fs/cgroup/raw-container"

MEMORY_LIMIT="100M"

echo "======================================"
echo " Setting up cgroups v2"
echo "======================================"

if [ ! -f "$PID_FILE" ]; then
    echo "ERROR: Container PID file not found."
    exit 1
fi

CONTAINER_PID=$(cat "$PID_FILE")

if ! sudo kill -0 "$CONTAINER_PID" 2>/dev/null; then
    echo "ERROR: Container is not running."
    exit 1
fi

echo "Checking cgroup filesystem..."

if ! mount | grep -q "type cgroup2"; then
    echo "ERROR: cgroups v2 is not mounted."
    exit 1
fi

echo "Creating cgroup..."

sudo mkdir -p "$CGROUP"

echo "Setting memory limit to $MEMORY_LIMIT..."

echo $((100 * 1024 * 1024)) | \
    sudo tee "$CGROUP/memory.max" > /dev/null

echo "Moving container process into cgroup..."

echo "$CONTAINER_PID" | \
    sudo tee "$CGROUP/cgroup.procs" > /dev/null

echo
echo "======================================"
echo " cgroup Configuration"
echo "======================================"

echo
echo "Memory limit:"
sudo cat "$CGROUP/memory.max"

echo
echo "Processes in cgroup:"
sudo cat "$CGROUP/cgroup.procs"

echo
echo "cgroup:"
sudo cat "$CGROUP/cgroup.controllers"
