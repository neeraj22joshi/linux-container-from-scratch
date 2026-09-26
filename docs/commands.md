# Linux Container From Scratch — Commands

This document contains the major Linux commands used to build, configure, test and clean up the container.

---

# 1. Install Required Packages

```bash
sudo apt update

sudo apt install -y \
    wget \
    tree \
    util-linux \
    iproute2 \
    iptables \
    iputils-ping \
    curl \
    psmisc
```

---

# 2. Create Project Directories

```bash
mkdir -p ~/raw-container/{base,upper,work,merged}
```

Verify:

```bash
tree ~/raw-container
```

---

# 3. Download Alpine Root Filesystem

```bash
wget https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-minirootfs-3.24.0-x86_64.tar.gz
```

Extract:

```bash
sudo tar -xzf \
    alpine-minirootfs-3.24.0-x86_64.tar.gz \
    -C ~/raw-container/base
```

Verify:

```bash
cat ~/raw-container/base/etc/os-release
```

---

# 4. Setup OverlayFS

Set paths:

```bash
BASE=$(realpath ~/raw-container/base)
UPPER=$(realpath ~/raw-container/upper)
WORK=$(realpath ~/raw-container/work)
MERGED=$(realpath ~/raw-container/merged)
```

Mount OverlayFS:

```bash
sudo mount -t overlay overlay \
    -o lowerdir=$BASE,upperdir=$UPPER,workdir=$WORK \
    $MERGED
```

Verify:

```bash
mount | grep overlay
```

---

# 5. Create Linux Namespaces

Create the container:

```bash
sudo unshare \
    --mount \
    --uts \
    --ipc \
    --net \
    --pid \
    --fork \
    --mount-proc \
    chroot "$MERGED" /bin/sh
```

Check PID:

```bash
echo $$
```

Expected:

```text
1
```

Check hostname:

```bash
hostname
```

Change hostname:

```bash
hostname raw-container
```

---

# 6. Inspect Namespaces

On the host:

```bash
sudo lsns
```

List network namespaces:

```bash
sudo lsns -t net
```

Inspect the container process:

```bash
sudo pstree -ap <CONTAINER_PID>
```

---

# 7. Create veth Pair

Create:

```bash
sudo ip link add veth-host type veth peer name veth-guest
```

Move the container side into the container network namespace:

```bash
sudo ip link set veth-guest netns <CONTAINER_PID>
```

Configure host side:

```bash
sudo ip addr add 10.200.0.1/24 dev veth-host

sudo ip link set veth-host up
```

---

# 8. Configure Container Network

Bring loopback up:

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ip link set lo up
```

Bring veth interface up:

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ip link set veth-guest up
```

Assign IP:

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ip addr add 10.200.0.2/24 dev veth-guest
```

Add default route:

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ip route add default via 10.200.0.1
```

Check:

```bash
sudo nsenter -t <CONTAINER_PID> -n ip addr

sudo nsenter -t <CONTAINER_PID> -n ip route
```

---

# 9. Test Container-to-Host Connectivity

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ping -c 3 10.200.0.1
```

---

# 10. Enable IP Forwarding

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

Expected:

```text
net.ipv4.ip_forward = 1
```

---

# 11. Configure NAT

Find the default interface:

```bash
ip route
```

Example:

```text
default via 172.31.x.x dev ens5
```

The interface is:

```text
ens5
```

Configure MASQUERADE:

```bash
sudo iptables -t nat -A POSTROUTING \
    -s 10.200.0.0/24 \
    -o ens5 \
    -j MASQUERADE
```

Check:

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

---

# 12. Test Internet Connectivity

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    ping -c 3 8.8.8.8
```

---

# 13. Configure DNS

Inside the container:

```bash
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

Test DNS:

```bash
curl https://example.com
```

---

# 14. Install Nginx

Inside the Alpine container:

```bash
apk update
```

Install:

```bash
apk add nginx curl
```

Create runtime directory:

```bash
mkdir -p /run/nginx
```

Start:

```bash
nginx
```

Check:

```bash
curl http://127.0.0.1
```

---

# 15. cgroups v2

Check:

```bash
mount | grep cgroup
```

Create cgroup:

```bash
sudo mkdir -p /sys/fs/cgroup/raw-container
```

Set memory limit:

```bash
echo $((100 * 1024 * 1024)) | \
    sudo tee /sys/fs/cgroup/raw-container/memory.max
```

Check:

```bash
sudo cat /sys/fs/cgroup/raw-container/memory.max
```

Move process:

```bash
echo <CONTAINER_PID> | \
    sudo tee /sys/fs/cgroup/raw-container/cgroup.procs
```

Check processes:

```bash
sudo cat /sys/fs/cgroup/raw-container/cgroup.procs
```

---

# 16. Useful Namespace Commands

List all namespaces:

```bash
sudo lsns
```

PID namespaces:

```bash
sudo lsns -t pid
```

Network namespaces:

```bash
sudo lsns -t net
```

Mount namespaces:

```bash
sudo lsns -t mnt
```

UTS namespaces:

```bash
sudo lsns -t uts
```

IPC namespaces:

```bash
sudo lsns -t ipc
```

---

# 17. Inspect Container Process

Find the container launcher:

```bash
ps aux | grep '[u]nshare'
```

Inspect process tree:

```bash
sudo pstree -ap <CONTAINER_PID>
```

Inspect process namespaces:

```bash
sudo lsns -p <CONTAINER_PID>
```

---

# 18. Inspect Networking

Host interfaces:

```bash
ip addr
```

Host routes:

```bash
ip route
```

Container interfaces:

```bash
sudo nsenter -t <CONTAINER_PID> -n ip addr
```

Container routes:

```bash
sudo nsenter -t <CONTAINER_PID> -n ip route
```

---

# 19. Inspect OverlayFS

```bash
mount | grep overlay
```

Check writable layer:

```bash
ls -la ~/raw-container/upper
```

Check merged filesystem:

```bash
ls -la ~/raw-container/merged
```

---

# 20. Cleanup

Stop the container:

```bash
sudo kill <CONTAINER_PID>
```

Remove veth:

```bash
sudo ip link delete veth-host
```

Remove NAT rule:

```bash
sudo iptables -t nat -D POSTROUTING \
    -s 10.200.0.0/24 \
    -o <WAN_INTERFACE> \
    -j MASQUERADE
```

Remove cgroup:

```bash
sudo rmdir /sys/fs/cgroup/raw-container
```

Unmount OverlayFS:

```bash
sudo umount ~/raw-container/merged
```

---

# 21. Project Automation

Instead of running each command manually, the repository provides scripts:

```bash
./scripts/01-download-rootfs.sh
./scripts/02-setup-overlayfs.sh
./scripts/03-create-container.sh
./scripts/04-setup-network.sh
./scripts/05-setup-cgroup.sh
./scripts/06-run-nginx.sh
```

Cleanup:

```bash
./scripts/cleanup.sh
```

---

# 22. Troubleshooting

## Check whether OverlayFS is mounted

```bash
mount | grep ~/raw-container/merged
```

## Check container process

```bash
ps aux | grep '[u]nshare'
```

## Check namespaces

```bash
sudo lsns
```

## Check veth

```bash
ip link show
```

## Check NAT

```bash
sudo iptables -t nat -L POSTROUTING -n -v
```

## Check cgroup

```bash
sudo cat /sys/fs/cgroup/raw-container/cgroup.procs
```

## Check Nginx

```bash
sudo nsenter -t <CONTAINER_PID> -n \
    curl http://127.0.0.1
```

---

# 23. Core Commands to Remember

```text
unshare  → Create namespaces
chroot   → Change root filesystem
mount    → Mount OverlayFS
ip       → Configure networking
nsenter  → Enter existing namespaces
iptables → Configure NAT
sysctl   → Configure kernel parameters
cgroups  → Control resources
nginx    → Run application
curl     → Test application
```
