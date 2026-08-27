#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://localhost:3000}"

check() {
  label="$1"
  url="$2"
  printf '%-24s' "$label"
  if curl --fail --silent --show-error "$url" >/dev/null; then
    printf 'OK\n'
  else
    printf 'FAILED (%s)\n' "$url"
    return 1
  fi
}

printf "Checking MJ's Cart at %s\n\n" "$BASE_URL"
check "Frontend" "$BASE_URL/health"
check "API gateway" "$BASE_URL/api/products"
check "Product catalog" "$BASE_URL/api/products/1"
check "Inventory" "$BASE_URL/api/inventory/1"

printf '\nAll local smoke checks passed.\n'
