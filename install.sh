#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: install.sh [--local] [--stop | --keep-running | --delete]
  --local         Install or update from the local image, then open setup.
  --stop          Stop the companion and strategy; keep all local files.
  --keep-running  Leave the running companion alone and close this command.
  --delete        Remove the agent from My Agents and local containers; archive setup and wallet files.
EOF
}
local_install=false
action=setup
for argument do
  case "$argument" in
    --local) local_install=true ;;
    --stop|--keep-running|--delete)
      [ "$action" = setup ] || { usage >&2; exit 2; }
      action=$argument ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app_dir=${DOMINION_BOT_HOME:-"$HOME/dominion-bot"}
case "$app_dir" in /*) ;; *) app_dir="$PWD/$app_dir" ;; esac
release_url=${DOMINION_BOT_RELEASE_URL:-https://github.com/webisoftSoftware/dominion-agent/releases/download/v0.1.0}

command -v docker >/dev/null 2>&1 || { echo "Docker is required. Install Docker Desktop or Docker Engine first." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required." >&2; exit 1; }
manage_companion() {
  [ -f "$app_dir/compose.yml" ] || { echo "No companion installed at $app_dir." >&2; exit 1; }
  case "$action" in
    --keep-running)
      (cd "$app_dir" && docker compose ps --status running --services) | grep -qx companion || {
        echo "The companion is not running. Run the installer to start it." >&2; exit 1;
      }
      echo "Companion left running. Close this terminal whenever you like."
      ;;
    --stop)
      (cd "$app_dir" && docker compose stop companion strategy)
      echo "Companion stopped. Wallet and setup files are kept. Rerun the installer to resume."
      ;;
    --delete)
      [ ! -L "$app_dir" ] || { echo "Refusing to archive a symlinked installation." >&2; exit 1; }
      app_dir=$(CDPATH= cd -- "$app_dir" && pwd -P)
      user_home=$(CDPATH= cd -- "$HOME" && pwd -P)
      [ "$app_dir" != / ] && [ "$app_dir" != "$user_home" ] || { echo "Unsafe installation directory." >&2; exit 1; }
      # Free the wallet on the website first, so a later agent can use it.
      (cd "$app_dir" && docker compose run --rm --no-deps -T companion dominion-bot unregister) || {
        echo "Could not remove the agent from My Agents; nothing was deleted. Finish its game or delete it in My Agents, then retry." >&2
        exit 1
      }
      (cd "$app_dir" && docker compose down)
      backup_dir="$app_dir.backup-$(date +%Y%m%d-%H%M%S)-$$"
      cd /
      mv "$app_dir" "$backup_dir"
      chmod 700 "$backup_dir"
      echo "Local companion removed. Private wallet/setup backup: $backup_dir"
      ;;
  esac
}
if [ "$action" != setup ]; then
  manage_companion
  exit 0
fi
if "$local_install"; then
  image=${DOMINION_BOT_IMAGE:-dominion-bot:local}
  [ -f "$source_dir/compose.yml" ] || { echo "Local installation requires the checkout's compose.yml beside install.sh." >&2; exit 1; }
  docker image inspect "$image" >/dev/null 2>&1 || {
    echo "Local image $image is missing. Build it first; see bot-companion/README.md." >&2; exit 1;
  }
else
  command -v curl >/dev/null 2>&1 || { echo "curl is required to download the Compose file." >&2; exit 1; }
fi

mkdir -p "$app_dir/data" "$app_dir/bot"
chmod 700 "$app_dir" "$app_dir/data" "$app_dir/bot"
cd "$app_dir"

if [ ! -f compose.yml ]; then
  temp_file=$(mktemp "$app_dir/.compose.yml.XXXXXX")
  trap 'rm -f "$temp_file"' 0 HUP INT TERM
  if "$local_install"; then
    cp "$source_dir/compose.yml" "$temp_file"
  else
    curl -fsSL "$release_url/compose.yml" -o "$temp_file"
  fi
  mv "$temp_file" compose.yml
fi

if [ ! -f .env ]; then
  (umask 077 && : > .env)
fi
chmod 600 .env
if ! grep -q '^DOMINION_BOT_UID=' .env; then
  printf '\nDOMINION_BOT_UID=%s\n' "$(id -u)" >> .env
fi
if ! grep -q '^DOMINION_BOT_GID=' .env; then
  printf '\nDOMINION_BOT_GID=%s\n' "$(id -g)" >> .env
fi

# Keep saved origins on reruns; new installations connect to preprod.
keep_origin() {
  origin_key=$1
  origin_value=$2
  if [ -z "$origin_value" ]; then
    grep -q "^$origin_key=." .env && return 0
    origin_value=https://dominion-preprod.1am.xyz
  fi
  [ "$(printf '%s' "$origin_value" | tr -d '\r\n')" = "$origin_value" ] || { echo "Invalid origin." >&2; exit 1; }
  temp_file=$(mktemp "$app_dir/.env.XXXXXX")
  sed "/^$origin_key=/d" .env > "$temp_file"
  printf '\n%s=%s\n' "$origin_key" "$origin_value" >> "$temp_file"
  chmod 600 "$temp_file"
  mv "$temp_file" .env
}
keep_origin DOMINION_BOT_HOST "${DOMINION_BOT_HOST:-}"
keep_origin DOMINION_SITE_URL "${DOMINION_SITE_URL:-}"

if "$local_install"; then
  temp_file=$(mktemp "$app_dir/.env.XXXXXX")
  sed '/^DOMINION_BOT_IMAGE=/d' .env > "$temp_file"
  printf '\nDOMINION_BOT_IMAGE=%s\n' "$image" >> "$temp_file"
  chmod 600 "$temp_file"
  mv "$temp_file" .env
else
  docker compose pull companion
fi
# Upgrade the original generated Compose file, keeping a copy and all wallet/strategy data.
if "$local_install" && grep -q '"/bot/server.py"' compose.yml; then
  cp -p compose.yml compose.yml.previous
  cp "$source_dir/compose.yml" compose.yml
fi
docker compose up -d companion strategy
viewer_status=0
if [ -t 1 ] && ( : </dev/tty ) 2>/dev/null; then
  trap ':' INT
  docker compose exec companion dominion-bot setup </dev/tty || viewer_status=$?
  trap - INT
else
  docker compose exec -T companion dominion-bot setup || viewer_status=$?
fi

if [ -t 1 ] && ( : </dev/tty ) 2>/dev/null; then
  while :; do
    printf '\n[Enter] Leave running · [s] Stop agent · [d] Delete local setup: ' >/dev/tty
    if ! IFS= read -r choice </dev/tty; then choice=; fi
    case "$choice" in
      ""|k|keep) action=--keep-running; break ;;
      s|stop) action=--stop; break ;;
      d|delete) action=--delete; break ;;
      *) echo "Choose Enter, s or d." >/dev/tty ;;
    esac
  done
  manage_companion
  exit 0
fi

cat <<'EOF'

Your bot is running. Useful commands from this directory:
  docker compose exec companion dominion-bot status
  docker compose logs -f companion
  docker compose ps

Manage or watch your bot in My Agents.
EOF

printf 'Lifecycle options: --stop, --keep-running, --delete (with the same installer).\n'
exit "$viewer_status"
