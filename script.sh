#!/usr/bin/env bash
set -euo pipefail

CHAIN_FILES=(
  "/opt/splunk/lib/python3.7/site-packages/certifi/cacert.pem"
  "/opt/splunk/lib/python3.9/site-packages/certifi/cacert.pem"
)

TS="$(date '+%Y%m%d_%H%M%S')"
COMMENT_PREFIX="# added-from:"

normalize_pem_stream() {
  sed -e 's/\r$//' -e 's/^[[:space:]]\+//'
}

fp_from_pem_stdin() {
  normalize_pem_stream \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
    | sed -E 's/^.*=//; s/://g' | tr 'A-F' 'a-f'
}

dedupe_added_only_one_chain() {
  local chain="$1"
  local tmp
  tmp="$(mktemp)"

  cp -p "$chain" "${chain}.bak.${TS}"

  awk -v prefix="$COMMENT_PREFIX" '
    BEGIN {
      in_cert=0
      pending_comment=""
      in_added=0
      cert=""
      print_mode=1
    }

    $0 ~ ("^" prefix) {
      pending_comment=$0
      in_added=1
      next
    }

    /-----BEGIN CERTIFICATE-----/ {
      in_cert=1
      cert=$0 "\n"
      next
    }

    in_cert==1 {
      cert=cert $0 "\n"
      if ($0 ~ /-----END CERTIFICATE-----/) {
        in_cert=0

        if (in_added==1) {
          print pending_comment
          print cert
          print "__ADDED_CERT_END__"
        } else {
          printf "%s", cert
          printf "\n"
        }

        pending_comment=""
        in_added=0
        cert=""
      }
      next
    }

    {
      if (in_added==0) {
        print $0
      }
      next
    }
  ' "$chain" \
  | {
      declare -A seen_added
      out_vendor=""
      buf_comment=""
      buf_cert=""
      in_added_stream=0

      while IFS= read -r line; do
        if [[ "$line" == "__ADDED_CERT_END__" ]]; then
          fp="$(printf "%s" "$buf_cert" | fp_from_pem_stdin || true)"
          if [[ -n "$fp" ]]; then
            if [[ -z "${seen_added[$fp]+x}" ]]; then
              seen_added[$fp]=1
              [[ -n "$buf_comment" ]] && printf "%s\n" "$buf_comment"
              printf "%s" "$buf_cert"
              printf "\n"
            fi
          fi
          buf_comment=""
          buf_cert=""
          in_added_stream=0
          continue
        fi

        if [[ "$line" == "${COMMENT_PREFIX}"* ]]; then
          buf_comment="$line"
          in_added_stream=1
          continue
        fi

        if [[ "$in_added_stream" -eq 1 ]]; then
          buf_cert+="$line"$'\n'
          continue
        fi

        printf "%s\n" "$line"
      done
    } > "$tmp"

  cp -p "$tmp" "$chain"
  rm -f "$tmp"
}

for chain in "${CHAIN_FILES[@]}"; do
  [[ -f "$chain" ]] || { echo "Missing chain: $chain"; exit 1; }
  [[ -w "$chain" ]] || { echo "Not writable: $chain"; exit 1; }

  echo "Deduping added certs only: $chain"
  dedupe_added_only_one_chain "$chain"
done

echo "Done." 
