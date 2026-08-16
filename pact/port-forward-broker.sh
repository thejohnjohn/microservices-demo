#!/usr/bin/env bash
set -euo pipefail

# Ensures a kubectl port-forward to the Pact Broker in the minikube cluster
# is listening on localhost:9292.
if ! /bin/sh -c 'echo > /dev/tcp/localhost/9292' 2>/dev/null; then
  echo "==> starting port-forward broker (cluster) -> localhost:9292"
  setsid nohup kubectl -n pact-broker port-forward svc/pact-broker 9292:80 \
    --address 127.0.0.1 > /tmp/pf-broker.log 2>&1 < /dev/null &
  disown
  for i in $(seq 1 15); do
    if /bin/sh -c 'echo > /dev/tcp/localhost/9292' 2>/dev/null; then
      break
    fi
    sleep 1
  done
fi
echo "broker: http://localhost:9292"