#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Config: target chain files
# -----------------------------
CHAIN_FILES=(
  "/opt/splunk/lib/python3.7/site-packages/certifi/cacert.pem"
  "/opt/splunk/lib/python3.9/site-packages/certifi/cacert.pem"
)

# -----------------------------
# Globals
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date '+%Y%m%d_%H%M%S')"
COMMENT_PREFIX="# added-from:"

log(){ echo "[$(date '+%F %T')] $*"; }

# -----------------------------
# Fingerprint helpers
# -----------------------------
# SHA256 fingerprint for a PEM cert file (assumes 1 cert per file)
cert_fp() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 \
    | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
}

# Extract every PEM cert block from a chain file and output SHA256 fingerprints (one per line)
# This is robust against comments, blank lines, and extra non-PEM text.
chain_fps() {
  local chain="$1"

  awk '
    /-----BEGIN CERTIFICATE-----/ {in_cert=1; cert=""; }
    in_cert { cert = cert $0 "\n" }
    /-----END CERTIFICATE-----/ {
      in_cert=0;
      print cert;
    }
  ' "$chain" \
  | while IFS= read -r certpem; do
      [[ -z "${certpem//[[:space:]]/}" ]] && continue
      openssl x509 -noout -fingerprint -sha256 2>/dev/null <<<"$certpem" \
        | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
    done
}

# -----------------------------
# Discover certs in script dir
# -----------------------------
shopt -s nullglob
CERT_FILES=( "$SCRIPT_DIR"/*.pem "$SCRIPT_DIR"/*.crt )
shopt -u nullglob
((${#CERT_FILES[@]})) || { echo "No cert files found in $SCRIPT_DIR"; exit 1; }

((${#CHAIN_FILES[@]})) || { echo "No CHAIN_FILES configured"; exit 1; }

# -----------------------------
# Main
# -----------------------------
for chain in "${CHAIN_FILES[@]}"; do
  [[ -f "$chain" ]] || { echo "Missing chain: $chain"; exit 1; }
  [[ -w "$chain" ]] || { echo "Not writable: $chain (run as correct user/sudo)"; exit 1; }

  log "----"
  log "Target chain: $chain"

  # Snapshot fingerprints currently in the chain
  mapfile -t fps_in_chain < <(chain_fps "$chain" | sort -u)

  backed_up=0

  for cert in "${CERT_FILES[@]}"; do
    [[ -f "$cert" ]] || continue

    # Skip non-PEM (and avoid grep interpreting pattern as an option)
    grep -q -- "-----BEGIN CERTIFICATE-----" "$cert" || continue

    fp="$(cert_fp "$cert")"

    if printf "%s\n" "${fps_in_chain[@]}" | grep -qx -- "$fp"; then
      log "$(basename "$cert") already present in $chain"
      continue
    fi

    # Backup once per chain, only if we are going to edit
    if [[ "$backed_up" -eq 0 ]]; then
      cp -p "$chain" "${chain}.bak.${TS}"
      log "Backup created: ${chain}.bak.${TS}"
      backed_up=1
    fi

    log "Appending $(basename "$cert") to $chain"
    {
      echo
      echo "${COMMENT_PREFIX} $(basename "$cert")"
      cat "$cert"
    } >> "$chain"

    # Update in-memory list so we don't append the same cert twice in one run
    fps_in_chain+=("$fp")
  done

  [[ "$backed_up" -eq 0 ]] && log "No changes needed for $chain"
done

log "Done." 
