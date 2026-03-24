# Trikato OS Gap Analysis

This comparison is grounded in:

- Static Trikato OS UI: `/home/martin/Trikato/trikato-os/solution.2./index.html`, `/home/martin/Trikato/trikato-os/solution.2./toovoog.html`, `/home/martin/Trikato/trikato-os/solution.2./klienditoimik.html`, `/home/martin/Trikato/trikato-os/vastavus.html`
- Canonical SQL/read layer: `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`
- Pipeline and importer: `/home/martin/Trikato/User-tools/accounting-pipeline`
- Architecture docs: `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, `/home/martin/Trikato/User-tools/trikato-os/START.md`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md`
- Example operating model: `/home/martin/Trikato/User-tools/Example-Notion/Accounting`
- Onboarding service: `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service`

## High-Level Comparison Matrix

| Area | Static UI | Pipeline code | Canonical DB / Baserow views | Docs / Notion / plugin | Assessment |
|---|---|---|---|---|---|
| Overview / operator dashboard | yes | no | partial | yes | UI exists, live-data wiring missing |
| Work queue / blockers / approvals | yes | partial | yes | yes | Concepts exist across all layers, but not unified |
| OCR extraction and review | partial | yes | partial | yes | Backend is real, review UX is still CLI/static |
| Missing-doc reminders | implied | partial | yes | yes | Data model exists, automation missing |
| Compliance and annual reports | yes | partial | yes | yes | Good model coverage, weak execution linkage |
| Customer onboarding | no Trikato OS page | partial | partial | yes | Separate plugin works, handoff into OS is missing |
| Baserow operational workspace | not in static UI | no write path | yes | yes | Read layer exists, action/write layer missing |
| Gmail / Drive worker-wide intake | implied | partial | audit tables exist | yes | Strategy is documented, implementation absent |
| Action engine / state transitions | implied by buttons | no | partial | yes | Biggest structural gap |

## Critical Correction on the Example-Notion Export

The Example-Notion export is not just a loose inspiration board.

Verified from actual CSV and HTML exports:

- `Tasks` carries `Blocked Reason`, `Owner`, `Status`, `Task Type`, and `Time Estimate (hrs)`
- `Document Requests` carries `Requested Date`, `Received Date`, `Request Channel`, and `Status`
- `Communications` carries `Direction`, `Follow-up due`, `Follow-up needed`, and `Owner`
- `Engagements` carries `Health`, `Priority`, `Service Type`, and linked requests/tasks
- `Clients` carries `Onboarding Date`, `Services`, `Payment Terms`, `Billing Type`, and `Status`

This means the Notion workspace already defines the manual action-layer semantics that Trikato OS still lacks operationally.

## Features Present in UI but Missing from Real Execution

| UI feature | UI evidence | Current backend reality | Gap |
|---|---|---|---|
| “Vajab kinnitust” OCR board | `/home/martin/Trikato/trikato-os/solution.2./toovoog.html` | Real approval is CLI-only in `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/human_approval.py` | No shared approval queue, no asynchronous approval state |
| “Helista kliendile”, “Kinnita”, “Esita”, “Jätka” actions | `/home/martin/Trikato/trikato-os/solution.2./toovoog.html`, `/home/martin/Trikato/trikato-os/vastavus.html` | Static links only; no action dispatcher or task execution layer found | Action layer is missing |
| Team workload panel | `/home/martin/Trikato/trikato-os/solution.2./index.html` | SQL has queues/views, but no computation layer or page binding for this exact panel | UI presentation outruns live implementation |
| Client timeline / dossier memory | `/home/martin/Trikato/trikato-os/solution.2./klienditoimik.html` | SQL has `work.work_notes`, `ops.communications`, `ops.document_requests`, but no assembled dossier app | UI concept is ahead of wired experience |
| Deadline escalation card | `/home/martin/Trikato/trikato-os/vastavus.html` | No partner escalation workflow code found | Escalation is represented visually, not operationally |

## Features Present in Code / Docs / Data Model but Missing from UI

| Backend / doc feature | Evidence | Current UI coverage | Gap |
|---|---|---|---|
| Onboarding contract/autocomplete service | `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md`, `/home/martin/Trikato/User-tools/accounting-pipeline/src/contract_client.py` | Not present in Trikato OS static UI | No onboarding journey in OS |
| EMTA quarterly enrichment | `/home/martin/Trikato/User-tools/accounting-pipeline/src/maksuamet_client.py`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Not surfaced | Missing financial-health or tax-snapshot views |
| Audit/sync/job schemas | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` (`workflow.*`, `audit.*`) | Not surfaced | No operator view of intake sync health or job failures |
| `ui.v_open_blockers`, `ui.v_open_document_requests`, `ui.v_compliance_gaps`, `ui.v_client_profile` | `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | Only partially mirrored in prototype pages | Static UI is not aligned to the best current live views |
| Notion action-model fields | `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Document Requests 328050f4229f81c38a85e23c5109df85.csv`, `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.csv` | Previously underrepresented in prototype UI; now mirrored only statically | Owner, blocked reason, task type, request channel, requested/received dates, and follow-up semantics still are not live-bound |
| Sales invoice import and headers/lines | `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py`, `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | Barely represented | Revenue/invoicing side is underrepresented in UI |
| Service-tier segmentation (`monthly`, `annual_only`, etc.) | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Not explicit in prototype pages | UI doesn’t distinguish operational cohorts |
| Workspace Studio / DWD / Add-on intake architecture | `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md`, `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | Not shown | Intake architecture is missing from product narrative |

## Features Present in Docs but Missing in Code

| Documented feature | Documentation evidence | Verification result |
|---|---|---|
| `src/baserow_client.py` | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | File not found |
| `sync_manifest.py` write path | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | `/home/martin/Trikato/User-tools/accounting-pipeline/src/sync_manifest.py` not found |
| `gmail_sync.py` | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | File not found |
| `merilin_sync.py` | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | File not found |
| Pipeline server `pipeline/main.py` | `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | File not found |
| `queue_worker.py` | `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | File not found |
| Add-on implementation | `/home/martin/Trikato/User-tools/trikato-os/TASKS.md`, `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md` | No add-on code found in audited paths |

## Features Present in Data Model but Barely or Not Populated

| Model / view | Evidence | Current observed state |
|---|---|---|
| `work.blockers` | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | Baserow row count snapshot shows `0` in `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` |
| `ops.document_requests` via `ui.v_open_document_requests` | `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | Baserow row count snapshot shows `0` |
| Reminder metadata (`last_reminded_at`, `response_status`) | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | Schema exists; no automation populating it found |
| Compliance currency tracking | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | View exists and returns rows, but P2 folder/workbook enrichment is still pending |
| `service_tier` segmentation | `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`, `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24.md` | Defaulted to `monthly`; richer classification still pending |

## Partially Implemented End-to-End Flows

### 1. Customer onboarding

- What exists:
  - autocomplete, company enrichment, contract fill service
  - pipeline wrapper client in `contract_client.py`
- What is missing:
  - automatic creation/update of `core.clients`
  - service enrollments from onboarding
  - signed contract / PDF / status lifecycle
  - onboarding surfaced in Trikato OS UI

### 2. Missing-document reminder flow

- What exists:
  - Notion blueprint for requests, follow-up due, follow-up needed, communications
  - concrete task semantics: owner, blocked reason, task type, time estimate
  - concrete request semantics: requested date, received date, request channel
  - canonical `ops.document_requests`, `ops.communications`, `work.blockers`
  - email draft generation for missing invoice fields
- What is missing:
  - actual reminder sender
  - reminder scheduling
  - communication log write-back
  - automatic unblock/resume when data arrives

### 3. OCR validation flow

- What exists:
  - OCR extraction
  - confidence/cross-check flags
  - CLI approval
  - static UI concept for OCR review
- What is missing:
  - persistent approval queue
  - reviewer ownership/SLA
  - approve/reject actions in Baserow/UI
  - webhook/queue resume into `merit_submit`

### 4. Baserow/database integration

- What exists:
  - canonical PostgreSQL model
  - 14 `ui.*` views
  - Baserow external tables created over views
- What is missing:
  - write path from pipeline or sync into canonical ops tables
  - real use of Baserow as action/approval hub
  - runtime reconciliation between pipeline artifacts and Baserow state

### 5. Worker-wide intake automation

- What exists:
  - local watcher
  - Drive fetch in pipeline
  - docs for DWD/add-on/Studio
- What is missing:
  - worker sync service
  - Gmail sync
  - route-to-client automation
  - job queue/service API

## Broken Flow Links

These are not broken HTML anchors. These are broken system handoffs.

| Intended flow | Evidence of intent | Verified break |
|---|---|---|
| Source file arrives → canonical job record → pipeline run → ops/action surface | `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md`, `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | No `pipeline/main.py`, no `queue_worker.py`, no `sync_manifest.py`, no runtime Baserow client |
| OCR flags → approval queue → approval action → Merit submission | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, static UI pages | Approval still happens only in CLI |
| Missing docs → document request → reminder → response → unblock | Notion export, SQL schema, prototype UI | No automation or write path found |
| Onboarding plugin → canonical client record → service enrollments → first engagement/work item | plugin README, `contract_client.py`, `TASKS.md` | Handoff into canonical DB is only planned |
| Baserow as “Client Manager” | `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`, `/home/martin/Trikato/User-tools/trikato-os/START.md` | Baserow currently reads views; it does not yet control the system |

## Duplicated Concepts with Different Names

| Normalized concept | Names currently used | Evidence |
|---|---|---|
| Client work package | `Engagements`, `work_items`, static UI “Pooleli” items | Example-Notion CSV, `work.work_items`, prototype HTML |
| Missing-doc follow-up | `Document Requests`, `Puuduvad dokumendid`, `Blokeeringud`, email drafts | Notion export, SQL schema, prototype UI, `email_draft.py` |
| Compliance tracker | `Compliance Calendar`, `Monthly Compliance`, `Vastavus`, `Annual Reports`, `client_compliance_currency` | Notion export, SQL views, prototype HTML |
| Approval state | `pending_approval`, `approval_status`, `Vajab kinnitamist`, `Kinnita` | `persist_json.py`, docs, prototype HTML |
| Client manager | `Baserow`, `Client Manager`, `Trikato teenused`, static Trikato OS UI | docs, implementation logs, UI files |
| Blocker registry | `Pooleli olevad asjad`, `work.blockers`, `Open Blockers`, `Blokeeringud` | workbook-driven docs, SQL, Baserow view, prototype UI |
| Internal action / follow-up | `Tasks`, `ops.tasks`, `Client Follow-up`, `Helista kliendile`, `Järgmine samm` | Notion export, SQL schema, prototype UI |

## Missing “Action Layer” Capabilities

These are the capabilities the repo clearly needs but does not yet provide end-to-end.

1. Create a first-class action when a blocker, reminder, validation issue, or approval need is detected.
2. Assign the action to a person, with due date, channel, and next-step semantics.
3. Send reminders to customers through the tracked channel and write the result back.
4. Convert inbound customer response into state change on the request/blocker/work item.
5. Resume downstream automation after approval or document receipt.
6. Escalate stale items to partner/internal reviewer with explicit workflow state.
7. Materialize the action layer in Baserow or another live UI instead of static HTML and CLI prompts.
8. Preserve field-level semantics already proven in Notion: owner, blocked reason, task type, time estimate, request channel, requested/received dates, follow-up due, follow-up needed, engagement health, and client lifecycle status.

## Conclusion

The strongest current assets are:

- the real pipeline
- the canonical schema and views
- the importer
- the onboarding service
- the Notion operational blueprint
- a concrete manual action model already proven in the Example-Notion export

The weakest link is the operational middle:

- no live action engine
- no write path tying pipeline results into Baserow/ops tables
- no real reminder or async approval loop

That middle layer is what must be unified next.
