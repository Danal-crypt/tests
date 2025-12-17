#!/usr/bin/env bash
set -euo pipefail

CHAIN_FILES=(
  "/opt/splunk/lib/python3.7/site-packages/certifi/cacert.pem"
  "/opt/splunk/lib/python3.9/site-packages/certifi/cacert.pem"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date '+%Y%m%d_%H%M%S')"
COMMENT_PREFIX="# added-from:"

log(){ echo "[$(date '+%F %T')] $*"; }

normalize_pem_stream() {
  sed -e 's/\r$//' -e 's/^[[:space:]]\+//'
}

cert_fp() {
  normalize_pem_stream < "$1" \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
    | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
}

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
      printf "%s" "$certpem" \
        | normalize_pem_stream \
        | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
        | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
    done
}

shopt -s nullglob
CERT_FILES=( "$SCRIPT_DIR"/*.pem "$SCRIPT_DIR"/*.crt )
shopt -u nullglob

((${#CERT_FILES[@]})) || { echo "No cert files found in $SCRIPT_DIR"; exit 1; }
((${#CHAIN_FILES[@]})) || { echo "No CHAIN_FILES configured"; exit 1; }

for chain in "${CHAIN_FILES[@]}"; do
  [[ -f "$chain" ]] || { echo "Missing chain: $chain"; exit 1; }
  [[ -w "$chain" ]] || { echo "Not writable: $chain"; exit 1; }

  log "----"
  log "Target chain: $chain"

  mapfile -t fps_in_chain < <(chain_fps "$chain" | sed '/^$/d' | sort -u)

  backed_up=0

  for cert in "${CERT_FILES[@]}"; do
    [[ -f "$cert" ]] || continue
    grep -q -- "-----BEGIN CERTIFICATE-----" "$cert" || continue

    fp="$(cert_fp "$cert")"
    if [[ -z "${fp:-}" ]]; then
      log "WARN: Could not fingerprint $(basename "$cert")"
      continue
    fi

    if printf "%s\n" "${fps_in_chain[@]}" | grep -qx -- "$fp"; then
      log "$(basename "$cert") already present in $chain"
      continue
    fi

    if [[ "$backed_up" -eq 0 ]]; then
      cp -p "$chain" "${chain}.bak.${TS}"
      log "Backup created: ${chain}.bak.${TS}"
      backed_up=1
    fi

    log "Appending $(basename "$cert") to $chain"
    {
      echo
      echo "${COMMENT_PREFIX} $(basename "$cert")"
      normalize_pem_stream < "$cert"
    } >> "$chain"

    fps_in_chain+=("$fp")
  done

  [[ "$backed_up" -eq 0 ]] && log "No changes needed for $chain"
done

log "Done." 
