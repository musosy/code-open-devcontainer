#!/usr/bin/env bash
set -e

# Help if no argument
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/project"
  exit 1
fi

# Pure bash ASCII to hex function
ascii_to_hex() {
  local str="$1"
  local -i i=0
  local hex=""
  while [ $i -lt ${#str} ]; do
    printf -v hex_char '%02x' "'${str:$i:1}"
    hex+=$hex_char
    ((i++))
  done
  echo "$hex"
}

# Encoder wrapper: use xxd if available, else ascii_to_hex
if command -v xxd >/dev/null 2>&1; then
  encode() { printf "%s" "$1" | xxd -p; }
else
  encode() { ascii_to_hex "$1"; }
fi

# Start/reuse devcontainer, capture JSON output
json=$(devcontainer up --workspace-folder "${1}")

# Extract values — jq if available, else grep/sed
if command -v jq >/dev/null 2>&1; then
  short_id=$(echo "$json" | jq -r '.containerId' | tr -cd 'a-f0-9' | cut -c1-12)
  workspace_folder=$(echo "$json" | jq -r '.remoteWorkspaceFolder')
else
  short_id=$(echo "$json" \
    | grep -o '"containerId" *: *"[^"]*"' \
    | sed 's/.*"containerId" *: *"//' \
    | sed 's/".*//' \
    | tr -cd 'a-f0-9' \
    | cut -c1-12)
  workspace_folder=$(echo "$json" \
    | grep -o '"remoteWorkspaceFolder" *: *"[^"]*"' \
    | sed 's/.*"remoteWorkspaceFolder" *: *"//' \
    | sed 's/".*//')
fi

# Encode container ID
encoded_id=$(encode "$short_id")

# Build and launch VS Code URI in the same window
uri="vscode-remote://attached-container+${encoded_id}${workspace_folder}"
code --reuse-window --folder-uri "$uri"

