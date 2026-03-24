# Trikato OS — System Flowchart

## Current Implemented Foundation

As of 2026-03-24, the delivered base is:

- PostgreSQL-first foundation in
  `/home/martin/Trikato/User-tools/trikato-os/sql/schema.sql`
- Baserow-facing view layer in
  `/home/martin/Trikato/User-tools/trikato-os/sql/views.sql`
- main consolidated UI dataset: `ui.v_main_data_table`
- importer implementation in
  `/home/martin/Trikato/User-tools/accounting-pipeline/src/foundation_importer.py`
- full implementation log in
  `/home/martin/Trikato/User-tools/trikato-os/IMPLEMENTATION-LOG-2026-03-24.md`

## Full System (Mermaid)

```mermaid
flowchart TD
    subgraph SOURCES["📥 Document Sources"]
        GD["Google Drive\n19 workers × ~37 clients each\nMy Drive + Shared Drives\n+ Shared-with-me folders"]
        GM["Gmail\n19 worker inboxes\nInvoice attachments\nfrom suppliers"]
        MAN["Manual Upload\nFuture: customer portal\nWhatsApp, email dropzone"]
    end

    subgraph AUTH["🔑 Auth Layer"]
        DWD["DWD Service Account\ntrikato-service-account.json\nImpersonates any @trikato.ee\nAutomated / background sync"]
        TOK["userOAuthToken\nFrom Add-on request\nWorker is actively present\nFresh, no expiry concern"]
    end

    subgraph INTAKE["📂 Intake Layer"]
        SYNC["sync_all_workers.py\ncron every 15 min\nDiscovers all 19 workers via Admin SDK\nchanges.list per worker (DWD)"]
        ADDON["GWS Add-on\nDrive sidebar + Gmail sidebar\nDrive trigger (auto on file create)\nPOST /intake → pipeline server"]
        STUDIO["Workspace Studio Flows\nno-code layer\nWorkers build own flows\nCustom step: Trikato Process Invoice"]
    end

    subgraph SERVER["⚙️ Pipeline Server (Cloud Run / localhost:8080)"]
        API["FastAPI main.py\nPOST /intake\nPOST /addon/drive/file\nPOST /addon/gmail/message\nGET /jobs/{id}"]
        QUEUE["Job Queue\nPostgreSQL jobs table\nqueue_worker.py\nN=3 concurrent"]
        PIPE["LangGraph Pipeline\n11 nodes — DO NOT TOUCH\ndrive_fetch → ingest → organizer\n→ bank_parser → invoice_extract\n→ reconciler → persist_json\n→ human_approval → merit_submit\n→ email_draft → html_report"]
    end

    subgraph STORAGE["💾 Storage"]
        PG["PostgreSQL\nCloud SQL prod\nport 5434 local\ntrikato database with\ncore/source/workflow/work/sales/accounting/ops/audit/ui"]
        GCS["Cloud Storage\nIncoming documents\nProcessed output\nHTML reports"]
        SM["Secret Manager\nDWD key\nMerit API keys\nDB connection string"]
    end

    subgraph OUTPUT["📤 Output"]
        MERIT["Merit Aktiva API\nInvoice submission\nHMAC-SHA256 auth\nBillId returned"]
        BR["Baserow\nhttp://192.168.10.6:8000\nWorker UI\nReads ui.* SQL views\nDisposable projection layer"]
        RPT["HTML Reports\nVastavusanalüüs\nPer client per period"]
        EMAIL["Email Drafts\nMissing data requests\nTo suppliers"]
    end

    subgraph CICD["🚀 CI/CD"]
        GH["GitHub Actions\nTest + lint on PR\nBuild Docker on merge"]
        AR["Artifact Registry\nDocker images"]
        CR["Cloud Run\ntrikato-pipeline service\nscales to zero\neurope-north1"]
        TF["Terraform\ninfra/ directory\nAll GCP resources\nCloudflare DNS"]
    end

    GD -->|"file arrives in\nclient folder"| SYNC
    GD -->|"Drive trigger\nor worker click"| ADDON
    GM -->|"cron poll\nDWD"| SYNC
    GM -->|"worker clicks\nSend to pipeline"| ADDON
    MAN --> ADDON

    DWD --> SYNC
    TOK --> ADDON
    ADDON --> STUDIO

    SYNC -->|"POST /intake\nfile_id + worker + client"| API
    ADDON -->|"POST /intake\n+ userOAuthToken"| API
    STUDIO -->|"POST custom step\nonExecuteFunction"| API

    API --> QUEUE
    QUEUE --> PIPE

    PIPE -->|"download file"| GCS
    PIPE -->|"write results"| PG
    PIPE -->|"submit invoice"| MERIT
    PIPE -->|"write report"| GCS

    PG --> BR
    GCS --> RPT
    MERIT -->|"BillId → PG"| PG
    PIPE --> EMAIL

    GH --> AR
    AR --> CR
    TF --> CR
    TF --> PG
    TF --> GCS
    TF --> SM

    style SOURCES fill:#e8f4fd,stroke:#2563eb
    style AUTH fill:#fef3c7,stroke:#d97706
    style INTAKE fill:#d1fae5,stroke:#16a34a
    style SERVER fill:#f3e8ff,stroke:#7c3aed
    style STORAGE fill:#fee2e2,stroke:#dc2626
    style OUTPUT fill:#d1fae5,stroke:#16a34a
    style CICD fill:#f1f5f9,stroke:#64748b
```

---

## Workspace Studio Flow — Invoice Intake

```mermaid
flowchart LR
    S1["🔵 STARTER\nFile added to Drive folder\n(client folder of any worker)"]
    -->
    S2["⚡ STEP 1\nAsk Gemini\nIs this an accounting document?\nOutput: is_invoice (yes/no)"]
    -->
    S3{"is_invoice?"}

    S3 -->|"yes"| S4["⚡ STEP 2\nTrikato: Process Invoice\n(custom step — our add-on)\nInputs: file_id, client_name\nOutput: job_id, status"]
    S3 -->|"no"| S5["⚡ STEP 2b\nCreate Task\nReview: non-invoice file\nAssign to worker"]

    S4 --> S6["⚡ STEP 3\nPost in Chat\n✅ Processing: filename\nfor client: client_name"]
```

---

## Workspace Studio Flow — Gmail Attachment Intake

```mermaid
flowchart LR
    G1["🔵 STARTER\nEmail received\nhas:attachment\nfilter: PDF or image"]
    -->
    G2["⚡ STEP 1\nAsk Gemini\nIdentify: sender company name\nIs this an invoice?\nOutput: company, is_invoice"]
    -->
    G3{"is_invoice?"}

    G3 -->|"yes"| G4["⚡ STEP 2\nTrikato: Route to Client\n(custom step)\nInput: company name\nOutput: client_name, matched"]
    G3 -->|"no"| G5["⚡ STEP 2b\nLabel email\nAdd label: Review needed"]

    G4 --> G6["⚡ STEP 3\nTrikato: Process Invoice\nInput: attachment, client_name"]
    G6 --> G7["⚡ STEP 4\nPost in Chat\n✅ invoice from sender\nrouted to client_name"]
```

---

## Dev → Prod Migration

```mermaid
flowchart LR
    subgraph DEV["Dev (today)"]
        D1["localhost:8080\nuvicorn main:app"]
        D2["Cloudflare Tunnel\npipeline.trikato.ee\n→ localhost:8080"]
        D3["PostgreSQL\nDocker port 5434"]
        D4["data/ directory\nlocal filesystem"]
    end

    subgraph PROD["Prod (Cloud Run)"]
        P1["Cloud Run\ntrikato-pipeline\neurope-north1"]
        P2["Cloudflare DNS\npipeline.trikato.ee\n→ Cloud Run URL"]
        P3["Cloud SQL\nPostgreSQL 16\ndb-g1-small ~€9/mo"]
        P4["Cloud Storage\ndocuments bucket"]
    end

    D2 -->|"terraform apply\nupdate CNAME"| P2
    D1 -->|"docker build + push\nCloud Run deploy"| P1
    D3 -->|"pg_dump → restore\nupdate DATABASE_URL"| P3
    D4 -->|"update GCS_BUCKET env var"| P4

    note["Add-on manifest URL never changes\nWorkers notice nothing"]
```
