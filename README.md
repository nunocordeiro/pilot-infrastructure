# pilot-infrastructure

GitOps repository for **Pilot** — HAOS node running on a mini PC at **192.168.42.95**.

Pilot is the Caddy reverse proxy and Home Assistant host for the Cordeiro home lab.
Critical HAOS state (automations, Uptime Kuma monitors, AdGuard rules) is covered by
**HAOS snapshots** — this repo only tracks infrastructure configs that are hard to
reconstruct and change often enough to warrant version control.

---

## What's Here

| Path | What it is |
|------|------------|
| `caddy/Caddyfile` | Caddy 2 reverse proxy config — all `*.cordeiro.pt` routing |
| `scripts/deploy-caddy.sh` | Pushes Caddyfile to Pilot and restarts the Caddy add-on |

---

## Installed Add-ons

| Add-on | Slug | Version | Purpose |
|--------|------|---------|---------|
| Advanced SSH & Web Terminal | `a0d7b954_ssh` | 23.0.9 | SSH access from Fort |
| Caddy 2 | `c80c7555_caddy-2` | 3.1.0 | Reverse proxy for all `*.cordeiro.pt` |
| Cloudflared | `396f0234_cloudflared` | 7.0.6 | External access to `ha.cordeiro.pt` (no open ports) |
| Tailscale | `a0d7b954_tailscale` | 0.28.1 | Mesh VPN; advertises local subnet routes |
| Uptime Kuma | `a0d7b954_uptime-kuma` | 0.17.2 | Uptime monitoring (`up.f.cordeiro.pt`) |
| AdGuard Home | `a0d7b954_adguard` | 6.1.3 | DNS ad blocker (secondary to Fort's) |
| Mosquitto broker | `core_mosquitto` | 6.5.2 | MQTT broker for HA automations |

---

## Add-on Options (non-secret)

### Cloudflared
```json
{
  "external_hostname": "ha.cordeiro.pt",
  "additional_hosts": []
}
```
> The tunnel credentials are stored internally by HAOS. On recovery, re-authenticate
> via the add-on UI — it will generate a new tunnel linked to the same hostname.

### Tailscale
```json
{
  "accept_dns": true,
  "accept_routes": true,
  "advertise_exit_node": true,
  "advertise_routes": ["local_subnets"],
  "login_server": "https://controlplane.tailscale.com",
  "snat_subnet_routes": true,
  "taildrop": true,
  "userspace_networking": false
}
```
> Re-authenticate via the add-on UI after recovery. The Tailscale node will appear
> in the Tailscale admin console as a new device; remove the old one.

### Mosquitto
Default config — no custom logins, no client certificates required.

### AdGuard Home
SSL enabled (`fullchain.pem` / `privkey.pem` — managed by HAOS).

---

## Network

- **Primary NIC:** USB ethernet (`enp0s20u1u4`, r8152 Realtek dongle) — known to be flaky, has caused reboots
- **WiFi fallback:** `wlp3s0`, SSID `Cordeiros Nest`, metric 200 (lower priority than ethernet at 100)
- **Tailscale IP:** assigned dynamically (check Tailscale admin console)

> The USB ethernet adapter has caused kernel reboots due to `Tx status -71` (EPROTO) errors.
> If Pilot becomes unreachable and ethernet is suspected, it will auto-recover via WiFi.

---

## Deploying a Caddyfile Change

From HolyClaude on Fort:

```bash
# Edit the Caddyfile
vim /path/to/pilot-infrastructure/caddy/Caddyfile

# Commit
git add caddy/Caddyfile && git commit -m "caddy: describe change" && git push

# Deploy to Pilot
./scripts/deploy-caddy.sh
```

Or manually:
```bash
SSH_KEY=~/.claude/ssh/haos_id
PILOT=nunocordeiro@192.168.42.95

scp -i $SSH_KEY Caddyfile $PILOT:/addon_configs/c80c7555_caddy-2/Caddyfile
ssh -i $SSH_KEY -o StrictHostKeyChecking=no $PILOT "
  TOKEN=\$(cat /run/s6/container_environment/SUPERVISOR_TOKEN)
  curl -s -X POST -H 'Authorization: Bearer \$TOKEN' http://supervisor/addons/c80c7555_caddy-2/restart
"
```

---

## Recovery Runbook

### Prerequisites
- HAOS image: https://www.home-assistant.io/installation/
- Latest HAOS snapshot (take one before any risky changes)
- Access to this repo

### Step 1 — Reinstall HAOS

Flash the HAOS image to the Pilot hardware. On first boot, restore from the most
recent snapshot via the HA onboarding UI. This restores:
- Home Assistant core config (automations, entities, dashboards)
- Most add-on data (Uptime Kuma monitors, AdGuard rules, etc.)

### Step 2 — Re-install add-ons not in snapshot

If the snapshot doesn't restore all add-ons, reinstall from the table above via
**Settings → Add-ons → Add-on Store**. Apply the options from this README.

### Step 3 — Re-authenticate tunnels

- **Cloudflared:** Open add-on UI → re-authenticate → tunnel reconnects to `ha.cordeiro.pt`
- **Tailscale:** Open add-on UI → re-authenticate → re-advertise subnet routes

### Step 4 — Restore Caddyfile

```bash
# From HolyClaude on Fort (once SSH is accessible):
./scripts/deploy-caddy.sh
```

### Step 5 — Restore WiFi fallback

If the network config wasn't preserved by the snapshot, re-apply the WiFi fallback:

```bash
# SSH into Pilot, then:
TOKEN=$(cat /run/s6/container_environment/SUPERVISOR_TOKEN)
curl -X POST "http://supervisor/network/interface/wlp3s0/update" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ipv4": {"method": "auto"},
    "wifi": {"ssid": "Cordeiros Nest", "auth": {"psk": "wificordeiros", "method": "wpa-psk"}},
    "enabled": true
  }'
```

Then set the route priorities so ethernet (metric 100) takes priority over WiFi (metric 200):
```bash
curl -X POST "http://supervisor/network/interface/enp0s20u1u4/update" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ipv4": {"method": "auto"}, "enabled": true}'
```

### Step 6 — Verify

- `ha.cordeiro.pt` → Home Assistant (Cloudflared tunnel)
- `home.f.cordeiro.pt` → Homepage (Caddy → Fort)
- `up.f.cordeiro.pt` → Uptime Kuma (Caddy → localhost:3001)
- `claude.f.cordeiro.pt` → HolyClaude (Caddy → Fort:3059)

---

## Snapshots

HAOS snapshots are the primary recovery mechanism for everything NOT in this repo.
Take a snapshot before any significant change:

**Settings → System → Backups → Create Backup**

Store externally (e.g. Synology NAS via the Samba share or Kopia backup).

---

*Last updated: 2026-05-11*
