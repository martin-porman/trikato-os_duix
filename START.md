# START HERE — Orientation for Any LLM

> Read this before touching any other file. It tells you exactly what exists,
> what works, what is broken, and what needs to be built.

---

## What Already Exists and Works

### 1. Accounting Pipeline (`/home/martin/Trikato/User-tools/accounting-pipeline/`)

A complete 11-node LangGraph pipeline. **Do not refactor this. It works.**

```
drive_fetch → ingest → organizer → bank_parser → invoice_extract
    → reconciler → persist_json → human_approval
    → merit_submit → email_draft → html_report
```

- `run.py` — CLI entry: `--local`, `--incoming`, or `--company + --period`
- `watcher.py` — watchdog on `data/incoming/` — **BUG: `recursive=False`, needs fix**
- `src/drive_client.py` — Drive API v3, OAuth2 or service account
- `src/merit_client.py` — Merit Aktiva HMAC-SHA256 client (ready, keys not set)
- `src/contract_client.py` — Contract Generator REST client (autocomplete, company data, fill contract)
- `src/maksuamet_client.py` — Maksuamet REST client (quarterly EMTA financials per company)
- ORC_LLM_Vision at `/home/martin/Trikato/Extraction/ORC_LLM_Vision/` (Gemini + GPT-4o)

**Two bugs to fix before anything else:**
```python
# watcher.py line ~26:
observer.schedule(IncomingHandler(), str(INCOMING), recursive=False)
# Change to: recursive=True

# run.py — add this function:
def extract_client_from_incoming_path(path):
    # parse data/incoming/{employee}/{client}/file → (client, employee)
```

### 2. Baserow (`/home/martin/Trikato/baserow/`)

Self-hosted Baserow running at `http://192.168.10.6:8000`. Premium unlocked.
PostgreSQL backend at port 5434 (Docker).

Current foundation state:

- canonical PostgreSQL database `trikato` exists — 10 schemas: `core/source/workflow/work/sales/accounting/ops/audit/ui`
- canonical SQL is at `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`
- Baserow-facing views are at `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`
- **14 `ui.*` views live** — primary daily view is `ui.v_my_monthly_queue` (not `v_main_data_table`)
- Baserow content should be treated as disposable and rebuilt over `ui.*` views

Key schema additions applied 2026-03-24 (Priority 1):
- `core.clients.service_tier` — monthly/annual_only/payroll_only/one_off (539 clients defaulted to `monthly`)
- `work.work_items.engagement_health` + `waiting_on` — orthogonal to workflow status
- `work.blockers` — new table mapping Pooleli olevad asjad.xlsx (blocker queue with contact tracking)
- `work.client_compliance_currency` — TSD/KMD last-filed-month per client
- `source.documents.document_role` — input_source/accounting_output/regulatory_submission/journal_xml
- `core.client_attributes` — `lang_preference`, `doc_delivery_method`, `billing_frequency`, `vat_threshold_alert`
- See full schema changelog in `work-03-database-schema.md`

### 3. Example-Notion (`/home/martin/Trikato/User-tools/Example-Notion/`)

Blueprint for the 9 Baserow tables to build:
`Clients | Engagements | Tasks | Invoices | Document Requests |
 Documents | Communications | Compliance Calendar | SOPs`

This is now a UI/reference blueprint only. It is not the canonical database
model anymore.

### 4. Foundation Implementation Log

Full implementation record:

- `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24.md`

### 5. Contract Generator (`baserow/Trikato-Plugins/Auto_Complete_Service/`)

Running on ports **8091** (FastAPI API) and **8092** (nginx frontend). Two Docker containers:
`trikato_contract_api` + `trikato_contract_web`.

**Role:** Client onboarding — searches Estonian Business Register, fetches authoritative company
data via SOAP, and fills `AccountingServiceAgreement2025.html`. Always start via `./start.sh`.

Python client: `accounting-pipeline/src/contract_client.py`

```python
from src.contract_client import contract_client
company = await contract_client.get_company("11104671")  # → legal data, VAT, mgmt board
results = await contract_client.autocomplete("Fatfox")
```

**Data it owns:** legal_form, company_status, address, email, phone, website, share_capital,
emtak_code, management_board, shareholders, VAT number (structured SOAP field — authoritative).

---

### 6. Maksuamet EMTA Service (`User-tools/Maksuamet/`)

Port **8181** (app) + **5435** (its own PostgreSQL). Start: `cd User-tools/Maksuamet && git checkout emtadata-v2 && docker compose up -d`.

**Role:** Quarterly financial snapshot per client — EMTA public data. Run after onboarding to
populate `core.client_financials`. Cron on 11th Jan/Apr/Jul/Oct after EMTA publishes.

Python client: `accounting-pipeline/src/maksuamet_client.py`

```python
from src.maksuamet_client import maksuamet_client
q = await maksuamet_client.get_latest_quarter("11104671")
# → stateTaxes, laborTaxes, turnover, employees, avgNetSalary, ...
```

**Data it owns:** stateTaxes, laborTaxes, turnover, employees (quarterly, from EMTA CSV).
Salary estimates are *calculated* from laborTaxes, not directly from EMTA.

**Note:** Maksuamet's internal `VatLookupService` scrapes ariregister HTML for its own UI.
Do NOT use it as the VAT source in the pipeline — use Contract Generator SOAP field instead.

---

### 7. Workspace Studio

Live at `https://studio.workspace.google.com/u/3/`
One existing flow (STOPPED): `t258d25ddc51a2a5c224363508bad9356`
— "Auto-create tasks when files are added to a folder" (Merilin's Drive)

---

## What Does NOT Exist Yet (Build List)

| # | Component | Status | File |
|---|-----------|--------|------|
| 1 | GCP project + Terraform | 🟡 Ready | work-01 |
| 2 | FastAPI server (wraps pipeline) | 🟡 Ready | work-02 |
| 3 | PostgreSQL schema + views — **P1 DDL done, P2 importer pending** | 🟡 In progress | work-03 |
| 4 | DWD service account + sync_all_workers.py | 🔴 Needs DWD key | work-04 |
| 5 | GWS Add-on (Drive trigger + Gmail sidebar) | 🔴 Needs Cloudflare | work-05 |
| 6 | Workspace Studio custom flows | 🔴 Needs add-on | work-06 |
| 7 | Baserow UI — **views ready, UI config pending** | 🟡 Ready | work-07 |
| 8 | GitHub Actions CI/CD | 🔴 Needs GCP | work-08 |

**Next immediate actions (no blockers):**
1. Work 03 P2 — run importer enhancements (set `service_tier`, parse folder names, import Pooleli)
2. Work 07 — connect Baserow to `ui.*` views, configure `v_my_monthly_queue` as default view
3. Work 02 — fix `watcher.py` `recursive=True` bug (5-min task)

---

## Auth Model (Critical to Understand)

```
TWO auth paths, both needed:

PATH A — User-initiated (add-on click or Studio flow):
  Worker interacts → Add-on sends userOAuthToken to server
  Server uses token to download file
  Token is fresh (user just acted)
  ✅ No DWD needed

PATH B — Automated (file arrives at 3am, cron sync):
  No user present → userOAuthToken would be expired
  Server uses DWD service account → impersonates worker
  DWD: admin sets up once in Google Admin Console
  ✅ One JSON key covers all 19 workers
```

**DWD setup (admin task, not code):**
```
Admin Console → Security → Access and data control
→ API controls → Manage Domain Wide Delegation → Add new
→ Client ID: <service_account_client_id>
→ Scopes: https://www.googleapis.com/auth/drive.readonly,
          https://www.googleapis.com/auth/gmail.readonly
```

**Python impersonation pattern:**
```python
from google.oauth2 import service_account
creds = service_account.Credentials.from_service_account_file(
    "trikato-service-account.json", scopes=SCOPES)
delegated = creds.with_subject("merilin@trikato.ee")
service = build("drive", "v3", credentials=delegated)
# Now acts exactly as merilin@trikato.ee
```

---

## Workspace Studio — What It Is

Studio is Google's no-code automation tool (`studio.workspace.google.com`).
Workers build flows: Starter → Steps (up to 20) — no coding.

**Available starters (triggers):**
- Email received (filter by sender / subject / label / content)
- Google Calendar schedule (time-based, recurring)
- Google Forms submission
- File added to Drive folder
- Manual trigger

**Available built-in steps:**
- Ask Gemini (summarize, decide, classify, generate)
- Send email (Gmail)
- Post in Google Chat
- Create Google Task
- Add label to email / Star email
- Add file to Drive / Auto-add attachments to Drive
- Create Google Doc / Add to Doc
- Draft email with Gemini
- Create calendar event

**Custom steps (Limited Preview — our add-on exposes these):**
- "Trikato: Process Invoice" — takes file_id, client → runs pipeline
- "Trikato: Route to Client" — maps email/file to correct client
- "Trikato: Check Status" — returns pipeline run status

**Available templates (from Discover page):**
- Email boosters: daily summaries, urgent email alerts, auto-add attachments to Drive,
  label action items, keyword alerts, star emails for follow-up
- Better meetings: pre-meeting briefs, post-meeting summaries, auto-create tasks from transcripts,
  meeting reminders, follow-up email drafts
- Tasks & action items: auto-create tasks from emails, customer request tracking,
  file follow-up tasks

---

## Dev Environment

```
Machine: Linux, /home/martin/, static IP
Pipeline port: 8080 (to be started)
Baserow port: 8000 (running)
PostgreSQL port: 5434 (running, Docker)
Foundation DB: `trikato`
Contract Generator API: 8091 | Contract Generator UI: 8092
Maksuamet EMTA API: 8181 | Maksuamet PostgreSQL: 5435
Cloudflare Tunnel: pipeline.trikato.ee → localhost:8080 (to be set up)
```

---

## File Locations

```
/home/martin/Trikato/User-tools/
├── accounting-pipeline/     ← existing working pipeline
├── Example-Notion/          ← Baserow schema blueprint
├── trikato-os/              ← THIS DIRECTORY (plans + work packages)
├── Emplyee-workspace-grep.2.md  ← Merilin's Drive investigation report
├── ARCHITECTURE-2026-03-21.md   ← Full architecture doc
├── SCALE-REFRAME-2026-03-21.md  ← 19 workers × 700 customers analysis
└── FULL-SYSTEM-PICTURE-2026-03-21.md ← system overview

/home/martin/Trikato/baserow/    ← Baserow installation
/home/martin/Trikato/Extraction/ORC_LLM_Vision/  ← invoice OCR engine
```

---

## Rules for Any LLM Working on This

1. **Do not touch** `accounting-pipeline/src/pipeline/` nodes — they work
2. **Do not touch** ORC_LLM_Vision — it works
3. Each work package is independent — read only the work-0X file you're assigned
4. All new Python goes in `accounting-pipeline/` alongside existing code
5. All infra goes in `trikato-os/infra/` (Terraform)
6. All add-on code goes in `trikato-os/addon/`
7. Target Python: 3.12. Target region: `europe-north1`
8. Verify with terminal — never claim "it works" without running it
9. Baserow is a read layer, not the source of truth
