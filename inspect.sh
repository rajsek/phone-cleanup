#!/usr/bin/env bash
# Read-only inspection. Device inventories stay in ignored, local run folders.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s SERIAL [USER_ID]\n' "$0" >&2
  exit 2
fi

ADB_BIN="${ADB_BIN:-adb}"
command -v "$ADB_BIN" >/dev/null || { printf 'adb not found; install Android SDK Platform-Tools.\n' >&2; exit 2; }
serial="$1"
state=$("$ADB_BIN" -s "$serial" get-state 2>/dev/null || true)
[[ "$state" == device ]] || { printf 'Device is not connected and authorized; inspect adb devices -l.\n' >&2; exit 1; }
user_id="${2:-$("$ADB_BIN" -s "$serial" shell am get-current-user | tr -d '\r')}"
[[ "$user_id" =~ ^[0-9]+$ ]] || { printf 'Could not determine a numeric Android user ID.\n' >&2; exit 2; }

project_dir=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$project_dir/runs"
run_dir=$(mktemp -d "$project_dir/runs/inspect.XXXXXX")
printf 'Read-only inspection; Android user: %s\n' "$user_id"
for property in ro.product.model ro.build.version.release ro.miui.ui.version.name ro.build.version.security_patch; do
  value=$("$ADB_BIN" -s "$serial" shell getprop "$property" | tr -d '\r')
  printf '%s=%s\n' "$property" "$value"
done | tee "$run_dir/device.txt"
printf 'android_user=%s\n' "$user_id" >> "$run_dir/device.txt"

"$ADB_BIN" -s "$serial" shell pm list packages --user "$user_id" | tr -d '\r' | LC_ALL=C sort > "$run_dir/packages.txt"
if ! grep -Eq '^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' "$run_dir/packages.txt" ||
   grep -Evq '^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' "$run_dir/packages.txt"; then
  printf 'Package inventory is empty or invalid; do not proceed. Check the selected user and connection.\n' >&2
  exit 1
fi
printf 'Installed packages: %s\n' "$(wc -l < "$run_dir/packages.txt" | tr -d ' ')"
printf 'Inspection saved locally: %s\nNo packages changed. Review the inventory before selecting a removal.\n' "$run_dir"
