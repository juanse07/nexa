#!/bin/bash
set -euo pipefail

# Helper script to run Flutter on a mobile device with all .env.local values
# forwarded as --dart-define flags.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -f ".env.local" ]]; then
  echo "⚠️  .env.local not found at $REPO_ROOT/.env.local"
  echo "Create the file first (you can copy from .env.defaults)."
  exit 1
fi

FLUTTER_CMD="${FLUTTER_CMD:-flutter}"

DEVICE_ID=""
declare -a FLUTTER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      if [[ $# -lt 2 ]]; then
        echo "Error: -d/--device requires a device id."
        exit 1
      fi
      DEVICE_ID="$2"
      shift 2
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift 1
      ;;
  esac
done

declare -a DART_DEFINES=()

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="${raw_line#"${raw_line%%[![:space:]]*}"}"  # ltrim
  if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
    continue
  fi
  if [[ "$line" != *"="* ]]; then
    echo "Skipping malformed line in .env.local: $raw_line"
    continue
  fi
  key="${line%%=*}"
  value="${line#*=}"

  key="$(echo -n "$key" | tr -d '[:space:]')"

  # Do not trim spaces inside the value, but strip trailing newline characters.
  value="${value%$'\r'}"

  export "$key=$value"
  DART_DEFINES+=("--dart-define=${key}=${value}")
done < ".env.local"

cmd=("$FLUTTER_CMD" "run")
if [[ -n "$DEVICE_ID" ]]; then
  cmd+=("-d" "$DEVICE_ID")
fi
if ((${#DART_DEFINES[@]})); then
  cmd+=("${DART_DEFINES[@]}")
fi
if ((${#FLUTTER_ARGS[@]})); then
  cmd+=("${FLUTTER_ARGS[@]}")
fi

exec "${cmd[@]}"
