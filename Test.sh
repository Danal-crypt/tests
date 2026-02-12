#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
DEPLOYMENT_APPS_DIR="$SPLUNK_HOME/etc/deployment-apps"
SERVERCLASS_CONF="$SPLUNK_HOME/etc/system/local/serverclass.conf"

# If you also want to consider serverclass.conf in apps (common), enable this:
INCLUDE_APP_LEVEL_SERVERCLASS_CONFS="${INCLUDE_APP_LEVEL_SERVERCLASS_CONFS:-true}"

# Optional: ignore apps by name (regex)
IGNORE_APP_REGEX="${IGNORE_APP_REGEX:-^$}"  # default: ignore nothing

# ---- Helpers ----
err() { echo "ERROR: $*" >&2; }
info() { echo "INFO:  $*" >&2; }

need_file() {
  [[ -f "$1" ]] || { err "Missing file: $1"; exit 1; }
}

need_dir() {
  [[ -d "$1" ]] || { err "Missing dir: $1"; exit 1; }
}

# ---- Validate ----
need_dir "$DEPLOYMENT_APPS_DIR"

if [[ ! -f "$SERVERCLASS_CONF" ]]; then
  info "No $SERVERCLASS_CONF found. (That can be valid.)"
fi

# ---- Collect all serverclass.conf locations to scan ----
declare -a SERVERCLASS_CONFS=()
[[ -f "$SERVERCLASS_CONF" ]] && SERVERCLASS_CONFS+=("$SERVERCLASS_CONF")

if [[ "$INCLUDE_APP_LEVEL_SERVERCLASS_CONFS" == "true" ]]; then
  # Common places deployment server admins put additional serverclass.conf stanzas:
  # $SPLUNK_HOME/etc/apps/*/local/serverclass.conf
  # $SPLUNK_HOME/etc/apps/*/default/serverclass.conf
  while IFS= read -r -d '' f; do SERVERCLASS_CONFS+=("$f"); done < <(
    find "$SPLUNK_HOME/etc/apps" -type f -name serverclass.conf -print0 2>/dev/null || true
  )
fi

if [[ ${#SERVERCLASS_CONFS[@]} -eq 0 ]]; then
  info "No serverclass.conf files found to scan."
fi

# ---- Parse referenced deployment apps from serverclass.conf ----
# We look for:
#   [serverClass:<name>:app:<appname>]
#   or other patterns containing ":app:" inside stanza headers
# This is robust across typical DS configs.
declare -A REFERENCED_APPS=()

for conf in "${SERVERCLASS_CONFS[@]}"; do
  # Extract stanza headers, then pull out the app name after ":app:"
  # Examples:
  #   [serverClass:prod_web:app:MyApp]
  #   [serverClass:all:app:TA-nix]
  while IFS= read -r header; do
    # Remove brackets
    header="${header#[}"
    header="${header%]}"
    # Only headers with ":app:" segments
    if [[ "$header" == *":app:"* ]]; then
      app="${header##*:app:}"
      # Trim anything after another ":" if present (rare, but safe)
      app="${app%%:*}"
      # Basic cleanup
      app="$(echo "$app" | sed 's/[[:space:]]*$//')"
      if [[ -n "$app" ]]; then
        REFERENCED_APPS["$app"]=1
      fi
    fi
  done < <(grep -E '^\s*\[.*\]\s*$' "$conf" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
done

# ---- List deployment-apps on disk ----
declare -A DISK_APPS=()
while IFS= read -r -d '' d; do
  app="$(basename "$d")"
  if [[ "$app" =~ $IGNORE_APP_REGEX ]]; then
    continue
  fi
  DISK_APPS["$app"]=1
done < <(find "$DEPLOYMENT_APPS_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

# ---- Compute sets ----
# Orphans: on disk but not referenced
declare -a ORPHAN_APPS=()
for app in "${!DISK_APPS[@]}"; do
  if [[ -z "${REFERENCED_APPS[$app]+x}" ]]; then
    ORPHAN_APPS+=("$app")
  fi
done

# Missing: referenced in config but not on disk
declare -a MISSING_APPS=()
for app in "${!REFERENCED_APPS[@]}"; do
  if [[ -z "${DISK_APPS[$app]+x}" ]]; then
    MISSING_APPS+=("$app")
  fi
done

# ---- Output ----
echo "=== Deployment-apps directory ==="
echo "$DEPLOYMENT_APPS_DIR"
echo

echo "=== serverclass.conf files scanned ==="
if [[ ${#SERVERCLASS_CONFS[@]} -eq 0 ]]; then
  echo "(none)"
else
  printf '%s\n' "${SERVERCLASS_CONFS[@]}" | sort
fi
echo

echo "=== Referenced apps (from serverclass stanzas) ==="
if [[ ${#REFERENCED_APPS[@]} -eq 0 ]]; then
  echo "(none found)"
else
  printf '%s\n' "${!REFERENCED_APPS[@]}" | sort
fi
echo

echo "=== Orphan deployment-apps (on disk, NOT referenced) ==="
if [[ ${#ORPHAN_APPS[@]} -eq 0 ]]; then
  echo "(none)"
else
  printf '%s\n' "${ORPHAN_APPS[@]}" | sort
fi
echo

echo "=== Missing deployment-apps (referenced, NOT on disk) ==="
if [[ ${#MISSING_APPS[@]} -eq 0 ]]; then
  echo "(none)"
else
  printf '%s\n' "${MISSING_APPS[@]}" | sort
fi
echo

# ---- Optional: generate delete commands for orphans ----
# Uncomment to print rm commands (still doesn't execute)
echo "=== Suggested delete commands for orphan apps (REVIEW BEFORE RUNNING) ==="
if [[ ${#ORPHAN_APPS[@]} -eq 0 ]]; then
  echo "(none)"
else
  for app in "$(printf '%s\n' "${ORPHAN_APPS[@]}" | sort)"; do
    # shellcheck disable=SC2086
    echo "rm -rf -- \"$DEPLOYMENT_APPS_DIR/$app\""
  done
fi
