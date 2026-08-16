#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.pact/bin:$PATH"
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-http://localhost:9292}"

BRANCH="${BRANCH:-$(git -C "$ROOT" branch --show-current)}"
SHA="${SHA:-$(git -C "$ROOT" rev-parse --short HEAD)}"
VERSION="${VERSION:-${SHA}-${BRANCH}}"

"$ROOT/pact/port-forward-broker.sh"

echo "==> ensuring cartservice (minikube) on :7070 and pact-state on :8080"
if ! /bin/sh -c 'echo > /dev/tcp/localhost/7070' 2>/dev/null; then
  setsid nohup kubectl port-forward svc/cartservice 7070:7070 --address 127.0.0.1 > /tmp/pf-cartservice.log 2>&1 < /dev/null &
  disown
fi
if ! /bin/sh -c 'echo > /dev/tcp/localhost/8080' 2>/dev/null; then
  setsid nohup kubectl port-forward svc/cartservice 8080:8080 --address 127.0.0.1 > /tmp/pf-pactstate.log 2>&1 < /dev/null &
  disown
fi

echo "==> waiting for cartservice on :7070"
for i in $(seq 1 30); do
  if /bin/sh -c 'echo > /dev/tcp/localhost/7070' 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "==> verifying against broker (provider state via cartservice /pact-state)"
pact verifier \
  --broker-url "$PACT_BROKER_BASE_URL" \
  --provider-name cartservice \
  --transport grpc \
  --hostname localhost \
  --port 7070 \
  --state-change-url http://localhost:8080/pact-state \
  --publish \
  --provider-version "$VERSION" \
  --provider-tags "$BRANCH" \
  --consumer-version-selectors '{"mainBranch": true}' \
  --enable-pending