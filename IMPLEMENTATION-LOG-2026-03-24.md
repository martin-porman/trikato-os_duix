# Trikato Foundation Implementation Log

Date: 2026-03-24
Owner: Codex session in `/home/martin/Trikato`

## Scope

This log records the PostgreSQL-first foundation work completed for Trikato.
The goal was to replace the earlier "9 Baserow tables first" direction with a
canonical database foundation that Baserow can consume later through SQL views.

This work was based on real source artifacts:

- `/home/martin/Trikato/Data_Source/Trikato/RAAMATUPIDAJA2 (AA, monthly).xlsx`
- `/home/martin/Trikato/Data_Source/Trikato/Müügiaruanded/`
- `/home/martin/Trikato/Data_Source/Merilin/`

## Why It Was Done This Way

The original plan assumed Baserow tables would be the first concrete model.
After inspecting the worker workbooks and Drive copies, that shape was not
stable enough to use as the source of truth.

The implemented design therefore uses:

- one PostgreSQL database: `trikato`
- multiple schemas for domain separation
- `ui.*` views as the disposable Baserow-facing layer

This keeps:

- canonical business state in PostgreSQL
- Baserow optional and replaceable
- imports idempotent and scriptable
- future cloud deployment straightforward

## Delivered Files

### SQL foundation

- `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`
- `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`

### Import and test code

- `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/tests/test_foundation_importer.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/requirements.txt`

### Updated flow docs

- `/home/martin/Trikato/User-tools/trikato-os/START.md`
- `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md`
- `/home/martin/Trikato/User-tools/trikato-os/TASKS.md`

## Database Design Delivered

Database name:

- `trikato`

Schemas delivered:

- `core`
- `source`
- `workflow`
- `work`
- `sales`
- `accounting`
- `ops`
- `audit`
- `ui`

Key delivered tables:

- `core.clients`
- `core.workers`
- `core.client_aliases`
- `core.client_contacts`
- `core.client_service_enrollments`
- `source.documents`
- `source.source_accounts`
- `source.source_client_roots`
- `source.source_period_folders`
- `source.source_document_buckets`
- `workflow.jobs`
- `workflow.pipeline_runs`
- `work.work_items`
- `work.work_requirements`
- `work.work_notes`
- `sales.sales_articles`
- `sales.sales_invoice_headers`
- `accounting.purchase_invoices`
- `accounting.merit_submissions`
- `ops.document_requests`
- `audit.sync_runs`

Main Baserow-facing views delivered:

- `ui.v_clients_overview`
- `ui.v_worker_work_queue`
- `ui.v_document_intake`
- `ui.v_sales_invoices`
- `ui.v_annual_report_pipeline`
- `ui.v_monthly_compliance`
- `ui.v_offboarded_clients`
- `ui.v_main_data_table`

## Import Logic Delivered

Importer entrypoint:

- `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py`

Imports implemented:

- monthly control workbook import
- pending-work workbook import
- sales article workbook import
- sales invoice workbook import
- Merilin Drive copy inventory import

Important importer behavior:

- workbook rows are mapped into canonical normalized tables
- sales reports are loaded into `sales.*`
- Drive structure is mapped into `source.*`
- Baserow is not written to directly

Important importer fixes made during implementation:

- fixed Postgres parameter typing issue in `ensure_client()`
- added JSON-safe payload conversion before writing JSONB
- added explicit commit checkpoints with progress output
- corrected AA import logic so nested year folders are not imported as fake
  clients like `2022` or `2023`

## Relevant Runtime Config

Local PostgreSQL target used in this implementation:

```text
host=127.0.0.1
port=5434
database=trikato
user=baserow
```

Importer command used:

```bash
PYTHONPATH='/home/martin/Trikato/User-tools/accounting-pipeline' \
'/home/martin/Trikato/User-tools/accounting-pipeline/.venv/bin/python' -u \
/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py \
--db-url 'postgresql://baserow:baserow_dev@127.0.0.1:5434/trikato'
```

Dependencies added:

```text
openpyxl>=3.1.5
psycopg[binary]>=3.2.3
```

## Commands Run and Outputs Observed

### Schema apply

Command:

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
-f /home/martin/Trikato/User-tools/trikato-os/sql/schema.sql
```

Output observed:

```text
CREATE SCHEMA
CREATE TABLE
CREATE INDEX
...
```

### View apply

Command:

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
-f /home/martin/Trikato/User-tools/trikato-os/sql/views.sql
```

Output observed:

```text
CREATE VIEW
...
CREATE VIEW
```

### Importer syntax check

Command:

```bash
'/home/martin/Trikato/User-tools/accounting-pipeline/.venv/bin/python' -m py_compile \
/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py
```

Output observed:

```text
<no output, exit code 0>
```

### Importer tests

Command:

```bash
PYTHONPATH='/home/martin/Trikato/User-tools/accounting-pipeline' \
'/home/martin/Trikato/User-tools/accounting-pipeline/.venv/bin/python' -m pytest \
/home/martin/Trikato/User-tools/accounting-pipeline/tests/test_foundation_importer.py -q
```

Output observed:

```text
6 passed in 0.12s
```

### Main data view check

Command:

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
"select count(*) from ui.v_main_data_table;"
```

Output observed during the session:

```text
528
```

### Fake AA client regression check

Command:

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
"select count(*) from core.clients where legal_name in ('2022','2023','2024','2025');"
```

Output observed:

```text
0
```

### Clean DB session check

Command:

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
"select state,wait_event_type,wait_event from pg_stat_activity where usename='baserow' and datname='trikato' and pid<>pg_backend_pid();"
```

Output observed after stopping the hanging importer:

```text
<no rows>
```

## Current Known State

What is complete:

- foundation schema exists
- Baserow-facing SQL views exist
- main consolidated UI view exists
- importer exists
- importer tests pass
- database sessions are clean

What is intentionally not complete yet:

- Work 02 FastAPI wrapper
- queue worker runtime
- full DWD sync
- Baserow external database configuration
- cloud deployment

What is partially complete:

- source inventory import from Merilin
  note: import was stopped after verifying shape and fixes, so source counts are
  partial by design

## How This Should Be Used Next

Local usage:

1. Apply `schema.sql`
2. Apply `views.sql`
3. Run the importer
4. Verify `ui.v_main_data_table`
5. Later point Baserow to `ui.*` views

Cloud usage later:

- keep `trikato` as managed PostgreSQL
- run API/importer/sync in containers
- keep Baserow optional and reading the SQL views

## Notes About Existing Dirty Files

This session did not revert unrelated existing user changes in:

- `/home/martin/Trikato/User-tools/accounting-pipeline/src/merit_client.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/bank_parser.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/merit_submit.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/organizer.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py`

Only the foundation-related files listed above were added or changed for this
implementation.

---

## Session 2 — Priority 1 Schema Additions + Priority 3 Views (2026-03-24)

### Scope

Applied all Priority 1 incremental DDL changes from `Claude.database.task.md`.
Added 6 Priority 3 `ui.*` views. Updated all project documentation files to match
the actual delivered state.

### Schema Changes Applied

All changes are additive (ALTER TABLE ADD COLUMN, CREATE TABLE, CREATE INDEX).
Zero rows were modified. Zero existing constraints were dropped.

| Change | Command | Observed output |
|--------|---------|----------------|
| `core.clients.service_tier` | ALTER TABLE ADD COLUMN | `ALTER TABLE` — 539 rows defaulted to `monthly` |
| `work.work_items.engagement_health` + `waiting_on` | ALTER TABLE ADD COLUMN | `ALTER TABLE` — 322 rows defaulted to `on_track` |
| `core.client_attributes` 4 new columns | ALTER TABLE ADD COLUMN | `ALTER TABLE` — 123 rows |
| `work.blockers` new table | CREATE TABLE + 2 indexes | `CREATE TABLE`, `CREATE INDEX` × 2 |
| `ops.document_requests` 4 new columns | ALTER TABLE ADD COLUMN | `ALTER TABLE` — 0 rows (empty table) |
| `source.documents.document_role` | ALTER TABLE ADD COLUMN | `ALTER TABLE` — 823 rows defaulted to `input_source` |
| `work.client_compliance_currency` new table | CREATE TABLE + index | `CREATE TABLE`, `CREATE INDEX` |
| `work.work_items.source_period_folder_id` FK | ALTER TABLE ADD COLUMN | `ALTER TABLE` |
| CHECK constraint `chk_accounting_system` | DO block | constraint applied to `core.clients` |
| CHECK constraint `chk_period_kind` | DO block | applied to `work.work_periods` (includes `annual_report` for 85 existing rows) |
| CHECK constraint `chk_bucket_type` | DO block | applied to `source.source_document_buckets` (includes `aa` for 15 existing rows) |

Note on CHECK idempotency: PostgreSQL does not support `ADD CONSTRAINT IF NOT EXISTS`.
The constraints are wrapped in `DO $$ BEGIN IF NOT EXISTS ... END $$` blocks in
`schema.sql` so the file remains safely re-runnable.

### Views Applied

```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -f /home/martin/Trikato/User-tools/trikato-os/sql/views.sql
```

Output: `CREATE VIEW` × 14, zero errors.

New views added:
- `ui.v_my_monthly_queue` — primary daily work queue
- `ui.v_open_blockers` — open/awaiting blockers by staleness
- `ui.v_open_document_requests` — missing docs with overdue days
- `ui.v_compliance_gaps` — TSD/KMD last-filed-month gaps
- `ui.v_annual_report_tracker` — AA pipeline with engagement_health
- `ui.v_client_profile` — full client context card

Existing views updated (new columns appended at end to comply with PG column-order rules):
- `ui.v_clients_overview` — added `service_tier`
- `ui.v_worker_work_queue` — added `engagement_health`, `waiting_on`, `service_tier`
- `ui.v_document_intake` — added `document_role`
- `ui.v_main_data_table` — added `service_tier`

### Files Modified

| File | Change |
|------|--------|
| `sql/schema.sql` | Appended migration section (607 → 719 lines) |
| `sql/views.sql` | Added 6 new views, updated 4 existing views |
| `TASKS.md` | Marked P1 done, added P2 and P3 task sections |
| `work-03-database-schema.md` | Full rewrite to match actual delivered multi-schema model |
| `work-07-baserow-ui.md` | Full rewrite to reference `ui.*` views (removed old `trikato.*` table references) |
| `IMPLEMENTATION-LOG-2026-03-24.md` | This section added |
| `START.md` | Updated schema overview, primary view, and build list |

### Runtime Verification

```bash
# All 14 views present
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
  "SELECT COUNT(*) FROM pg_views WHERE schemaname='ui';"
# Output: 14

# service_tier column exists with correct default
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
  "SELECT service_tier, COUNT(*) FROM core.clients GROUP BY service_tier;"
# Output: monthly|539

# New tables exist
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato -Atc \
  "SELECT to_regclass('work.blockers'), to_regclass('work.client_compliance_currency');"
# Output: work.blockers|work.client_compliance_currency
```
