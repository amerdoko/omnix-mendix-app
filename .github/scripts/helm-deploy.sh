#!/usr/bin/env bash
# helm-deploy.sh - run helm upgrade against a private AKS via az aks command invoke
# Usage: helm-deploy.sh <RG> <AKS> <NS> <RELEASE> <CHART_DIR> <VALUES_FILE> <IMAGE_REPO> <IMAGE_TAG>
set -euo pipefail
RG="$1"; AKS="$2"; NS="$3"; RELEASE="$4"; CHART_DIR="$5"; VALUES="$6"; IMG="$7"; TAG="$8"

echo "Deploying ${RELEASE} → ${AKS} in ${RG} (image=${IMG}:${TAG})"

CTX_DIR=$(mktemp -d)
cp -r "${CHART_DIR}" "${CTX_DIR}/chart"
cp "${VALUES}" "${CTX_DIR}/values.yaml"
cd "${CTX_DIR}"
ls -la

az aks command invoke \
  -g "${RG}" -n "${AKS}" \
  --file . \
  --command "kubectl create namespace ${NS} --dry-run=client -o yaml | kubectl apply -f - && \
             helm upgrade --install ${RELEASE} ./chart \
               -n ${NS} \
               -f values.yaml \
               --set image.repository=${IMG} \
               --set image.tag=${TAG} \
               --set image.pullPolicy=Always \
               --wait --timeout 8m && \
             kubectl -n ${NS} rollout status deploy/${RELEASE} --timeout=8m"
