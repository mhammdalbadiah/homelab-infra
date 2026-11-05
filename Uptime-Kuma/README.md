# Uptime Kuma on Fedora 44 LXC (Podman + Quadlet)

![Fedora](https://img.shields.io/badge/Fedora-44-51A2DA?logo=fedora&logoColor=white)
![Podman](https://img.shields.io/badge/Podman-Quadlet-892CA0?logo=podman&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-LXC-E57000?logo=proxmox&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Nushell-3AA675)
![Uptime Kuma](https://img.shields.io/badge/Uptime%20Kuma-v2-5CDD8B?logo=uptimekuma&logoColor=white)

Self-hosted uptime monitoring for my homelab servers and services.

This guide uses **Podman instead of Docker**, **Nushell instead of Bash**, and runs on **Fedora 44**, inside an unprivileged **LXC container on Proxmox**.

| Component | Choice |
|---|---|
| Host | Proxmox VE |
| Container | Unprivileged LXC, Fedora 44 |
| Runtime | Podman (rootful) + Quadlet (systemd) |
| Shell | Nushell |
| Editor | Vim |
| Database | SQLite |
| Port | `3001` |

---

> ⚠️ **Rootless Podman does NOT work inside an unprivileged LXC container.**
>
> It fails with `newuidmap: write to uid_map failed: Operation not permitted`, because the LXC only has 65,536 UIDs and rootless Podman needs an extra range outside of it.
>
> So this guide runs Uptime Kuma as a **system service with `sudo`** (rootful Podman). The LXC container itself is the isolation layer.

---

## 1. Enable nesting on the Proxmox host

Run this on the **Proxmox host**, not inside the container:

```bash
pct set <CTID> --features nesting=1,keyctl=1
pct reboot <CTID>
```

## 2. Check that you are inside the LXC

```nu
systemd-detect-virt
# should print: lxc
```

## 3. Install Podman and Vim, then create the Quadlet folder

```nu
sudo dnf install -y podman vim; sudo mkdir -p /etc/containers/systemd
```

> `-p` works here because `sudo` runs the regular GNU `mkdir`.
> Without `sudo`, Nushell's built-in `mkdir` does not accept `-p` (it creates parent folders automatically).

## 4. Create the Quadlet file

**Option A: copy it from this folder**

```nu
git clone https://github.com/mhammdalbadiah/homelab-infra.git
cd homelab-infra/uptime-kuma
sudo cp uptime-kuma.container /etc/containers/systemd/
```

**Option B: write it with Vim (watch out !)**

```nu
sudo vim /etc/containers/systemd/uptime-kuma.container
```

1. Press `i` to start typing
2. Paste the content below (if the indentation breaks, press `Esc`, type `:set paste`, then press `i` again)
3. Press `Esc`, then type `:wq` to save and exit

```ini
[Unit]
Description=Uptime Kuma

[Container]
Image=docker.io/louislam/uptime-kuma:2
ContainerName=uptime-kuma
PublishPort=3001:3001
Volume=uptime-kuma:/app/data
AutoUpdate=registry

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

| Key | What it does |
|---|---|
| `Image` | Fully qualified image name (required for auto-updates) |
| `ContainerName` | Fixed name instead of a random one |
| `PublishPort` | Exposes the web UI on port 3001 |
| `Volume` | Named volume that stores the database and settings |
| `AutoUpdate=registry` | Allows `podman-auto-update` to pull new images |
| `Restart=always` | systemd restarts the container if it crashes |
| `WantedBy=multi-user.target` | Starts the service at boot (system service, not `default.target`) |

## 5. Check that the file saved

```nu
open --raw /etc/containers/systemd/uptime-kuma.container
```

## 6. Load and start it

```nu
sudo systemctl daemon-reload
sudo systemctl start uptime-kuma
sudo systemctl status uptime-kuma --no-pager
```

> The first start pulls the image, so give it a minute.
> You should see `active (running)` and `Waiting for user action...` in the logs.

**No linger or `systemctl enable` needed.** It's a system service, so it survives reboots and logouts, and the `[Install]` section handles starting at boot.

## 7. Open the web UI

Get the container's IP:

```nu
ip -br a
```

Use the `eth0` address (ignore `10.88.0.x`, that's Podman's internal network).

Open `http://<container-ip>:3001`, then:

1. Pick **SQLite** for the database (lightest option, perfect for a homelab)
2. Create the admin account
3. Enable 2FA: Settings -> Security

> Give the container a static IP in Proxmox (Container -> Network -> eth0) or a DHCP reservation on your router, so the address never changes.

## 8. Enable automatic updates

```nu
sudo systemctl enable --now podman-auto-update.timer
```

---

## Useful commands

```nu
# status
sudo systemctl status uptime-kuma --no-pager

# live logs
sudo journalctl -u uptime-kuma -f

# restart
sudo systemctl restart uptime-kuma

# real memory usage of the container
sudo podman stats --no-stream

# check the Quadlet file for typos
/usr/libexec/podman/quadlet -dryrun
```

## Backup

Easiest: schedule a Proxmox backup of the whole LXC (Datacenter -> Backup -> Add).

Or export just the data volume:

```nu
sudo systemctl stop uptime-kuma
sudo podman volume export uptime-kuma --output uptime-kuma-backup.tar
sudo systemctl start uptime-kuma
```

> Keep the data on local storage. Uptime Kuma does not support NFS for its data directory.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `newuidmap: write to uid_map failed` | Rootless Podman can't run in an unprivileged LXC. Use `/etc/containers/systemd/` + `sudo systemctl` |
| `$DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined` | Happens with `systemctl --user` in an LXC console. Not needed with this setup. Never mix `sudo` with `--user` |
| `Unit uptime-kuma.service not found` | Typo in the Quadlet file. Run `/usr/libexec/podman/quadlet -dryrun`, fix it, then `sudo systemctl daemon-reload` |
| Permission or mount errors on start | Nesting is off. Run the `pct set` command from step 1 on the Proxmox host |
| `The mkdir command doesn't have flag -p` | Nushell's `mkdir` creates parents by itself. Use `mkdir dir` or `^mkdir -p dir` |
| Command waits with `:::` after a trailing `\` | `\` doesn't chain commands in Nushell. Use `;` instead |
| `log file:` prompt in the status output | You pressed `s` inside the pager. Press `Esc` then `q`, or use `--no-pager` |
| Status shows ~1.7G memory | That's file cache from pulling the image. Check real usage with `sudo podman stats --no-stream` |

## Nushell vs Bash cheat sheet

| Bash | Nushell |
|---|---|
| `mkdir -p dir` | `mkdir dir` or `^mkdir -p dir` |
| `$USER` | `$env.USER` |
| `cmd1 && cmd2` | `cmd1; cmd2` |
| `cat file` | `open --raw file` |
| `$(id -u)` inside a path | `$"/run/user/(id -u \| str trim)"` |

---

## References

- [Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Podman Quadlet documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Proxmox LXC documentation](https://pve.proxmox.com/wiki/Linux_Container)
