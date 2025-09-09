#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: tizen-wgt-install <TV_IP> --wgt /path/to/app.wgt [--port 26101]

Installs a local .wgt to a Samsung TV in Developer Mode.

Examples:
  tizen-wgt-install 192.168.1.50 --wgt /work/Jellyfin.wgt
  tizen-wgt-install 192.168.1.50 --wgt /work/Jellyfin.wgt --port 26101
EOF
}

cancelled() {
  echo "Cancelled by user. No changes made." >&2
  exit 130
}
trap cancelled INT TERM

if [ "$#" -eq 0 ] || [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
  usage
  exit 0
fi

IP=""
WGT=""
PORT="26101"

# First positional is IP
IP=${1:-}
if [ -z "$IP" ]; then
  echo "Error: missing TV_IP." >&2
  echo >&2
  usage
  exit 1
fi
shift || true

while [ "$#" -gt 0 ]; do
  case "$1" in
    --wgt)
      shift || true
      WGT=${1:-}
      ;;
    --port)
      shift || true
      PORT=${1:-}
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo >&2
      usage
      exit 2
      ;;
  esac
  shift || true
done

if [ -z "$WGT" ]; then
  echo "Error: --wgt path is required." >&2
  echo "Hint: pass an absolute path inside the container, e.g. /work/App.wgt" >&2
  exit 1
fi

if [ ! -f "$WGT" ]; then
  echo "Error: .wgt file not found at: $WGT" >&2
  echo "Hint: mount your current folder: -v \"$PWD:/work\" and reference it as /work/YourApp.wgt" >&2
  exit 1
fi

echo "Starting sdb server..."
sdb start-server >/dev/null 2>&1 || true

echo "Connecting to $IP:$PORT ..."
if ! sdb connect "$IP:$PORT"; then
  echo "Error: failed to connect via sdb to $IP:$PORT" >&2
  echo "Hints: verify IP, same subnet, Developer Mode ON, correct port (26101)." >&2
  exit 1
fi

echo "Waiting for device to become 'device'..."
tries=0
until sdb devices | awk -v target="$IP:$PORT" '$1==target && $2=="device" {found=1} END{exit found?0:1}'; do
  tries=$((tries+1))
  if [ "$tries" -ge 3 ]; then
    echo "Error: target $IP:$PORT not in 'device' state after retries." >&2
    echo "Hints: ensure Developer Mode is ON, IP/port are correct (default 26101), and TV is reachable." >&2
    exit 1
  fi
  sleep 2
  sdb connect "$IP:$PORT" >/dev/null 2>&1 || true
done

echo "Listing devices..."
sdb devices || true

echo "Configuring tizen target..."
tizen target delete --name tv >/dev/null 2>&1 || true
tizen target add --name tv --host "$IP" --port "$PORT"
tizen target list || true

if ! tizen target list | awk '$1=="Name" && $3=="tv" {print; found=1} END{exit found?0:1}'; then
  echo "Error: failed to create tizen target 'tv'." >&2
  exit 1
fi

echo "Installing $(basename "$WGT") to target 'tv'..."
WGT_DIR=$(dirname "$WGT")
WGT_NAME=$(basename "$WGT")
(
  cd "$WGT_DIR"
  tizen install -n "$WGT_NAME" -t tv
)

echo "Installed. If the icon doesn’t appear, reboot the TV and check Apps → Installed."
