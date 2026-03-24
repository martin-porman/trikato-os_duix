# Trikato OS Feature Inventory

Scope audited from real files:

- `/home/martin/Trikato/trikato-os/solution.2./index.html`
- `/home/martin/Trikato/trikato-os/vastavus.html`
- `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`
- `/home/martin/Trikato/User-tools/Example-Notion/Accounting`
- `/home/martin/Trikato/User-tools/accounting-pipeline`
- `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`
- `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`
- `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service`

Status vocabulary used in this inventory:

- `implemented` = real code/schema/view exists and is grounded in inspected files
- `partial` = some real pieces exist, but the end-to-end feature is incomplete
- `planned` = explicitly specified in docs/tasks, but implementation is absent
- `implied` = strongly suggested by structure/docs/UI, but not materially implemented
- `missing` = called for by the operating model, but not found

Verification note:

- the user-supplied path `/home/martin/Trikato/User-tools/Example-Notion/Accounting/328050f4229f807085fedfe90ba70bec.html` was not found during audit
- Example-Notion findings below are grounded only in files that were actually present and read

## Customer Onboarding

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Company autocomplete | Search Estonian Business Register by company name | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/main.py`, `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/autocomplete.py` | Estonian public autocomplete API, FastAPI service | None for basic lookup |
| Company legal enrichment | Fetch legal/company data, VAT, board, shareholders via SOAP | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/company_details.py`, `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md` | SOAP credentials, SOAP API | Should write into canonical client records automatically |
| Contract generation | Fill `AccountingServiceAgreement2025.html` with company data | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/template_filler.py` | Contract template, company details service | No signed-contract workflow or canonical handoff |
| Onboarding temp preview state | Save temp JSON for preview/edit and test-save output | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/main.py`, `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/temp/` | Local temp storage | Not part of core Trikato OS workflow |
| Onboarding service role in OS | Plugin is explicitly defined as the one-time client onboarding service | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md` | `accounting-pipeline/src/contract_client.py` | Needs formal downstream write into canonical DB and ops workflow |
| Canonical onboarding write-back | Populate `core.clients` and related legal fields from onboarding | partial | `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` (`3.P2-I`), `/home/martin/Trikato/User-tools/accounting-pipeline/src/contract_client.py` | Contract service, canonical DB | Tasked but not implemented in importer or pipeline |
| Onboarding PDF/email/send flow | Save PDF, email contract, store in Baserow | planned | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/Autocomplete.md` | PDF renderer, SMTP, Baserow storage | Not present in service code |

## Source Intake

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Drive fetch inside pipeline | Pipeline can fetch matching files from Google Drive or use local/incoming path | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/drive_fetch.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/drive_client.py` | Google Drive API, OAuth/service account | Shared Drive support still incomplete |
| Incoming folder ingestion | Drop local/incoming files and run pipeline | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/run.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py` | File watcher, local filesystem | Watcher recursion bug still documented |
| Watched intake automation | `watcher.py` auto-runs `run.py --incoming` on new file | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py` | watchdog | `recursive=False` means nested intake is incomplete |
| Shared Drive support | Search and fetch from shared drives | partial | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/drive_client.py` | Google Drive flags like `supportsAllDrives` | Not fully present in current code |
| Gmail attachment intake | Poll/watch Gmail for invoice attachments | planned | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Gmail API, OAuth scope, client routing | `gmail_sync.py` not found |
| Worker-wide DWD sync | Enumerate all workers and automate background sync | planned | `/home/martin/Trikato/User-tools/trikato-os/START.md`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md`, `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md` | DWD service account, Admin SDK | `sync_all_workers.py` and related sync implementation not found |
| Google Workspace Add-on intake | User-initiated Drive/Gmail “send to pipeline” actions | planned | `/home/martin/Trikato/User-tools/trikato-os/START.md`, `/home/martin/Trikato/User-tools/FLOWCHART.md`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | Cloudflare/public endpoint, add-on manifest | No add-on code found in audited paths |
| Workspace Studio custom flows | No-code file/email routing and task creation | partial | `/home/martin/Trikato/User-tools/trikato-os/START.md`, `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md` | Workspace Studio, custom steps | Only documented/stopped flow; no custom step implementation found |

## OCR, Parsing, and Document Processing

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| ZIP extraction / ingest | Extract ZIPs or copy files into work directory | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/ingest.py` | Local work directory | None for current local flow |
| File organization and renaming | Categorize into Müük/Ost/Pank/Raamatupidamine/Vajab ülevaatust | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/organizer.py` | pdfplumber, DOCX parsing | Keyword model is heuristic, not action-aware |
| Bank statement parsing | Parse bank PDFs and camt.053 XML into structured transactions | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/bank_parser.py` | `pdftotext`, XML parser | Some bank format coverage remains heuristic |
| OCR invoice extraction | LLM-powered invoice extraction through ORC_LLM_Vision | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/invoice_extract.py` | `/home/martin/Trikato/Extraction/ORC_LLM_Vision` | Needs web-based validation surface |
| Invoice math validation | VAT, total, and line-item cross-checks with flags | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/invoice_extract.py` | OCR output | Flags are produced, but not routed into an action layer |
| OCR validation queue | Human review of low-confidence or mismatched OCR results | partial | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/human_approval.py`, `/home/martin/Trikato/trikato-os/solution.2./toovoog.html` | OCR output, review UI | Real implementation is CLI only; Trikato OS UI is static/mock |

## Accounting Pipeline and Delivery

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Sequential pipeline orchestration | 11-node LangGraph pipeline with shared state | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/state.py` | LangGraph | Broader business-state transitions are not modeled |
| Invoice-bank reconciliation | Match invoices to bank transactions with status outcomes | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/reconciler.py` | rapidfuzz, parsed bank data | Match outcomes are not yet feeding blocker/task creation |
| State snapshot persistence | Save run state JSON as `pending_approval` | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/persist_json.py` | Filesystem output | No canonical DB write path yet |
| Human approval step | Approve/reject/edit invoice data before submission | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/human_approval.py` | CLI input | Blocks automation; should become async web/Baserow approval |
| Merit Aktiva submission | Submit approved purchase invoices to Merit | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/merit_submit.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/merit_client.py` | Merit credentials | Only purchase invoice path; no broader accounting-software export layer |
| Missing-data email drafts | Generate Estonian HTML requests for missing invoice fields | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/email_draft.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/templates/email_missing.html.j2` | Jinja2 | Drafts are generated, but no send/log/reminder engine |
| HTML reconciliation report | Render vastavus-style report | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/html_report.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/templates/report_vastavus.html.j2` | Jinja2 | Report is file output, not wired into live UI |
| Send data to accounting software | Operational accounting output to Merit | partial | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/merit_submit.py` | Approved invoices, Merit API | Only one integration path is implemented |
| EMTA/Maksuamet data retrieval | Quarterly financial snapshot client | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/maksuamet_client.py`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Maksuamet service | Not yet wired into canonical client tables |

## Canonical Data Model and Baserow / Database Layer

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Canonical PostgreSQL model | Multi-schema model for core/source/workflow/work/sales/accounting/ops/audit/ui | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | PostgreSQL `trikato` DB | Continue importer backfill and application usage |
| Baserow-facing SQL views | Operational projection layer via `ui.*` views | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | PostgreSQL, Baserow external DB sync | Needs sustained write-back and UI config completion |
| Workbook and drive-copy importer | Import workbook reality and Merilin folder structure into canonical tables | implemented | `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py` | openpyxl, PostgreSQL | Priority-2 enrichments still pending |
| Service tier / engagement health / waiting_on | Operational metadata for work queue and client segmentation | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | Canonical DB | Needs importer population rules to become meaningful |
| Blocker table | Formal blocker queue modeled from `Pooleli olevad asjad.xlsx` | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | `work.blockers` | Import into it is still incomplete |
| Document requests / communications / tasks / checklists tables | Action-oriented ops tables matching Notion blueprint | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | `ops.*` tables | Most are schema-only today, not populated by automation |
| Compliance currency tracking | Track latest filed month/year for TSD/KMD/AA | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | `work.client_compliance_currency` | Folder-name parsing/backfill still pending |
| Baserow operational workspace | External tables synced from `ui.*` views in Baserow | partial | `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` | Baserow external DB sync | Some views are live, but key rows remain zero and no write path exists |
| Baserow write client | App/API client for writing pipeline and sync results into Baserow | missing | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` mentions `src/baserow_client.py`; file not found | Baserow token, REST client | Implement actual write path |

## Action Layer, Reminders, and Workflow Control

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Work items and requirements | Service-period work objects with requirement statuses | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | `work.work_items`, `work.work_requirements` | Need automatic state changes from events |
| Reminder metadata on doc requests | Track contact channel, reminder time, and response status | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | `ops.document_requests` | No service currently sends or updates reminders |
| Blocker contact tracking | Track contact channel, contacted time, response time, resolution | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | `work.blockers` | Needs automation and importer backfill |
| Open blockers queue | Surface stale unresolved blockers | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`, `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` | `ui.v_open_blockers` | No data loaded yet (`0` rows in Baserow snapshot) |
| Open document request queue | Surface overdue requests and reminders | implemented | `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`, `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` | `ui.v_open_document_requests` | No data loaded yet (`0` rows in Baserow snapshot) |
| Send reminder to customer | Outbound follow-up action over email/WhatsApp/phone/portal | partial | Notion shows the pattern in `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.csv`; DB has fields in `ops.document_requests` | `ops.document_requests`, `ops.communications`, task ownership | No actual sender/automation found |
| Action engine / state transitions | Reusable model for “create action → wait → remind → unblock → resume pipeline” | missing | Pipeline is only linear in `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py`; action tables exist in SQL but no orchestration code found | `ops.*`, `work.*`, `workflow.*` | Build orchestration rules and triggers |
| Baserow-based async approval | Replace CLI approval with web/row-driven approval | planned | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Baserow write client, webhooks, pipeline resume | No implementation found |

## UI Pages, Dashboards, and Operator Surfaces

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| Overview dashboard | Static worker-first command center | implemented | `/home/martin/Trikato/trikato-os/solution.2./index.html` | Shared CSS/JS | Not live-data-backed |
| Workflow queue page | Static queue showing engagements, tasks, document requests, OCR approval, blockers, period view, and communications follow-up | implemented | `/home/martin/Trikato/trikato-os/solution.2./toovoog.html`, `/home/martin/Trikato/trikato-os/toovoog.html` | Shared CSS/JS | Not wired to `ui.*` or live actions |
| Compliance page | Static deadlines, monthly matrix, annual report tracker, escalation | implemented | `/home/martin/Trikato/trikato-os/vastavus.html`, `/home/martin/Trikato/trikato-os/solution.2./vastavus.html` | Shared CSS/JS | Not wired to `ui.v_monthly_compliance`/`ui.v_annual_report_tracker` |
| Client dossier page | Static client lifecycle, engagement, request, communication, document, report, and note surface | implemented | `/home/martin/Trikato/trikato-os/solution.2./klienditoimik.html`, `/home/martin/Trikato/trikato-os/klienditoimik.html` | Shared CSS/JS | Not wired to `ui.v_client_profile`, tasks, requests, comms |
| Baserow work queue UI | Live queue views over SQL projections | partial | `/home/martin/Trikato/User-tools/trikato-os/work-07-baserow-ui.md`, `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` | External DB sync | Configuration exists in part; operational write-back is absent |
| Onboarding plugin web page | Generic test/demo page for contract service | implemented but non-core | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/page/index.html` | FastAPI service | Treat as plugin test UI, not Trikato OS core surface |

## Notion Blueprint Features

| Feature | Description | Status | Evidence path(s) | Related dependencies | Missing parts / next step |
|---|---|---|---|---|---|
| 9-domain operating blueprint | Clients, Engagements, Tasks, Document Requests, Documents, Communications, Compliance Calendar, Invoices, SOPs | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting` | Notion export only | This is the strongest current action-model reference, but not the canonical backend |
| Engagement-centered work model | Client work is organized around linked engagement records with due date, health, priority, service type, and status | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Engagements 328050f4229f817ca00bfce2ff60b125.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Engagements/Redwood Coffee — Monthly Bookkeeping (Feb 2026) 328050f4229f819c9188f14e622d042b.html` | Linked client/tasks/requests | Canonical mapping should be `work.work_items` + `work.work_periods` with explicit health/priority semantics |
| Task/action semantics | Tasks carry owner, due date, blocked reason, task type, notes, and time estimate | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks/Send doc request reminder depreciation schedule 328050f4229f8193b8d0d67fa00793cc.html` | Linked engagement/client work | Canonical `ops.tasks` should preserve these fields and drive UI/action rules |
| Document request lifecycle semantics | Requests carry requested date, received date, request channel, notes, due date, and status | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Document Requests 328050f4229f81c38a85e23c5109df85.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Document Requests 328050f4229f81c38a85e23c5109df85.html` | Linked engagement/client work | Canonical `ops.document_requests` should preserve these lifecycle semantics |
| Reminder/follow-up pattern | Communications + tasks + document requests carry follow-up dates, channels, and “follow-up needed” flags | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv` | Linked client work records | Needs canonical implementation and automation |
| Client lifecycle metadata | Clients carry onboarding date, billing type, payment terms, services, status, and primary contact | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Clients 328050f4229f813e8af0d5ce896b50de.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Clients/Redwood Coffee Roasters LLC 328050f4229f813e99b0c7c1adba9e77.html` | Client master and CRM layer | Canonical `core.*` and `ui.v_client_profile` should expose these fields explicitly |
| SOP/template support | Standardized checklists and email templates | implemented as reference | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists 328050f4229f812cb40fe7f944b6b47d.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists/Client Document Request Email Template 328050f4229f81799545dc572b87799c.html`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists/Monthly Bookkeeping Close SOP 328050f4229f8167b225f31177e2a2a0.html` | SOP/checklist library | Canonical `ops.checklists` exists but needs content, template linkage, and UI |

## Summary by Explicitly Requested Missing Areas

| Requested area | Current finding | Status | Evidence path(s) |
|---|---|---|---|
| action layer | Canonical tables exist and Notion proves the needed task/request/communication semantics, but no orchestration engine exists | partial | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py` |
| send reminder to customer | Modeled concretely as task + document request + communication with channel/follow-up fields, but not automated | partial | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.csv`, `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` |
| onboard customer | Working lookup/fill service exists; canonical handoff incomplete | partial | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` |
| send papers/data to accounting software | Merit purchase-invoice submission exists | partial | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/merit_submit.py` |
| validate OCR | OCR extraction + math checks + CLI review exist | partial | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/invoice_extract.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/human_approval.py` |
| workflow automation/state transitions | Linear pipeline state exists; async business transitions do not | partial | `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/state.py`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py`, `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` |
| Baserow/database integration | Canonical DB and read views exist; runtime write path missing | partial | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`, `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` |
| onboarding plugin role | One-time legal/company onboarding and contract prep | implemented | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/contract_client.py` |
