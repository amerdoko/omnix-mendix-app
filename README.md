# Omnix Mendix App

Mendix demo application + GitOps CI/CD pipeline targeting Azure AKS in **dev → SIT → prod** with manual approval gates between environments. Disaster recovery (DR) is active-passive via Azure Front Door and is **out of band** from this pipeline (DR is bumped manually after a successful prod deploy or on-demand).

## Live endpoints

| Env  | Public URL                                                                 | Cluster              | Region        |
|------|----------------------------------------------------------------------------|----------------------|---------------|
| dev  | http://(dev-lb-ip)/                                                        | `aks-omnix-dev`      | westus2       |
| sit  | http://(sit-lb-ip)/                                                        | `aks-omnix-sit`      | westus2       |
| prod | https://ep-omnix-amhff7fwg8azbucj.b02.azurefd.net/ (via Front Door)        | `aks-omnix-prod`     | westus2       |
| dr   | (same FD URL — auto-failover target)                                       | `aks-omnix-dr`       | northcentralus|

## How a release flows

1. Bump `VERSION` (or push any commit on `main`)
2. GitHub Actions:
   - **build** → `az acr build` produces `acromnixl7yf2e.azurecr.io/omnix-mendix:<version>-<sha>`
   - **deploy-dev** → `helm upgrade` against `aks-omnix-dev` (no approval)
   - **smoke-dev** → `curl /release.json`, assert version matches
   - **deploy-sit** → requires GitHub Environment approval, helm upgrade SIT
   - **smoke-sit** → curl version check
   - **deploy-prod** → requires GitHub Environment approval, helm upgrade prod
   - **smoke-prod** → curl Front Door, assert version matches
3. To promote DR after prod, re-run workflow with `target=dr` (manual dispatch).

## Repo layout

```
.
├── Dockerfile           # wrapper image: base = sample Mendix, overlays release banner
├── VERSION              # semver, bumped per release
├── app/
│   ├── release.html     # /release.html landing — version, sha, region
│   ├── release.json     # JSON sibling for smoke tests
│   └── banner.html      # optional injected banner (not auto-included today)
├── helm/                # Helm chart (lifted from prod working chart)
│   ├── values-dev.yaml
│   ├── values-sit.yaml
│   ├── values-prod.yaml
│   └── values-dr.yaml
└── .github/workflows/
    └── deploy.yml       # CI/CD pipeline
```

## OIDC federation (no secrets in the repo)

A user-assigned managed identity `id-omnix-cicd-gh` lives in `rg-omnix-shared` with:
- **Federated credentials** for GitHub Environments `dev`, `sit`, `prod` on this repo
- **AcrPush** on `acromnixl7yf2e`
- **Contributor** on `rg-omnix-dev`, `rg-omnix-sit`, `rg-omnix-prod`, `rg-omnix-shared`
- **Azure Kubernetes Service RBAC Cluster Admin** scoped to each AKS cluster

The workflow uses `azure/login@v2` with `client-id` / `tenant-id` / `subscription-id` and `id-token: write` permission. No long-lived secrets are stored in GitHub.

## Smoke test contract

Every deploy job runs:

```sh
curl -fsS http://<lb-or-fd>/release.json | jq -e ".appVersion == \"$EXPECTED\""
```

Failure rolls the job, which halts the next environment's gate.
