# Work 02 — Pipeline Server (FastAPI)

> **For the LLM doing this work:** Read START.md first.
> This work wraps the existing LangGraph pipeline in a FastAPI server.
> **Do NOT touch** `accounting-pipeline/src/pipeline/` nodes — they work.
> All new files go in `accounting-pipeline/` alongside existing code.

---

## What Already Exists (Do Not Break)

```
/home/martin/Trikato/User-tools/accounting-pipeline/
├── src/
│   ├── pipeline/          ← 11 nodes, DO NOT TOUCH
│   ├── drive_client.py    ← OAuth2/service account Drive access
│   ├── merit_client.py    ← Merit Aktiva HMAC-SHA256 client
│   └── ...
├── run.py                 ← CLI entry (has bug to fix)
├── watcher.py             ← watchdog on data/incoming/ (has bug to fix)
└── .env → ../Extraction/ORC_LLM_Vision/.env
```

---

## Task 2.1 — Fix watcher.py (⚡ 5-minute quick win)

File: `/home/martin/Trikato/User-tools/accounting-pipeline/watcher.py`

Find line ~26:
```python
observer.schedule(IncomingHandler(), str(INCOMING), recursive=False)
```

Change to:
```python
observer.schedule(IncomingHandler(), str(INCOMING), recursive=True)
```

**Verify:**
```bash
python3 -m py_compile /home/martin/Trikato/User-tools/accounting-pipeline/watcher.py
echo "Exit code: $?"
```

---

## Task 2.2 — Fix run.py path extraction (⚡ 30-minute quick win)

File: `/home/martin/Trikato/User-tools/accounting-pipeline/run.py`

Add this function (find the right place after imports):
```python
def extract_client_from_incoming_path(path: str) -> tuple[str, str]:
    """
    Parse data/incoming/{employee}/{client}/file.pdf
    Returns (client_name, employee_email)

    Examples:
      data/incoming/merilin/Fatfox_OÜ/invoice.pdf → ("Fatfox_OÜ", "merilin")
      /abs/path/incoming/ann/ClientX/doc.pdf → ("ClientX", "ann")
    """
    from pathlib import Path
    p = Path(path)
    parts = p.parts

    # Find 'incoming' in path
    try:
        idx = list(parts).index("incoming")
        employee = parts[idx + 1]
        client = parts[idx + 2]
        return client, employee
    except (ValueError, IndexError):
        return "unknown_client", "unknown_employee"
```

**Verify:**
```bash
python3 -c "
import sys
sys.path.insert(0, '/home/martin/Trikato/User-tools/accounting-pipeline')
from run import extract_client_from_incoming_path
print(extract_client_from_incoming_path('data/incoming/merilin/Fatfox_OÜ/invoice.pdf'))
print(extract_client_from_incoming_path('/home/martin/data/incoming/ann/ClientX/doc.pdf'))
"
```
Expected output:
```
('Fatfox_OÜ', 'merilin')
('ClientX', 'ann')
```

---

## Task 2.10 — Set Merit API Keys in .env (⚡ 5-minute quick win)

File: `/home/martin/Trikato/Extraction/ORC_LLM_Vision/.env` (pipeline symlinks to this)

Find these lines and fill in the real values:
```
MERIT_API_ID=your_merit_api_id_here
MERIT_API_KEY=your_merit_api_key_here
```

Ask Martin for the Merit credentials if not available.

**Verify:**
```bash
grep MERIT /home/martin/Trikato/Extraction/ORC_LLM_Vision/.env
```

---

## Task 2.3 — Create pipeline/main.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/pipeline/main.py`

```python
"""
Trikato Pipeline Server
FastAPI wrapper around the existing LangGraph pipeline.
Accepts jobs from: Drive sync, GWS Add-on, Workspace Studio custom steps.
"""
import os
import sys
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# Add accounting-pipeline to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from queue_worker import enqueue_job, get_job_status
from src.storage_client import StorageClient

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Trikato Pipeline Server starting")
    yield
    logger.info("Trikato Pipeline Server shutting down")


app = FastAPI(
    title="Trikato Pipeline Server",
    version="1.0.0",
    lifespan=lifespan
)


# ─── Request/Response Models ───────────────────────────────────────────────

class IntakeRequest(BaseModel):
    file_id: str                    # Google Drive file ID
    client_name: str                # Client company name
    worker_email: str               # Which @trikato.ee worker
    user_oauth_token: str | None = None  # Present if user-initiated
    source: str = "unknown"         # "addon", "sync", "studio"

class IntakeResponse(BaseModel):
    job_id: str
    status: str = "queued"

class JobStatus(BaseModel):
    job_id: str
    status: str                     # queued | running | done | error
    created_at: str | None = None
    completed_at: str | None = None
    report_url: str | None = None
    error_message: str | None = None


# ─── Health ────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "service": "trikato-pipeline"}


# ─── Main Intake ───────────────────────────────────────────────────────────

@app.post("/intake", response_model=IntakeResponse)
async def intake(req: IntakeRequest):
    """
    Unified intake endpoint.
    Called by: DWD sync cron, Add-on Drive trigger, Workspace Studio.
    Enqueues job for async processing by queue_worker.py
    """
    logger.info(f"Intake: file={req.file_id} client={req.client_name} "
                f"worker={req.worker_email} source={req.source}")

    job_id = await enqueue_job(
        file_id=req.file_id,
        client_name=req.client_name,
        worker_email=req.worker_email,
        user_oauth_token=req.user_oauth_token,
        source=req.source,
    )

    return IntakeResponse(job_id=job_id, status="queued")


# ─── Job Status ────────────────────────────────────────────────────────────

@app.get("/jobs/{job_id}", response_model=JobStatus)
async def get_job(job_id: str):
    """Check status of a pipeline job."""
    job = await get_job_status(job_id)
    if not job:
        raise HTTPException(status_code=404, detail=f"Job {job_id} not found")
    return job


# ─── Workspace Studio Custom Step Endpoints ────────────────────────────────

@app.post("/addon/studio/process-invoice/config")
async def studio_process_invoice_config(event: dict):
    """Config card for 'Trikato: Process Invoice' Studio step."""
    return {
        "action": {
            "navigations": [{"pushCard": {
                "header": {"title": "Trikato: Process Invoice"},
                "sections": [{"widgets": [
                    {"textParagraph": {
                        "text": "Routes the Drive file through the Trikato accounting pipeline."
                    }}
                ]}]
            }}]
        }
    }


@app.post("/addon/studio/process-invoice/execute")
async def studio_process_invoice(event: dict):
    """Execute endpoint for 'Trikato: Process Invoice' Studio step."""
    try:
        inputs = event["workflow"]["actionInvocation"]["inputs"]
        file_id = inputs["file_id"]["stringValues"][0]
        client_name = inputs["client_name"]["stringValues"][0]
        worker_email = event.get("commonEventObject", {}).get("userLocale", "")

        job_id = await enqueue_job(
            file_id=file_id,
            client_name=client_name,
            worker_email=worker_email,
            source="studio",
        )

        return {
            "hostAppAction": {
                "workflowAction": {
                    "outputVariables": {
                        "job_id": {"stringValues": [job_id]},
                        "status": {"stringValues": ["queued"]},
                    }
                }
            }
        }
    except (KeyError, IndexError) as e:
        raise HTTPException(status_code=400, detail=f"Invalid Studio event: {e}")


@app.post("/addon/studio/route-client/execute")
async def studio_route_client(event: dict):
    """Execute endpoint for 'Trikato: Route to Client' Studio step."""
    from rapidfuzz import process as fuzz_process
    from src.baserow_client import get_all_clients

    inputs = event["workflow"]["actionInvocation"]["inputs"]
    company_name = inputs["company_name"]["stringValues"][0]

    clients = await get_all_clients()
    client_names = [c["name"] for c in clients]

    match, score, idx = fuzz_process.extractOne(company_name, client_names)
    matched_client = clients[idx]

    return {
        "hostAppAction": {
            "workflowAction": {
                "outputVariables": {
                    "matched_client": {"stringValues": [matched_client["name"]]},
                    "client_id": {"integerValues": [matched_client["id"]]},
                }
            }
        }
    }


@app.post("/addon/studio/status/execute")
async def studio_check_status(event: dict):
    """Execute endpoint for 'Trikato: Check Status' Studio step."""
    inputs = event["workflow"]["actionInvocation"]["inputs"]
    job_id = inputs["job_id"]["stringValues"][0]

    job = await get_job_status(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    return {
        "hostAppAction": {
            "workflowAction": {
                "outputVariables": {
                    "status": {"stringValues": [job["status"]]},
                    "report_url": {"stringValues": [job.get("report_url", "")]},
                }
            }
        }
    }
```

---

## Task 2.4 — POST /intake (already in main.py above)

The `/intake` endpoint is defined in Task 2.3. It accepts the unified `IntakeRequest` body and returns `job_id`.

---

## Task 2.5 — POST /process (called by queue_worker)

This is called internally by `queue_worker.py` — not exposed externally.
The queue worker calls the existing pipeline directly via Python imports, not HTTP.
See `queue_worker.py` (Task 2.8) for the call pattern.

---

## Task 2.6 — GET /health and GET /jobs/{job_id} (already in main.py above)

Both endpoints are defined in Task 2.3.

---

## Task 2.7 — src/storage_client.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/src/storage_client.py`

```python
"""
StorageClient — unified interface for local filesystem (dev) and GCS (prod).
Controlled by STORAGE_BACKEND env var: "local" (default) or "gcs"
"""
import os
import asyncio
from pathlib import Path


class StorageClient:
    def __init__(self):
        self.backend = os.getenv("STORAGE_BACKEND", "local")
        self.local_base = Path(os.getenv("LOCAL_DATA_DIR", "data"))
        self.gcs_bucket = os.getenv("GCS_BUCKET", "")

        if self.backend == "gcs":
            from google.cloud import storage
            self._gcs = storage.Client()
            self._bucket = self._gcs.bucket(self.gcs_bucket)

    def _local_path(self, key: str) -> Path:
        p = self.local_base / key
        p.parent.mkdir(parents=True, exist_ok=True)
        return p

    async def write(self, key: str, data: bytes) -> str:
        """Write bytes. Returns URI (file:// or gs://)."""
        if self.backend == "gcs":
            blob = self._bucket.blob(key)
            await asyncio.get_event_loop().run_in_executor(
                None, blob.upload_from_string, data
            )
            return f"gs://{self.gcs_bucket}/{key}"
        else:
            path = self._local_path(key)
            path.write_bytes(data)
            return f"file://{path.absolute()}"

    async def read(self, key: str) -> bytes:
        """Read bytes by key."""
        if self.backend == "gcs":
            blob = self._bucket.blob(key)
            return await asyncio.get_event_loop().run_in_executor(
                None, blob.download_as_bytes
            )
        else:
            return self._local_path(key).read_bytes()

    async def exists(self, key: str) -> bool:
        if self.backend == "gcs":
            blob = self._bucket.blob(key)
            return await asyncio.get_event_loop().run_in_executor(None, blob.exists)
        else:
            return self._local_path(key).exists()

    def public_url(self, key: str) -> str:
        """Get public URL for HTML reports."""
        if self.backend == "gcs":
            return f"https://storage.googleapis.com/{self.gcs_bucket}/{key}"
        else:
            return f"http://localhost:8080/reports/{key}"
```

---

## Task 2.8 — queue_worker.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/queue_worker.py`

```python
"""
Job queue backed by PostgreSQL jobs table.
queue_worker.py — run as a background process alongside main.py
Polls for pending jobs, processes N=3 concurrently.
"""
import asyncio
import logging
import os
import uuid
from datetime import datetime, timezone

import asyncpg

logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://pipeline:pipeline@localhost:5434/trikato"
)
MAX_CONCURRENT = int(os.getenv("QUEUE_CONCURRENCY", "3"))
POLL_INTERVAL = 5  # seconds


async def enqueue_job(
    file_id: str,
    client_name: str,
    worker_email: str,
    user_oauth_token: str | None = None,
    source: str = "unknown",
) -> str:
    """Insert a job into the queue. Returns job_id."""
    job_id = str(uuid.uuid4())
    conn = await asyncpg.connect(DATABASE_URL)
    try:
        await conn.execute("""
            INSERT INTO trikato.jobs
                (id, file_id, client_name, worker_email, user_oauth_token,
                 source, status, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, 'queued', $7)
        """, job_id, file_id, client_name, worker_email,
            user_oauth_token, source,
            datetime.now(timezone.utc))
    finally:
        await conn.close()
    return job_id


async def get_job_status(job_id: str) -> dict | None:
    conn = await asyncpg.connect(DATABASE_URL)
    try:
        row = await conn.fetchrow(
            "SELECT * FROM trikato.jobs WHERE id = $1", job_id
        )
        if not row:
            return None
        return dict(row)
    finally:
        await conn.close()


async def _process_one(job: dict) -> None:
    """Execute one job through the pipeline."""
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).parent))

    conn = await asyncpg.connect(DATABASE_URL)
    try:
        # Mark as running
        await conn.execute(
            "UPDATE trikato.jobs SET status='running', started_at=$1 WHERE id=$2",
            datetime.now(timezone.utc), job["id"]
        )

        # Choose auth: user token (fresh) or DWD (automated)
        from src.drive_client import DriveClient
        if job.get("user_oauth_token"):
            drive = DriveClient(oauth_token=job["user_oauth_token"])
        else:
            drive = DriveClient(impersonate=job["worker_email"])

        # Download file from Drive
        file_path = await drive.download_to_local(
            job["file_id"],
            f"data/incoming/{job['worker_email']}/{job['client_name']}/"
        )

        # Run through LangGraph pipeline
        from src.pipeline.graph import run_pipeline
        result = await run_pipeline(
            file_path=str(file_path),
            client_name=job["client_name"],
            worker_email=job["worker_email"],
        )

        # Mark done
        await conn.execute("""
            UPDATE trikato.jobs
            SET status='done', completed_at=$1, report_url=$2
            WHERE id=$3
        """, datetime.now(timezone.utc), result.get("report_url"), job["id"])

        logger.info(f"Job {job['id']} completed: {result.get('report_url')}")

    except Exception as e:
        logger.exception(f"Job {job['id']} failed: {e}")
        await conn.execute(
            "UPDATE trikato.jobs SET status='error', error_message=$1 WHERE id=$2",
            str(e), job["id"]
        )
    finally:
        await conn.close()


async def _worker_loop():
    """Continuously poll for pending jobs, process up to MAX_CONCURRENT."""
    semaphore = asyncio.Semaphore(MAX_CONCURRENT)

    async def run_with_limit(job):
        async with semaphore:
            await _process_one(job)

    conn = await asyncpg.connect(DATABASE_URL)
    logger.info(f"Queue worker started (concurrency={MAX_CONCURRENT})")

    while True:
        try:
            rows = await conn.fetch("""
                SELECT * FROM trikato.jobs
                WHERE status = 'queued'
                ORDER BY created_at
                LIMIT $1
            """, MAX_CONCURRENT)

            if rows:
                # Mark fetched rows as claimed (prevents double-processing)
                ids = [r["id"] for r in rows]
                await conn.execute("""
                    UPDATE trikato.jobs
                    SET status = 'running'
                    WHERE id = ANY($1::uuid[]) AND status = 'queued'
                """, ids)

                tasks = [run_with_limit(dict(r)) for r in rows]
                await asyncio.gather(*tasks, return_exceptions=True)
            else:
                await asyncio.sleep(POLL_INTERVAL)

        except Exception as e:
            logger.exception(f"Queue worker loop error: {e}")
            await asyncio.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(_worker_loop())
```

---

## Task 2.9 — Dockerfile

File: `/home/martin/Trikato/User-tools/accounting-pipeline/Dockerfile`

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install system deps
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    poppler-utils \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Start: FastAPI server + queue worker in same container
# (For prod, split into two Cloud Run services or use background thread)
CMD ["sh", "-c", \
     "python queue_worker.py & uvicorn pipeline.main:app --host 0.0.0.0 --port 8080"]

EXPOSE 8080
```

Create/update `requirements.txt` to include:
```
fastapi>=0.110.0
uvicorn[standard]>=0.27.0
asyncpg>=0.29.0
pydantic>=2.0.0
google-auth>=2.0.0
google-auth-oauthlib>=1.0.0
google-auth-httplib2>=0.1.0
google-api-python-client>=2.0.0
rapidfuzz>=3.0.0
python-dotenv>=1.0.0
```

---

## How to Run (Dev)

```bash
cd /home/martin/Trikato/User-tools/accounting-pipeline/

# Install deps
pip install -r requirements.txt

# Start queue worker in background
python queue_worker.py &

# Start API server
uvicorn pipeline.main:app --host 0.0.0.0 --port 8080 --reload
```

---

## Verification Checklist

- [ ] `python3 -m py_compile watcher.py` — exit 0
- [ ] `python3 -m py_compile pipeline/main.py` — exit 0
- [ ] `python3 -m py_compile queue_worker.py` — exit 0
- [ ] `curl http://localhost:8080/health` returns `{"status":"ok"}`
- [ ] `curl -X POST http://localhost:8080/intake -H "Content-Type: application/json" -d '{"file_id":"test","client_name":"TestClient","worker_email":"merilin@trikato.ee","source":"manual"}'` returns `{"job_id":"...","status":"queued"}`
- [ ] `curl http://localhost:8080/jobs/{job_id}` returns job status
- [ ] `docker build -t trikato-pipeline .` completes without errors
