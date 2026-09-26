#!/bin/bash

set -e

PROJECT_DIR="$HOME/raw-container"
PID_FILE="$PROJECT_DIR/container.pid"

CONTAINER_IP="10.200.0.2/24"
HOST_IP="10.200.0.1/24"
NETWORK="10.200.0.0/24"

if [ ! -f "$PID_FILE" ]; then
    echo "ERROR: Container PID file not found."
    echo "Run ./03-create-container.sh first."
    exit 1
fi

CONTAINER_PID=$(cat "$PID_FILE")

if ! sudo kill -0 "$CONTAINER_PID" 2>/dev/null; then
    echo "ERROR: Container is not running."
    exit 1
fi

echo "======================================"
echo " Setting up Container Networking"
echo "======================================"

# Detect default network interface
WAN_IF=$(ip route | awk '/default/ {print $5; exit}')

if [ -z "$WAN_IF" ]; then
    echo "ERROR: Could not detect WAN interface."
    exit 1
fi

echo "WAN interface: $WAN_IF"

# Remove old veth if present
sudo ip link delete veth-host 2>/dev/null || true

echo "Creating veth pair..."

sudo ip link add veth-host type veth peer name veth-guest

echo "Moving container side into network namespace..."

sudo ip link set veth-guest netns "$CONTAINER_PID"

echo "Configuring host interface..."

sudo ip addr add "$HOST_IP" dev veth-host
sudo ip link set veth-host up

echo "Configuring container interface..."

sudo nsenter -t "$CONTAINER_PID" -n \
    ip link set lo up

sudo nsenter -t "$CONTAINER_PID" -n \
    ip link set veth-guest up

sudo nsenter -t "$CONTAINER_PID" -n \
    ip addr add "$CONTAINER_IP" dev veth-guest

echo "Adding default route..."

sudo nsenter -t "$CONTAINER_PID" -n \
    ip route add default via 10.200.0.1

echo "Enabling IP forwarding..."

sudo sysctl -w net.ipv4.ip_forward=1

echo "Configuring NAT..."

sudo iptables -t nat -C POSTROUTING \
    -s "$NETWORK" \
    -o "$WAN_IF" \
    -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING \
    -s "$NETWORK" \
    -o "$WAN_IF" \
    -j MASQUERADE

echo
echo "======================================"
echo " Network Configuration"
echo "======================================"

echo
echo "Host:"
ip addr show veth-host

echo
echo "Container:"
sudo nsenter -t "$CONTAINER_PID" -n ip addr

echo
echo "Container routes:"
sudo nsenter -t "$CONTAINER_PID" -n ip route

echo
echo "Testing host connectivity..."

sudo nsenter -t "$CONTAINER_PID" -n \
    ping -c 3 10.200.0.1

echo
echo "Testing Internet connectivity..."

sudo nsenter -t "$CONTAINER_PID" -n \
    ping -c 3 8.8.8.8
