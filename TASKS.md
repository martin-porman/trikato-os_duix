# Master Task List

**Legend:** 🔴 Blocked · 🟡 Ready · 🟢 Done · ⚡ Quick win

---

## Phase 0 — Prerequisites (Admin Tasks, Not Code)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| P1 | Create GCP project for Trikato | Admin | 🟡 | Enable billing |
| P2 | Set up DWD in Google Admin Console | GWS Admin | 🟡 | See START.md auth section |
| P3 | Generate DWD service account JSON key | Admin | 🔴 | Needs P1 |
| P4 | Get Merit API credentials (ID + Key) | Martin | 🟡 | Add to .env |
| P5 | Set up Cloudflare Tunnel | Martin | 🟡 | `pipeline.trikato.ee → localhost:8080` |
| P6 | Create GitHub repo `trikato-accounting-os` | Martin | 🟡 | Monorepo |

---

## Phase 1 — Foundation (Work 01–03)

### Work 01: Infra + Terraform
| # | Task | File |
|---|------|------|
| 1.1 | Create `infra/` Terraform directory structure | work-01 |
| 1.2 | Terraform: GCP project + enable APIs | work-01 |
| 1.3 | Terraform: Service account + IAM | work-01 |
| 1.4 | Terraform: Artifact Registry | work-01 |
| 1.5 | Terraform: Cloud SQL (PostgreSQL 16, europe-north1) | work-01 |
| 1.6 | Terraform: Cloud Storage bucket | work-01 |
| 1.7 | Terraform: Secret Manager secrets | work-01 |
| 1.8 | Terraform: Cloud Run service (empty image) | work-01 |
| 1.9 | Terraform: Cloudflare DNS CNAME | work-01 |
| 1.10 | `dev.tfvars` + `prod.tfvars` | work-01 |

### Work 02: Pipeline Server
| # | Task | File |
|---|------|------|
| 2.1 | ⚡ Fix `watcher.py` — `recursive=True` | work-02 |
| 2.2 | ⚡ Fix `run.py` — `extract_client_from_incoming_path()` | work-02 |
| 2.3 | Create `pipeline/main.py` (FastAPI app) | work-02 |
| 2.4 | `POST /intake` endpoint | work-02 |
| 2.5 | `POST /process` endpoint (called by queue_worker) | work-02 |
| 2.6 | `GET /health` + `GET /jobs/{job_id}` | work-02 |
| 2.7 | `src/storage_client.py` (local filesystem + GCS interface) | work-02 |
| 2.8 | `queue_worker.py` (PostgreSQL jobs table, N=3 concurrent) | work-02 |
| 2.9 | `Dockerfile` for pipeline service | work-02 |
| 2.10 | ⚡ Set `MERIT_API_ID` + `MERIT_API_KEY` in `.env` | work-02 |
| 2.11 | 🟢 `src/contract_client.py` — autocomplete + company data + fill contract (Contract Generator wrapper) | work-02 |
| 2.12 | 🟢 `src/maksuamet_client.py` — quarterly EMTA financials (Maksuamet wrapper) | work-02 |

### Work 03: Database Schema
| # | Task | File |
|---|------|------|
| 3.1 | 🟢 Write canonical SQL foundation in `/sql/schema.sql` | work-03 |
| 3.2 | 🟢 Create `trikato` database and apply schemas: `core/source/workflow/work/sales/accounting/ops/audit/ui` | work-03 |
| 3.3 | 🟢 Create canonical tables for clients, workers, documents, jobs, pipeline runs, sales, accounting, ops, audit | work-03 |
| 3.4 | 🟢 Create SQL read layer in `/sql/views.sql` | work-03 |
| 3.5 | 🟢 Create main Baserow-facing view: `ui.v_main_data_table` | work-03 |
| 3.6 | 🟢 Implement workbook and Drive importer in `src/foundation_importer.py` | work-03 |
| 3.7 | 🟢 Add importer tests in `tests/test_foundation_importer.py` | work-03 |
| 3.8 | 🟡 Re-run full clean source import after importer fixes | work-03 |
| 3.9 | 🟡 Connect Baserow to `ui.*` views (external DB config) | work-03 |
| 3.10 | 🟡 Rebuild Baserow workspace from SQL views only | work-03 |
| 3.11 | 🟢 Write implementation log and update flow docs | work-03 |

### Work 03 — Priority 1: Schema Incremental Additions (2026-03-24) ✅ ALL DONE
| # | Task | Status |
|---|------|--------|
| 3.P1-A | Add `service_tier` to `core.clients` (monthly/annual_only/payroll_only/one_off) | 🟢 |
| 3.P1-B | Add `engagement_health` + `waiting_on` to `work.work_items` | 🟢 |
| 3.P1-C | Add `lang_preference`, `doc_delivery_method`, `billing_frequency`, `vat_threshold_alert` to `core.client_attributes` | 🟢 |
| 3.P1-D | Create `work.blockers` table (Pooleli olevad asjad model) | 🟢 |
| 3.P1-E | Add `contact_channel`, `contacted_at`, `last_reminded_at`, `response_status` to `ops.document_requests` | 🟢 |
| 3.P1-F | Add `document_role` to `source.documents` (input_source/accounting_output/regulatory_submission/journal_xml) | 🟢 |
| 3.P1-G | Create `work.client_compliance_currency` table (TSD/KMD last-filed-month) | 🟢 |
| 3.P1-H | Add `source_period_folder_id` FK to `work.work_items` | 🟢 |
| 3.P1-I | Add CHECK constraints: `accounting_system`, `period_kind`, `bucket_type` | 🟢 |

### Work 03 — Priority 2: Importer Enhancements
| # | Task | Status |
|---|------|--------|
| 3.P2-A | Parse folder-name status suffixes (`2024 OK`, `AA-12.03.25 tegemata`) → write to `work.client_compliance_currency` + `work.blockers` | 🟡 |
| 3.P2-B | Import `Pooleli olevad asjad.xlsx` into `work.blockers` (6 client sheets) | 🟡 |
| 3.P2-C | Import `Klientide täpsem info` → `core.client_attributes` (lang_preference, doc_delivery_method, vat_threshold_alert from note parsing) | 🟡 |
| 3.P2-D | Set `service_tier` from workbook sheet membership (`Lepingulised` → monthly, `Aastaaruande` → annual_only) | 🟡 |
| 3.P2-E | Update `accounting_system` to use `merit`/`joosep` vocabulary (already enforced by CHECK) | 🟡 |
| 3.P2-F | Set `document_role` during Drive inventory import based on file name patterns (Bilanss/Kasumiaruanne → accounting_output, KMD*.pdf → regulatory_submission, KD-*.xml → journal_xml) | 🟡 |
| 3.P2-G | Create `core.client_financials` table — EMTA quarterly snapshot per client (stateTaxes, laborTaxes, turnover, employees, avgNetSalary) | 🟡 |
| 3.P2-H | Backfill `core.client_financials` for all clients using `maksuamet_client.get_company_financials()` → cron on 11th Jan/Apr/Jul/Oct | 🟡 |
| 3.P2-I | On client onboarding: call `contract_client.get_company()` to populate `core.clients` legal fields (registry_code already exists; add legal_form, emtak_code, management_board JSONB, shareholders JSONB, onboarded_at) | 🟡 |

### Work 03 — Priority 3: New UI Views ✅ ALL DONE
| # | Task | Status |
|---|------|--------|
| 3.P3-A | Create `ui.v_my_monthly_queue` (primary daily work view, filters monthly clients) | 🟢 |
| 3.P3-B | Create `ui.v_open_blockers` (open/awaiting_response blockers ordered by staleness) | 🟢 |
| 3.P3-C | Create `ui.v_open_document_requests` (missing docs with overdue days) | 🟢 |
| 3.P3-D | Create `ui.v_compliance_gaps` (TSD/KMD filing currency gaps) | 🟢 |
| 3.P3-E | Create `ui.v_annual_report_tracker` (AA pipeline with engagement_health) | 🟢 |
| 3.P3-F | Create `ui.v_client_profile` (full client context card) | 🟢 |
| 3.P3-G | Expose `service_tier`, `engagement_health`, `waiting_on`, `document_role` in existing views | 🟢 |

---

## Phase 2 — Intake (Work 04–05)

### Work 04: DWD Sync
| # | Task | File |
|---|------|------|
| 4.1 | `src/drive_enumerator.py` (DWD version, all workers) | work-04 |
| 4.2 | `src/sync_manifest.py` (SQLite dedup + PG write) | work-04 |
| 4.3 | `sync_all_workers.py` — discover workers via Admin SDK | work-04 |
| 4.4 | `sync_all_workers.py` — backfill mode (full scan) | work-04 |
| 4.5 | `sync_all_workers.py` — delta mode (changes.list) | work-04 |
| 4.6 | GWS native file export (Docs→PDF, Sheets→XLSX) | work-04 |
| 4.7 | Exponential backoff on 403/429 quota errors | work-04 |
| 4.8 | `data/sync_state/{worker}_pagetoken.txt` per worker | work-04 |
| 4.9 | Crontab entry: `*/15 * * * *` delta sync | work-04 |
| 4.10 | Run backfill — log results | work-04 |

### Work 05: Google Workspace Add-on
| # | Task | File |
|---|------|------|
| 5.1 | Add-on manifest JSON (HTTP runtime, not Apps Script) | work-05 |
| 5.2 | OAuth scopes: `drive.readonly` + `gmail.readonly` | work-05 |
| 5.3 | `POST /addon/drive/homepage` — sidebar card | work-05 |
| 5.4 | `POST /addon/drive/file` — selected file card + Send button | work-05 |
| 5.5 | `POST /addon/gmail/message` — email sidebar + attachment routing | work-05 |
| 5.6 | Client auto-detection from Drive folder name | work-05 |
| 5.7 | Client auto-detection from Gmail sender domain | work-05 |
| 5.8 | Add-on deployed in Google Cloud (manifest registered) | work-05 |
| 5.9 | Admin installs add-on for all 19 workers | work-05 |
| 5.10 | Drive installable trigger registered per worker | work-05 |

---

## Phase 3 — No-Code Layer (Work 06–07)

### Work 06: Workspace Studio Flows
| # | Task | File |
|---|------|------|
| 6.1 | Reactivate existing stopped flow (Merilin's Drive → Tasks) | work-06 |
| 6.2 | Studio flow: File → Gemini classify → Trikato step or Task | work-06 |
| 6.3 | Studio flow: Gmail attachment → Gemini identify → Route | work-06 |
| 6.4 | Studio flow: Daily unread email summary for each worker | work-06 |
| 6.5 | Custom step manifest: "Trikato: Process Invoice" | work-06 |
| 6.6 | Custom step manifest: "Trikato: Route to Client" | work-06 |
| 6.7 | Custom step manifest: "Trikato: Check Status" | work-06 |
| 6.8 | Deploy custom steps via Add-on (flows section in manifest) | work-06 |
| 6.9 | Test flow end-to-end in Studio UI | work-06 |

### Work 07: Baserow UI
| # | Task | File |
|---|------|------|
| 7.1 | Baserow: Create/rebuild "Trikato" workspace | work-07 |
| 7.2 | Baserow: Connect to external PostgreSQL (port 5434) | work-07 |
| 7.3 | Baserow: Import `ui.*` views, starting with `ui.v_main_data_table` | work-07 |
| 7.4 | Baserow: Views — per-worker filtered view (assigned_worker) | work-07 |
| 7.5 | Baserow: Views — compliance calendar next 30 days | work-07 |
| 7.6 | Baserow: Views — documents pending review | work-07 |
| 7.7 | Baserow: Views — pipeline runs status | work-07 |
| 7.8 | Baserow: Row-level permissions (worker sees own clients) | work-07 |
| 7.9 | Baserow: Seed clients table from Merit client list | work-07 |
| 7.10 | Baserow: Seed workers table (19 @trikato.ee emails) | work-07 |

---

## Phase 4 — CI/CD (Work 08)

### Work 08: GitHub Actions + Cloud Build
| # | Task | File |
|---|------|------|
| 8.1 | `.github/workflows/ci.yml` — test + lint on PR | work-08 |
| 8.2 | `.github/workflows/deploy.yml` — build + push + deploy on main | work-08 |
| 8.3 | GitHub secrets: `GCP_SA_KEY`, `PROJECT`, `CLOUDFLARE_API_TOKEN` | work-08 |
| 8.4 | `docker-compose.dev.yml` — local: pipeline + postgres + baserow | work-08 |
| 8.5 | Test full deploy pipeline end-to-end | work-08 |

---

## Quick Wins (Do These First, Independent)

| Task | Time | Impact |
|------|------|--------|
| ⚡ Fix `watcher.py` `recursive=True` | 5 min | Makes Drive sync work |
| ⚡ Fix `run.py` path extraction | 30 min | watcher can infer client |
| ⚡ Set Merit API keys in `.env` | 5 min | Pipeline submits to Merit |
| ⚡ Set up Cloudflare Tunnel | 10 min | Add-on has an endpoint |
| ⚡ Reactivate stopped Studio flow | 5 min | Merilin gets task alerts again |

---

## Work Package Dependencies

```
P1 P2 P3 P4 P5 P6     ← Prerequisites (must come first)
    ↓
Work 01 (Terraform) ←── needed for prod, NOT needed for dev start
Work 02 (Server) ←───── can start now, just needs Python
Work 03 (Database) ←─── foundation delivered; importer + Baserow integration remain
    ↓
Work 04 (DWD Sync) ←─── needs P3 (DWD key) + Work 03 (schema)
Work 05 (Add-on) ←────── needs P5 (Cloudflare) + Work 02 (server)
    ↓
Work 06 (Studio) ←────── needs Work 05 (add-on deployed)
Work 07 (Baserow UI) ←── needs Work 03 (schema + tables exist)
    ↓
Work 08 (CI/CD) ←──────── needs Work 01 (GCP) + Work 02 (Dockerfile)
```
