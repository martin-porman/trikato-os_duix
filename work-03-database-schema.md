# Work 03 — Database Schema + Baserow

> **For the LLM doing this work:** Read START.md first.
> PostgreSQL is running at port 5434 (Docker: `baserow-postgres-1`).
> Baserow is running at http://192.168.10.6:8000. Premium unlocked.
> Connection: `postgresql://baserow:baserow_dev@127.0.0.1:5434/trikato`

---

## Architecture

```
PostgreSQL port 5434 — database: trikato
├── core.*        ← clients, workers, contacts, service enrollments
├── source.*      ← Drive folder inventory (accounts → roots → periods → buckets → documents)
├── workflow.*    ← pipeline jobs and run records
├── work.*        ← work items, periods, requirements, notes, blockers, compliance currency
├── sales.*       ← Trikato's own invoices to clients
├── accounting.*  ← purchase invoices, Merit submissions
├── ops.*         ← document requests, tasks, checklists, communications
├── audit.*       ← sync runs, job events, document events
└── ui.*          ← Baserow-facing read-only views (disposable, rebuilt from SQL)

Baserow (http://192.168.10.6:8000)
└── External Database → same PostgreSQL
    └── Tables created against ui.* views only (not raw tables)
```

---

## Canonical SQL Files

| File | Purpose |
|------|---------|
| `sql/schema.sql` | All CREATE TABLE, indexes, constraints. Idempotent — safe to re-run. |
| `sql/views.sql` | All `ui.*` views. Idempotent (`CREATE OR REPLACE VIEW`). |

Apply commands:
```bash
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -f /home/martin/Trikato/User-tools/trikato-os/sql/schema.sql

PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -f /home/martin/Trikato/User-tools/trikato-os/sql/views.sql
```

---

## Delivered Tables (Current State)

### core.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `core.clients` | `id`, `legal_name`, `registry_code`, `accounting_system`, `service_tier` | `service_tier`: monthly/annual_only/payroll_only/one_off |
| `core.workers` | `id`, `email`, `display_name`, `active` | 19 @trikato.ee workers |
| `core.client_aliases` | `client_id`, `alias`, `alias_type` | `alias_type='folder_name'` for Drive matching |
| `core.client_contacts` | `client_id`, `name`, `email`, `phone` | Contact persons |
| `core.client_service_enrollments` | `client_id`, `service_type_id`, `active` | Which services each client uses |
| `core.service_types` | `code`, `label`, `category` | TSD, KMD, AA, monthly_bookkeeping, etc. |
| `core.client_attributes` | `client_id`, `vehicle_flag`, `important_info`, `lang_preference`, `doc_delivery_method`, `billing_frequency`, `vat_threshold_alert` | Extended client metadata |

### source.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `source.source_accounts` | `worker_id`, `source_name`, `account_type` | One per worker Drive account |
| `source.source_client_roots` | `source_account_id`, `client_id`, `folder_name`, `folder_path` | Top-level client folder |
| `source.source_period_folders` | `source_client_root_id`, `year_num`, `month_num`, `period_type` | Year or month sub-folder |
| `source.source_document_buckets` | `source_period_folder_id`, `bucket_type`, `bucket_name` | müük/ost/pank/maksuamet/etc. |
| `source.documents` | `client_id`, `file_name`, `file_ext`, `document_category`, `document_role` | `document_role`: input_source/accounting_output/regulatory_submission/journal_xml |

### work.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `work.work_periods` | `client_id`, `year_num`, `month_num`, `period_kind` | Period kind: monthly/annual/ad_hoc/etc. |
| `work.work_items` | `client_id`, `status`, `engagement_health`, `waiting_on`, `source_period_folder_id` | `engagement_health`: on_track/risk/blocked |
| `work.work_requirements` | `work_item_id`, `requirement_code`, `requirement_status` | TSD/KMD/AA/INF/ARIREGISTER |
| `work.work_notes` | `client_id`, `work_item_id`, `note_type`, `body` | Freeform notes |
| `work.blockers` | `client_id`, `blocker_type`, `body`, `status`, `contact_channel`, `contacted_at` | Pooleli olevad asjad model |
| `work.client_compliance_currency` | `client_id`, `obligation_code`, `last_completed_year`, `last_completed_month` | TSD/KMD last-filed-month tracker |
| `work.requirement_catalog` | `code`, `label`, `obligation_type` | Reference table for requirement codes |
| `work.client_lifecycle_events` | `client_id`, `event_type`, `event_date`, `reason` | Onboarding/offboarding |

### ops.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `ops.document_requests` | `client_id`, `requested_item`, `status`, `contact_channel`, `contacted_at`, `response_status` | Missing document requests with contact tracking |
| `ops.tasks` | `client_id`, `title`, `status`, `due_date` | General tasks |
| `ops.checklists` | `checklist_name`, `service_type_id`, `content` | SOPs (currently empty) |

### sales.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `sales.sales_invoice_headers` | `invoice_number`, `client_id`, `total_amount`, `trikato_entry_code` | Trikato's own issued invoices |
| `sales.sales_articles` | `article_code`, `description`, `unit_price` | Price list |

### accounting.*
| Table | Key columns | Notes |
|-------|------------|-------|
| `accounting.purchase_invoices` | `client_id`, `vendor_name`, `total_amount`, `merit_bill_id` | Purchase invoices extracted from documents |
| `accounting.merit_submissions` | `client_id`, `bill_id`, `request_payload`, `response_payload` | Merit API submission records |

---

## Current Row Counts (2026-03-24)

```sql
SELECT 'core.clients'              AS tbl, COUNT(*) FROM core.clients
UNION ALL SELECT 'core.workers',             COUNT(*) FROM core.workers
UNION ALL SELECT 'source.documents',         COUNT(*) FROM source.documents
UNION ALL SELECT 'work.work_items',          COUNT(*) FROM work.work_items
UNION ALL SELECT 'work.work_periods',        COUNT(*) FROM work.work_periods
UNION ALL SELECT 'sales.sales_invoice_headers', COUNT(*) FROM sales.sales_invoice_headers;
-- Expected: ~539 clients, 823 documents, 322 work_items, 322 work_periods
```

---

## UI Views (Baserow-Facing Layer)

All views are in the `ui` schema. These are the only things Baserow should connect to.

| View | Purpose | Key filter |
|------|---------|------------|
| `ui.v_main_data_table` | Full client snapshot — one row per client | All clients |
| `ui.v_clients_overview` | Simplified client list with service summary | All clients |
| `ui.v_my_monthly_queue` | **Primary daily work view** — monthly service clients | `service_tier='monthly'` |
| `ui.v_open_blockers` | Open/waiting blockers ordered by staleness | `status IN ('open','awaiting_response')` |
| `ui.v_open_document_requests` | Missing documents with overdue days | `status NOT IN ('received','cancelled')` |
| `ui.v_compliance_gaps` | TSD/KMD filing gaps per client | `service_tier='monthly'`, active only |
| `ui.v_annual_report_tracker` | Annual report pipeline with engagement_health | `service_type='annual_report'` |
| `ui.v_client_profile` | Full context card (pre-call review) | All clients |
| `ui.v_worker_work_queue` | All work items with engagement_health | All work items |
| `ui.v_document_intake` | Drive document inventory with document_role | All documents |
| `ui.v_sales_invoices` | Trikato's issued invoices | All invoices |
| `ui.v_monthly_compliance` | Monthly TSD/KMD compliance grid | Monthly service types |
| `ui.v_annual_report_pipeline` | (Legacy) Annual report items | `annual_report` service type |
| `ui.v_offboarded_clients` | Clients that left | offboarded/deleted/liquidated |

---

## Schema Changes Log

### Priority 1 — Applied 2026-03-24 (non-breaking, additive only)

| Change | SQL object | Details |
|--------|-----------|---------|
| Two-tier client roster | `core.clients.service_tier` | `monthly`/`annual_only`/`payroll_only`/`one_off` |
| Engagement health | `work.work_items.engagement_health` | `on_track`/`risk`/`blocked` |
| Waiting-on state | `work.work_items.waiting_on` | `client`/`tax_authority`/`internal`/`partner` |
| Client language | `core.client_attributes.lang_preference` | `et`/`en`/`ru` |
| Doc delivery | `core.client_attributes.doc_delivery_method` | `email`/`google_drive`/`portal`/etc. |
| Billing cadence | `core.client_attributes.billing_frequency` | `monthly`/`annual`/`per_service` |
| VAT threshold alert | `core.client_attributes.vat_threshold_alert` | BOOLEAN, watch €40k |
| Blocker queue | `work.blockers` (new table) | Maps to Pooleli olevad asjad.xlsx |
| Doc request channels | `ops.document_requests.*` | `contact_channel`, `contacted_at`, `last_reminded_at`, `response_status` |
| Document role | `source.documents.document_role` | `input_source`/`accounting_output`/`regulatory_submission`/`journal_xml` |
| Compliance currency | `work.client_compliance_currency` (new table) | TSD/KMD last-filed-month |
| Work-to-Drive link | `work.work_items.source_period_folder_id` | FK to `source.source_period_folders` |
| Vocabulary constraints | CHECK constraints | `accounting_system`, `period_kind`, `bucket_type` |

---

## Priority 2: Importer Enhancements (Pending)

See TASKS.md section "Work 03 — Priority 2".

Key tasks:
- Parse folder-name status suffixes (`2024 OK`, `AA-12.03.25 tegemata`) into `work.client_compliance_currency`
- Import `Pooleli olevad asjad.xlsx` → `work.blockers`
- Import `Klientide täpsem info` → `core.client_attributes` (lang, delivery method, VAT alert)
- Set `service_tier` from workbook sheet membership
- Set `document_role` during Drive sync based on filename patterns

---

## Connect Baserow to ui.* Views

```
Host: 192.168.10.6
Port: 5434
Database: trikato
Username: baserow
Password: baserow_dev
Schema: ui
```

### Recommended view order in Baserow workspace

1. **v_my_monthly_queue** — default landing, filter by worker
2. **v_open_blockers** — requires daily attention
3. **v_open_document_requests** — missing docs queue
4. **v_compliance_gaps** — TSD/KMD status board
5. **v_annual_report_tracker** — AA pipeline
6. **v_client_profile** — client lookup
7. **v_main_data_table** — full overview (keep for backward compat)

---

## External Service Integration (Priority 2 — Pending)

Two live services feed data into the schema. Both have Python clients in `accounting-pipeline/src/`.

### Contract Generator → `core.clients` onboarding fields

On first client onboarding, call `src/contract_client.py`:
```python
company = await contract_client.get_company(registry_code)
# Populate into core.clients:
#   legal_form, company_status, emtak_code, emtak_activity,
#   share_capital, financial_year_period
# Populate into core.client_attributes:
#   (email, phone, website if not already set)
# Populate into core.client_contacts:
#   management_board members (JSONB → rows)
```

**VAT number:** `company['vat_number']` from SOAP `kmkr_number` field — authoritative.
Do NOT use Maksuamet's `VatLookupService` (HTML scraper) for this.

### Maksuamet → `core.client_financials` (new table, task 3.P2-G)

Proposed table — to be added to `sql/schema.sql`:
```sql
CREATE TABLE IF NOT EXISTS core.client_financials (
    id               SERIAL PRIMARY KEY,
    client_id        INTEGER NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    registry_code    TEXT NOT NULL,
    year             TEXT NOT NULL,
    quarter          INTEGER NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    quarter_label    TEXT,                   -- "Q4 2025"
    state_taxes      BIGINT,                 -- riiklikud maksud (EUR)
    labor_taxes      BIGINT,                 -- tööjõumaksud (EUR)
    turnover         BIGINT,                 -- maksustatav käive (EUR)
    employees        INTEGER,                -- töötajate arv (headcount)
    avg_gross_salary BIGINT,                 -- calculated by Maksuamet
    avg_net_salary   BIGINT,                 -- calculated by Maksuamet
    employer_cost    BIGINT,                 -- calculated by Maksuamet
    synced_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (client_id, year, quarter)
);
CREATE INDEX IF NOT EXISTS idx_client_financials_client ON core.client_financials(client_id);
CREATE INDEX IF NOT EXISTS idx_client_financials_quarter ON core.client_financials(year, quarter);
```

Backfill: `maksuamet_client.get_company_financials(registry_code)` → insert all quarters.
Cron: 11th Jan/Apr/Jul/Oct at 08:15 (one day after EMTA publishes).

---

## Verification Commands

```bash
# Schema OK
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -c "\dn" | grep -E "core|source|work|ops|ui"

# All 14 views present
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -c "SELECT viewname FROM pg_views WHERE schemaname='ui' ORDER BY viewname;"

# New columns applied
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -c "SELECT service_tier, COUNT(*) FROM core.clients GROUP BY service_tier;"

# Blockers table ready
PGPASSWORD='baserow_dev' psql -h 127.0.0.1 -p 5434 -U baserow -d trikato \
  -c "SELECT to_regclass('work.blockers'), to_regclass('work.client_compliance_currency');"
```
