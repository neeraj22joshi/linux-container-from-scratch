# Linux Container From Scratch — Architecture

## 1. Overview

This project demonstrates how a Linux container can be built using native Linux kernel features without Docker or a Container Runtime Interface (CRI).

The container is built using:

* Alpine Linux root filesystem
* Linux namespaces
* OverlayFS
* `chroot`
* cgroups v2
* veth networking
* Linux routing
* iptables NAT
* Nginx

The project is implemented and tested on an Ubuntu AWS EC2 instance.

---

# 2. High-Level Architecture

```text
                         AWS EC2
                    Ubuntu Linux Host
                           │
                           │
                    Linux Kernel
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
     Namespaces         OverlayFS        cgroups v2
          │                │                │
          │                │                │
          ▼                ▼                ▼
   Process/Network     Container FS     Resource Limits
      Isolation
          │
          │
          ▼
    ┌─────────────────────────────┐
    │        Container            │
    │                             │
    │  Alpine Linux               │
    │  PID Namespace              │
    │  UTS Namespace              │
    │  IPC Namespace              │
    │  Mount Namespace            │
    │  Network Namespace           │
    │                             │
    │       Nginx :80             │
    └─────────────┬───────────────┘
                  │
                veth
                  │
          ┌───────┴────────┐
          │                │
     veth-guest        veth-host
     10.200.0.2        10.200.0.1
          │                │
          └────────┬───────┘
                   │
                iptables
                   │
                Internet
```

---

# 3. Container Filesystem

The container uses Alpine Linux as its root filesystem.

```text
Alpine minirootfs
       │
       ▼
     base/
       │
       │ lower layer
       ▼
   ┌───────────┐
   │ OverlayFS │
   └─────┬─────┘
         │
         ▼
      merged/
         │
         ▼
   Container Root FS
```

The project uses four directories:

```text
raw-container/
├── base/
├── upper/
├── work/
└── merged/
```

### base

Contains the original Alpine Linux root filesystem.

### upper

Contains changes made to the container filesystem.

### work

Internal working directory required by OverlayFS.

### merged

The final filesystem presented to the container.

---

# 4. Linux Namespaces

Namespaces provide isolation between the container and the host.

The container is created using:

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

## PID Namespace

Provides process isolation.

Inside the container:

```bash
echo $$
```

returns:

```text
1
```

The container therefore has its own PID namespace.

Processes inside the container cannot see the normal host process hierarchy in the same way as processes in the host namespace.

---

## UTS Namespace

Provides hostname isolation.

Inside the container:

```bash
hostname raw-container
```

The container can therefore have a hostname different from the Ubuntu host.

---

## IPC Namespace

Provides isolation for System V IPC and POSIX message queues.

This prevents IPC objects from being directly shared across the isolated namespace.

---

## Mount Namespace

Provides an isolated view of mounted filesystems.

The container uses its own mount namespace and its own `/proc` filesystem.

---

## Network Namespace

Provides an isolated network stack.

The container gets its own:

* Network interfaces
* IP addresses
* Routing table
* Network namespace

---

# 5. chroot

After creating the namespaces, the process changes its root filesystem using:

```bash
chroot /path/to/merged /bin/sh
```

This makes the Alpine filesystem appear as the root filesystem to processes inside the container.

`chroot` alone is not a container.

The isolation comes from combining it with Linux namespaces, cgroups and other kernel features.

---

# 6. Container Networking

The container has its own network namespace.

A veth pair connects the container network namespace with the host.

```text
                 Host
           10.200.0.1/24
                  │
             veth-host
                  │
                  │
             veth-guest
                  │
                  ▼
              Container
           10.200.0.2/24
```

Inside the container:

```bash
ip addr
```

shows the container network interface.

The default route points to:

```text
10.200.0.1
```

---

# 7. Internet Connectivity

The Ubuntu host acts as the gateway.

IP forwarding is enabled:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Traffic from the container network is translated using iptables:

```bash
sudo iptables -t nat -A POSTROUTING \
    -s 10.200.0.0/24 \
    -o <WAN_INTERFACE> \
    -j MASQUERADE
```

Traffic flow:

```text
Container
10.200.0.2
     │
     ▼
10.200.0.1
     │
     ▼
Ubuntu Host
     │
 iptables NAT
     │
     ▼
Internet
```

---

# 8. cgroups v2

Linux cgroups are used to control and account for resource usage.

This project uses cgroups v2 to configure a memory limit.

Example:

```bash
echo $((100 * 1024 * 1024)) \
    | sudo tee /sys/fs/cgroup/raw-container/memory.max
```

This limits the cgroup to approximately 100 MiB of memory.

The container process is then placed into the cgroup using:

```bash
echo <PID> | sudo tee /sys/fs/cgroup/raw-container/cgroup.procs
```

---

# 9. Nginx Workload

Nginx runs inside the container.

The application flow is:

```text
Nginx
  │
  │ TCP :80
  ▼
Container Network Namespace
  │
  ▼
127.0.0.1
```

The application can be tested using:

```bash
curl http://127.0.0.1
```

---

# 10. Complete Container Flow

```text
Alpine RootFS
      │
      ▼
   OverlayFS
      │
      ▼
Linux Namespaces
      │
      ├── PID
      ├── UTS
      ├── IPC
      ├── Mount
      └── Network
      │
      ▼
    chroot
      │
      ▼
  Container
      │
      ├───────────────┐
      │               │
      ▼               ▼
   cgroups          veth
      │               │
      │               ▼
      │          Host Network
      │               │
      │          iptables NAT
      │               │
      │               ▼
      │            Internet
      │
      ▼
 Resource Limits

             Container
                 │
                 ▼
               Nginx
                 │
                 ▼
               HTTP
```

---

# 11. Key Concepts Demonstrated

| Component         | Purpose                              |
| ----------------- | ------------------------------------ |
| Alpine rootfs     | Container filesystem                 |
| OverlayFS         | Layered writable filesystem          |
| `chroot`          | Changes apparent root filesystem     |
| PID namespace     | Process isolation                    |
| UTS namespace     | Hostname isolation                   |
| IPC namespace     | IPC isolation                        |
| Mount namespace   | Mount isolation                      |
| Network namespace | Network isolation                    |
| veth              | Connects container and host networks |
| iptables NAT      | Provides Internet connectivity       |
| cgroups v2        | Resource control                     |
| Nginx             | Containerized workload               |

---

# 12. Important Concept

A Linux container is not a single feature.

It is a combination of Linux kernel mechanisms:

```text
Container
    │
    ├── Namespaces → Isolation
    ├── cgroups → Resource Control
    ├── OverlayFS → Filesystem Layers
    ├── chroot → Root Filesystem
    └── Networking → Connectivity
```

This project demonstrates these mechanisms individually and combines them into a working container environment.
