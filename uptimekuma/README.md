# Uptime Kuma — Pilot

Monitor config backup for the Uptime Kuma instance on Pilot (HAOS add-on, `https://up.f.cordeiro.pt`).

## Files

- `monitors.json` — exported monitor and notification config (import via Settings → Backup → Import)

## Exporting

1. Open Uptime Kuma at https://up.f.cordeiro.pt
2. Settings → Backup → Export
3. Save the JSON as `monitors.json` in this directory
4. Commit and push

## Importing (recovery)

After restoring from a HAOS snapshot, Uptime Kuma data is already restored — skip this.

If recovering from scratch without a snapshot:
1. Reinstall the Uptime Kuma add-on via HAOS Settings → Add-ons
2. Open the add-on web UI
3. Settings → Backup → Import → select `monitors.json`
4. Re-enter redacted values:
   - Notification → Telegram bot token (`telegramBotToken`)

## Keeping in sync

When monitor configs change, export from the UI (Settings → Backup → Export)
and commit the updated `monitors.json`.
