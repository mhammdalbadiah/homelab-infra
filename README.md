# 🏠 Homelab Infrastructure

Production-grade self-hosted infrastructure running on bare-metal hardware in Riyadh, Saudi Arabia. Built for hands-on Cloud, DevOps, and Security engineering.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TP-Link TL-SG108E                           │
│                      Managed Gigabit Switch                        │
│               (VLAN segmentation · 8-port GbE)                     │
└──────┬──────────────────┬──────────────────┬───────────────────────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐
│  Raspberry   │  │   Clients    │  │     Xeon E5-2690 Server      │
│   Pi 5 4GB   │  │  (Remote)    │  │        Proxmox VE 9.2        │
│              │  │ • Arch PC    │  │   8C/16T · 32GB DDR3 · X79   │
│ • Samba NAS  │  │ • MacBook M3 │  │                              │
│ • Tailscale  │  │ • iPhone     │  │  ┌─────────────────────────┐ │
│ • Uptime Kuma│  │              │  │  │   Kubernetes (k3s)      │ │
│ • PaperMC    │  │  Tailscale   │  │  │  ┌────────┐ ┌────────┐  │ │
│ • OLED Mon.  │  │  (VPN in)    │  │  │  │Worker 1│ │Worker 2│  │ │
│              │  │              │  │  │  └────────┘ └────────┘  │ │
│  K3s Worker  │  │              │  │  │  ┌────────┐             │ │
│  (hybrid)    │  │              │  │  │  │ Master │             │ │
└──────────────┘  └──────────────┘  │  │  └────────┘             │ │
                                    │  └─────────────────────────┘ │
                                    │                              │
                                    │  ┌─────────────────────────┐ │
                                    │  │   DevOps Stack          │ │
                                    │  │  Gitea · ArgoCD         │ │
                                    │  │  Tekton · Portainer     │ │
                                    │  └─────────────────────────┘ │
                                    │                              │
                                    │  ┌─────────────────────────┐ │
                                    │  │   Monitoring            │ │
                                    │  │  Prometheus · Grafana   │ │
                                    │  │  Alertmanager           │ │
                                    │  └─────────────────────────┘ │
                                    │                              │
                                    │  ┌─────────────────────────┐ │
                                    │  │   Services              │ │
                                    │  │  Nextcloud · LocalStack │ │
                                    │  │  Pi-hole · WireGuard    │ │
                                    │  │  Nginx Proxy · MinIO    │ │
                                    │  └─────────────────────────┘ │
                                    │                              │
                                    │  ┌─────────────────────────┐ │
                                    │  │   BlackArch VM          │ │
                                    │  │  6C · 12GB · 80GB SSD   │ │
                                    │  │  2800+ security tools   │ │
                                    │  └─────────────────────────┘ │
                                    │                              │
                                    │  ┌─────────────────────────┐ │
                                    │  │   Lab VMs               │ │
                                    │  │  Sandbox (Debian)       │ │
                                    │  │  Ubuntu Server          │ │
                                    │  │  Rocky Linux            │ │
                                    │  └─────────────────────────┘ │
                                    └──────────────────────────────┘
```

---

## Hardware

### Xeon Server — Main Hypervisor

| Component | Spec |
|-----------|------|
| CPU | Intel Xeon E5-2690 (8C/16T, 2.9GHz) |
| RAM | 32GB DDR3 Quad Channel |
| Motherboard | X79 S7 (LGA 2011) |
| PSU | Corsair CV650 |
| OS Drive | 128GB SSD — Proxmox VE 9.2 |
| VM Drive | 250GB SSD — VMs and containers |
| Data Drive | 500GB HDD — Nextcloud, NAS, backups |
| Hypervisor | Proxmox VE 9.2 |

### Raspberry Pi 5 — Edge Node

| Component | Spec |
|-----------|------|
| Model | Raspberry Pi 5 (4GB RAM) |
| Role | NAS, monitoring, K3s worker node |
| Network | LAN (via switch) · Tailscale for remote access |
| Display | SSD1306 OLED — custom Arabic Matrix rain |

### Network

| Device | Role |
|--------|------|
| TP-Link TL-SG108E | Managed switch, VLAN segmentation |
| Tailscale | Remote access from external devices |
| WireGuard | External access tunnel |

---

## Services

### Kubernetes (k3s) — Hybrid Cluster

| Node | Host | Role |
|------|------|------|
| master | Xeon VM | Control Plane |
| worker-1 | Xeon VM | Workloads |
| worker-2 | Xeon VM | Workloads |
| worker-3 | Raspberry Pi 5 | Lightweight pods |

### CI/CD & DevOps

| Service | Purpose |
|---------|---------|
| Gitea | Lightweight self-hosted Git server |
| ArgoCD | GitOps continuous delivery for Kubernetes |
| Tekton | Cloud-native CI/CD pipelines on Kubernetes |
| Nexus Repository | Docker image and artifact storage |
| Portainer | Container management UI |
| Terraform | Infrastructure as Code |
| Ansible | Configuration management |

### Monitoring & Observability

| Service | Purpose |
|---------|---------|
| Prometheus | Metrics collection |
| Grafana | Dashboards and visualization |
| Alertmanager | Alert routing and notifications |
| Uptime Kuma | Service uptime monitoring (on Pi) |
| Custom OLED Dashboard | Real-time Pi system stats on SSD1306 |

### Security

| Service | Purpose |
|---------|---------|
| BlackArch VM | Penetration testing lab (2800+ tools) |

### Lab

| Service | Purpose |
|---------|---------|
| Sandbox VM (Debian) | General-purpose testing environment |
| Ubuntu Server VM | Cloud/production environment practice |
| Rocky Linux VM | RHEL-based enterprise environment practice |

### Networking & Access

| Service | Purpose |
|---------|---------|
| Pi-hole | DNS-level ad blocking |
| WireGuard | VPN tunnel |
| Tailscale | Remote access from external devices |
| Nginx Proxy Manager | Reverse proxy and SSL termination |

### Self-Hosted Services

| Service | Purpose |
|---------|---------|
| Nextcloud | Private cloud storage |
| LocalStack | AWS service simulation for certification prep |
| MinIO | S3-compatible object storage |
| PaperMC | Minecraft server (1.21.11) |
| Samba | Network file sharing (NAS) |

---

## Storage Layout

```
Xeon Server
├── /dev/sda — 128GB SSD
│   └── Proxmox VE OS + LXC containers
├── /dev/sdb — 500GB HDD
│   └── Nextcloud data, NAS, backups
└── /dev/sdc — 250GB SSD
    └── VMs (BlackArch, Sandbox, Ubuntu, Rocky, K3s nodes, etc.)

Raspberry Pi 5
└── 250GB SSD
    └── Samba NAS share, PaperMC world data
```

---

## Network Topology

```
                    ISP Router
                        │
                        ▼
              TP-Link TL-SG108E
             ┌────┬────┬────┬────┐
             │    │    │    │    │
             ▼    ▼    ▼    ▼    ▼
           Xeon  Pi5  Arch  Mac  ···
                       PC   Book

VLAN 1 (Management) ── Proxmox Web UI
VLAN 2 (Services)   ── VMs, containers
VLAN 3 (Lab)        ── BlackArch, Sandbox, Ubuntu, Rocky
VLAN 4 (IoT)        ── Isolated devices

Tailscale (Remote Access):
  Arch PC · MacBook · iPhone → tunnel into homelab from anywhere
```

---

## Resource Allocation

| Service | Cores | RAM | Storage | Drive |
|---------|-------|-----|---------|-------|
| Proxmox OS | — | 2 GB | 10 GB | SSD 128GB |
| K3s Master | 2 | 2 GB | 10 GB | SSD 250GB |
| K3s Worker × 2 | 2 each | 4 GB | 20 GB | SSD 250GB |
| Gitea | 1 | 512 MB | 5 GB | SSD 250GB |
| ArgoCD | 1 | 512 MB | 5 GB | SSD 250GB |
| Tekton | 2 | 1 GB | 5 GB | SSD 250GB |
| BlackArch VM | 6 | 12 GB | 80 GB | SSD 250GB |
| Sandbox VM (Debian) | 4 | 4 GB | 30 GB | SSD 250GB |
| Ubuntu Server VM | 2 | 2 GB | 20 GB | SSD 250GB |
| Rocky Linux VM | 2 | 2 GB | 20 GB | SSD 250GB |
| Prometheus + Grafana | 1 | 1 GB | 10 GB | HDD |
| Pi-hole | 1 | 256 MB | 2 GB | SSD 128GB |
| Nextcloud (LXC) | 1 | 1 GB | — | HDD |
| LocalStack (LXC) | 2 | 1 GB | 5 GB | SSD 128GB |
| MinIO | 1 | 1 GB | 20 GB | HDD |
| Nexus | 1 | 2 GB | 15 GB | HDD |
| **Total** | **31** | **~26 GB** | **~195 GB** | |

---

## Tech Stack

```
Virtualization    Proxmox VE · QEMU/KVM · LXC
Orchestration     Kubernetes (k3s) · Docker · Portainer
CI/CD             Tekton · ArgoCD (GitOps) · Nexus
IaC               Terraform · Ansible
Monitoring        Prometheus · Grafana · Alertmanager · Uptime Kuma
Security          BlackArch (penetration testing lab)
Networking        Tailscale (remote access) · WireGuard · Pi-hole · Nginx Proxy Manager
Cloud Sim         LocalStack (AWS)
Storage           MinIO (S3-compatible) · Samba NAS · Nextcloud
OS                Proxmox VE · Arch Linux · BlackArch · Debian · Ubuntu · Rocky Linux
Languages         Bash · Python · Go
```
