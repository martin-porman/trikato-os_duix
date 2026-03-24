# Work 07 — Baserow UI

> **For the LLM doing this work:** Read START.md and work-03-database-schema.md first.
> Baserow is running at http://192.168.10.6:8000. Premium unlocked.
> PostgreSQL is at port 5434. Work 03 schema + views must be applied before this work.
> This work is ONLY UI configuration — no Python, no SQL changes.
> **Baserow reads only `ui.*` views — never raw tables.**

---

## Architecture

```
Baserow (http://192.168.10.6:8000)
└── External PostgreSQL connection
    ├── Host: 192.168.10.6 (or 127.0.0.1 if same machine)
    ├── Port: 5434, DB: trikato, User: baserow, Password: baserow_dev
    └── Schema: ui   ← connect to the ui schema only
        └── 14 read-only views (pipeline writes to raw tables; Baserow reads ui.* projections)
```

Workers log in to Baserow to see their work queue, blockers, document requests, and compliance status.
Row-level filtering: each worker sees only their clients via view filters or shared view links.

---

## Task 7.1 — Create "Trikato Accounting OS" Workspace

1. Open http://192.168.10.6:8000
2. Click "Create workspace" → Name: **Trikato Accounting OS**
3. Invite all 19 @trikato.ee workers as members (Viewer role)
4. Martin and admin accounts → Admin role

---

## Task 7.2 — Connect External PostgreSQL

1. Workspace → Settings → Integrations → "Add external database"
2. Fill in:
   ```
   Type:     PostgreSQL
   Host:     192.168.10.6
   Port:     5434
   Database: trikato
   Username: baserow
   Password: baserow_dev
   Schema:   ui
   ```
3. "Test connection" → must show green ✅
4. Click "Connect"

---

## Task 7.3 — Create Tables in Baserow (one per ui.* view)

Create each table by selecting the corresponding `ui.*` view from the external DB.
All tables are read-only — workers cannot edit them in Baserow.

### Primary Work Views

| Baserow Table Name | PostgreSQL View | Default View Name |
|-------------------|----------------|-------------------|
| Monthly Work Queue | `ui.v_my_monthly_queue` | "My Monthly Queue" |
| Open Blockers | `ui.v_open_blockers` | "Open Blockers" |
| Document Requests | `ui.v_open_document_requests` | "Missing Documents" |
| Compliance Gaps | `ui.v_compliance_gaps` | "TSD/KMD Gaps" |
| Annual Reports | `ui.v_annual_report_tracker` | "Annual Report Pipeline" |
| Client Profiles | `ui.v_client_profile` | "Client Profiles" |

### Secondary / Reference Views

| Baserow Table Name | PostgreSQL View | Default View Name |
|-------------------|----------------|-------------------|
| All Clients | `ui.v_main_data_table` | "All Clients" |
| Clients Overview | `ui.v_clients_overview` | "Clients Overview" |
| Work Queue (Full) | `ui.v_worker_work_queue` | "Work Queue" |
| Document Inventory | `ui.v_document_intake` | "Document Inventory" |
| Sales Invoices | `ui.v_sales_invoices` | "Trikato Invoices" |
| Monthly Compliance | `ui.v_monthly_compliance` | "Monthly Compliance Grid" |
| Offboarded Clients | `ui.v_offboarded_clients` | "Offboarded Clients" |

---

## Task 7.4 — Configure the Monthly Work Queue (Primary View)

Table: **Monthly Work Queue** (→ `ui.v_my_monthly_queue`)

This is the default landing page for every worker.

**Grid view "My Queue — [Month]":**
1. Filter: `worker_email` = current worker's email
2. Filter: `status` != `done`
3. Sort: `engagement_health` (blocked first), then `due_date` ascending
4. Color rows by `engagement_health`:
   - `blocked` → red
   - `risk` → yellow
   - `on_track` → green

**Key columns to show:**
- `client_name`, `period_key` (year+month), `status`, `engagement_health`, `waiting_on`
- `tsd_pending` (boolean), `kmd_pending` (boolean)
- `open_blocker_count`, `open_doc_request_count`
- `accounting_system` (merit/joosep — drives which pipeline to use)
- `latest_note_body`

---

## Task 7.5 — Configure Open Blockers View

Table: **Open Blockers** (→ `ui.v_open_blockers`)

**Grid view "Needs Follow-Up":**
1. Already filtered at SQL level: only open/awaiting_response
2. Sort: `days_since_contact` descending (most stale first)
3. Filter by worker: `worker_name` = current worker
4. Color rows:
   - `days_since_contact` > 7 → red
   - `days_since_contact` 3–7 → yellow
   - `days_since_contact` < 3 → default

**Key columns:** `client_name`, `blocker_type`, `document_ref`, `body`, `status`, `contact_channel`, `days_since_contact`

---

## Task 7.6 — Configure Document Requests View

Table: **Document Requests** (→ `ui.v_open_document_requests`)

**Grid view "Missing Documents":**
1. Already filtered: only non-received/non-cancelled
2. Sort: `days_overdue` descending
3. Filter by worker: `worker_name` = current worker
4. Color rows: `days_overdue` > 0 → red

**Key columns:** `client_name`, `period_key`, `requested_item`, `request_category`, `response_status`, `days_overdue`, `last_reminded_at`

---

## Task 7.7 — Configure Compliance Gaps View

Table: **Compliance Gaps** (→ `ui.v_compliance_gaps`)

**Grid view "TSD/KMD Status":**
1. Already filtered: monthly clients, active only
2. Filter: `kmd_gap_months` > 0 OR `tsd_gap_months` > 0
3. Sort: `kmd_gap_months` + `tsd_gap_months` descending
4. Filter by worker: `worker_name` = current worker

**Key columns:** `client_name`, `kmd_obligation`, `kmd_last_month`, `kmd_gap_months`, `tsd_obligation`, `tsd_last_month`, `tsd_gap_months`

---

## Task 7.8 — Configure Annual Report Tracker

Table: **Annual Reports** (→ `ui.v_annual_report_tracker`)

**Grid view "AA Pipeline [Year]":**
1. Filter: `aa_year` = current year OR previous year
2. Filter: `aa_status` != `done`
3. Sort: `engagement_health` (blocked first), then `aa_due_date`
4. Color by `engagement_health`

**Key columns:** `client_name`, `service_tier`, `aa_year`, `aa_status`, `engagement_health`, `aa_due_date`, `ariregister_filed`, `aa_blocker_count`, `folder_name_status_encoded`

---

## Task 7.9 — Row-Level Permissions (Per-Worker Views)

Baserow Premium supports shareable views with pre-set filters.

**Approach (simpler, works today):**
1. For each worker, create a shareable view link with `worker_email` or `worker_name` filter pre-set to their identity
2. Send each worker their personal link
3. Worker bookmarks → sees only their data

**Shareable link setup per worker:**
1. Open "My Monthly Queue" grid view
2. Add filter: `worker_email` = `merilin@trikato.ee`
3. Share → "Create shareable link" → copy link → send to Merilin
4. Repeat for each of the 19 workers

---

## Task 7.10 — Verify Data Counts

After connecting, verify Baserow matches PostgreSQL:

```bash
# Check expected counts
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc "
SELECT 'clients' AS view, COUNT(*) FROM ui.v_main_data_table
UNION ALL SELECT 'monthly_queue', COUNT(*) FROM ui.v_my_monthly_queue
UNION ALL SELECT 'compliance_gaps', COUNT(*) FROM ui.v_compliance_gaps
UNION ALL SELECT 'annual_tracker', COUNT(*) FROM ui.v_annual_report_tracker;"
```

Baserow row counts must match these numbers exactly.

---

## Verification Checklist

- [ ] Workspace "Trikato Accounting OS" exists
- [ ] External PostgreSQL connected (green ✅, schema: `ui`)
- [ ] `ui.v_my_monthly_queue` table visible in Baserow with correct column names
- [ ] `ui.v_open_blockers` table visible
- [ ] `ui.v_compliance_gaps` table visible
- [ ] `ui.v_annual_report_tracker` shows `engagement_health` column
- [ ] `ui.v_client_profile` shows `lang_preference`, `vat_threshold_alert`
- [ ] At least one worker shareable view link created and tested
- [ ] Row counts in Baserow match `SELECT COUNT(*)` from PostgreSQL
- [ ] `service_tier` column visible in `v_my_monthly_queue` (monthly/annual_only)
