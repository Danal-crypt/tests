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

# Get SHA256 fingerprint from a PEM cert file (single cert)
cert_fp() {
  openssl x509 -in "$1" -noout -fingerprint -sha256 \
    | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
}

# Extract all certs from a chain and output their SHA256 fingerprints (one per line)
chain_fps() {
  local chain="$1"
  awk '
    /-----BEGIN CERTIFICATE-----/ {p=1}
    p {print}
    /-----END CERTIFICATE-----/   {p=0; print ""}  # blank line between certs
  ' "$chain" \
  | awk 'NF{print} !NF{print "---CERT---"}' \
  | awk '
      $0=="---CERT---" {
        # end of a cert block, print it
        if (cert!="") { print cert; cert="" }
        next
      }
      { cert = cert $0 "\n" }
      END { if (cert!="") print cert }
    ' \
  | while IFS= read -r certpem; do
      [[ -z "${certpem//[[:space:]]/}" ]] && continue
      openssl x509 -noout -fingerprint -sha256 2>/dev/null <<<"$certpem" \
        | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
    done
}

shopt -s nullglob
CERT_FILES=( "$SCRIPT_DIR"/*.pem "$SCRIPT_DIR"/*.crt )
shopt -u nullglob
((${#CERT_FILES[@]})) || { echo "No cert files found in $SCRIPT_DIR"; exit 1; }

for chain in "${CHAIN_FILES[@]}"; do
  [[ -f "$chain" ]] || { echo "Missing chain: $chain"; exit 1; }
  [[ -w "$chain" ]] || { echo "Not writable: $chain"; exit 1; }

  log "----"
  log "Target chain: $chain"

  mapfile -t fps_before < <(chain_fps "$chain" | sort -u)

  backed_up=0
  for cert in "${CERT_FILES[@]}"; do
    # Skip non-PEM certs (quick check)
    grep -q "-----BEGIN CERTIFICATE-----" "$cert" || continue

    fp="$(cert_fp "$cert")"

    if printf "%s\n" "${fps_before[@]}" | grep -qx "$fp"; then
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
      cat "$cert"
    } >> "$chain"

    # update in-memory list so we don't append twice in same run
    fps_before+=("$fp")
  done

  [[ "$backed_up" -eq 0 ]] && log "No changes needed for $chain"
done

log "Done."
