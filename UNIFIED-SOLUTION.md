# Trikato OS — Unified Solution

## System Purpose

Trikato OS should be one operating system for the accounting firm, not a set of disconnected tools.

Grounded purpose from the repo:

- intake documents from worker environments and customer shares
- organize and process them through the accounting pipeline
- keep client, period, blocker, reminder, compliance, and approval state in one canonical model
- surface that state to operators and leads through Baserow and purpose-built UI pages
- hand approved accounting output to Merit and related delivery channels

The repo already contains the major fragments:

- a working invoice/accounting pipeline
- a working onboarding service
- a working canonical PostgreSQL schema plus UI views
- a strong Notion-derived ops blueprint
- static Trikato OS screens showing the intended worker experience

The unified solution is therefore not “invent a new system.” It is:

1. keep the real pipeline
2. keep the canonical PostgreSQL model
3. keep Baserow as the operational projection and editing surface
4. absorb the Notion action/reminder patterns into the canonical model
5. connect onboarding, intake, approval, reminders, and compliance into one action-driven flow

## Major Modules

### 1. Onboarding and Client Setup

Purpose:

- create or enrich the client master record
- establish legal/company truth
- generate the accounting service agreement
- create the first operational footprint in the OS

Grounding:

- `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md`
- `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/company_details.py`
- `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/template_filler.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/contract_client.py`

Unified role:

- the onboarding plugin remains a specialized service, not the main OS UI
- it owns company lookup, legal enrichment, and contract generation
- after onboarding, Trikato OS must create/update:
  - `core.clients`
  - `core.client_contacts`
  - `core.client_attributes`
  - `core.client_service_enrollments`
  - initial `work.work_items` / `work.work_periods`

Recommended addition:

- an onboarding handoff job that takes the plugin response and writes the canonical client record and first service setup

### 2. Source Intake

Purpose:

- ingest accounting documents from the real worker environment
- preserve source context: worker, client root, period, bucket, channel

Grounding:

- `/home/martin/Trikato/User-tools/accounting-pipeline/src/drive_client.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/drive_fetch.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py`
- `/home/martin/Trikato/User-tools/trikato-os/START.md`
- `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md`

Unified role:

- near-term intake remains a mix of local/incoming folder, Drive fetch, and worker-managed source folders
- medium-term intake becomes:
  - DWD worker sync
  - Gmail attachment intake
  - add-on initiated intake from Gmail/Drive

Canonical write targets:

- `source.source_accounts`
- `source.source_client_roots`
- `source.source_period_folders`
- `source.source_document_buckets`
- `source.documents`
- `audit.sync_runs`
- `audit.sync_run_items`

Recommended addition:

- build the missing sync/API layer:
  - `src/baserow_client.py`
  - sync service / manifest
  - pipeline server + queue worker

### 3. Canonical Data Layer

Purpose:

- hold one authoritative model of clients, documents, work, accounting data, reminders, blockers, compliance, and outputs

Grounding:

- `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`
- `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py`

Unified rule:

- PostgreSQL is the source of truth
- Baserow is a projection and operator tool over `ui.*` views
- static HTML pages are design references, not the runtime source of truth
- Example-Notion is the strongest current reference for action semantics, but not the canonical backend

Core canonical modules:

- `core.*` = clients, workers, contacts, service enrollments, attributes
- `source.*` = source account structure and file inventory
- `work.*` = work periods, work items, requirements, notes, blockers, lifecycle, compliance currency
- `sales.*` = sales invoices and article imports
- `accounting.*` = purchase invoices, bank transactions, matches, Merit submissions, compliance obligations
- `ops.*` = tasks, communications, document requests, checklists
- `workflow.*` and `audit.*` = jobs, attempts, pipeline runs, trace events
- `ui.*` = operator-facing read views

Field-level semantics proven by the Example-Notion export:

- `Clients` proves the operator surface needs onboarding date, services, payment terms, primary contact, and lifecycle status
- `Engagements` proves the work container needs health, priority, service type, due date, and linked tasks/requests
- `Tasks` proves actions need owner, blocked reason, task type, due date, notes, and time estimate
- `Document Requests` proves missing-input tracking needs requested date, received date, request channel, notes, and explicit status
- `Communications` proves contact logging needs direction, follow-up due, follow-up needed, owner, and summary
- `SOPs & Checklists` proves operator templates/checklists are part of the real workflow, not optional documentation

### 4. Accounting Pipeline

Purpose:

- turn source documents into classified, validated, reviewed accounting output

Grounding:

- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py`
- `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/*.py`

Current real sequence:

1. `drive_fetch`
2. `ingest`
3. `organizer`
4. `bank_parser`
5. `invoice_extract`
6. `reconciler`
7. `persist_json`
8. `human_approval`
9. `merit_submit`
10. `email_draft`
11. `html_report`

Unified role:

- keep this as the document/accounting engine
- do not redesign the node chain as the main architectural move
- wrap it with better intake, approval, and action orchestration

### 5. Action Engine

Purpose:

- convert findings, missing inputs, approvals, and deadlines into trackable actions

This is the missing middle layer and should be the center of the unified system.

The repo already gives the building blocks:

- `work.work_items`
- `work.work_requirements`
- `work.blockers`
- `ops.tasks`
- `ops.communications`
- `ops.document_requests`
- `workflow.jobs`
- `workflow.pipeline_runs`

The Notion export adds the concrete semantics the canonical model should preserve:

- `ops.tasks` should carry at least owner, task type, blocked reason, due date, notes, and time estimate
- `ops.document_requests` should carry request channel, requested date, received date, due date, status, and notes
- `ops.communications` should carry channel, direction, follow-up due, follow-up needed, owner, and summary
- `work.work_items` should expose engagement health, priority, service type, and current status in the operator UI
- `ui.v_client_profile` should expose onboarding date, services, billing/payment expectations, primary contact, and lifecycle status

The unified action engine should normalize all of these cases:

1. missing client document
2. OCR confidence / anomaly review
3. approval required before Merit submission
4. deadline approaching
5. client response overdue
6. partner escalation required
7. onboarding follow-up

Recommended operating pattern:

- `work.work_items` = durable engagement-period work container
- `ops.document_requests` = explicit requested missing inputs
- `work.blockers` = unresolved issues preventing progress
- `ops.tasks` = internal operator work
- `ops.communications` = customer/internal touchpoints
- `workflow.jobs` = machine-executed jobs

Recommended additions:

- action generator rules:
  - OCR flag → task or blocker
  - missing document → document request + optional communication
  - stale request → reminder task + communication draft
  - approved invoice → job to submit to Merit
  - no reply after reminder threshold → partner escalation blocker
- transition rules:
  - `requested` → `awaiting_response` → `received` or `no_response`
  - `open` blocker → `awaiting_response` → `resolved` or `dropped`
  - approval `pending` → `approved` or `rejected`

## User Journeys

### Journey 1: Onboard customer

1. Operator searches company in onboarding service.
2. Service returns authoritative legal/company data.
3. Operator fills/generates accounting agreement.
4. Handoff creates canonical client record and service setup.
5. First work items, compliance defaults, and client profile become available in Baserow/UI.

Current state:

- steps 1–3 exist
- steps 4–5 are only partial/planned

### Journey 2: Monthly bookkeeping close

1. Documents arrive through worker source folders, Gmail, or add-on/manual intake.
2. Source inventory writes source records and routes the file into the pipeline.
3. Pipeline organizes, parses, extracts, and reconciles.
4. Low-confidence or anomalous items become review actions.
5. Missing inputs become document requests/blockers.
6. Approved items go to Merit where applicable.
7. Reports and operational state become visible in Baserow/UI.

Current state:

- steps 2–4 exist in pieces
- steps 5–7 are only partially unified

### Journey 3: Missing-document reminder loop

1. Work item detects missing bank/ost/müük/payroll input.
2. System creates `ops.document_requests` record.
3. System optionally drafts/sends customer communication.
4. Reminder schedule is tracked through `contacted_at`, `last_reminded_at`, `response_status`.
5. When the client responds or the document arrives, request closes and blocker resolves.

Current state:

- data structures and blueprint exist
- the actual reminder loop does not

### Journey 4: OCR validation and accounting submission

1. OCR extracts invoice.
2. Cross-check flags are generated.
3. Reviewer confirms or edits extracted fields.
4. Approved invoice is submitted to Merit.
5. Submission result and BillId are stored and visible.

Current state:

- steps 1, 2, 4 exist
- step 3 exists only in CLI
- step 5 exists only partially in artifacts / docs, not in a unified operator surface

### Journey 5: Compliance and annual report control

1. Client is classified into monthly / annual-only / payroll-only / one-off service tier.
2. Work items and compliance currency indicate what period is due or lagging.
3. Annual-report and monthly-compliance views surface blockers, due dates, and waiting states.
4. Partner escalation occurs when approvals or client responses stall.

Current state:

- data model and views exist
- operator HTML exists conceptually
- escalation workflow is not operationalized

## Unified Feature Map

| Unified module | Primary canonical tables/views | Primary code/services | Primary UI surface |
|---|---|---|---|
| Onboarding | `core.clients`, `core.client_contacts`, `core.client_attributes`, `core.client_service_enrollments` | Auto_Complete_Service, `contract_client.py` | future onboarding flow in Baserow/OS |
| Source intake | `source.*`, `audit.sync_*`, `workflow.jobs` | `drive_client.py`, future DWD/Gmail/add-on sync | Baserow intake tables, future live intake dashboard |
| Processing | `accounting.*`, `workflow.pipeline_runs`, artifacts | 11-node pipeline | work queue, OCR review, reports |
| Action engine | `work.work_items`, `work.work_requirements`, `work.blockers`, `ops.tasks`, `ops.document_requests`, `ops.communications` | currently missing orchestration | queue, dossier, blockers, reminders, communications, follow-up ownership |
| Compliance | `accounting.compliance_obligations`, `work.client_compliance_currency`, `ui.v_monthly_compliance`, `ui.v_annual_report_tracker`, `ui.v_compliance_gaps` | importer + future calculators | `vastavus` screen, Baserow compliance views |
| Client memory | `ui.v_client_profile`, notes, comms, requests | importer + future aggregation | `klienditoimik` screen, Baserow client profiles |
| Delivery | `accounting.merit_submissions`, output artifacts, source docs with `document_role` | `merit_submit.py`, `html_report.py`, `email_draft.py` | report links, submission status, customer follow-up |

## Recommended Unified Runtime Surfaces

### 1. Baserow becomes the live operator surface

Use Baserow over `ui.*` for:

- daily monthly queue
- open blockers
- open document requests
- compliance gaps
- annual report tracker
- client profiles

Reason:

- these views already exist
- Baserow workspace tables are already partially created
- this is the shortest path to a usable operations product

### 2. Static Trikato OS HTML becomes a design/product spec

Use the static pages to shape:

- terminology
- page hierarchy
- worker mental model
- future custom front-end

But do not treat static HTML as the runtime system until it is wired to live data and actions.

### 3. Onboarding plugin stays specialized

Keep the plugin as a focused onboarding/legal-data/contract tool.

Do not merge its generic test UI into the main operator shell.

## Integrations

### Real integrations already present

- Google Drive
- Merit Aktiva
- Estonian Business Register autocomplete
- Estonian Business Register SOAP detail API
- Maksuamet/EMTA service
- ORC_LLM_Vision OCR stack

### Integrations that must be added or finished

- Baserow write client
- Gmail intake
- DWD sync
- add-on custom step handlers
- queue/API wrapper around pipeline
- reminder sending channel(s)

## Operator and Admin Workflows

### Operator

- see personal monthly queue
- see owned tasks with blocked reason, task type, and time estimate
- see blockers and stale requests
- see document requests by channel, requested date, received date, and follow-up due
- review OCR issues
- review client dossier
- send reminder or log customer contact
- approve accounting output

### Team lead / partner

- view risk/blocked annual reports
- inspect compliance gaps
- resolve escalations
- monitor workload and stale blockers

### Admin / system operator

- monitor sync runs and job events
- manage intake sources
- manage service tiers and worker mappings
- monitor Baserow sync and view health

## Compliance and Validation Flow

The unified system should split compliance into two layers:

### Period execution layer

- monthly bookkeeping / payroll / KMD / TSD work items
- request missing docs
- track waiting_on / blockers
- file / close when ready

### obligation currency layer

- `work.client_compliance_currency`
- `accounting.compliance_obligations`
- compliance gap views
- annual report tracker

This matters because Trikato OS needs to answer two different questions:

1. “What am I doing right now for this client and period?”
2. “What is overdue or unfiled at the compliance level?”

The current schema is already close to this distinction. The UI should respect it.

## Missing Components and Recommended Additions

### Highest-value additions

1. Implement the action engine on top of existing canonical tables.
2. Implement the missing Baserow/client write path.
3. Replace CLI approval with async approval in Baserow or equivalent live UI.
4. Implement missing-document reminder automation.
5. Finish importer P2 work so blockers, service tiers, and compliance currency are populated correctly.
6. Add onboarding handoff into canonical DB.
7. Add intake sync/API layer for DWD and Gmail.

### Specific recommended modules

| Module | Why |
|---|---|
| `src/baserow_client.py` | missing write path to Baserow / Client Manager |
| sync service (`sync_manifest.py` or equivalent) | source inventory + dedup + source-document creation |
| pipeline API wrapper | job-based execution, status inspection, add-on/Studio entrypoint |
| action rules engine | convert pipeline findings and missing docs into tasks/requests/blockers |
| reminder dispatcher | operational follow-up instead of passive draft generation |
| approval handler | async approval and downstream resume |
| onboarding handoff worker | turn contract-service output into canonical client setup |

## Final Assessment

### What exists already

- working accounting pipeline
- working onboarding service
- working canonical SQL schema
- working `ui.*` operational views
- working importer for workbook and Merilin drive copy
- Baserow external tables over major views
- a concrete Example-Notion action blueprint with clients, engagements, tasks, document requests, communications, invoices, and SOPs
- static Trikato OS screens with a strong worker-first information architecture

### What is half-built

- Baserow as true client/action manager
- onboarding handoff into canonical DB
- OCR validation as a web workflow
- blocker and document-request population
- compliance-currency enrichment
- worker-wide intake automation
- reminder/follow-up operations
- static UI mirroring of the full task/request/communication semantics

### What is missing

- real action engine
- Baserow/runtime write path
- Gmail sync
- DWD sync
- add-on implementation
- async approval flow
- automated reminder sending
- pipeline API/queue wrapper
- preservation of Notion-proven action semantics in live Baserow/runtime surfaces

### What should be added to make this a real unified OS

1. Make PostgreSQL the unquestioned canonical backend and Baserow the operational editing surface.
2. Use the existing `ops.*`, `work.*`, and `workflow.*` tables to build the missing action layer.
3. Wire onboarding, intake, OCR review, reminders, compliance, and Merit submission through that action layer.
4. Preserve the Notion-proven field semantics when doing so: owner, blocked reason, task type, request channel, requested/received dates, follow-up due, engagement health, and client lifecycle fields.
5. Treat the static HTML as the design/experience reference, not the live system, until data and actions are connected.
6. Finish the integration layer so every important event writes into the canonical model and becomes visible in Baserow/UI.
