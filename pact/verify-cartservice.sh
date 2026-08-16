#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.pact/bin:$PATH"
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-http://localhost:9292}"

BRANCH="${BRANCH:-$(git -C "$ROOT" branch --show-current)}"
SHA="${SHA:-$(git -C "$ROOT" rev-parse --short HEAD)}"
VERSION="${VERSION:-${SHA}-${BRANCH}}"

echo "==> starting cartservice + redis"
docker compose -f "$ROOT/docker-compose.cartservice.yml" up -d
trap 'docker compose -f "$ROOT/docker-compose.cartservice.yml" down >/dev/null 2>&1' EXIT

echo "==> starting provider state server"
python3 "$ROOT/pact/state-server.py" &
STATE_PID=$!
trap 'kill $STATE_PID 2>/dev/null; docker compose -f "$ROOT/docker-compose.cartservice.yml" down >/dev/null 2>&1' EXIT
sleep 1

echo "==> waiting for cartservice on :7070"
for i in $(seq 1 30); do
  if docker exec cartservice-verify /bin/sh -c 'echo > /dev/tcp/localhost/7070' 2>/dev/null; then
    break
  fi
  sleep 1
done

echo "==> verifying against broker"
pact verifier \
  --broker-url "$PACT_BROKER_BASE_URL" \
  --provider-name cartservice \
  --transport grpc \
  --hostname localhost \
  --port 7070 \
  --state-change-url http://localhost:8090 \
  --publish \
  --provider-version "$VERSION" \
  --provider-tags "$BRANCH" \
  --consumer-version-selectors '{"mainBranch": true}' \
  --enable-pending