#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.pact/bin:$PATH"
export PACT_BROKER_BASE_URL="${PACT_BROKER_BASE_URL:-http://localhost:9292}"

# Creates a Pact Broker webhook that triggers the provider verification
# workflow on GitHub via repository_dispatch whenever a pact for
# checkoutservice -> cartservice is published.
#
# Requires:
#   - GH_TOKEN: a GitHub PAT with `repo` scope (fine-grained: Actions write)
#   - GITHUB_REPO: owner/repo, e.g. thejohnjohn/microservices-demo
#   - EVENT_TYPE: workflow_dispatch event type (default: pact-contract-changed)
#
# Usage: GH_TOKEN=<pat> GITHUB_REPO=thejohnjohn/microservices-demo ./pact/create-webhook.sh

: "${GH_TOKEN:?set GH_TOKEN with a GitHub PAT}"
GITHUB_REPO="${GITHUB_REPO:?set GITHUB_REPO (owner/repo)}"
EVENT_TYPE="${EVENT_TYPE:-pact-contract-changed}"

echo "creating webhook: $PACT_BROKER_BASE_URL -> $GITHUB_REPO ($EVENT_TYPE)"

pact broker create-webhook \
  --broker-base-url "$PACT_BROKER_BASE_URL" \
  --consumer checkoutservice \
  --provider cartservice \
  --contract-content-changed \
  --description "Trigger cartservice provider verification (GitHub Actions)" \
  --request POST \
  "https://api.github.com/repos/${GITHUB_REPO}/dispatches" \
  -H 'Content-Type: application/json' "Authorization: Bearer ${GH_TOKEN}" \
  -d '{"event_type":"'"${EVENT_TYPE}"'","client_payload":{"pact_url":"{pactbroker.pactUrl}","consumer_version":"{pactbroker.consumerVersionNumber}"}}'

echo
echo "webhook created. Add a repository_dispatch trigger to the provider workflow:"
echo "  repository_dispatch:"
echo "    types: [${EVENT_TYPE}]"