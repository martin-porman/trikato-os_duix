# Trikato OS Path Map

Path-indexed map of the most relevant audited files and folders.

| Path | Purpose |
|---|---|
| `/home/martin/Trikato/trikato-os/solution.2./index.html` | Static Trikato OS overview/dashboard prototype used as the strongest UI reference for the worker-facing shell |
| `/home/martin/Trikato/trikato-os/solution.2./toovoog.html` | Static workflow queue page showing engagements, tasks, document requests, OCR review, blockers, and follow-up activity |
| `/home/martin/Trikato/trikato-os/solution.2./klienditoimik.html` | Static client dossier page showing client lifecycle, engagement health, document requests, communications, and notes |
| `/home/martin/Trikato/trikato-os/solution.2./vastavus.html` | Static compliance/annual-report page inside solution 2 |
| `/home/martin/Trikato/trikato-os/vastavus.html` | Primary compliance page explicitly named by the task and used for comparison |
| `/home/martin/Trikato/trikato-os/solution.2./assets/styles.css` | Shared styling for the static Trikato OS reference UI |
| `/home/martin/Trikato/trikato-os/solution.2./assets/app.js` | Shared lightweight interactions for the static UI reference |
| `/home/martin/Trikato/User-tools/FULL-SYSTEM-PICTURE-2026-03-21.md` | System-level architecture memo connecting intake, pipeline, Baserow, and future automation layers |
| `/home/martin/Trikato/User-tools/trikato-os/START.md` | Current orientation document describing what exists, what is missing, and priority next steps |
| `/home/martin/Trikato/User-tools/trikato-os/TASKS.md` | Master implementation task list and current status of work packages |
| `/home/martin/Trikato/User-tools/trikato-os/FLOWCHART.md` | Mermaid system and intake flowcharts for the intended end-to-end architecture |
| `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24.md` | Verified SQL/schema/view implementation record for the canonical DB layer |
| `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24-SESSION3.md` | Baserow external-table setup log with row counts and sync IDs |
| `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql` | Canonical PostgreSQL schema for Trikato OS across `core/source/workflow/work/sales/accounting/ops/audit/ui` |
| `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql` | Baserow-facing and operator-facing `ui.*` read views |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting` | Reference export of the 9-domain operational model used as a workflow blueprint |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/readme.txt` | Narrative context tying the Notion export to worker Drive/Gmail reality and automation goals |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Clients 328050f4229f813e8af0d5ce896b50de.csv` | Example client master table with linked communications, compliance items, engagements, invoices, and service mix |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Engagements 328050f4229f817ca00bfce2ff60b125.csv` | Example engagement/work-package table with due dates, health, requests, tasks, and service type |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Engagements/Redwood Coffee — Monthly Bookkeeping (Feb 2026) 328050f4229f819c9188f14e622d042b.html` | Concrete engagement page showing due date, health, status, linked requests, and linked tasks |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks 328050f4229f8175af65d401a048bc23.csv` | Example task/action table including owner, due date, blocked reason, and task type |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Tasks/Send doc request reminder depreciation schedule 328050f4229f8193b8d0d67fa00793cc.html` | Concrete reminder task page showing blocked reason, owner, due date, task type, and follow-up note |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Document Requests 328050f4229f81c38a85e23c5109df85.csv` | Example missing-document request table with requested/received dates, channel, and status |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Document Requests 328050f4229f81c38a85e23c5109df85.html` | HTML export confirming the request-lifecycle fields and linked engagement structure |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Documents 328050f4229f8131bdb2c7e58680b2c9.csv` | Example document inventory table with request linkage, sensitivity, and status |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.csv` | Example communications log showing follow-up due dates and follow-up-needed flags |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Communications 328050f4229f81f5a9d8c4214cc2ae13.html` | HTML export confirming direction, follow-up due, follow-up needed, summary, and owner fields |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Compliance Calendar 328050f4229f812ba30ed6f93bcc0ba4.csv` | Example compliance/deadline table with jurisdiction, period, and status |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Invoices 328050f4229f81bf8419d817d22d66ed.csv` | Example billing/invoicing table for client charges and payment status |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists 328050f4229f812cb40fe7f944b6b47d.csv` | Example SOP/template/checklist library used to standardize recurring work and messaging |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists/Client Document Request Email Template 328050f4229f81799545dc572b87799c.html` | Concrete client-facing reminder/template page used as a messaging pattern reference |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/SOPs & Checklists/Monthly Bookkeeping Close SOP 328050f4229f8167b225f31177e2a2a0.html` | Concrete internal SOP page used as an operator checklist/process reference |
| `/home/martin/Trikato/User-tools/Example-Notion/Accounting/Clients/Redwood Coffee Roasters LLC 328050f4229f813e99b0c7c1adba9e77.html` | Concrete client page showing onboarding date, services, payment terms, status, and linked records |
| `/home/martin/Trikato/User-tools/accounting-pipeline/CODEBASE.md` | Codebase-level documentation for the pipeline and its 11-node structure |
| `/home/martin/Trikato/User-tools/accounting-pipeline/run.py` | CLI entrypoint for pipeline execution in local, incoming, or company/period mode |
| `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py` | Filesystem watcher that auto-triggers the pipeline from `data/incoming` |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/workflow.py` | LangGraph wiring of the 11 pipeline nodes |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/state.py` | Shared `PipelineState` structure passed through the workflow |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/drive_fetch.py` | Intake node that fetches from Drive or bypasses via local/incoming path |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/ingest.py` | Ingest node that unpacks ZIPs and creates clean work directories |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/organizer.py` | Organizer node that categorizes and renames files into accounting buckets |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/bank_parser.py` | Bank parser node for PDF and camt.053 bank statements |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/invoice_extract.py` | OCR invoice extraction node using ORC_LLM_Vision and math checks |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/reconciler.py` | Matching logic between invoices and bank transactions |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/persist_json.py` | State snapshot serializer marking runs as `pending_approval` |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/human_approval.py` | Current CLI-based approval and edit step |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/merit_submit.py` | Merit Aktiva submission node for approved purchase invoices |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/email_draft.py` | Missing-data email draft generator |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/pipeline/nodes/html_report.py` | Vastavus-style HTML report generator |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/drive_client.py` | Google Drive API client used by pipeline intake |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/merit_client.py` | Merit Aktiva HMAC API client |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/contract_client.py` | Wrapper client for the onboarding/contract generator service |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/maksuamet_client.py` | Wrapper client for EMTA/Maksuamet financial snapshot service |
| `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py` | Canonical importer for workbooks, Merilin drive copy, and sales reports into PostgreSQL |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/README.md` | Onboarding-service role, API, operational ports, and intended role in Trikato OS |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/Autocomplete.md` | Feature spec for the onboarding service, including planned Baserow/PDF/email work |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/main.py` | FastAPI implementation of onboarding endpoints |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/config.py` | Service configuration and external endpoint settings |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/models/schemas.py` | Pydantic request/response models for the onboarding service |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/autocomplete.py` | Business Register autocomplete client |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/company_details.py` | SOAP company-data enrichment client |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/service/services/template_filler.py` | HTML contract filler and test-save logic |
| `/home/martin/Trikato/baserow/Trikato-Plugins/Auto_Complete_Service/page/index.html` | Generic plugin test/demo UI; useful only as a service wrapper, not as the main Trikato OS UI |
| `/home/martin/Trikato/User-tools/trikato-os/work-07-baserow-ui.md` | Baserow configuration plan mapping `ui.*` views into operator tables |
| `/home/martin/Trikato/User-tools/trikato-os/FEATURE-INVENTORY.md` | Feature-by-feature inventory produced by this audit |
| `/home/martin/Trikato/User-tools/trikato-os/GAP-ANALYSIS.md` | Gap analysis comparing UI, docs, code, schema, and plugin realities |
| `/home/martin/Trikato/User-tools/trikato-os/UNIFIED-SOLUTION.md` | Consolidated unified Trikato OS solution document produced by this audit |
