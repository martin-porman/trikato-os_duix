CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS source;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS work;
CREATE SCHEMA IF NOT EXISTS sales;
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS ui;

CREATE TABLE IF NOT EXISTS core.workers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email TEXT,
    display_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    source_account_type TEXT NOT NULL DEFAULT 'human',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_workers_email_not_null
    ON core.workers (LOWER(email))
    WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS core.clients (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    legal_name TEXT NOT NULL,
    registry_code TEXT,
    vat_number TEXT,
    entity_type TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    primary_worker_id BIGINT REFERENCES core.workers(id),
    accounting_system TEXT NOT NULL DEFAULT 'unknown',
    onboarding_date DATE,
    offboarding_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_clients_registry_code
    ON core.clients (registry_code)
    WHERE registry_code IS NOT NULL AND BTRIM(registry_code) <> '';

CREATE INDEX IF NOT EXISTS idx_clients_primary_worker_status
    ON core.clients (primary_worker_id, status);

CREATE INDEX IF NOT EXISTS idx_clients_legal_name
    ON core.clients (LOWER(legal_name));

CREATE TABLE IF NOT EXISTS core.client_aliases (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    alias TEXT NOT NULL,
    alias_type TEXT NOT NULL DEFAULT 'folder_name',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_client_aliases_client_alias
    ON core.client_aliases (client_id, LOWER(alias));

CREATE TABLE IF NOT EXISTS core.client_contacts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    role TEXT,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.service_types (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'service',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO core.service_types (code, label, category)
VALUES
    ('monthly_bookkeeping', 'Monthly bookkeeping', 'recurring'),
    ('annual_report', 'Annual report', 'annual'),
    ('payroll_tsd', 'Payroll TSD', 'compliance'),
    ('kmd_vat', 'KMD / VAT', 'compliance'),
    ('one_off', 'One-off', 'ad_hoc'),
    ('other', 'Other', 'misc')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS core.client_service_enrollments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    service_type_id BIGINT NOT NULL REFERENCES core.service_types(id),
    cadence TEXT NOT NULL DEFAULT 'ad_hoc',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    start_date DATE,
    end_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.client_attributes (
    client_id BIGINT PRIMARY KEY REFERENCES core.clients(id) ON DELETE CASCADE,
    industry_text TEXT,
    management_board_text TEXT,
    founded_on DATE,
    fiscal_year_text TEXT,
    vehicle_flag BOOLEAN,
    general_ledger_note TEXT,
    important_info TEXT,
    raw_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source.source_accounts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    worker_id BIGINT REFERENCES core.workers(id),
    source_name TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    root_path TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_kind, root_path)
);

CREATE TABLE IF NOT EXISTS source.source_client_roots (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_account_id BIGINT NOT NULL REFERENCES source.source_accounts(id) ON DELETE CASCADE,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    folder_name TEXT NOT NULL,
    folder_path TEXT NOT NULL,
    path_status TEXT NOT NULL DEFAULT 'unmapped',
    confidence NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_source_client_roots_account_path
    ON source.source_client_roots (source_account_id, folder_path);

CREATE TABLE IF NOT EXISTS source.source_period_folders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_client_root_id BIGINT NOT NULL REFERENCES source.source_client_roots(id) ON DELETE CASCADE,
    period_label TEXT NOT NULL,
    year_num INTEGER,
    month_num INTEGER,
    period_type TEXT NOT NULL DEFAULT 'misc',
    folder_path TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_source_period_folders_year_month_type
    ON source.source_period_folders (year_num, month_num, period_type);

CREATE UNIQUE INDEX IF NOT EXISTS uq_source_period_folders_root_path
    ON source.source_period_folders (source_client_root_id, folder_path);

CREATE TABLE IF NOT EXISTS source.source_document_buckets (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_period_folder_id BIGINT NOT NULL REFERENCES source.source_period_folders(id) ON DELETE CASCADE,
    bucket_type TEXT NOT NULL DEFAULT 'general',
    bucket_name TEXT NOT NULL,
    folder_path TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_period_folder_id, folder_path)
);

CREATE TABLE IF NOT EXISTS source.documents (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    source_account_id BIGINT REFERENCES source.source_accounts(id) ON DELETE SET NULL,
    source_client_root_id BIGINT REFERENCES source.source_client_roots(id) ON DELETE SET NULL,
    source_period_folder_id BIGINT REFERENCES source.source_period_folders(id) ON DELETE SET NULL,
    source_document_bucket_id BIGINT REFERENCES source.source_document_buckets(id) ON DELETE SET NULL,
    source_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_ext TEXT,
    mime_type TEXT,
    size_bytes BIGINT,
    file_hash TEXT,
    document_category TEXT NOT NULL DEFAULT 'general',
    period_key TEXT,
    document_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_source_path_hash
    ON source.documents (source_path, COALESCE(file_hash, ''));

CREATE INDEX IF NOT EXISTS idx_documents_client_category_period
    ON source.documents (client_id, document_category, period_key);

CREATE INDEX IF NOT EXISTS idx_documents_file_hash
    ON source.documents (file_hash)
    WHERE file_hash IS NOT NULL;

CREATE TABLE IF NOT EXISTS source.document_versions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES source.documents(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL,
    source_path TEXT NOT NULL,
    file_hash TEXT,
    observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, version_no)
);

CREATE TABLE IF NOT EXISTS source.document_tags (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES source.documents(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, tag)
);

CREATE TABLE IF NOT EXISTS workflow.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type TEXT NOT NULL DEFAULT 'pipeline_intake',
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    source_document_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    priority TEXT NOT NULL DEFAULT 'normal',
    payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_workflow_jobs_status_created
    ON workflow.jobs (status, created_at);

CREATE TABLE IF NOT EXISTS workflow.job_attempts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES workflow.jobs(id) ON DELETE CASCADE,
    attempt_no INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'running',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    UNIQUE (job_id, attempt_no)
);

CREATE TABLE IF NOT EXISTS workflow.pipeline_runs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_id UUID REFERENCES workflow.jobs(id) ON DELETE SET NULL,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    source_document_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    report_url TEXT,
    error_message TEXT,
    output_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_client_status
    ON workflow.pipeline_runs (client_id, status);

CREATE TABLE IF NOT EXISTS workflow.pipeline_artifacts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pipeline_run_id BIGINT NOT NULL REFERENCES workflow.pipeline_runs(id) ON DELETE CASCADE,
    artifact_type TEXT NOT NULL,
    storage_uri TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS work.work_periods (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    service_type_id BIGINT NOT NULL REFERENCES core.service_types(id),
    year_num INTEGER,
    month_num INTEGER,
    period_start DATE,
    period_end DATE,
    period_kind TEXT NOT NULL DEFAULT 'ad_hoc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_work_periods_client_service_period
    ON work.work_periods (
        client_id,
        service_type_id,
        COALESCE(year_num, -1),
        COALESCE(month_num, -1),
        period_kind
    );

CREATE TABLE IF NOT EXISTS work.work_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    work_period_id BIGINT REFERENCES work.work_periods(id) ON DELETE CASCADE,
    service_type_id BIGINT NOT NULL REFERENCES core.service_types(id),
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'not_started',
    priority TEXT NOT NULL DEFAULT 'normal',
    last_invoice_number TEXT,
    due_date DATE,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_work_items_client_service_period
    ON work.work_items (client_id, service_type_id, work_period_id);

CREATE INDEX IF NOT EXISTS idx_work_items_worker_status_due
    ON work.work_items (worker_id, status, due_date);

CREATE TABLE IF NOT EXISTS work.requirement_catalog (
    code TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO work.requirement_catalog (code, label)
VALUES
    ('TSD', 'Payroll TSD'),
    ('KMD', 'VAT / KMD'),
    ('AA', 'Annual report'),
    ('INF', 'INF filing'),
    ('ARIREGISTER', 'Business register check'),
    ('MERIT_SYNC', 'Merit / Joosep sync'),
    ('BANK_MISSING', 'Missing bank data'),
    ('SALES_MISSING', 'Missing sales data'),
    ('PURCHASE_MISSING', 'Missing purchase data')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS work.work_requirements (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    work_item_id BIGINT NOT NULL REFERENCES work.work_items(id) ON DELETE CASCADE,
    requirement_code TEXT NOT NULL REFERENCES work.requirement_catalog(code),
    requirement_status TEXT NOT NULL DEFAULT 'unknown',
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (work_item_id, requirement_code)
);

CREATE INDEX IF NOT EXISTS idx_work_requirements_code_status
    ON work.work_requirements (requirement_code, requirement_status);

CREATE TABLE IF NOT EXISTS work.work_notes (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE CASCADE,
    work_item_id BIGINT REFERENCES work.work_items(id) ON DELETE CASCADE,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    note_type TEXT NOT NULL DEFAULT 'client_master_note',
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS work.client_lifecycle_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_date DATE,
    reason TEXT,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sales.sales_report_imports (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    report_month DATE,
    file_name TEXT NOT NULL,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    row_count INTEGER NOT NULL DEFAULT 0,
    report_type TEXT NOT NULL,
    UNIQUE (file_name, report_type)
);

CREATE TABLE IF NOT EXISTS sales.sales_articles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_code TEXT NOT NULL,
    name_et TEXT NOT NULL,
    name_en TEXT,
    unit TEXT,
    article_type TEXT,
    sales_price NUMERIC(14, 2),
    vat_code TEXT,
    vat_label TEXT,
    sales_account TEXT,
    purchase_account TEXT,
    inventory_account TEXT,
    cogs_account TEXT,
    article_group TEXT,
    active_status TEXT,
    source_import_id BIGINT REFERENCES sales.sales_report_imports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_articles_code
    ON sales.sales_articles (article_code);

CREATE INDEX IF NOT EXISTS idx_sales_articles_code_active
    ON sales.sales_articles (article_code, active_status);

CREATE TABLE IF NOT EXISTS sales.sales_invoice_headers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_number TEXT NOT NULL,
    invoice_date DATE,
    due_date DATE,
    customer_name_raw TEXT NOT NULL,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    assigned_bookkeeper_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    total_amount NUMERIC(14, 2),
    currency TEXT NOT NULL DEFAULT 'EUR',
    trikato_entry_code TEXT,
    sent_at DATE,
    paid_amount NUMERIC(14, 2),
    issued_by_user TEXT,
    vat_number TEXT,
    source_file_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    source_import_id BIGINT REFERENCES sales.sales_report_imports(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_invoice_headers_invoice_number
    ON sales.sales_invoice_headers (invoice_number);

CREATE INDEX IF NOT EXISTS idx_sales_invoice_headers_bookkeeper_date
    ON sales.sales_invoice_headers (assigned_bookkeeper_id, invoice_date);

CREATE TABLE IF NOT EXISTS sales.sales_invoice_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sales_invoice_id BIGINT NOT NULL REFERENCES sales.sales_invoice_headers(id) ON DELETE CASCADE,
    line_description TEXT NOT NULL,
    article_id BIGINT REFERENCES sales.sales_articles(id) ON DELETE SET NULL,
    quantity NUMERIC(14, 4),
    unit_price NUMERIC(14, 2),
    line_total NUMERIC(14, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounting.purchase_invoices (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    source_document_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    vendor_name TEXT,
    vendor_registry_code TEXT,
    vendor_vat_number TEXT,
    invoice_number TEXT,
    invoice_date DATE,
    due_date DATE,
    total_amount NUMERIC(14, 2),
    vat_amount NUMERIC(14, 2),
    net_amount NUMERIC(14, 2),
    currency TEXT NOT NULL DEFAULT 'EUR',
    status TEXT NOT NULL DEFAULT 'extracted',
    extracted_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounting.purchase_invoice_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_invoice_id BIGINT NOT NULL REFERENCES accounting.purchase_invoices(id) ON DELETE CASCADE,
    line_no INTEGER,
    description TEXT,
    quantity NUMERIC(14, 4),
    unit_price NUMERIC(14, 2),
    line_total NUMERIC(14, 2),
    vat_rate NUMERIC(6, 2)
);

CREATE TABLE IF NOT EXISTS accounting.bank_transactions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    source_document_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    account_identifier TEXT,
    transaction_date DATE,
    amount NUMERIC(14, 2),
    currency TEXT NOT NULL DEFAULT 'EUR',
    description TEXT,
    counterparty TEXT,
    reference TEXT,
    direction TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounting.invoice_matches (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purchase_invoice_id BIGINT NOT NULL REFERENCES accounting.purchase_invoices(id) ON DELETE CASCADE,
    bank_transaction_id BIGINT REFERENCES accounting.bank_transactions(id) ON DELETE SET NULL,
    match_status TEXT NOT NULL DEFAULT 'candidate',
    confidence NUMERIC(5, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounting.merit_submissions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE SET NULL,
    purchase_invoice_id BIGINT REFERENCES accounting.purchase_invoices(id) ON DELETE SET NULL,
    bill_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    request_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    response_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accounting.compliance_obligations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    work_period_id BIGINT REFERENCES work.work_periods(id) ON DELETE SET NULL,
    obligation_code TEXT NOT NULL,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'pending',
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ops.tasks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE CASCADE,
    work_item_id BIGINT REFERENCES work.work_items(id) ON DELETE CASCADE,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    task_type TEXT NOT NULL DEFAULT 'general',
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'todo',
    due_date DATE,
    blocked_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ops.communications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE CASCADE,
    work_item_id BIGINT REFERENCES work.work_items(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    channel TEXT NOT NULL,
    direction TEXT,
    summary TEXT NOT NULL,
    body TEXT,
    communicated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ops.document_requests (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT REFERENCES core.clients(id) ON DELETE CASCADE,
    work_item_id BIGINT REFERENCES work.work_items(id) ON DELETE SET NULL,
    worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    source_document_id BIGINT REFERENCES source.documents(id) ON DELETE SET NULL,
    request_category TEXT NOT NULL DEFAULT 'general',
    requested_item TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    requested_date DATE,
    due_date DATE,
    received_date DATE,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ops.checklists (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    checklist_name TEXT NOT NULL,
    service_type_id BIGINT REFERENCES core.service_types(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    owner_worker_id BIGINT REFERENCES core.workers(id) ON DELETE SET NULL,
    content JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit.sync_runs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_account_id BIGINT REFERENCES source.source_accounts(id) ON DELETE SET NULL,
    run_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'started',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    detail JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TABLE IF NOT EXISTS audit.sync_run_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sync_run_id BIGINT NOT NULL REFERENCES audit.sync_runs(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    item_path TEXT,
    status TEXT NOT NULL DEFAULT 'seen',
    detail JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit.job_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_id UUID REFERENCES workflow.jobs(id) ON DELETE CASCADE,
    pipeline_run_id BIGINT REFERENCES workflow.pipeline_runs(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    detail JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit.document_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id BIGINT REFERENCES source.documents(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    detail JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- MIGRATION 2026-03-24: Incremental schema additions (Priority 1)
-- All ALTER TABLE and CREATE TABLE below are additive (non-breaking).
-- Applied to live DB: baserow-postgres-1, db=trikato
-- ============================================================

-- P1-A: Two-tier client roster (monthly vs annual_only)
ALTER TABLE core.clients
ADD COLUMN IF NOT EXISTS service_tier TEXT NOT NULL DEFAULT 'monthly'
    CHECK (service_tier IN ('monthly', 'annual_only', 'payroll_only', 'one_off'));

-- P1-B: Engagement health and waiting-on state (orthogonal to workflow status)
ALTER TABLE work.work_items
ADD COLUMN IF NOT EXISTS engagement_health TEXT NOT NULL DEFAULT 'on_track'
    CHECK (engagement_health IN ('on_track', 'risk', 'blocked')),
ADD COLUMN IF NOT EXISTS waiting_on TEXT
    CHECK (waiting_on IN (NULL, 'client', 'tax_authority', 'internal', 'partner'));

-- P1-C: Client communication and billing attributes
ALTER TABLE core.client_attributes
ADD COLUMN IF NOT EXISTS lang_preference TEXT DEFAULT 'et'
    CHECK (lang_preference IN ('et', 'en', 'ru')),
ADD COLUMN IF NOT EXISTS doc_delivery_method TEXT DEFAULT 'email'
    CHECK (doc_delivery_method IN ('email', 'google_drive', 'onedrive', 'paper', 'portal')),
ADD COLUMN IF NOT EXISTS billing_frequency TEXT DEFAULT 'monthly'
    CHECK (billing_frequency IN ('monthly', 'annual', 'per_service')),
ADD COLUMN IF NOT EXISTS vat_threshold_alert BOOLEAN DEFAULT FALSE;

-- P1-D: Blocker queue (maps to Pooleli olevad asjad.xlsx)
CREATE TABLE IF NOT EXISTS work.blockers (
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
    document_ref TEXT,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'awaiting_response', 'resolved', 'dropped')),
    contact_channel TEXT
        CHECK (contact_channel IN (NULL, 'email', 'whatsapp', 'phone', 'portal')),
    contacted_at TIMESTAMPTZ,
    response_received_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blockers_client_status ON work.blockers (client_id, status);
CREATE INDEX IF NOT EXISTS idx_blockers_work_item ON work.blockers (work_item_id) WHERE work_item_id IS NOT NULL;

-- P1-E: Contact tracking on document requests
ALTER TABLE ops.document_requests
ADD COLUMN IF NOT EXISTS contact_channel TEXT
    CHECK (contact_channel IN (NULL, 'email', 'whatsapp', 'phone', 'portal')),
ADD COLUMN IF NOT EXISTS contacted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_reminded_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS response_status TEXT DEFAULT 'not_sent'
    CHECK (response_status IN ('not_sent', 'awaiting_response', 'received', 'no_response'));

-- P1-F: Document role (input vs output vs regulatory submission)
ALTER TABLE source.documents
ADD COLUMN IF NOT EXISTS document_role TEXT NOT NULL DEFAULT 'input_source'
    CHECK (document_role IN (
        'input_source',
        'accounting_output',
        'regulatory_submission',
        'journal_xml',
        'correspondence'
    ));

-- P1-G: Compliance currency — last-filed-period per client per obligation
CREATE TABLE IF NOT EXISTS work.client_compliance_currency (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES core.clients(id) ON DELETE CASCADE,
    obligation_code TEXT NOT NULL,
    last_completed_year INTEGER,
    last_completed_month INTEGER,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (client_id, obligation_code)
);

CREATE INDEX IF NOT EXISTS idx_compliance_currency_client ON work.client_compliance_currency (client_id);

-- P1-H: Link work items to their corresponding Drive period folder
ALTER TABLE work.work_items
ADD COLUMN IF NOT EXISTS source_period_folder_id BIGINT
    REFERENCES source.source_period_folders(id) ON DELETE SET NULL;

-- P1-I: Controlled vocabulary constraints (idempotent via DO blocks)
-- Note: period_kind includes 'annual_report' (85 existing rows); bucket_type includes 'aa' (15 existing rows)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_accounting_system' AND conrelid='core.clients'::regclass) THEN
        ALTER TABLE core.clients ADD CONSTRAINT chk_accounting_system
            CHECK (accounting_system IN ('merit', 'joosep', 'unknown', 'other'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_period_kind' AND conrelid='work.work_periods'::regclass) THEN
        ALTER TABLE work.work_periods ADD CONSTRAINT chk_period_kind
            CHECK (period_kind IN ('monthly', 'quarterly', 'half_year', 'annual', 'annual_report', 'ad_hoc'));
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chk_bucket_type' AND conrelid='source.source_document_buckets'::regclass) THEN
        ALTER TABLE source.source_document_buckets ADD CONSTRAINT chk_bucket_type
            CHECK (bucket_type IN ('müük', 'ost', 'pank', 'maksuamet', 'investeeringud', 'palgaleht', 'muu', 'pearaamat_output', 'aa'));
    END IF;
END $$;
