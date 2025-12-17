#!/usr/bin/env bash
set -euo pipefail

# Targets to maintain
CHAIN_FILES=(
  # "/opt/splunk/etc/apps/Splunk_TA_microsoft-cloudservices/bin/cacert.pem"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date '+%Y%m%d_%H%M%S')"
COMMENT_PREFIX="# added-from:"

log(){ echo "[$(date '+%F %T')] $*"; }

# Expand cert files in this directory (adjust globs if you want)
shopt -s nullglob
CERT_FILES=( "$SCRIPT_DIR"/*.pem "$SCRIPT_DIR"/*.crt )
shopt -u nullglob

((${#CHAIN_FILES[@]})) || { echo "No CHAIN_FILES set"; exit 1; }
((${#CERT_FILES[@]}))  || { echo "No cert files found in $SCRIPT_DIR"; exit 1; }

for chain in "${CHAIN_FILES[@]}"; do
  [[ -f "$chain" ]] || { echo "Missing chain: $chain"; exit 1; }
  [[ -w "$chain" ]] || { echo "Not writable: $chain"; exit 1; }

  # Only create backup if we actually change something
  backed_up=0

  for cert in "${CERT_FILES[@]}"; do
    # Skip script itself if it matches glob somehow
    [[ "$cert" == "${BASH_SOURCE[0]}" ]] && continue

    # Pull the first PEM block (assumes one cert per file)
    pem_block="$(awk '
      /-----BEGIN CERTIFICATE-----/ {in=1}
      in {print}
      /-----END CERTIFICATE-----/ {exit}
    ' "$cert")"

    # If no PEM block, ignore file
    [[ -n "${pem_block//[[:space:]]/}" ]] || continue

    # Check if exact block already exists
    if grep -Fqx -- "$pem_block" "$chain"; then
      log "$(basename "$cert") already present in $chain"
      continue
    fi

    # Backup once per chain before first edit
    if [[ "$backed_up" -eq 0 ]]; then
      cp -p "$chain" "${chain}.bak.${TS}"
      log "Backup created: ${chain}.bak.${TS}"
      backed_up=1
    fi

    log "Appending $(basename "$cert") to $chain"
    {
      echo
      echo "${COMMENT_PREFIX} $(basename "$cert")"
      echo "$pem_block"
    } >> "$chain"
  done

  [[ "$backed_up" -eq 0 ]] && log "No changes needed for $chain"
done

log "Done."
