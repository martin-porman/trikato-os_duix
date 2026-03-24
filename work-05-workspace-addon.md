# Work 05 — Google Workspace Add-on (HTTP Runtime)

> **For the LLM doing this work:** Read START.md first.
> This is an HTTP add-on — NOT Apps Script. Hosted on Cloud Run (or Cloudflare Tunnel for dev).
> All add-on files go in `trikato-os/addon/`.
> Prerequisite: Work 02 (server running at pipeline.trikato.ee).

---

## What This Builds

```
trikato-os/addon/
├── manifest.json       ← Add-on manifest (registered with Google Cloud)
└── (server endpoints already in accounting-pipeline/pipeline/main.py)
```

Workers install the add-on once. It appears in:
- Drive sidebar when viewing any file
- Gmail sidebar when reading any email

---

## How HTTP Add-ons Work

1. Admin registers add-on manifest with Google Cloud (once)
2. Admin deploys to all 19 workers via Google Admin Console (once)
3. Each worker authorizes the OAuth scopes on first open (one consent click)
4. Every time a worker interacts → Google sends POST to our server with:
   - `event.userOAuthToken` — fresh token scoped to the add-on's OAuth scopes
   - `event.drive.selectedItems[].id` — selected Drive file(s)
   - `event.gmail.messageId` — open Gmail message
5. Our server uses the `userOAuthToken` to access Drive/Gmail AS the worker
6. Server returns a Card JSON response → rendered in worker's sidebar

Key difference from DWD:
- `userOAuthToken`: worker is present, token is fresh → use for Drive access in add-on calls
- DWD: worker is absent (3am cron) → use for automated sync

---

## Task 5.1 — Add-on Manifest JSON

File: `trikato-os/addon/manifest.json`

```json
{
  "name": "Trikato Pipeline",
  "description": "Send documents to the Trikato accounting pipeline",
  "logoUrl": "https://pipeline.trikato.ee/static/logo.png",
  "homepageTrigger": {
    "runFunction": "https://pipeline.trikato.ee/addon/drive/homepage"
  },
  "oauthScopes": [
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/script.locale"
  ],
  "addOns": {
    "common": {
      "name": "Trikato Pipeline",
      "logoUrl": "https://pipeline.trikato.ee/static/logo.png",
      "useLocaleFromApp": true
    },
    "drive": {
      "homepageTrigger": {
        "runFunction": "https://pipeline.trikato.ee/addon/drive/homepage"
      },
      "onItemsSelectedTrigger": {
        "runFunction": "https://pipeline.trikato.ee/addon/drive/file"
      }
    },
    "gmail": {
      "homepageTrigger": {
        "runFunction": "https://pipeline.trikato.ee/addon/gmail/message"
      },
      "contextualTriggers": [
        {
          "unconditional": {},
          "onTriggerFunction": "https://pipeline.trikato.ee/addon/gmail/message"
        }
      ]
    }
  },
  "flows": {
    "workflowElements": [
      {
        "id": "trikato-process-invoice",
        "state": "ACTIVE",
        "name": "Trikato: Process Invoice",
        "description": "Send a Drive file to the Trikato accounting pipeline",
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
              "description": "Job status",
              "cardinality": "SINGLE",
              "dataType": { "basicType": "STRING" }
            }
          ],
          "onConfigFunction": "https://pipeline.trikato.ee/addon/studio/process-invoice/config",
          "onExecuteFunction": "https://pipeline.trikato.ee/addon/studio/process-invoice/execute"
        }
      },
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
      },
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
    ]
  }
}
```

---

## Task 5.3 — POST /addon/drive/homepage

Add to `accounting-pipeline/pipeline/main.py`:

```python
@app.post("/addon/drive/homepage")
async def drive_homepage(event: dict):
    """Drive sidebar homepage card — shown when add-on opens without selection."""
    user_email = event.get("commonEventObject", {}).get("userLocale", "")

    return {
        "action": {
            "navigations": [{
                "pushCard": {
                    "header": {
                        "title": "Trikato Pipeline",
                        "subtitle": "Accounting document processor"
                    },
                    "sections": [{
                        "header": "How to use",
                        "widgets": [
                            {
                                "textParagraph": {
                                    "text": "1. Select a file in Drive\n2. Click <b>Send to Pipeline</b>\n3. The file is automatically classified and routed"
                                }
                            },
                            {
                                "buttonList": {
                                    "buttons": [{
                                        "text": "View Pipeline Status",
                                        "onClick": {
                                            "openLink": {
                                                "url": "http://192.168.10.6:8000"
                                            }
                                        }
                                    }]
                                }
                            }
                        ]
                    }]
                }
            }]
        }
    }
```

---

## Task 5.4 — POST /addon/drive/file

```python
@app.post("/addon/drive/file")
async def drive_file(event: dict):
    """
    Drive sidebar card for selected file(s).
    Shows file info + Send to Pipeline button.
    Uses userOAuthToken for Drive metadata lookup.
    """
    selected = event.get("drive", {}).get("selectedItems", [])
    if not selected:
        return await drive_homepage(event)

    file_info = selected[0]
    file_id = file_info.get("id", "")
    file_name = file_info.get("title", "Unknown file")
    mime_type = file_info.get("mimeType", "")
    user_email = event.get("authorizationEventObject", {}).get("userIdToken", "")

    # Auto-detect client from folder context
    oauth_token = event.get("authorizationEventObject", {}).get("userOAuthToken", "")
    client_name = await _detect_client_from_file(file_id, oauth_token)

    return {
        "action": {
            "navigations": [{
                "pushCard": {
                    "header": {
                        "title": file_name,
                        "subtitle": "Ready to process"
                    },
                    "sections": [
                        {
                            "widgets": [
                                {
                                    "keyValue": {
                                        "topLabel": "Detected client",
                                        "content": client_name or "Not detected — will prompt",
                                        "icon": "PERSON"
                                    }
                                },
                                {
                                    "keyValue": {
                                        "topLabel": "File type",
                                        "content": mime_type.split("/")[-1].upper(),
                                        "icon": "DESCRIPTION"
                                    }
                                }
                            ]
                        },
                        {
                            "widgets": [{
                                "buttonList": {
                                    "buttons": [{
                                        "text": "Send to Pipeline",
                                        "onClick": {
                                            "action": {
                                                "function": "https://pipeline.trikato.ee/addon/drive/send",
                                                "parameters": [
                                                    {"key": "file_id", "value": file_id},
                                                    {"key": "client_name", "value": client_name or ""}
                                                ]
                                            }
                                        },
                                        "color": {"red": 0.2, "green": 0.6, "blue": 0.2}
                                    }]
                                }
                            }]
                        }
                    ]
                }
            }]
        }
    }


@app.post("/addon/drive/send")
async def drive_send(event: dict):
    """Handle 'Send to Pipeline' button click."""
    params = {p["key"]: p["value"]
              for p in event.get("commonEventObject", {}).get("parameters", [])}

    file_id = params.get("file_id", "")
    client_name = params.get("client_name", "")
    oauth_token = event.get("authorizationEventObject", {}).get("userOAuthToken", "")
    worker_email = event.get("commonEventObject", {}).get("userLocale", "")

    job_id = await enqueue_job(
        file_id=file_id,
        client_name=client_name,
        worker_email=worker_email,
        user_oauth_token=oauth_token,
        source="addon_drive",
    )

    return {
        "action": {
            "navigations": [{
                "pushCard": {
                    "header": {"title": "Sent to Pipeline"},
                    "sections": [{
                        "widgets": [
                            {"textParagraph": {"text": f"✅ Job queued: <b>{job_id[:8]}...</b>"}},
                            {"textParagraph": {"text": "Processing will complete within a few minutes."}}
                        ]
                    }]
                }
            }]
        }
    }


async def _detect_client_from_file(file_id: str, oauth_token: str) -> str | None:
    """Try to infer client name from the Drive folder containing this file."""
    try:
        from googleapiclient.discovery import build
        from google.oauth2.credentials import Credentials
        creds = Credentials(token=oauth_token)
        service = build("drive", "v3", credentials=creds)
        file_meta = service.files().get(
            fileId=file_id,
            fields="parents",
            supportsAllDrives=True
        ).execute()
        if file_meta.get("parents"):
            folder = service.files().get(
                fileId=file_meta["parents"][0],
                fields="name",
                supportsAllDrives=True
            ).execute()
            return folder.get("name")
    except Exception:
        pass
    return None
```

---

## Task 5.5 — POST /addon/gmail/message

```python
@app.post("/addon/gmail/message")
async def gmail_message(event: dict):
    """
    Gmail sidebar card for open email.
    Shows: sender, has attachment, Send attachments to pipeline button.
    """
    message_id = event.get("gmail", {}).get("messageId", "")
    oauth_token = event.get("authorizationEventObject", {}).get("userOAuthToken", "")
    worker_email = event.get("commonEventObject", {}).get("userLocale", "")

    # Get email metadata using userOAuthToken
    sender = "Unknown"
    subject = ""
    has_pdf = False
    attachment_ids = []

    try:
        from googleapiclient.discovery import build
        from google.oauth2.credentials import Credentials
        creds = Credentials(token=oauth_token)
        service = build("gmail", "v1", credentials=creds)
        msg = service.users().messages().get(
            userId="me",
            id=message_id,
            format="metadata",
            metadataHeaders=["From", "Subject"]
        ).execute()

        headers = {h["name"]: h["value"] for h in msg["payload"].get("headers", [])}
        sender = headers.get("From", "Unknown")
        subject = headers.get("Subject", "")

        # Check for PDF attachments
        for part in msg["payload"].get("parts", []):
            if part.get("filename", "").lower().endswith((".pdf", ".jpg", ".jpeg", ".png")):
                has_pdf = True
                attachment_ids.append(part.get("body", {}).get("attachmentId", ""))

    except Exception as e:
        logger.warning(f"Gmail metadata fetch failed: {e}")

    # Build card
    widgets = [
        {"keyValue": {"topLabel": "From", "content": sender, "icon": "EMAIL"}},
        {"keyValue": {"topLabel": "Subject", "content": subject or "(no subject)", "icon": "DESCRIPTION"}},
        {"keyValue": {
            "topLabel": "Attachments",
            "content": "PDF/image attachments found" if has_pdf else "No invoice attachments",
            "icon": "ATTACHMENT"
        }},
    ]

    if has_pdf:
        widgets.append({
            "buttonList": {
                "buttons": [{
                    "text": "Route attachments to Pipeline",
                    "onClick": {
                        "action": {
                            "function": "https://pipeline.trikato.ee/addon/gmail/route",
                            "parameters": [
                                {"key": "message_id", "value": message_id},
                                {"key": "sender", "value": sender},
                            ]
                        }
                    },
                    "color": {"red": 0.2, "green": 0.6, "blue": 0.2}
                }]
            }
        })

    return {
        "action": {
            "navigations": [{
                "pushCard": {
                    "header": {"title": "Trikato Pipeline", "subtitle": "Email analysis"},
                    "sections": [{"widgets": widgets}]
                }
            }]
        }
    }


@app.post("/addon/gmail/route")
async def gmail_route(event: dict):
    """Route Gmail attachments to pipeline via Drive (auto-add to Drive first)."""
    params = {p["key"]: p["value"]
              for p in event.get("commonEventObject", {}).get("parameters", [])}
    message_id = params.get("message_id", "")
    sender = params.get("sender", "")
    oauth_token = event.get("authorizationEventObject", {}).get("userOAuthToken", "")
    worker_email = event.get("commonEventObject", {}).get("userLocale", "")

    # Note: Gmail attachments go Drive first (via Studio flow "Auto-add attachments")
    # then pipeline picks up from Drive. This endpoint is for direct manual routing.
    job_id = await enqueue_job(
        file_id=f"gmail:{message_id}",  # special prefix — queue worker handles Gmail
        client_name=sender,
        worker_email=worker_email,
        user_oauth_token=oauth_token,
        source="addon_gmail",
    )

    return {
        "action": {
            "navigations": [{
                "pushCard": {
                    "header": {"title": "Attachments Routed"},
                    "sections": [{
                        "widgets": [
                            {"textParagraph": {"text": f"✅ Job queued: <b>{job_id[:8]}...</b>"}},
                            {"textParagraph": {"text": f"Email from {sender} sent to pipeline."}}
                        ]
                    }]
                }
            }]
        }
    }
```

---

## Task 5.8 — Deploy Add-on

### Step 1: Register the add-on in Google Cloud Console

```bash
# Install gcloud if needed
# Register add-on with the manifest
gcloud workspace-add-ons deployments create trikato-pipeline \
  --deployment-file=trikato-os/addon/manifest.json
```

Or via Console: APIs & Services → Workspace Add-ons → Create new deployment.

### Step 2: Publish to your domain (internal)

In the deployment settings, set visibility to "Internal" so only `@trikato.ee` users see it.

---

## Task 5.9 — Admin Installs for All 19 Workers

In Google Admin Console:
1. Apps → Google Workspace Marketplace apps → Add app to domain install list
2. Search for "Trikato Pipeline" (internal)
3. Install for all users in organization

Workers will see the add-on automatically. On first use, they click "Authorize" — one consent click for all scopes.

---

## Task 5.10 — Drive Installable Trigger

The add-on's `onItemsSelectedTrigger` fires automatically when a worker selects a file in Drive. No additional trigger registration needed — it's declared in the manifest.

For programmatic Drive triggers (file created in folder), see Work 06 (Studio flows) which uses the built-in "File added to Drive folder" starter.

---

## Verification Checklist

- [ ] `pipeline.trikato.ee` resolves and returns 200 on `/health`
- [ ] `manifest.json` validates (no JSON syntax errors): `python3 -m json.tool manifest.json`
- [ ] `curl -X POST https://pipeline.trikato.ee/addon/drive/homepage -H "Content-Type: application/json" -d '{}'` returns a Card JSON
- [ ] Add-on appears in Drive sidebar for merilin@trikato.ee
- [ ] Selecting a file shows the file card with "Send to Pipeline" button
- [ ] Clicking "Send to Pipeline" creates a job: `SELECT * FROM trikato.jobs ORDER BY created_at DESC LIMIT 1`
- [ ] Gmail sidebar shows email metadata for open email
- [ ] Custom steps appear in Studio step picker (requires Google to enable "Limited Preview" for trikato.ee domain)

---

## Important: Custom Steps (flows section in manifest)

The `flows.workflowElements` in the manifest exposes our custom steps to Workspace Studio.
This is a **Limited Preview** feature — it must be enabled per domain by Google.

To request access:
- Go to: https://workspace.google.com/products/studio/
- Look for "Custom steps" or "Workspace Studio Limited Preview" sign-up
- Or contact your Google Workspace rep

Until enabled, Studio flows work fine with built-in steps only; custom steps won't appear in the step picker.
