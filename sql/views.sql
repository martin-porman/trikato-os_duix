CREATE SCHEMA IF NOT EXISTS ui;

CREATE OR REPLACE VIEW ui.v_clients_overview AS
WITH active_services AS (
    SELECT
        cse.client_id,
        STRING_AGG(st.label, ', ' ORDER BY st.label) AS active_services
    FROM core.client_service_enrollments cse
    JOIN core.service_types st ON st.id = cse.service_type_id
    WHERE cse.active
    GROUP BY cse.client_id
),
open_blocks AS (
    SELECT
        wi.client_id,
        STRING_AGG(DISTINCT wr.requirement_code, ', ' ORDER BY wr.requirement_code) AS block_flags
    FROM work.work_items wi
    JOIN work.work_requirements wr ON wr.work_item_id = wi.id
    WHERE wr.requirement_status IN ('missing', 'blocked', 'open', 'pending')
    GROUP BY wi.client_id
),
latest_note AS (
    SELECT DISTINCT ON (wn.client_id)
        wn.client_id,
        wn.body
    FROM work.work_notes wn
    ORDER BY wn.client_id, wn.created_at DESC
)
SELECT
    c.id,
    c.legal_name,
    c.registry_code,
    c.vat_number,
    c.entity_type,
    c.status,
    c.accounting_system,
    w.display_name AS primary_worker,
    w.email AS primary_worker_email,
    COALESCE(s.active_services, '') AS active_services,
    COALESCE(b.block_flags, '') AS block_flags,
    ln.body AS latest_note,
    c.onboarding_date,
    c.offboarding_date,
    c.updated_at,
    c.service_tier
FROM core.clients c
LEFT JOIN core.workers w ON w.id = c.primary_worker_id
LEFT JOIN active_services s ON s.client_id = c.id
LEFT JOIN open_blocks b ON b.client_id = c.id
LEFT JOIN latest_note ln ON ln.client_id = c.id;

CREATE OR REPLACE VIEW ui.v_worker_work_queue AS
SELECT
    wi.id AS work_item_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    w.email AS worker_email,
    st.code AS service_code,
    st.label AS service_label,
    wp.period_kind,
    wp.year_num,
    wp.month_num,
    wi.status,
    wi.priority,
    wi.due_date,
    wi.last_invoice_number,
    MAX(CASE WHEN wr.requirement_code = 'TSD' THEN wr.requirement_status END) AS tsd_status,
    MAX(CASE WHEN wr.requirement_code = 'KMD' THEN wr.requirement_status END) AS kmd_status,
    MAX(CASE WHEN wr.requirement_code = 'AA' THEN wr.requirement_status END) AS aa_status,
    MAX(CASE WHEN wr.requirement_code = 'INF' THEN wr.requirement_status END) AS inf_status,
    STRING_AGG(
        CASE
            WHEN wr.requirement_status IN ('missing', 'blocked', 'open', 'pending')
                THEN wr.requirement_code || ':' || wr.requirement_status
            ELSE NULL
        END,
        ', '
        ORDER BY wr.requirement_code
    ) AS block_summary,
    wi.engagement_health,
    wi.waiting_on,
    c.service_tier
FROM work.work_items wi
JOIN core.clients c ON c.id = wi.client_id
LEFT JOIN core.workers w ON w.id = wi.worker_id
JOIN core.service_types st ON st.id = wi.service_type_id
LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
LEFT JOIN work.work_requirements wr ON wr.work_item_id = wi.id
GROUP BY
    wi.id,
    c.legal_name,
    w.display_name,
    w.email,
    st.code,
    st.label,
    wp.period_kind,
    wp.year_num,
    wp.month_num,
    wi.status,
    wi.priority,
    wi.due_date,
    wi.last_invoice_number,
    wi.engagement_health,
    wi.waiting_on,
    c.service_tier;

CREATE OR REPLACE VIEW ui.v_document_intake AS
SELECT
    d.id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    sa.source_name,
    d.source_path,
    d.file_name,
    d.file_ext,
    d.mime_type,
    d.document_category,
    d.period_key,
    spf.period_type,
    sdb.bucket_type,
    d.size_bytes,
    d.document_date,
    d.observed_at,
    d.document_role
FROM source.documents d
LEFT JOIN core.clients c ON c.id = d.client_id
LEFT JOIN core.workers w ON w.id = d.worker_id
LEFT JOIN source.source_accounts sa ON sa.id = d.source_account_id
LEFT JOIN source.source_period_folders spf ON spf.id = d.source_period_folder_id
LEFT JOIN source.source_document_buckets sdb ON sdb.id = d.source_document_bucket_id;

CREATE OR REPLACE VIEW ui.v_sales_invoices AS
SELECT
    sih.id,
    sih.invoice_number,
    sih.invoice_date,
    sih.due_date,
    sih.customer_name_raw,
    c.legal_name AS mapped_client_name,
    w.display_name AS assigned_bookkeeper,
    sih.total_amount,
    sih.currency,
    sih.paid_amount,
    (COALESCE(sih.paid_amount, 0) >= COALESCE(sih.total_amount, 0)) AS is_paid,
    sih.trikato_entry_code,
    sih.issued_by_user,
    sih.vat_number,
    sri.file_name AS source_report_file
FROM sales.sales_invoice_headers sih
LEFT JOIN core.clients c ON c.id = sih.client_id
LEFT JOIN core.workers w ON w.id = sih.assigned_bookkeeper_id
LEFT JOIN sales.sales_report_imports sri ON sri.id = sih.source_import_id;

CREATE OR REPLACE VIEW ui.v_annual_report_pipeline AS
WITH annual_items AS (
    SELECT
        wi.id,
        wi.client_id,
        wi.worker_id,
        wi.status,
        wi.priority,
        wi.due_date,
        wp.year_num
    FROM work.work_items wi
    JOIN core.service_types st ON st.id = wi.service_type_id
    LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
    WHERE st.code = 'annual_report'
),
annual_notes AS (
    SELECT DISTINCT ON (client_id)
        client_id,
        body
    FROM work.work_notes
    WHERE note_type IN ('annual_report_note', 'client_master_note')
    ORDER BY client_id, created_at DESC
)
SELECT
    ai.id AS work_item_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    ai.year_num,
    ai.status,
    ai.priority,
    ai.due_date,
    MAX(CASE WHEN wr.requirement_code = 'AA' THEN wr.requirement_status END) AS aa_status,
    MAX(CASE WHEN wr.requirement_code = 'ARIREGISTER' THEN wr.requirement_status END) AS ariregister_status,
    STRING_AGG(
        CASE
            WHEN wr.requirement_status IN ('missing', 'blocked', 'open', 'pending')
                THEN wr.requirement_code
            ELSE NULL
        END,
        ', '
        ORDER BY wr.requirement_code
    ) AS missing_artifacts,
    an.body AS latest_note
FROM annual_items ai
JOIN core.clients c ON c.id = ai.client_id
LEFT JOIN core.workers w ON w.id = ai.worker_id
LEFT JOIN work.work_requirements wr ON wr.work_item_id = ai.id
LEFT JOIN annual_notes an ON an.client_id = ai.client_id
GROUP BY ai.id, c.legal_name, w.display_name, ai.year_num, ai.status, ai.priority, ai.due_date, an.body;

CREATE OR REPLACE VIEW ui.v_monthly_compliance AS
SELECT
    wi.id AS work_item_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    wp.year_num,
    wp.month_num,
    wi.status,
    wi.due_date,
    MAX(CASE WHEN wr.requirement_code = 'TSD' THEN wr.requirement_status END) AS tsd_status,
    MAX(CASE WHEN wr.requirement_code = 'KMD' THEN wr.requirement_status END) AS kmd_status,
    MAX(CASE WHEN wr.requirement_code = 'BANK_MISSING' THEN wr.requirement_status END) AS bank_missing_status,
    MAX(CASE WHEN wr.requirement_code = 'PURCHASE_MISSING' THEN wr.requirement_status END) AS purchase_missing_status,
    MAX(CASE WHEN wr.requirement_code = 'SALES_MISSING' THEN wr.requirement_status END) AS sales_missing_status
FROM work.work_items wi
JOIN core.service_types st ON st.id = wi.service_type_id
JOIN core.clients c ON c.id = wi.client_id
LEFT JOIN core.workers w ON w.id = wi.worker_id
LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
LEFT JOIN work.work_requirements wr ON wr.work_item_id = wi.id
WHERE st.code IN ('monthly_bookkeeping', 'payroll_tsd', 'kmd_vat')
GROUP BY wi.id, c.legal_name, w.display_name, wp.year_num, wp.month_num, wi.status, wi.due_date;

CREATE OR REPLACE VIEW ui.v_offboarded_clients AS
SELECT
    c.id AS client_id,
    c.legal_name,
    c.status AS client_status,
    cle.event_type,
    cle.event_date,
    cle.reason,
    cle.note
FROM work.client_lifecycle_events cle
JOIN core.clients c ON c.id = cle.client_id
WHERE cle.event_type IN ('offboarded', 'deleted', 'liquidated');

CREATE OR REPLACE VIEW ui.v_main_data_table AS
WITH active_services AS (
    SELECT
        cse.client_id,
        STRING_AGG(st.label, ', ' ORDER BY st.label) AS active_services
    FROM core.client_service_enrollments cse
    JOIN core.service_types st ON st.id = cse.service_type_id
    WHERE cse.active
    GROUP BY cse.client_id
),
open_blocks AS (
    SELECT
        wi.client_id,
        STRING_AGG(DISTINCT wr.requirement_code, ', ' ORDER BY wr.requirement_code) AS block_flags
    FROM work.work_items wi
    JOIN work.work_requirements wr ON wr.work_item_id = wi.id
    WHERE wr.requirement_status IN ('missing', 'blocked', 'open', 'pending')
    GROUP BY wi.client_id
),
latest_note AS (
    SELECT DISTINCT ON (wn.client_id)
        wn.client_id,
        wn.body,
        wn.created_at
    FROM work.work_notes wn
    ORDER BY wn.client_id, wn.created_at DESC
),
latest_monthly AS (
    SELECT DISTINCT ON (wi.client_id)
        wi.client_id,
        wi.id AS work_item_id,
        wi.status,
        wi.priority,
        wi.due_date,
        wp.year_num,
        wp.month_num,
        MAX(CASE WHEN wr.requirement_code = 'TSD' THEN wr.requirement_status END) AS tsd_status,
        MAX(CASE WHEN wr.requirement_code = 'KMD' THEN wr.requirement_status END) AS kmd_status,
        MAX(CASE WHEN wr.requirement_code = 'BANK_MISSING' THEN wr.requirement_status END) AS bank_missing_status,
        MAX(CASE WHEN wr.requirement_code = 'PURCHASE_MISSING' THEN wr.requirement_status END) AS purchase_missing_status,
        MAX(CASE WHEN wr.requirement_code = 'SALES_MISSING' THEN wr.requirement_status END) AS sales_missing_status
    FROM work.work_items wi
    JOIN core.service_types st ON st.id = wi.service_type_id
    LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
    LEFT JOIN work.work_requirements wr ON wr.work_item_id = wi.id
    WHERE st.code IN ('monthly_bookkeeping', 'payroll_tsd', 'kmd_vat')
    GROUP BY wi.client_id, wi.id, wi.status, wi.priority, wi.due_date, wp.year_num, wp.month_num
    ORDER BY wi.client_id, wp.year_num DESC NULLS LAST, wp.month_num DESC NULLS LAST, wi.due_date DESC NULLS LAST, wi.id DESC
),
latest_annual AS (
    SELECT DISTINCT ON (wi.client_id)
        wi.client_id,
        wi.id AS work_item_id,
        wi.status,
        wi.priority,
        wi.due_date,
        wp.year_num,
        MAX(CASE WHEN wr.requirement_code = 'AA' THEN wr.requirement_status END) AS aa_status,
        MAX(CASE WHEN wr.requirement_code = 'ARIREGISTER' THEN wr.requirement_status END) AS ariregister_status
    FROM work.work_items wi
    JOIN core.service_types st ON st.id = wi.service_type_id
    LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
    LEFT JOIN work.work_requirements wr ON wr.work_item_id = wi.id
    WHERE st.code = 'annual_report'
    GROUP BY wi.client_id, wi.id, wi.status, wi.priority, wi.due_date, wp.year_num
    ORDER BY wi.client_id, wp.year_num DESC NULLS LAST, wi.due_date DESC NULLS LAST, wi.id DESC
),
sales_stats AS (
    SELECT
        sih.client_id,
        COUNT(*) AS sales_invoice_count,
        MAX(sih.invoice_date) AS last_sales_invoice_date,
        SUM(COALESCE(sih.total_amount, 0)) AS sales_invoice_total,
        SUM(COALESCE(sih.paid_amount, 0)) AS sales_paid_total
    FROM sales.sales_invoice_headers sih
    WHERE sih.client_id IS NOT NULL
    GROUP BY sih.client_id
),
doc_stats AS (
    SELECT
        d.client_id,
        COUNT(*) AS document_count,
        MAX(d.observed_at) AS last_document_seen_at
    FROM source.documents d
    WHERE d.client_id IS NOT NULL
    GROUP BY d.client_id
)
SELECT
    c.id AS client_id,
    c.legal_name,
    c.registry_code,
    c.vat_number,
    c.entity_type,
    c.status AS client_status,
    c.accounting_system,
    w.display_name AS primary_worker,
    w.email AS primary_worker_email,
    COALESCE(s.active_services, '') AS active_services,
    COALESCE(b.block_flags, '') AS block_flags,
    ln.body AS latest_note,
    ln.created_at AS latest_note_created_at,
    lm.work_item_id AS latest_monthly_work_item_id,
    lm.year_num AS latest_monthly_year,
    lm.month_num AS latest_monthly_month,
    lm.status AS latest_monthly_status,
    lm.priority AS latest_monthly_priority,
    lm.due_date AS latest_monthly_due_date,
    lm.tsd_status,
    lm.kmd_status,
    lm.bank_missing_status,
    lm.purchase_missing_status,
    lm.sales_missing_status,
    la.work_item_id AS latest_annual_work_item_id,
    la.year_num AS latest_annual_year,
    la.status AS latest_annual_status,
    la.priority AS latest_annual_priority,
    la.due_date AS latest_annual_due_date,
    la.aa_status,
    la.ariregister_status,
    COALESCE(ss.sales_invoice_count, 0) AS sales_invoice_count,
    COALESCE(ss.sales_invoice_total, 0)::numeric(14,2) AS sales_invoice_total,
    COALESCE(ss.sales_paid_total, 0)::numeric(14,2) AS sales_paid_total,
    ss.last_sales_invoice_date,
    COALESCE(ds.document_count, 0) AS document_count,
    ds.last_document_seen_at,
    c.onboarding_date,
    c.offboarding_date,
    c.updated_at,
    c.service_tier
FROM core.clients c
LEFT JOIN core.workers w ON w.id = c.primary_worker_id
LEFT JOIN active_services s ON s.client_id = c.id
LEFT JOIN open_blocks b ON b.client_id = c.id
LEFT JOIN latest_note ln ON ln.client_id = c.id
LEFT JOIN latest_monthly lm ON lm.client_id = c.id
LEFT JOIN latest_annual la ON la.client_id = c.id
LEFT JOIN sales_stats ss ON ss.client_id = c.id
LEFT JOIN doc_stats ds ON ds.client_id = c.id;

-- ============================================================
-- VIEWS ADDED 2026-03-24: Priority-3 workflow views
-- These are additive — do not drop existing views above.
-- ============================================================

-- View 1: Primary daily work queue for monthly-service clients
CREATE OR REPLACE VIEW ui.v_my_monthly_queue AS
SELECT
    wi.id AS work_item_id,
    c.legal_name AS client_name,
    c.service_tier,
    w.display_name AS worker_name,
    w.email AS worker_email,
    wp.year_num,
    wp.month_num,
    wi.status,
    wi.engagement_health,
    wi.waiting_on,
    wi.due_date,
    c.accounting_system,
    tsd_ccc.last_completed_year AS tsd_last_year,
    tsd_ccc.last_completed_month AS tsd_last_month,
    kmd_ccc.last_completed_year AS kmd_last_year,
    kmd_ccc.last_completed_month AS kmd_last_month,
    CASE
        WHEN tsd_ccc.last_completed_month IS NULL THEN TRUE
        WHEN wp.year_num > tsd_ccc.last_completed_year THEN TRUE
        WHEN wp.year_num = tsd_ccc.last_completed_year
             AND wp.month_num > tsd_ccc.last_completed_month THEN TRUE
        ELSE FALSE
    END AS tsd_pending,
    CASE
        WHEN kmd_ccc.last_completed_month IS NULL THEN TRUE
        WHEN wp.year_num > kmd_ccc.last_completed_year THEN TRUE
        WHEN wp.year_num = kmd_ccc.last_completed_year
             AND wp.month_num > kmd_ccc.last_completed_month THEN TRUE
        ELSE FALSE
    END AS kmd_pending,
    (SELECT COUNT(*) FROM work.blockers b
     WHERE b.client_id = c.id AND b.status IN ('open', 'awaiting_response')) AS open_blocker_count,
    (SELECT COUNT(*) FROM ops.document_requests dr
     WHERE dr.client_id = c.id AND dr.status NOT IN ('received', 'cancelled')) AS open_doc_request_count,
    ln.body AS latest_note_body
FROM work.work_items wi
JOIN core.clients c ON c.id = wi.client_id
LEFT JOIN core.workers w ON w.id = wi.worker_id
JOIN core.service_types st ON st.id = wi.service_type_id
LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
LEFT JOIN work.client_compliance_currency tsd_ccc
    ON tsd_ccc.client_id = c.id AND tsd_ccc.obligation_code = 'TSD'
LEFT JOIN work.client_compliance_currency kmd_ccc
    ON kmd_ccc.client_id = c.id AND kmd_ccc.obligation_code = 'KMD'
LEFT JOIN LATERAL (
    SELECT wn.body FROM work.work_notes wn
    WHERE wn.client_id = c.id ORDER BY wn.created_at DESC LIMIT 1
) ln ON TRUE
WHERE c.service_tier = 'monthly'
AND st.code IN ('monthly_bookkeeping', 'payroll_tsd', 'kmd_vat');

-- View 2: All open/waiting blockers ordered by staleness
CREATE OR REPLACE VIEW ui.v_open_blockers AS
SELECT
    b.id AS blocker_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    b.blocker_type,
    b.document_ref,
    b.body,
    b.status,
    b.contact_channel,
    b.contacted_at,
    EXTRACT(DAY FROM NOW() - b.contacted_at)::INTEGER AS days_since_contact,
    b.response_received_at,
    b.created_at
FROM work.blockers b
JOIN core.clients c ON c.id = b.client_id
LEFT JOIN core.workers w ON w.id = b.worker_id
WHERE b.status IN ('open', 'awaiting_response')
ORDER BY b.contacted_at ASC NULLS FIRST;

-- View 3: Open document requests with overdue days
CREATE OR REPLACE VIEW ui.v_open_document_requests AS
SELECT
    dr.id AS request_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    wp.year_num || COALESCE('-' || LPAD(wp.month_num::TEXT, 2, '0'), '') AS period_key,
    dr.requested_item,
    dr.request_category,
    dr.status,
    dr.contact_channel,
    dr.response_status,
    dr.requested_date,
    dr.due_date,
    CASE WHEN dr.due_date IS NOT NULL
         THEN EXTRACT(DAY FROM NOW() - dr.due_date)::INTEGER
         ELSE NULL
    END AS days_overdue,
    dr.last_reminded_at
FROM ops.document_requests dr
JOIN core.clients c ON c.id = dr.client_id
LEFT JOIN core.workers w ON w.id = dr.worker_id
LEFT JOIN work.work_items wi ON wi.id = dr.work_item_id
LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
WHERE dr.status NOT IN ('received', 'cancelled')
ORDER BY days_overdue DESC NULLS LAST;

-- View 4: TSD/KMD filing currency gaps for monthly clients
CREATE OR REPLACE VIEW ui.v_compliance_gaps AS
SELECT
    c.id AS client_id,
    c.legal_name AS client_name,
    w.display_name AS worker_name,
    c.service_tier,
    EXISTS (
        SELECT 1 FROM core.client_service_enrollments cse
        JOIN core.service_types st ON st.id = cse.service_type_id
        WHERE cse.client_id = c.id AND cse.active AND st.code = 'kmd_vat'
    ) AS kmd_obligation,
    kmd_ccc.last_completed_year AS kmd_last_year,
    kmd_ccc.last_completed_month AS kmd_last_month,
    CASE
        WHEN kmd_ccc.last_completed_month IS NULL OR kmd_ccc.last_completed_year IS NULL THEN NULL
        ELSE (EXTRACT(YEAR FROM NOW())::INTEGER - kmd_ccc.last_completed_year) * 12
             + EXTRACT(MONTH FROM NOW())::INTEGER - kmd_ccc.last_completed_month
    END AS kmd_gap_months,
    EXISTS (
        SELECT 1 FROM core.client_service_enrollments cse
        JOIN core.service_types st ON st.id = cse.service_type_id
        WHERE cse.client_id = c.id AND cse.active AND st.code = 'payroll_tsd'
    ) AS tsd_obligation,
    tsd_ccc.last_completed_year AS tsd_last_year,
    tsd_ccc.last_completed_month AS tsd_last_month,
    CASE
        WHEN tsd_ccc.last_completed_month IS NULL OR tsd_ccc.last_completed_year IS NULL THEN NULL
        ELSE (EXTRACT(YEAR FROM NOW())::INTEGER - tsd_ccc.last_completed_year) * 12
             + EXTRACT(MONTH FROM NOW())::INTEGER - tsd_ccc.last_completed_month
    END AS tsd_gap_months
FROM core.clients c
LEFT JOIN core.workers w ON w.id = c.primary_worker_id
LEFT JOIN work.client_compliance_currency kmd_ccc
    ON kmd_ccc.client_id = c.id AND kmd_ccc.obligation_code = 'KMD'
LEFT JOIN work.client_compliance_currency tsd_ccc
    ON tsd_ccc.client_id = c.id AND tsd_ccc.obligation_code = 'TSD'
WHERE c.service_tier = 'monthly'
AND c.status = 'active';

-- View 5: Annual report pipeline tracker (replaces v_annual_report_pipeline)
CREATE OR REPLACE VIEW ui.v_annual_report_tracker AS
WITH annual_items AS (
    SELECT
        wi.id,
        wi.client_id,
        wi.worker_id,
        wi.status,
        wi.engagement_health,
        wi.priority,
        wi.due_date,
        wp.year_num
    FROM work.work_items wi
    JOIN core.service_types st ON st.id = wi.service_type_id
    LEFT JOIN work.work_periods wp ON wp.id = wi.work_period_id
    WHERE st.code = 'annual_report'
),
annual_notes AS (
    SELECT DISTINCT ON (client_id)
        client_id,
        body
    FROM work.work_notes
    WHERE note_type IN ('annual_report_note', 'client_master_note')
    ORDER BY client_id, created_at DESC
)
SELECT
    ai.id AS work_item_id,
    c.legal_name AS client_name,
    c.service_tier,
    w.display_name AS primary_worker,
    ai.year_num AS aa_year,
    ai.status AS aa_status,
    ai.engagement_health,
    ai.due_date AS aa_due_date,
    MAX(CASE WHEN wr.requirement_code = 'ARIREGISTER' THEN wr.requirement_status END) AS ariregister_filed,
    scr.folder_name AS folder_name_status_encoded,
    (SELECT COUNT(*) FROM work.blockers b
     WHERE b.client_id = c.id AND b.status IN ('open', 'awaiting_response')) AS aa_blocker_count,
    an.body AS notes
FROM annual_items ai
JOIN core.clients c ON c.id = ai.client_id
LEFT JOIN core.workers w ON w.id = ai.worker_id
LEFT JOIN work.work_requirements wr ON wr.work_item_id = ai.id
LEFT JOIN annual_notes an ON an.client_id = ai.client_id
LEFT JOIN LATERAL (
    SELECT folder_name FROM source.source_client_roots
    WHERE client_id = ai.client_id
    ORDER BY created_at DESC LIMIT 1
) scr ON TRUE
GROUP BY
    ai.id, c.id, c.legal_name, c.service_tier, w.display_name,
    ai.year_num, ai.status, ai.engagement_health,
    ai.due_date, scr.folder_name, an.body;

-- View 6: Full client context card (pre-call review)
CREATE OR REPLACE VIEW ui.v_client_profile AS
SELECT
    c.id AS client_id,
    c.legal_name,
    c.registry_code,
    c.vat_number,
    c.entity_type,
    c.status AS client_status,
    c.service_tier,
    c.accounting_system,
    c.onboarding_date,
    c.offboarding_date,
    w.display_name AS primary_worker,
    w.email AS primary_worker_email,
    ca.important_info,
    ca.vehicle_flag,
    ca.lang_preference,
    ca.doc_delivery_method,
    ca.billing_frequency,
    ca.vat_threshold_alert,
    ca.fiscal_year_text,
    tsd_ccc.last_completed_year AS tsd_last_year,
    tsd_ccc.last_completed_month AS tsd_last_month,
    kmd_ccc.last_completed_year AS kmd_last_year,
    kmd_ccc.last_completed_month AS kmd_last_month,
    aa_ccc.last_completed_year AS aa_last_year,
    last_inv.invoice_number AS last_invoice_number,
    last_inv.invoice_date AS last_invoice_date,
    (SELECT COUNT(*) FROM work.blockers b
     WHERE b.client_id = c.id AND b.status IN ('open', 'awaiting_response')) AS open_blocker_count,
    (SELECT COUNT(*) FROM ops.document_requests dr
     WHERE dr.client_id = c.id AND dr.status NOT IN ('received', 'cancelled')) AS open_doc_request_count,
    c.updated_at
FROM core.clients c
LEFT JOIN core.workers w ON w.id = c.primary_worker_id
LEFT JOIN core.client_attributes ca ON ca.client_id = c.id
LEFT JOIN work.client_compliance_currency tsd_ccc
    ON tsd_ccc.client_id = c.id AND tsd_ccc.obligation_code = 'TSD'
LEFT JOIN work.client_compliance_currency kmd_ccc
    ON kmd_ccc.client_id = c.id AND kmd_ccc.obligation_code = 'KMD'
LEFT JOIN work.client_compliance_currency aa_ccc
    ON aa_ccc.client_id = c.id AND aa_ccc.obligation_code = 'AA'
LEFT JOIN LATERAL (
    SELECT invoice_number, invoice_date
    FROM sales.sales_invoice_headers
    WHERE client_id = c.id
    ORDER BY invoice_date DESC NULLS LAST, id DESC
    LIMIT 1
) last_inv ON TRUE;
