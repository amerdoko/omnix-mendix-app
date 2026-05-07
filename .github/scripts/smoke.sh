#!/usr/bin/env bash
# smoke.sh - hit the LB IP directly and assert release.json appVersion matches expected
# Usage: smoke.sh <RG> <AKS> <NS> <RELEASE> <EXPECTED_VERSION>
set -euo pipefail
RG="$1"; AKS="$2"; NS="$3"; RELEASE="$4"; EXPECTED="$5"

echo "Smoke test ${RELEASE} in ${AKS} → expecting appVersion=${EXPECTED}"

# Wait up to 5 min for LB to provision a public IP, then return only the IP
LB=""
for i in $(seq 1 30); do
  RAW=$(az aks command invoke -g "${RG}" -n "${AKS}" \
    --command "kubectl -n ${NS} get svc ${RELEASE}-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'" \
    --query logs -o tsv 2>/dev/null || true)
  # Strip ANSI, whitespace, any chars that aren't digits or dots; keep first IP-shaped token
  CANDIDATE=$(echo "$RAW" | tr -d '\r' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
  if [[ -n "$CANDIDATE" ]]; then
    LB="$CANDIDATE"
    echo "LB IP = ${LB}"
    break
  fi
  echo "[$i] no LB IP yet — sleeping 10s"
  sleep 10
done

if [[ -z "${LB:-}" ]]; then
  echo "✗ Could not discover LB IP for ${RELEASE}"
  exit 1
fi

for i in $(seq 1 30); do
  ACTUAL=$(curl -fsS --max-time 8 "http://${LB}/release.json" 2>/dev/null | jq -r .appVersion 2>/dev/null || echo "")
  echo "[$i] release.json appVersion=${ACTUAL} (expecting ${EXPECTED})"
  if [ "${ACTUAL}" = "${EXPECTED}" ]; then
    echo "✓ smoke OK"
    exit 0
  fi
  sleep 10
done
echo "✗ smoke timed out"
exit 1
