# Work 08 — CI/CD (GitHub Actions + Cloud Build)

> **For the LLM doing this work:** Read START.md first.
> Prerequisite: Work 01 (Terraform) must be applied. GCP project must exist.
> Prerequisite: Work 02 (Dockerfile) must exist.
> Repository: `trikato-accounting-os` (monorepo) on GitHub.

---

## What This Builds

```
.github/workflows/
├── ci.yml      ← Test + lint on every PR
└── deploy.yml  ← Build Docker + push + deploy Cloud Run on merge to main

docker-compose.dev.yml   ← Local dev: pipeline + postgres + baserow
```

---

## Repository Structure (Monorepo)

```
trikato-accounting-os/
├── accounting-pipeline/     ← existing working pipeline (copy from /home/martin/)
├── trikato-os/              ← plans + work packages (this dir)
│   ├── addon/               ← manifest.json
│   ├── infra/               ← Terraform
│   └── sql/                 ← schema.sql
├── .github/workflows/
│   ├── ci.yml
│   └── deploy.yml
├── docker-compose.dev.yml
└── .gitignore
```

---

## Task 8.1 — .github/workflows/ci.yml

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    name: Test + Lint
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: trikato
          POSTGRES_USER: pipeline
          POSTGRES_PASSWORD: testpassword
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    env:
      DATABASE_URL: postgresql://pipeline:testpassword@localhost:5432/trikato
      MERIT_API_ID: test
      MERIT_API_KEY: test
      STORAGE_BACKEND: local
      LOCAL_DATA_DIR: /tmp/trikato-test

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python 3.12
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip

      - name: Install dependencies
        run: |
          pip install -r accounting-pipeline/requirements.txt
          pip install pytest pytest-asyncio httpx

      - name: Apply database schema
        run: |
          psql $DATABASE_URL -f trikato-os/sql/schema.sql

      - name: Lint
        run: |
          pip install ruff
          ruff check accounting-pipeline/src/ accounting-pipeline/pipeline/
          ruff check accounting-pipeline/queue_worker.py

      - name: Compile check (no syntax errors)
        run: |
          python3 -m py_compile accounting-pipeline/pipeline/main.py
          python3 -m py_compile accounting-pipeline/queue_worker.py
          python3 -m py_compile accounting-pipeline/src/storage_client.py
          python3 -m py_compile accounting-pipeline/src/baserow_client.py
          python3 -m py_compile accounting-pipeline/src/drive_enumerator.py
          python3 -m py_compile accounting-pipeline/src/sync_manifest.py
          python3 -m py_compile accounting-pipeline/sync_all_workers.py

      - name: Run tests
        run: |
          cd accounting-pipeline
          python -m pytest tests/ -v --tb=short
        env:
          PYTHONPATH: .

      - name: Validate addon manifest
        run: |
          python3 -m json.tool trikato-os/addon/manifest.json > /dev/null
          echo "manifest.json is valid JSON"

      - name: Validate Terraform syntax
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6"
      - run: |
          cd trikato-os/infra
          terraform init -backend=false
          terraform validate
```

---

## Task 8.2 — .github/workflows/deploy.yml

```yaml
name: Deploy

on:
  push:
    branches: [main]
    paths:
      - 'accounting-pipeline/**'
      - '.github/workflows/deploy.yml'

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: europe-north1
  SERVICE_NAME: trikato-pipeline
  REGISTRY: europe-north1-docker.pkg.dev

jobs:
  build-and-deploy:
    name: Build + Push + Deploy
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write   # For Workload Identity Federation

    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - name: Build Docker image
        run: |
          docker build \
            -t ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/trikato-pipeline/pipeline:${{ github.sha }} \
            -t ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/trikato-pipeline/pipeline:latest \
            accounting-pipeline/

      - name: Push Docker image
        run: |
          docker push ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/trikato-pipeline/pipeline:${{ github.sha }}
          docker push ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/trikato-pipeline/pipeline:latest

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy ${{ env.SERVICE_NAME }} \
            --image=${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/trikato-pipeline/pipeline:${{ github.sha }} \
            --region=${{ env.REGION }} \
            --platform=managed \
            --no-traffic \
            --tag=sha-${{ github.sha }}

      - name: Run smoke test on new revision
        run: |
          NEW_URL=$(gcloud run services describe ${{ env.SERVICE_NAME }} \
            --region=${{ env.REGION }} \
            --format="value(status.address.url)")
          # Hit the tagged revision directly
          TAGGED_URL=$(gcloud run revisions describe ${{ env.SERVICE_NAME }}-sha-${{ github.sha }} \
            --region=${{ env.REGION }} \
            --format="value(status.url)" 2>/dev/null || echo "$NEW_URL")

          STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$TAGGED_URL/health" \
            -H "Authorization: Bearer $(gcloud auth print-identity-token)")
          if [ "$STATUS" != "200" ]; then
            echo "Smoke test failed: HTTP $STATUS"
            exit 1
          fi
          echo "Smoke test passed: HTTP $STATUS"

      - name: Shift 100% traffic to new revision
        run: |
          gcloud run services update-traffic ${{ env.SERVICE_NAME }} \
            --region=${{ env.REGION }} \
            --to-latest

      - name: Notify success
        if: success()
        run: |
          echo "✅ Deployed ${{ github.sha }} to Cloud Run"
          echo "URL: https://pipeline.trikato.ee"
```

---

## Task 8.3 — GitHub Secrets

Set these in the repository Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Federation provider resource name |
| `GCP_SERVICE_ACCOUNT` | `trikato-pipeline@PROJECT_ID.iam.gserviceaccount.com` |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with DNS edit permissions |

**Set up Workload Identity Federation (replaces service account key):**
```bash
# Create the pool and provider (run once)
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Bind to service account
gcloud iam service-accounts add-iam-policy-binding \
  trikato-pipeline@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/martin-porman/trikato-accounting-os"
```

---

## Task 8.4 — docker-compose.dev.yml

File: `docker-compose.dev.yml` (at repo root)

```yaml
version: "3.9"

services:
  pipeline:
    build:
      context: accounting-pipeline/
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgresql://pipeline:pipeline@postgres:5432/trikato
      STORAGE_BACKEND: local
      LOCAL_DATA_DIR: /app/data
      MERIT_API_ID: ${MERIT_API_ID}
      MERIT_API_KEY: ${MERIT_API_KEY}
      PIPELINE_URL: http://localhost:8080
    volumes:
      - ./accounting-pipeline:/app
      - pipeline_data:/app/data
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - trikato

  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: trikato
      POSTGRES_USER: pipeline
      POSTGRES_PASSWORD: pipeline
    ports:
      - "5434:5432"    # Match existing local port
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./trikato-os/sql/schema.sql:/docker-entrypoint-initdb.d/schema.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U pipeline -d trikato"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - trikato

  # Note: Baserow already runs separately at http://192.168.10.6:8000
  # No need to include it here — it connects to the same PostgreSQL above

volumes:
  postgres_data:
  pipeline_data:

networks:
  trikato:
    driver: bridge
```

Run dev stack:
```bash
# Start pipeline + postgres
docker-compose -f docker-compose.dev.yml up

# Or with rebuild
docker-compose -f docker-compose.dev.yml up --build

# Background
docker-compose -f docker-compose.dev.yml up -d
```

---

## Task 8.5 — Test Full Deploy Pipeline

```bash
# 1. Local build test
cd accounting-pipeline
docker build -t trikato-pipeline-test .
docker run --rm -p 8080:8080 -e DATABASE_URL="..." trikato-pipeline-test &
curl http://localhost:8080/health
# Should return {"status":"ok"}

# 2. Push to trigger CI
git checkout -b test/ci-validation
echo "# CI test" >> README.md
git add README.md
git commit -m "test: trigger CI pipeline"
git push origin test/ci-validation
# Open PR → watch GitHub Actions

# 3. Merge to trigger deploy
git checkout main
git merge test/ci-validation
git push origin main
# Watch GitHub Actions deploy job
```

---

## .gitignore

Add at repo root:

```gitignore
# Secrets
*.tfvars
*.tfstate
*.tfstate.backup
.terraform/
.env
trikato-service-account.json
token.json

# Python
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.ruff_cache/
venv/
.venv/

# Data (never commit raw documents)
data/
*.pdf
*.jpg
*.jpeg
*.png

# Logs
*.log
logs/

# Docker
.dockerignore
```

---

## Verification Checklist

- [ ] `ci.yml` triggers on PR and passes all steps
- [ ] `deploy.yml` triggers on merge to main
- [ ] `docker-compose.dev.yml up` starts pipeline on port 8080
- [ ] `curl http://localhost:8080/health` returns 200 after docker-compose starts
- [ ] Docker image builds without errors: `docker build accounting-pipeline/`
- [ ] Smoke test in deploy.yml returns 200 before traffic shift
- [ ] Cloud Run service updated after merge to main
- [ ] `https://pipeline.trikato.ee/health` returns 200 after prod deploy

---

## Notes

- **Workload Identity Federation** (WIF) is preferred over service account JSON keys. Keys can leak; WIF uses short-lived OIDC tokens. The setup above uses WIF — no GCP_SA_KEY secret needed.
- **No-traffic deploy + smoke test**: New revision gets 0% traffic. We test it. Then shift 100%. Rollback is instant: `gcloud run services update-traffic --to-revisions=PREV_REV=100`.
- **docker-compose.dev.yml**: Uses port 5434 for PostgreSQL to match the existing local setup. If you already have PostgreSQL running at 5434 locally, either stop it or change the compose port.
- **CI PostgreSQL**: Uses port 5432 (standard) in CI to avoid conflicts. `DATABASE_URL` is set accordingly.
