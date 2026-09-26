#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"
BASE_DIR="$PROJECT_DIR/base"

ALPINE_VERSION="3.24.0"
ARCH="x86_64"

URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"

echo "======================================"
echo " Downloading Alpine Root Filesystem"
echo "======================================"

mkdir -p "$PROJECT_DIR"

if [ -f "$BASE_DIR/etc/os-release" ]; then
    echo "Alpine root filesystem already exists."
    exit 0
fi

mkdir -p "$BASE_DIR"

TMP_FILE="/tmp/alpine-minirootfs.tar.gz"

echo "Downloading Alpine ${ALPINE_VERSION}..."

wget -O "$TMP_FILE" "$URL"

echo "Extracting Alpine root filesystem..."

sudo tar -xzf "$TMP_FILE" -C "$BASE_DIR"

rm -f "$TMP_FILE"

echo
echo "Alpine root filesystem created:"
cat "$BASE_DIR/etc/os-release"

echo
echo "Root filesystem:"
echo "$BASE_DIR"
