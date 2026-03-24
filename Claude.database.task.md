

Trikato Accounting Data Model — Research Memo
Date: 2026-03-24

Status: Research only — no files modified

Corpus inspected:

/home/martin/Trikato/User-tools/trikato-os/START.md
/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24.md
/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md
/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql (607 lines, full read)
/home/martin/Trikato/User-tools/trikato-os/sql/views.sql (369 lines, full read)
/home/martin/Trikato/User-tools/Example-Notion/README.md + all 9 DB schema docs
/home/martin/Trikato/User-tools/Example-Notion/output/schema/relations.json + full_schema.json
/home/martin/Trikato/User-tools/Example-Notion/output/diagrams/02_database_schema.md
/home/martin/Trikato/User-tools/Example-Notion/Accounting/Engagements *.csv
/home/martin/Trikato/Data_Source/Trikato/RAAMATUPIDAJA2 (AA, monthly).xlsx — all 6 sheets, headers + sample rows
/home/martin/Trikato/Data_Source/Merilin/Pooleli olevad asjad.xlsx — all 6 sheets, full content
/home/martin/Trikato/Data_Source/Merilin/ — root listing + deep folder inspection of: AA/, Koodireaktor OÜ 2024 OK/, Dragondev OÜ/, Grunder Ehitus OÜ/, W4nted Bodyparts OÜ/, Agile Management OÜ/, Veyrat Press OÜ/, LH Ventures OÜ/, Inforker OÜ AA-12.03.25 tegemata/
Not inspected (binary/image, noted): .jpg, .pdf files inside client folders; HTML source of Notion record pages; büroo.xlsx and Tabel klientidega.xlsx in AAA Tähtis info (structure similar to RAAMATUPIDAJA2, not read for time reasons).

1. Executive Summary
The current PostgreSQL schema is structurally sound but was designed top-down from an architectural ideal rather than bottom-up from how Estonian small-firm accountants actually work. The real data reveals three things the schema doesn't adequately model: (1) a two-tier client roster (monthly-service clients vs. annual-report-only clients) with fundamentally different workflows, (2) a compliance currency concept — every client has a "last completed month" marker for each filing type (TSD/KMD), not just binary done/not-done, and (3) a per-client freeform blocker queue where individual invoice anomalies and unanswered questions accumulate and require a dedicated data structure with client-response tracking.

The Example-Notion blueprint is useful for its engagement lifecycle model and its separation of document-request tracking from document storage, but it is an American tax-practice model. Its concepts of "Engagement Health" (On track / Risk / Blocked) and "Waiting on Client" as a distinct status are directly applicable and missing from the current schema. Its jurisdiction and billing-type fields are US-specific and not applicable.

The current ui.* view layer is too aggregated — it collapses everything into one wide row per client. Accountants managing 37+ clients each need a work-queue view per period, not a snapshot of the "latest" everything.

The recommended direction is an incremental evolution of the current schema, not a full rewrite. The core tables are good. The main gaps are: missing engagement_health field, missing compliance_currency concept, missing blocker entity, missing request_channel on document requests, and underdeveloped client-tier categorization.

2. What the Real Source Data Reveals
2.1 The Two-Tier Client Roster (Verified fact)
Source: /home/martin/Trikato/Data_Source/Trikato/RAAMATUPIDAJA2 (AA, monthly).xlsx, sheets Lepingulised kliendid (241 rows) and Aastaaruande kliendid (~205 rows).

The workbook is explicitly divided into two populations:

Lepingulised kliendid ("contracted clients"): monthly bookkeeping service. They have TSD/KMD compliance obligations tracked per month. They get monthly invoices. They send documents monthly.
Aastaaruande kliendid ("annual report clients"): annual report only. No monthly filings. They get one invoice per year. They send documents once a year or whenever prompted.
This is not just a service-enrollment difference. It's a fundamentally different workflow and cadence. The current schema can represent it via core.client_service_enrollments but does not make it a first-class citizen or enforce it in views.

A third sub-population exists within Lepingulised kliendid: some contracted clients file only TSD (payroll, no VAT), some file only KMD (VAT, no payroll), and some file both. This is encoded in the Klientide täpsem info sheet as: KMD=Jah/- and TSD=Jah/-.

2.2 Compliance Currency: Last-Filed-Month, Not Binary (Verified fact)
Source: Lepingulised kliendid TSD/KMD columns; To do list(enda omaga ühendada).

The TSD and KMD columns in the main client sheet contain values like TSD 08, KMD 04, KMD 08. These are last-completed-period markers — "the TSD for month 08 has been filed." A value of None for a monthly client means either the obligation doesn't apply, or there is a current gap.

The To do list(enda omaga ühendada) sheet (25 rows) uses a different encoding: TSD (pending), KMD (pending), - (not applicable). This is the action-needed view of the same data.

The current schema models compliance via work.work_requirements.requirement_status (missing/blocked/open/pending). This works for a point-in-time status but does not naturally express "last completed through month MM." A query to answer "which clients have a TSD gap for this month?" requires computing against the requirement records, not reading a field directly.

2.3 The Folder-Name Status Encoding (Verified fact)
Source: ls /home/martin/Trikato/Data_Source/Merilin/

Worker folder names actively encode compliance status. Observed patterns:

Koodireaktor OÜ 2024 OK — annual report for 2024 is done
Defency OÜ 2024 OK — same
Intelate OÜ 2024 OK — same
Jaroliann OÜ 2024 OK, dokid teha — 2024 done but documents still need to be created
Inforker OÜ AA-12.03.25 tegemata — annual report not done, deadline was 12 March 2025
Ef Record OÜ AA — annual report work in progress
The accountant uses folder renaming as a lightweight status system. When the sync_all_workers.py imports Drive structure, parsing these suffixes is critical and currently is not implemented in the import logic. The current schema stores these as folder_name in source.source_client_roots.folder_name but does not parse the status encoding out of them.

2.4 Document Folder Taxonomy (Verified fact)
Source: Deep inspection of Koodireaktor, Dragondev, Grunder, Veyrat folders.

The real folder hierarchy follows an consistent pattern with some variation:


<Client>/
  <YEAR>/              ← e.g., 2022, 2023, 2024
    Müük/              ← sales invoices (müügiarved)
    Ost/               ← purchase invoices (ostuarved)
    Pank/              ← bank statements
    Maksuamet/         ← tax authority filings
    Investeeringud/    ← investments (some clients)
    I poolaasta/       ← H1 sub-period
    II poolaasta/      ← H2 sub-period
    <report files>     ← Bilanss, Kasumiaruanne, Pearaamat, Päevaraamat PDFs
  <MM.YYYY>/           ← monthly period (some clients use this instead of year)
    Ostuarved/         ← same bucket inside monthly
    Maksuamet/
    <named files>

Naming conventions for individual documents:
  OA-N <vendor> <invoice_id>.pdf   ← purchase invoices (numbered)
  AR-N <vendor>.pdf                ← sales invoices
  KD-MM-YYYY.xml                   ← journal entries (kanded), Merit XML format
  <YYYYMMDD>_KMD<MMYYYY>.pdf       ← KMD (VAT return) submission
  palgaleht MM.YY.pdf              ← payroll slip
  statement.pdf / EE..._Account_Statement_YYYY-MM-DD.pdf ← bank statement
The current source.source_document_buckets.bucket_type is generic. It should use this vocabulary: müük, ost, pank, maksuamet, investeeringud, palgaleht, pearaamat_output (for generated output artifacts).

Critically: output artifacts (Bilanss, Kasumiaruanne, Pearaamat, Päevaraamat) are the products of the accounting work, not source input documents. They live at the year-folder level alongside, but semantically above, the input buckets. The current schema treats all files in source.documents uniformly; it has document_category but no distinction between "accountant-generated output" and "client-supplied input."

2.5 The Pooleli Workbook: A Freeform Blocker Queue (Verified fact)
Source: /home/martin/Trikato/Data_Source/Merilin/Pooleli olevad asjad.xlsx

Six sheets, one per active-issue client. Content is pure freeform but follows a pattern:


Row: "MA250005 - Küsimus, et miks..." | "Ei ole vastanud"
Row: "1. Circle K 329,02EUR"          | "olemas"
Row: "Endiselt on puudu ostuarveid"   |
Row: "Laenulepingute vormistamist ei ole näinud" |
The second column carries a response status: Ei ole vastanud (hasn't responded), olemas (present/available). The first column names the specific issue — often with an invoice identifier (e.g., MA250008).

This is a per-client, per-period issue log that tracks:

Specific anomalies in individual documents (wrong VAT rate on a specific invoice)
Missing physical documents not yet delivered
Legal/structural issues awaiting formalization
Work-in-progress notes (tehtud 551 kirjet = 551 entries done)
Client contact outcome (Ei ole vastanud = waiting for answer)
The current schema has work.work_notes (freeform text per work item) and ops.document_requests (structured missing-doc requests) and ops.tasks (general tasks). None of these capture the "I flagged an anomaly in invoice MA250008, I wrote to the client, they haven't responded" triad. ops.document_requests is the closest but lacks: issue type (anomaly vs. missing doc vs. structural problem), the contacted_at/last_response_at timestamps, and the response outcome.

2.6 Rich Client Notes as Institutional Memory (Verified fact)
Source: Klientide täpsem info sheet, 57 rows.

This sheet contains dense multi-paragraph notes per client. The Agrokeelva OÜ entry alone is ~500 words covering PRIA grants, two bank accounts, cash position, old receivables, a cross-company receipt issue, and a year-end inventory adjustment requirement.

Key recurring note types:

Accounting system quirks (Pearaamat saadetud 2024 = ledger sent to client in 2024)
Communication preferences (Igakuiselt ainult TSD, Saadab iga kuu Drive lingi)
Business structure facts (two bank accounts, export-only business, Estonian-language requirement)
Tax-specific alerts (home office deduction percentages: kodukontor 33,3%, vehicle categories: N1)
Thresholds to watch (kui aasta lõpus 40000€ lähenema = alert when approaching €40k VAT threshold)
Billing notes (Arve aasta lõpus kokku = invoice once at year end)
The current schema has core.client_attributes.important_info (TEXT) and work.work_notes. These can store this content but there is no structure to the notes — they cannot be queried for "clients with vehicle flag" or "clients near VAT threshold" without free-text search.

2.7 The Merit/Joosep System Distinction (Verified fact)
Source: Lepingulised kliendid column "Meritis/Joosepis" (M or J), Täpsem info column "Merit/Joosep" (Merit (Joosep), Joosep, Merit).

Two accounting systems are in use: Merit Aktiva and Joosep (a competing Estonian accounting SaaS). Every client is in exactly one. This is a client attribute, not just a flag. Certain pipeline behaviors differ: the merit_client.py handles Merit submissions; presumably a different client would need a Joosep path.

The current schema has core.clients.accounting_system TEXT NOT NULL DEFAULT 'unknown'. This is adequate but not enforced as a controlled vocabulary. The value should be merit, joosep, or unknown.

2.8 Period Structures Are Heterogeneous (Verified fact)
Observed period patterns across clients:

Monthly: MM.YYYY (Dragondev, Grunder 2025)
Annual: YYYY (Koodireaktor, W4nted Bodyparts)
Half-year: I poolaasta / II poolaasta (Koodireaktor sub-periods within year)
Multi-month range: 10-12.2024 (Veyrat — Q4 consolidated)
Annual-only with AA subfolder: AA/ root folder (separate client type)
Mixed: Some clients have both a year folder AND monthly sub-folders (Grunder has 2024/ with 06.2025/ inside — this is likely a misplace, the monthly folders may have been created inside the wrong year)
The current schema handles this via source.source_period_folders with year_num, month_num, and period_type. The period_type of H1, H2, Q4, etc. are not enumerated in the current catalog. The work.work_periods table has period_kind TEXT NOT NULL DEFAULT 'ad_hoc' but similarly lacks an explicit set of valid values.

3. What the Current PostgreSQL Model Gets Right
Multi-schema separation (core/source/workflow/work/sales/accounting/ops/audit/ui) is architecturally sound and correctly separates concerns. Do not collapse this.

core.client_aliases correctly anticipates that folder names (Koodireaktor OÜ 2024 OK) differ from legal names (Koodireaktor OÜ). The alias_type='folder_name' pattern is exactly right.

source.* hierarchy (source_accounts → source_client_roots → source_period_folders → source_document_buckets → documents) maps directly to the real folder tree. The depth is correct.

work.requirement_catalog with codes TSD, KMD, AA, INF, ARIREGISTER maps directly to the column headers in the workbook. These are the right items to track.

work.work_notes can absorb the content of the Pooleli olevad asjad.xlsx and Klientide täpsem info sheets. The table structure is a reasonable container.

work.client_lifecycle_events with reason field covers the Lahkunud sheet well. The reason values map: "Teeb ise/keegi teine" = self_service, "LAHKUS" = offboarded.

sales.sales_invoice_headers.trikato_entry_code and assigned_bookkeeper_id are real fields from the workbook (Viimati esitatud arve and worker assignment).

core.client_attributes.vehicle_flag matches the Auto column in Täpsem info.

accounting.merit_submissions correctly models the Merit Aktiva API submission cycle with bill_id and request/response payloads.

ui.v_worker_work_queue and ui.v_annual_report_pipeline are the right conceptual views. Their structure is correct in intent.

4. Where the Current Model Mismatches Real Accounting Operations
4.1 No Explicit Client Service Tier (Critical gap)
The workbook has two distinct populations (241 monthly + 205 annual-only) with fundamentally different workflows. The current schema represents this only through core.client_service_enrollments — an intersection table that an accountant would never query directly. There is no core.clients.service_tier field, no enforced distinction, and no UI view that filters by tier.

Impact: When an accountant opens the monthly work queue, they see annual-only clients mixed in. When they open the annual report pipeline, they need to differentiate clients where annual reports are all they do from clients where annual reports are one of several obligations.

4.2 No Engagement Health vs. Work Item Status Distinction (Critical gap)
Source: Example-Notion Engagements database.

The Notion blueprint separates Status (Intake/In Progress/Waiting on Client/Review/Filed/Delivered) from Health (On track/Risk/Blocked). The current schema has only work.work_items.status. An engagement can be "In Progress" (status correct) but "Blocked" (health problem) simultaneously — these are orthogonal. Merging them forces awkward states like status = 'blocked' which is not a workflow stage, or leaving the blockage invisible.

Impact: The v_worker_work_queue view cannot currently show a worker which items are blocked vs. merely in progress. The only signal is block_flags from work_requirements, which is indirect.

4.3 No Compliance Currency (Last-Filed-Period) Concept (Critical gap)
The workbook tracks TSD/KMD as "last filed month" not "is this done." The current schema tracks them as requirements with statuses (missing/blocked/open/done), which requires one work_requirement row per filing per period. For a client with 12 months × 2 filings = 24 requirement rows per year, the current approach is operationally correct but the UI views don't surface the "how far behind are we?" answer directly.

Impact: An accountant cannot easily answer "which of my clients are behind on TSD by more than 1 month?" without a complex query across work_items and work_requirements joined by period. The workbook answers this with a single glance at the column.

4.4 No Blocker Entity (Major gap)
Source: Pooleli olevad asjad.xlsx

The workbook's per-client sheet is a structured blocker queue: item description + optional response status. The current schema's closest analog is work.work_notes (freeform, no response tracking) and ops.document_requests (structured, but only for missing documents, not for invoice anomalies or legal issues).

There is no place to record: "I flagged invoice MA250008 as problematic (wrong VAT), I contacted the client on 2026-03-10, they haven't responded." The ops.tasks table could hold the task but lacks contacted_at, awaiting_response, response_received_at, and contact_channel.

4.5 ops.document_requests Missing Request Channel (Minor gap)
Source: Example-Notion Document Requests schema, real Pooleli workbook.

The workbook and Notion both record how a request was sent (email, WhatsApp, phone). The current ops.document_requests table has no channel field. This matters because the accountant needs to know whether a follow-up should go via email or WhatsApp, and whether a prior contact was documented.

4.6 No Accounting Output Artifact Concept (Moderate gap)
Source: Koodireaktor, Dragondev, W4nted Bodyparts folder structures.

Every completed month or year produces a set of output documents: Bilanss.pdf, Kasumiaruanne.pdf, Pearaamat.pdf, Päevaraamat.pdf, and sometimes an XML journal file (.xml with KD prefix) submitted to Merit. These are not source input documents — they are deliverables.

The current source.documents table treats all files uniformly. There is no document_role distinguishing input_source from accounting_output from regulatory_submission. This makes it impossible to query "which clients are missing their year-end reports" or "what was the last Pearaamat sent?"

4.7 ui.v_main_data_table Is Too Wide and Too Aggregated
The view produces one row per client with latest_monthly_* and latest_annual_* columns. For an accountant managing 37 clients, this means:

They cannot see the state of January 2026 for a client while March 2026 work exists
The "latest" logic (DISTINCT ON ... ORDER BY year DESC, month DESC) means past-period issues disappear from view once a new period is opened
The view is 35+ columns wide — not usable as a Baserow grid without heavy filtering
4.8 Workbook-Encoded Status Notes Are Not Parsed (Moderate gap)
The Mis on puudu, oluline info column in Lepingulised kliendid mixes multiple data types in one field: language flag (ENG), service note (Drive kaustas dokumendid), financial note (Laenude makseid tuleb korrigeerida), billing note. The current schema imports these into work.work_notes.body, where they are invisible to any structured query. The language flag (ENG) in particular should be a client attribute since it affects worker communication.

4.9 work.work_periods Is Weakly Connected to source.source_period_folders (Architectural gap)
Work periods (the accounting work done) and source period folders (the Drive folder structure) are parallel hierarchies that should link. A month of work (work.work_periods) corresponds to one or more Drive period folders (source.source_period_folders). This link doesn't exist in the current schema, making it impossible to answer "are all the input documents for March 2026 present for this client?" as a structured query.

5. Proposed Canonical Database Redesign
These are changes only. Tables not mentioned should be retained as-is.

5.1 Add service_tier to core.clients (Driven by workbook reality)

ALTER TABLE core.clients 
ADD COLUMN service_tier TEXT NOT NULL DEFAULT 'monthly' 
CHECK (service_tier IN ('monthly', 'annual_only', 'payroll_only', 'one_off'));
Why: The Lepingulised vs. Aastaaruande split is a fundamental operational category, not derivable from service enrollments at query time.

5.2 Add lang_preference and doc_delivery_method to core.client_attributes (Driven by workbook reality)

-- Add to core.client_attributes:
lang_preference TEXT DEFAULT 'et',           -- 'et', 'en', 'ru'
doc_delivery_method TEXT DEFAULT 'email',    -- 'email', 'google_drive', 'onedrive', 'paper', 'portal'
billing_frequency TEXT DEFAULT 'monthly',    -- 'monthly', 'annual', 'per_service'
vat_threshold_alert BOOLEAN DEFAULT FALSE,   -- flag to watch €40k threshold
Why: These properties are referenced repeatedly in the notes and drive communication and billing workflows. Currently they are buried in freeform important_info.

5.3 Add engagement_health to work.work_items (Driven by Notion blueprint + real usage)

ALTER TABLE work.work_items 
ADD COLUMN engagement_health TEXT NOT NULL DEFAULT 'on_track'
CHECK (engagement_health IN ('on_track', 'risk', 'blocked'));

ALTER TABLE work.work_items
ADD COLUMN waiting_on TEXT 
CHECK (waiting_on IN (NULL, 'client', 'tax_authority', 'internal', 'partner'));
Why: The current status field conflates workflow stage with health. "Waiting on client" is a distinct state that drives different worker actions than "in progress." The Notion blueprint validates this separation.

5.4 Add work.blockers Table (New table, driven by Pooleli workbook)

CREATE TABLE work.blockers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    work_item_id BIGINT REFERENCES work.work_items(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    blocker_type TEXT NOT NULL DEFAULT 'unresolved_item'
        CHECK (blocker_type IN (
            'invoice_anomaly', 'missing_document', 'missing_bank_data',
            'legal_structure_issue', 'client_contact_pending', 
            'internal_review', 'unresolved_item'
        )),
    document_ref TEXT,          -- e.g. "MA250008", "OA-3", etc.
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'awaiting_response', 'resolved', 'dropped')),
    contact_channel TEXT        -- 'email', 'whatsapp', 'phone'
        CHECK (contact_channel IN (NULL, 'email', 'whatsapp', 'phone', 'portal')),
    contacted_at TIMESTAMPTZ,
    response_received_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON work.blockers (client_id, status);
CREATE INDEX ON work.blockers (work_item_id) WHERE work_item_id IS NOT NULL;
Why: The Pooleli olevad asjad.xlsx is this table. It tracks specific open issues with client-contact status that don't fit neatly into either document_requests or tasks.

5.5 Add contact_channel and Response Tracking to ops.document_requests (Driven by real usage + Notion blueprint)

ALTER TABLE ops.document_requests
ADD COLUMN contact_channel TEXT CHECK (contact_channel IN (NULL, 'email', 'whatsapp', 'phone', 'portal')),
ADD COLUMN contacted_at TIMESTAMPTZ,
ADD COLUMN last_reminded_at TIMESTAMPTZ,
ADD COLUMN response_status TEXT DEFAULT 'not_sent'
    CHECK (response_status IN ('not_sent', 'awaiting_response', 'received', 'no_response'));
Why: The Pooleli workbook shows Ei ole vastanud (no response) as a critical status. The Notion blueprint has Request Channel. Both converge on this need.

5.6 Add document_role to source.documents (Driven by folder reality)

ALTER TABLE source.documents
ADD COLUMN document_role TEXT NOT NULL DEFAULT 'input_source'
    CHECK (document_role IN (
        'input_source',         -- client-supplied: invoices, bank statements
        'accounting_output',    -- firm-generated: Bilanss, Kasumiaruanne, Pearaamat
        'regulatory_submission',-- filed with authority: KMD PDF, TSD XML
        'journal_xml',          -- Merit KD XML file
        'correspondence'        -- emails, letters
    ));
Why: Without this, you can't distinguish "source material we process" from "reports we produce." The folder analysis shows these coexist in the same year folder.

5.7 Add compliance_currency to work.work_periods / Client-level Concept (Driven by workbook reality)
Rather than a new table, add a computed/maintained view approach: create a work.client_compliance_currency table that stores the last-completed period for each compliance obligation per client:


CREATE TABLE work.client_compliance_currency (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    obligation_code TEXT NOT NULL,  -- 'TSD', 'KMD', 'AA'
    last_completed_year INTEGER,
    last_completed_month INTEGER,   -- NULL for annual obligations
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (client_id, obligation_code)
);
This table is maintained by the importer and the pipeline. It directly answers "what is the last filed period for client X, obligation Y?" — the exact question the workbook's TSD/KMD columns answer.

5.8 Add source_period_folder_id Link to work.work_items (Architectural connection)

ALTER TABLE work.work_items
ADD COLUMN source_period_folder_id BIGINT 
    REFERENCES source.source_period_folders(id) ON DELETE SET NULL;
Why: This creates the explicit link between "work we're doing for month M" and "the Drive folder for month M." Currently these are parallel hierarchies with no join key.

5.9 Establish Controlled Vocabulary for accounting_system (Minor fix)

-- Add check constraint to core.clients
ALTER TABLE core.clients
ADD CONSTRAINT chk_accounting_system 
CHECK (accounting_system IN ('merit', 'joosep', 'unknown', 'other'));
5.10 Enumerate period_kind and bucket_type (Minor fix)
Add CHECK constraints or lookup catalogs for work.work_periods.period_kind (monthly, quarterly, half_year, annual, ad_hoc) and source.source_document_buckets.bucket_type (müük, ost, pank, maksuamet, investeeringud, palgaleht, muu, pearaamat_output).

6. Proposed User-Facing Presentation Model
The current ui.* views should be replaced with views that map to actual accountant workflows, not data model slices.

6.1 Principle: Views Should Answer Workflow Questions
An accountant at Trikato answers these questions daily:

"What work do I need to do for each of my clients this month?"
"What documents am I still waiting on from clients?"
"Which clients are blocked and why?"
"Which annual reports are in progress and when are they due?"
"Which clients need TSD filed and which need KMD filed this cycle?"
"What's the complete context for client X before I call them?"
The current ui.v_main_data_table answers none of these directly. It's a data snapshot, not a workflow tool.

6.2 Keep Baserow as the View Layer
The recommendation from START.md — Baserow reads ui.* views, PostgreSQL is canonical — is correct. Do not put business logic in Baserow. All filtering and aggregation happens in SQL.

7. Suggested Core Tables, Relations, and Workflow/State Concepts
Engagement state machine (replacement for work.work_items.status)

not_started
  → in_progress          (work begun)
    → waiting_on_client  (health-orthogonal: work paused on client)
    → waiting_on_auth    (waiting on tax authority)
    → in_review          (internal review)
  → done                 (all compliance filed, deliverables sent)
  → abandoned            (client offboarded mid-period)
Separately, engagement_health is maintained as a manual/computed flag:

on_track — default
risk — approaching deadline, dependency at risk
blocked — cannot proceed without external input
Blocker lifecycle (new work.blockers table)

open → awaiting_response (after contacted_at is set)
     → resolved          (client answered, issue closed)
     → dropped           (issue dismissed without resolution)
Compliance currency concept
work.client_compliance_currency is updated by:

The importer when reading the workbook
The pipeline after successful merit_submit
Folder-name status parsing
When source_client_roots.folder_name contains suffixes like 2024 OK, AA-12.03.25 tegemata, 2024 OK, dokid teha, the importer should:

Extract the status-encoded year and status words
Upsert into work.client_compliance_currency (AA obligation, year=2024, last_completed_year=2024 for "OK")
Flag dokid teha cases as a work.blocker of type internal_review
8. Suggested User-Facing Views
View 1: ui.v_my_monthly_queue — Primary daily work view
Purpose: For a given worker, show all monthly clients with their current-period status.

Key columns:

worker_name, client_name, service_tier, period (current month)
work_status, engagement_health, waiting_on
tsd_last_month, kmd_last_month (from compliance_currency)
tsd_pending, kmd_pending (computed: current month > last_month)
open_blocker_count, open_doc_request_count
accounting_system (merit/joosep — drives which pipeline path to use)
latest_note_body
Filter defaults: service_tier = 'monthly', status != 'done', current month.

View 2: ui.v_annual_report_tracker — Annual report pipeline
Purpose: Track all annual-report work across both monthly and annual_only clients.

Key columns:

client_name, service_tier, primary_worker
aa_year, aa_status, engagement_health, aa_due_date
ariregister_filed (is it in business register?)
folder_name_status_encoded (raw folder suffix for reference)
aa_blocker_count, notes
Filter defaults: current year and previous year; status not done.

View 3: ui.v_open_blockers — Blocked clients and waiting items
Purpose: Everything that needs follow-up action today.

Key columns:

client_name, worker_name, blocker_type, document_ref, body
status, contact_channel, contacted_at, days_since_contact
response_status
Filter defaults: status IN ('open', 'awaiting_response'), ordered by days_since_contact DESC.

View 4: ui.v_open_document_requests — Missing document tracker
Purpose: All outstanding document requests with overdue flagging.

Key columns:

client_name, worker_name, period_key, requested_item, request_category
status, contact_channel, response_status
requested_date, due_date, days_overdue
last_reminded_at
Filter defaults: status NOT IN ('received'), ordered by days_overdue DESC.

View 5: ui.v_compliance_gaps — TSD/KMD currency check
Purpose: Which clients have a gap in their compliance filings?

Key columns:

client_name, worker_name, service_tier
kmd_obligation (boolean), kmd_last_month, kmd_gap_months
tsd_obligation (boolean), tsd_last_month, tsd_gap_months
Filter defaults: service_tier = 'monthly', (kmd_gap_months > 0 OR tsd_gap_months > 0).

View 6: ui.v_client_profile — Full client context card
Purpose: Everything about a single client for a pre-call review.

Key columns:

All core.clients fields
core.client_attributes fields (notes, fiscal_year, vehicle_flag, lang_preference, doc_delivery_method, vat_threshold_alert)
Last 3 notes
Last 5 blockers (open)
Last 3 document requests (open)
Compliance currency for TSD/KMD/AA
Last invoice number and date
This replaces the "client notes sidebar" concept from the workbook.

View 7: ui.v_offboarded_clients — Keep as-is
The current implementation is correct and covers the Lahkunud sheet.

9. Risks, Unknowns, and Migration Concerns
9.1 The v_main_data_table Has 528 Rows in Production
The current view works and is the main view. Any migration of view definitions must not break the row count or silently drop data. All new views should be additive — create new ui.* views without dropping existing ones until they are no longer referenced.

9.2 Folder-Name Status Parsing Is Inference, Not Ground Truth
The folder suffix 2024 OK is reliable for "2024 annual report done." The suffix AA-12.03.25 tegemata ("not done, deadline 12 March 2025") is reliable for "not completed." However, once a folder is renamed (after work is done), the historical suffix is lost. The parsed status should always be marked source='folder_name_inference' and overridden when the pipeline writes a confirmed status. Do not treat folder-name inference as authoritative.

9.3 The Pooleli Workbook Is Not Comprehensive
Only 6 clients appear in Pooleli olevad asjad.xlsx. The remaining ~35 clients either have no open blockers or use a different tracking method (possibly just notes in the RAAMATUPIDAJA2 workbook or in Gmail). The work.blockers table should therefore be populated from the workbook import for these 6 clients, but the absence of a blocker record does not mean a client is clean — it may just mean the worker hasn't migrated their notes.

9.4 The Klientide täpsem info Sheet Has Only 57 Rows
The main client sheets have 241 + 205 rows. Only 57 clients have detailed notes in Täpsem info. The importer must handle this mismatch gracefully: clients without a Täpsem info row should get a blank client_attributes row, not an error.

9.5 Two Workers, Two Drive Structures
Only Merilin's Drive has been inspected. The implementation log notes there are 19 workers. Other workers may have different folder naming conventions, different bucket names (Estonian vs. transliterated), or different period structures. The source.* layer is designed to handle this variation, but the bucket_type vocabulary and the folder-name status parser will need to be validated against at least 2-3 other workers' data before being treated as canonical.

9.6 Annual-Only Clients in the AA Subfolder May Not Have Client Records Yet
The AA folder contains clients like AA Alexcompany OÜ, AA Bajans OÜ, etc. These appear to be Merilin's annual-report-only clients stored under a subfolder. The importer regression fix (preventing 2022, 2023, 2024 from becoming fake clients) is confirmed working. However, the sub-subfolder clients within AA/2024 AA tehtud/ (e.g., AA Algolab, AA Famke OÜ) should be imported as annual-only clients, not as sub-clients of AA. The current importer may need to handle the AA/<client> path pattern separately from <client>/<year>/<bucket>.

9.7 Grunder Ehitus Folder Anomaly
Grunder Ehitus OÜ/2024/06.2025/ — a monthly period folder (06.2025) appears inside the year folder 2024/. This is likely a data entry error (worker put June 2025 work inside the 2024 folder). The importer should detect and log path anomalies where year_num derived from folder path conflicts with year_num of parent folder.

9.8 Merit XML Journal Files
Dragondev OÜ_KD-05-2025.xml is a Merit Aktiva journal entry file in the Drive folder. This is the input to the merit_submit pipeline node. The current schema stores the submission result in accounting.merit_submissions but does not record the XML file itself as a source.document with document_role='journal_xml'. This means there is no traceability from "which XML was submitted" back to the Drive file. Low risk for now, but worth addressing before Merit integration is live.

10. Prioritized Implementation Plan
Ordered by impact-to-effort ratio. Each item is scoped for a single focused session.

Priority 1: Schema incremental additions (non-breaking DDL)
Effort: One session. Risk: Zero — all are additive ALTER TABLE ADD COLUMN or new tables.

Add service_tier to core.clients with CHECK constraint
Add engagement_health and waiting_on to work.work_items
Add lang_preference, doc_delivery_method, billing_frequency, vat_threshold_alert to core.client_attributes
Create work.blockers table
Add contact_channel, contacted_at, last_reminded_at, response_status to ops.document_requests
Add document_role to source.documents
Create work.client_compliance_currency table
Add source_period_folder_id FK to work.work_items
Add CHECK constraints for accounting_system, period_kind, bucket_type
Priority 2: Importer enhancements
Effort: Two sessions. Risk: Medium — must not break existing import logic.

Parse folder-name status suffixes ( 2024 OK, AA-12.03.25 tegemata) and write to work.client_compliance_currency and work.blockers
Import Pooleli olevad asjad.xlsx into work.blockers
Import Klientide täpsem info into core.client_attributes (lang_preference, doc_delivery_method, fiscal_year, vehicle_flag, vat_threshold_alert from notes parsing)
Set service_tier from sheet membership (Lepingulised → monthly, Aastaaruande → annual_only)
Update accounting_system to use merit/joosep vocabulary
Set document_role during Drive inventory import based on file name patterns
Priority 3: Replace/add UI views
Effort: One session. Risk: Low — additive views don't break existing ones.

Create ui.v_my_monthly_queue (the primary daily work view)
Create ui.v_open_blockers
Create ui.v_open_document_requests (enhance existing v_document_intake)
Create ui.v_compliance_gaps
Rebuild ui.v_annual_report_tracker (replaces v_annual_report_pipeline with richer columns)
Create ui.v_client_profile (full context card)
Priority 4: Baserow configuration
Effort: One session. Risk: Low — Baserow is disposable.

Configure Baserow external database pointing to trikato at port 5434
Create one Baserow table per ui.* view (not editable — read-only projections)
Set up worker-scoped row permissions (each worker sees only their clients)
Configure the monthly queue view as the default landing page per worker
Deferred (not in priority list, but noted)
SOPs/Checklists table (ops.checklists exists but is empty — populate from Notion blueprint)
Communication log (ops.communications exists — connect to Gmail integration when DWD is live)
Automatic compliance currency update from merit_submit pipeline node outcome
Cross-worker folder structure validation (validate bucket taxonomy across all 19 workers)