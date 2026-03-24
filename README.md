# Trikato Accounting OS

**What this is:** A complete accounting firm operating system for Trikato.
19 workers · ~700 customers · Google Workspace · Merit Aktiva · Baserow · Google Cloud

---

## Directory

| File | Purpose |
|------|---------|
| [START.md](START.md) | **Read this first.** Orientation, current state, what's done |
| [FLOWCHART.md](FLOWCHART.md) | Full system architecture flowchart (Mermaid) |
| [TASKS.md](TASKS.md) | Master task list, all work packages, status |
| [work-01-infra-terraform.md](work-01-infra-terraform.md) | GCP project + Terraform + Cloudflare |
| [work-02-pipeline-server.md](work-02-pipeline-server.md) | FastAPI server wrapping existing pipeline |
| [work-03-database-schema.md](work-03-database-schema.md) | PostgreSQL schema + Baserow table setup |
| [work-04-dwd-sync.md](work-04-dwd-sync.md) | Domain-Wide Delegation + sync_all_workers.py |
| [work-05-workspace-addon.md](work-05-workspace-addon.md) | Google Workspace Add-on (HTTP runtime) |
| [work-06-studio-flows.md](work-06-studio-flows.md) | Workspace Studio flows — no-code automation layer |
| [work-07-baserow-ui.md](work-07-baserow-ui.md) | Baserow tables, views, worker UI |
| [work-08-cicd.md](work-08-cicd.md) | GitHub Actions + Cloud Build + deploy pipeline |

---

## Stack

```
Google Workspace (Drive + Gmail + Studio)
    ↓ Add-on (HTTP) + Studio flows
Pipeline Server (FastAPI + LangGraph 11 nodes)
    ↓
PostgreSQL (Cloud SQL) ← Baserow reads this
    ↓
Merit Aktiva API
Cloud Storage (documents)
Secret Manager (keys)
Terraform (infra)
GitHub Actions (CI/CD)
```

## Key Numbers

- Workers: 19 (`@trikato.ee` Google Workspace accounts)
- Customers: ~700 (Drive folders per worker)
- Existing pipeline nodes: 11 (working, not to be touched)
- Drive API quota: 12,000 QPM per impersonated user = plenty
- Target region: `europe-north1` (Finland, closest to Estonia)
