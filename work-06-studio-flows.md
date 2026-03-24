# Work 06 — Workspace Studio Flows

> **For the LLM doing this work:** Read START.md first. This work package is
> about the no-code automation layer in Google Workspace Studio.
> No Python. No Terraform. Studio UI + Add-on manifest JSON only.
>
> **Prerequisite:** Work 05 (Add-on) must be deployed first — custom steps come from the add-on.

---

## What Workspace Studio Is

Studio (`studio.workspace.google.com`) is Google's no-code flow builder.
Workers build flows without code: pick a Starter → add Steps → turn on.

**Key facts from official docs:**
- Max 20 steps per flow
- Steps run synchronously (one completes before next starts)
- Custom steps = our Add-on exposes them via `flows.workflowElements` in manifest
- Custom steps are **Limited Preview** — must be enabled per org
- The `hostApp: "WORKFLOW"` in event object identifies Studio-triggered calls
- Our server receives: `event.workflow.actionInvocation.inputs`

---

## Available Built-in Starters

| Starter | Config |
|---------|--------|
| Email received | filter: sender, subject, label, has:attachment |
| Calendar schedule | recurring time (daily, weekly, hourly) |
| Google Forms submitted | specify form ID |
| File added to Drive folder | specify folder ID |
| Manual | user clicks "Run" |

## Available Built-in Steps

| Step | What it does |
|------|-------------|
| Ask Gemini | classify/summarize/decide — returns text output |
| Send email | Gmail send |
| Post in Chat | post to a space or DM |
| Create Task | Google Tasks |
| Add label | Gmail label |
| Star email | Gmail star |
| Add to Drive | move/copy file |
| Auto-add attachments | save email attachments to Drive folder |
| Create Doc | new Google Doc from template |
| Add to Doc | append text to existing Doc |
| Draft email | Gemini-generated draft |
| Create calendar event | new event |

---

## Task 6.1 — Reactivate Existing Stopped Flow

**Flow ID:** `t258d25ddc51a2a5c224363508bad9356`
**Original name:** "Auto-create tasks when files are added to a folder"
**Account:** `merilin@trikato.ee` (u/3)

Steps:
1. Go to `https://studio.workspace.google.com/u/3/workflow/t258d25ddc51a2a5c224363508bad9356`
2. Check why it's stopped (likely: Merilin's account or folder permissions)
3. Re-enable it as a baseline — this gives Merilin task alerts immediately
4. Document the flow structure for reference

---

## Task 6.2 — Main Intake Flow: Drive File → Pipeline

**Name:** "Trikato: Process new client document"
**Who turns it on:** Each of the 19 workers (or admin deploys template)

### Flow structure:
```
STARTER: File added to Drive folder
Config: [worker selects their client folders, one flow per folder OR wildcard]

STEP 1: Ask Gemini
Prompt: "Is this file an accounting document (invoice, receipt, bank statement,
contract)? Reply with only: YES or NO"
Input: file name + detected mime type
Output: is_accounting_doc (string)

STEP 2: [condition on is_accounting_doc]
If YES → STEP 3
If NO → STEP 4

STEP 3: Trikato: Process Invoice  ← our custom step
Inputs:
  - file_id: from starter output
  - client_name: from folder name (starter output)
  - worker_email: from authenticated user
Output:
  - job_id (string)
  - status (string)

STEP 4: Create Task  ← built-in
Title: "Review non-invoice file: {filename}"
Due: +3 days
```

### Studio manifest JSON for this flow template:
```json
{
  "name": "Trikato: Process new client document",
  "description": "When a file lands in a client folder, classify with Gemini and send to pipeline if it's an accounting document",
  "starter": "drive_file_added",
  "steps": [
    {
      "type": "gemini_ask",
      "prompt": "Is '{filename}' an accounting document (invoice, receipt, bank statement)? Reply YES or NO only.",
      "output": "is_accounting_doc"
    },
    {
      "type": "custom_step",
      "stepId": "trikato-process-invoice",
      "inputs": {
        "file_id": "{{starter.file_id}}",
        "client_name": "{{starter.folder_name}}"
      }
    }
  ]
}
```

---

## Task 6.3 — Gmail Attachment Flow

**Name:** "Trikato: Route invoice from email"
**Trigger:** Email received with PDF attachment

```
STARTER: Email received
Filter: has:attachment, filename:*.pdf OR filename:*.jpg

STEP 1: Ask Gemini
Prompt: "From this email subject and sender '{sender}', what company name is the sender?
         Is this an invoice or receipt? Return JSON: {company: string, is_invoice: bool}"
Output: gemini_analysis (string/JSON)

STEP 2: Auto-add attachments to Drive  ← built-in
Destination: /Incoming Documents/{sender_company}/
Output: drive_file_id

STEP 3: Trikato: Route to Client  ← our custom step
Input: company_name from Step 1 output
Output: matched_client (string), confidence (number)

STEP 4: Trikato: Process Invoice  ← our custom step
Input: file_id from Step 2, client_name from Step 3
Output: job_id

STEP 5: Post in Chat  ← built-in (optional)
Message: "📄 Invoice from {sender} routed to {matched_client} — job {job_id}"
```

---

## Task 6.4 — Daily Summary Flow

**Name:** "Trikato: Daily unread email summary"
**Useful for:** Workers who get many client emails, don't want to miss invoices

```
STARTER: Calendar schedule
Config: Every weekday at 08:00 EET

STEP 1: Ask Gemini
Prompt: "Summarize my unread emails from the past 24 hours.
         List any that contain invoices or accounting documents separately."
Output: summary (string)

STEP 2: Post in Chat (to self / space)
Message: "📬 Your daily email summary:\n{summary}"
```

---

## Tasks 6.5–6.7 — Custom Step Manifests

These go in the Add-on manifest (`appsscript.json` or HTTP manifest).
See Work 05 for the full add-on. Here are the step definitions:

### "Trikato: Process Invoice"
```json
{
  "id": "trikato-process-invoice",
  "state": "ACTIVE",
  "name": "Trikato: Process Invoice",
  "description": "Send a Drive file to the Trikato accounting pipeline for processing",
  "workflowAction": {
    "inputs": [
      {
        "id": "file_id",
        "description": "Google Drive file ID",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      },
      {
        "id": "client_name",
        "description": "Client company name",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      }
    ],
    "outputs": [
      {
        "id": "job_id",
        "description": "Pipeline job ID",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      },
      {
        "id": "status",
        "description": "Job status: queued/running/done/error",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      }
    ],
    "onConfigFunction": "https://pipeline.trikato.ee/addon/studio/process-invoice/config",
    "onExecuteFunction": "https://pipeline.trikato.ee/addon/studio/process-invoice/execute"
  }
}
```

### "Trikato: Route to Client"
```json
{
  "id": "trikato-route-client",
  "state": "ACTIVE",
  "name": "Trikato: Route to Client",
  "description": "Match a company name to a Trikato client record",
  "workflowAction": {
    "inputs": [
      {
        "id": "company_name",
        "description": "Company name from email or filename",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      }
    ],
    "outputs": [
      {
        "id": "matched_client",
        "description": "Matched Trikato client name",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      },
      {
        "id": "client_id",
        "description": "Database client ID",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "INTEGER" }
      }
    ],
    "onConfigFunction": "https://pipeline.trikato.ee/addon/studio/route-client/config",
    "onExecuteFunction": "https://pipeline.trikato.ee/addon/studio/route-client/execute"
  }
}
```

### "Trikato: Check Status"
```json
{
  "id": "trikato-check-status",
  "state": "ACTIVE",
  "name": "Trikato: Check Job Status",
  "description": "Check the processing status of a pipeline job",
  "workflowAction": {
    "inputs": [
      {
        "id": "job_id",
        "description": "Job ID from Process Invoice step",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      }
    ],
    "outputs": [
      {
        "id": "status",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      },
      {
        "id": "report_url",
        "description": "URL to HTML reconciliation report",
        "cardinality": "SINGLE",
        "dataType": { "basicType": "STRING" }
      }
    ],
    "onConfigFunction": "https://pipeline.trikato.ee/addon/studio/status/config",
    "onExecuteFunction": "https://pipeline.trikato.ee/addon/studio/status/execute"
  }
}
```

---

## Task 6.8 — Server Endpoints for Studio Steps

Add these to `pipeline/main.py` (Work 02):

```python
# Studio custom step endpoints
# Event body format: {"workflow": {"actionInvocation": {"inputs": {...}}}}

@app.post("/addon/studio/process-invoice/execute")
async def studio_process_invoice(event: dict):
    inputs = event["workflow"]["actionInvocation"]["inputs"]
    file_id = inputs["file_id"]["stringValues"][0]
    client_name = inputs["client_name"]["stringValues"][0]

    job_id = await enqueue_job(file_id=file_id, client_name=client_name)

    return {
        "hostAppAction": {
            "workflowAction": {
                "outputVariables": {
                    "job_id": {"stringValues": [job_id]},
                    "status": {"stringValues": ["queued"]}
                }
            }
        }
    }

@app.post("/addon/studio/route-client/execute")
async def studio_route_client(event: dict):
    inputs = event["workflow"]["actionInvocation"]["inputs"]
    company_name = inputs["company_name"]["stringValues"][0]

    # Fuzzy match against clients table using rapidfuzz
    from rapidfuzz import process
    client = fuzzy_match_client(company_name)  # queries PostgreSQL

    return {
        "hostAppAction": {
            "workflowAction": {
                "outputVariables": {
                    "matched_client": {"stringValues": [client["name"]]},
                    "client_id": {"integerValues": [client["id"]]}
                }
            }
        }
    }
```

---

## Task 6.9 — Test Checklist

- [ ] Open Studio as merilin@trikato.ee
- [ ] Create new flow, verify "Trikato:" steps appear in step picker
- [ ] Build flow: Drive file added → Trikato: Process Invoice
- [ ] Drop a test PDF into Fatfox OÜ folder
- [ ] Verify Studio Activity tab shows flow ran
- [ ] Verify `GET /jobs/{job_id}` returns status
- [ ] Verify Baserow `documents` table has new row
- [ ] Check pipeline ran and produced HTML report

---

## What Studio Cannot Do (Limitations)

- Steps cannot START a flow (no custom starters — use built-in Drive trigger)
- Max 20 steps per flow
- Custom steps are Limited Preview — need Google to enable for trikato.ee domain
- No branching/conditionals natively — use Gemini to return "YES/NO" then chain steps
- No loops — handle retries server-side
- Studio flows are per-user — each worker manages their own flows
  (Admin can deploy template, worker turns it on)
