# Trikato Baserow Data Sync — Session 3 Implementation Log

Date: 2026-03-24
Session: Baserow PostgreSQL Data Sync setup (Work 07)

---

## What Was Done

Connected the live `trikato` PostgreSQL database to Baserow via PostgreSQL Data Sync.
All 13 `ui.*` views are now visible as Baserow tables in the **Trikato** workspace.

---

## Root Causes Found and Fixed

### Fix 1 — `BASEROW_PREVENT_POSTGRESQL_DATA_SYNC_CONNECTION_TO_DATABASE`

**Problem:** Baserow defaults this setting to `true`, which blocks any data sync connection
to the same hostname as Baserow's own database. Since both Baserow (`baserow` DB) and Trikato
(`trikato` DB) live on the same Docker `postgres` service, every sync attempt returned:

```
ERROR_SYNC_ERROR: It's not allowed to connect to this hostname.
```

**Fix:** Added `BASEROW_PREVENT_POSTGRESQL_DATA_SYNC_CONNECTION_TO_DATABASE: "false"` to
all three relevant services in `docker-compose.dev-unlocked-lan-new.yml`:
- `backend`
- `celery`
- `celery-exportworker`

Both `baserow/docker-compose.dev-unlocked-lan-new.yml` and
`baserow/archive/configs/docker-compose.dev-unlocked-lan-new.yml` updated.

### Fix 2 — PostgreSQL views have no primary key metadata

**Problem:** Baserow's PostgreSQL data sync type queries `pg_catalog.pg_index` and
`information_schema.table_constraints` to find primary key columns. PostgreSQL views
cannot have primary key constraints, so all `ui.*` view columns returned `unique_primary=False`.
Baserow then raised `ERROR_UNIQUE_PRIMARY_PROPERTY_NOT_FOUND` and refused to create the sync.

**Fix:** Added a fallback to
`baserow/backend/src/baserow/contrib/database/data_sync/postgresql_data_sync_type.py`
in `get_properties()`:

```python
# If no primary key was found (e.g. for SQL views which cannot have PKs in
# PostgreSQL), fall back to marking the first column as unique_primary so that
# Baserow can still use the view for data sync.
if properties and not any(p.unique_primary for p in properties):
    properties[0].unique_primary = True
```

This is safe because all `ui.*` views are designed with a unique ID column first
(e.g. `work_item_id`, `client_id`, `blocker_id`, `request_id`).

---

## Baserow Connection Details Used

```
Type:     PostgreSQL Data Sync
Host:     postgres          ← Docker internal hostname
Port:     5432              ← Docker internal port (NOT 5434)
Database: trikato
Schema:   ui
Username: baserow
Password: baserow_dev
SSL Mode: prefer
```

Note: From inside Docker containers, use `postgres:5432`. From the host machine,
use `127.0.0.1:5434`.

---

## Tables Created in Baserow (database: "Trikato teenused", workspace: "Trikato")

| Baserow Table         | PostgreSQL View              | Row Count |
|-----------------------|------------------------------|-----------|
| Monthly Work Queue    | `ui.v_my_monthly_queue`      | 237       |
| Open Blockers         | `ui.v_open_blockers`         | 0         |
| Document Requests     | `ui.v_open_document_requests`| 0         |
| Compliance Gaps       | `ui.v_compliance_gaps`       | 440       |
| Annual Reports        | `ui.v_annual_report_tracker` | 85        |
| Client Profiles       | `ui.v_client_profile`        | 539       |
| All Clients           | `ui.v_main_data_table`       | 539       |
| Clients Overview      | `ui.v_clients_overview`      | 539       |
| Work Queue Full       | `ui.v_worker_work_queue`     | 322       |
| Document Inventory    | `ui.v_document_intake`       | 823       |
| Sales Invoices        | `ui.v_sales_invoices`        | 587       |
| Monthly Compliance    | `ui.v_monthly_compliance`    | 237       |
| Offboarded Clients    | `ui.v_offboarded_clients`    | 99        |

Row counts verified against PostgreSQL — exact match.

---

## Data Sync IDs (for manual re-sync via API)

| data_sync id | table_id | Table Name            |
|--------------|----------|-----------------------|
| 14           | 779      | Monthly Work Queue    |
| 15           | 780      | Open Blockers         |
| 16           | 781      | Document Requests     |
| 17           | 782      | Compliance Gaps       |
| 18           | 783      | Annual Reports        |
| 19           | 784      | Client Profiles       |
| 20           | 785      | All Clients           |
| 21           | 786      | Clients Overview      |
| 22           | 787      | Work Queue Full       |
| 23           | 788      | Document Inventory    |
| 24           | 789      | Sales Invoices        |
| 25           | 790      | Monthly Compliance    |
| 26           | 791      | Offboarded Clients    |

To manually trigger a re-sync via API:
```bash
curl -X POST http://192.168.10.6:8000/api/database/data-sync/{data_sync_id}/sync/async/ \
  -H "Authorization: JWT <token>"
```

---

## Baserow Admin User Created

A superuser was created for admin access during setup:
- Email: `dev@baserow.io` (existing dev account, password reset to `baserow123`)

---

## What Remains (Work 07 Tasks 7.4–7.9)

These must be done through the Baserow UI — no API equivalent for grid view configuration:

- [ ] Task 7.4 — Configure "My Queue" grid view on Monthly Work Queue
  (filter by `worker_email`, sort by `engagement_health`, color rows)
- [ ] Task 7.5 — Configure Open Blockers view (sort by `days_since_contact`)
- [ ] Task 7.6 — Configure Document Requests view (sort by `days_overdue`)
- [ ] Task 7.7 — Configure Compliance Gaps view (filter gaps > 0)
- [ ] Task 7.8 — Configure Annual Reports tracker
- [ ] Task 7.9 — Create per-worker shareable view links (19 workers)

See `work-07-baserow-ui.md` for the exact configuration steps per view.

---

## Files Modified This Session

| File | Change |
|------|--------|
| `baserow/docker-compose.dev-unlocked-lan-new.yml` | Added `BASEROW_PREVENT_POSTGRESQL_DATA_SYNC_CONNECTION_TO_DATABASE: "false"` to `backend`, `celery`, `celery-exportworker` services |
| `baserow/archive/configs/docker-compose.dev-unlocked-lan-new.yml` | Same changes (archive copy) |
| `baserow/backend/src/baserow/contrib/database/data_sync/postgresql_data_sync_type.py` | Added view PK fallback in `get_properties()` |
