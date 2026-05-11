#!/bin/bash
# Deploy Caddy config from this repo to Pilot and restart the add-on.
# Run from HolyClaude on Fort (has the SSH key at ~/.claude/ssh/haos_id).
#
# Usage: ./scripts/deploy-caddy.sh [path/to/repo]

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CADDYFILE="$REPO_DIR/caddy/Caddyfile"
PILOT="nunocordeiro@192.168.42.95"
SSH_KEY="$HOME/.claude/ssh/haos_id"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"
REMOTE_PATH="/addon_configs/c80c7555_caddy-2/Caddyfile"

echo "Deploying Caddyfile to Pilot..."
scp $SSH_OPTS "$CADDYFILE" "$PILOT:$REMOTE_PATH"

echo "Restarting Caddy add-on..."
ssh $SSH_OPTS "$PILOT" "
  TOKEN=\$(cat /run/s6/container_environment/SUPERVISOR_TOKEN)
  curl -s -X POST -H \"Authorization: Bearer \$TOKEN\" http://supervisor/addons/c80c7555_caddy-2/restart
"

echo "Done."
