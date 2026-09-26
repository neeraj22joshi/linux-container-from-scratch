#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"

BASE="$PROJECT_DIR/base"
UPPER="$PROJECT_DIR/upper"
WORK="$PROJECT_DIR/work"
MERGED="$PROJECT_DIR/merged"

echo "======================================"
echo " Setting up OverlayFS"
echo "======================================"

mkdir -p "$BASE"
mkdir -p "$UPPER"
mkdir -p "$WORK"
mkdir -p "$MERGED"

BASE=$(realpath "$BASE")
UPPER=$(realpath "$UPPER")
WORK=$(realpath "$WORK")
MERGED=$(realpath "$MERGED")

if mountpoint -q "$MERGED"; then
    echo "OverlayFS is already mounted."
    mount | grep "$MERGED"
    exit 0
fi

sudo mount -t overlay overlay \
    -o lowerdir="$BASE",upperdir="$UPPER",workdir="$WORK" \
    "$MERGED"

echo
echo "OverlayFS mounted successfully."

mount | grep "$MERGED"

echo
echo "Container filesystem:"
ls "$MERGED"
