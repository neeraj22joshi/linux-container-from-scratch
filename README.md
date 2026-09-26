# Linux Container From Scratch

A hands-on project demonstrating how Linux containers work internally by building an isolated container environment without Docker or a Container Runtime Interface (CRI).

The project uses native Linux features such as namespaces, OverlayFS, cgroups v2, veth networking, `chroot`, and iptables NAT.

## Architecture

```text
                    Ubuntu AWS EC2
                         │
              ┌──────────┴──────────┐
              │                     │
        Linux Kernel          Host Networking
              │                     │
      ┌───────┼────────┐            │
      │       │        │            │
 Namespaces OverlayFS cgroups       │
      │       │        │            │
      │       │        └── Resource Limits
      │       │
      │       └── Container Root Filesystem
      │
      ├── PID Namespace
      ├── UTS Namespace
      ├── IPC Namespace
      ├── Mount Namespace
      └── Network Namespace
                    │
                  veth
              ┌─────┴─────┐
              │           │
         Host veth     Container veth
         10.200.0.1    10.200.0.2
              │           │
              └─────┬─────┘
                    │
                 iptables
                    │
                 Internet
                    │
                  Nginx
```

## Technologies

* Linux
* Ubuntu
* Alpine Linux
* Linux Namespaces
* PID Namespace
* UTS Namespace
* IPC Namespace
* Mount Namespace
* Network Namespace
* OverlayFS
* chroot
* cgroups v2
* veth
* iproute2
* iptables
* Nginx
* AWS EC2

## What This Project Demonstrates

### 1. Container Root Filesystem

An Alpine Linux minirootfs is used as the container's root filesystem.

```text
Alpine minirootfs
       │
       ▼
container root filesystem
```

### 2. OverlayFS

OverlayFS provides a writable layer over the read-only Alpine base filesystem.

```text
        Container
           │
        OverlayFS
        ┌──┴───┐
        │      │
      upper   base
      layer   Alpine
```

### 3. Linux Namespaces

The container is launched using Linux namespaces:

```bash
unshare \
  --mount \
  --uts \
  --ipc \
  --net \
  --pid \
  --fork \
  --mount-proc
```

This provides isolation for:

* Processes
* Hostname
* IPC
* Network
* Mounts

Inside the container, the shell runs as PID 1.

### 4. chroot

The container filesystem is changed to the Alpine root filesystem:

```bash
chroot /path/to/container/rootfs /bin/sh
```

### 5. Container Networking

A veth pair connects the container network namespace with the host.

```text
Container
10.200.0.2
    │
veth-guest
    │
veth-host
    │
10.200.0.1
    │
Ubuntu Host
```

The container uses the host as its default gateway.

### 6. Internet Connectivity

IP forwarding is enabled on the host:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

iptables MASQUERADE provides NAT:

```bash
sudo iptables -t nat -A POSTROUTING \
  -s 10.200.0.0/24 \
  -o <WAN_INTERFACE> \
  -j MASQUERADE
```

### 7. Nginx Workload

Nginx is installed and executed inside the isolated container.

The application can be tested with:

```bash
curl http://127.0.0.1
```

### 8. cgroups v2

cgroups are used to control container resources such as memory.

Example:

```bash
echo $((100 * 1024 * 1024)) \
  | sudo tee /sys/fs/cgroup/my-raw-container/memory.max
```

## Container Building Flow

```text
Alpine RootFS
      │
      ▼
OverlayFS
      │
      ▼
Linux Namespaces
      │
      ▼
chroot
      │
      ▼
Network Namespace
      │
      ▼
veth Pair
      │
      ▼
iptables NAT
      │
      ▼
cgroups v2
      │
      ▼
Nginx
```

## Why Build a Container Without Docker?

Docker provides a convenient interface for creating containers, but the underlying isolation and resource-management mechanisms are provided by the Linux kernel.

This project explores those underlying mechanisms directly:

```text
Docker / Container Runtime
          │
          ▼
      Linux Kernel
          │
   ┌──────┼─────────┐
   ▼      ▼         ▼
Namespaces OverlayFS cgroups
          │
          ▼
       Container
```

## Environment

Tested on:

* Ubuntu 26.04 LTS
* x86_64
* AWS EC2
* Linux kernel 7.0.x
* Alpine Linux 3.24

## Learning Outcomes

Through this project I gained hands-on understanding of:

* Linux process isolation
* PID namespaces
* Network namespaces
* Linux mount namespaces
* OverlayFS
* Linux cgroups v2
* veth networking
* Linux routing
* NAT
* Container root filesystems
* How container networking works
* How container isolation is implemented at the Linux kernel level

## Future Improvements

Possible extensions:

* Container lifecycle management
* Port forwarding
* CPU limits using cgroups
* Read-only root filesystem
* Container configuration file
* Automated setup and cleanup scripts

