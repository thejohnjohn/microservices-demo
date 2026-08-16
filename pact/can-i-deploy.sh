#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.pact/bin:$PATH"
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-http://localhost:9292}"

BRANCH="${BRANCH:-$(git -C "$ROOT" branch --show-current)}"
SHA="${SHA:-$(git -C "$ROOT" rev-parse --short HEAD)}"
VERSION="${VERSION:-${SHA}-${BRANCH}}"

"$ROOT/pact/port-forward-broker.sh"

echo "==> can-i-deploy checkoutservice ($VERSION)"
pact broker can-i-deploy \
  --broker-base-url "$PACT_BROKER_BASE_URL" \
  --pacticipant checkoutservice \
  --version "$VERSION" \
  --to-environment test