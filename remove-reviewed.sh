#!/usr/bin/env bash
# One explicitly reviewed package per invocation. No built-in removal list.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'Usage: %s SERIAL PACKAGE\nTargets the currently active Android user.\n' "$0" >&2
  exit 2
fi
ADB_BIN="${ADB_BIN:-adb}"
command -v "$ADB_BIN" >/dev/null || { printf 'adb not found; install Android SDK Platform-Tools.\n' >&2; exit 2; }
serial="$1"
package="$2"
[[ "$package" =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$ ]] || { printf 'Invalid package ID; nothing changed.\n' >&2; exit 2; }
state=$("$ADB_BIN" -s "$serial" get-state 2>/dev/null || true)
[[ "$state" == device ]] || { printf 'Device is not connected and authorized. Nothing changed.\n' >&2; exit 1; }
user_id=$("$ADB_BIN" -s "$serial" shell am get-current-user | tr -d '\r')
[[ "$user_id" =~ ^[0-9]+$ ]] || { printf 'Could not determine the active Android user.\n' >&2; exit 1; }

# Guardrails for obvious essentials; this is not a complete dependency model.
case "$package" in
  android|com.android.systemui|com.android.settings|com.android.shell|com.android.phone|com.android.server.telecom|com.android.providers.*|com.android.packageinstaller|com.google.android.packageinstaller|com.miui.global.packageinstaller|com.google.android.permissioncontroller|com.android.permissioncontroller|com.google.android.gms|com.google.android.gsf|com.android.vending|com.miui.core|com.miui.system|com.miui.security*|com.miui.guardprovider|com.miui.powerkeeper|com.android.updater|com.android.networkstack*|com.google.android.networkstack*|com.android.bluetooth|com.android.wifi.*)
    printf 'Refusing an essential/protected package: %s\n' "$package" >&2
    exit 1 ;;
esac
keyboard=$("$ADB_BIN" -s "$serial" shell settings --user "$user_id" get secure default_input_method | tr -d '\r')
launcher=$("$ADB_BIN" -s "$serial" shell cmd package resolve-activity --brief --user "$user_id" -a android.intent.action.MAIN -c android.intent.category.HOME | tr -d '\r' | tail -n 1)
[[ "$keyboard" == */* && "$launcher" == */* ]] || { printf 'Cannot identify the active keyboard and launcher; nothing changed.\n' >&2; exit 1; }
if [[ "$package" == "${keyboard%%/*}" || "$package" == "${launcher%%/*}" ]]; then
  printf 'Refusing the active keyboard or launcher: %s\n' "$package" >&2
  exit 1
fi

project_dir=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$project_dir/runs"
run_dir=$(mktemp -d "$project_dir/runs/remove.XXXXXX")
inventory() {
  "$ADB_BIN" -s "$serial" shell pm list packages --user "$user_id" | tr -d '\r' | LC_ALL=C sort > "$1"
  if ! grep -Eq '^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' "$1" ||
     grep -Evq '^package:[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' "$1"; then
    printf 'Package inventory is empty or invalid; verification failed. Records: %s\n' "$run_dir" >&2
    exit 1
  fi
}
inventory "$run_dir/before.txt"
grep -Fxq "package:$package" "$run_dir/before.txt" || { printf 'Package is not installed for user %s; nothing changed.\n' "$user_id"; exit 0; }
model=$("$ADB_BIN" -s "$serial" shell getprop ro.product.model | tr -d '\r')
printf 'Device model: %s\nADB target: %s\nAndroid user: %s\nRemove: %s\n' "$model" "$serial" "$user_id" "$package"
printf 'This removes the app for this user with -k (requesting retained data).\nReview dependencies and feature loss before continuing.\nType REMOVE to proceed: '
answer=''
read -r answer || true
[[ "$answer" == REMOVE ]] || { printf 'Cancelled; nothing changed.\n'; exit 0; }

current_user=$("$ADB_BIN" -s "$serial" shell am get-current-user | tr -d '\r')
[[ "$current_user" == "$user_id" ]] || { printf 'Active user changed; nothing removed.\n' >&2; exit 1; }
result_code=0
"$ADB_BIN" -s "$serial" shell pm uninstall -k --user "$user_id" "$package" > "$run_dir/uninstall.txt" 2>&1 || result_code=$?
cat "$run_dir/uninstall.txt"
inventory "$run_dir/after.txt"
diff_code=0
diff -u "$run_dir/before.txt" "$run_dir/after.txt" > "$run_dir/changes.diff" || diff_code=$?
[[ "$diff_code" -le 1 ]] || { printf 'Could not compare inventories. Records: %s\n' "$run_dir" >&2; exit 1; }
if grep -Fxq "package:$package" "$run_dir/after.txt"; then
  printf 'NOT VERIFIED: package remains installed. Command exit: %s. Records: %s\n' "$result_code" "$run_dir" >&2
  exit 1
fi

# Absence alone does not authorize unrelated changes.
comm -23 "$run_dir/before.txt" "$run_dir/after.txt" > "$run_dir/removed.txt"
comm -13 "$run_dir/before.txt" "$run_dir/after.txt" > "$run_dir/added.txt"
printf 'package:%s\n' "$package" > "$run_dir/expected-removed.txt"
if ! cmp -s "$run_dir/removed.txt" "$run_dir/expected-removed.txt" || [[ -s "$run_dir/added.txt" ]]; then
  printf 'Target is absent, but other package changes occurred. Review %s before continuing.\n' "$run_dir" >&2
  exit 1
fi
if [[ "$result_code" -ne 0 ]] || ! tr -d '\r' < "$run_dir/uninstall.txt" | grep -Fxq Success; then
  printf 'Target is absent, but uninstall reported an error or unexpected output. Review %s.\n' "$run_dir" >&2
  exit 1
fi
printf 'VERIFIED: only %s disappeared from user %s inventory.\nRecords: %s\nCheck normal phone functions and visible behaviour separately.\n' "$package" "$user_id" "$run_dir"
