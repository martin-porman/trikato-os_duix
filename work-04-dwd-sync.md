# Work 04 — DWD Sync (sync_all_workers.py)

> **For the LLM doing this work:** Read START.md first.
> This is the automated background sync. No user present.
> Prerequisite: Work 03 (schema) must exist. DWD service account key required (admin task P3).
> All new files go in `accounting-pipeline/` alongside existing code.

---

## What This Builds

```
sync_all_workers.py     ← orchestrator, runs every 15 min via cron
src/drive_enumerator.py ← DWD Drive scanner for one worker
src/sync_manifest.py    ← dedup + PostgreSQL write
data/sync_state/        ← per-worker Change page tokens
```

---

## DWD Auth Pattern (Critical)

```python
from google.oauth2 import service_account
from googleapiclient.discovery import build

SCOPES = [
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/admin.directory.user.readonly",
]

def get_drive_service(worker_email: str):
    """Returns Drive service impersonating worker_email via DWD."""
    creds = service_account.Credentials.from_service_account_file(
        "trikato-service-account.json",
        scopes=SCOPES,
    )
    delegated = creds.with_subject(worker_email)
    return build("drive", "v3", credentials=delegated)
```

---

## Task 4.1 — src/drive_enumerator.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/src/drive_enumerator.py`

```python
"""
Drive enumerator using Domain-Wide Delegation.
Discovers all files for one @trikato.ee worker.
Uses Changes API for delta mode, full scan for backfill.
"""
import logging
import os
from pathlib import Path
from typing import Generator

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

logger = logging.getLogger(__name__)

SERVICE_ACCOUNT_FILE = os.getenv(
    "DWD_SERVICE_ACCOUNT_FILE",
    "trikato-service-account.json"
)

SCOPES = [
    "https://www.googleapis.com/auth/drive.readonly",
]

# MIME types to process (accounting documents)
TARGET_MIME_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/tiff",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-excel",
    # Google Workspace native
    "application/vnd.google-apps.spreadsheet",
    "application/vnd.google-apps.document",
}

# GWS native → export as
EXPORT_MAP = {
    "application/vnd.google-apps.spreadsheet": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.google-apps.document": "application/pdf",
}


def _get_service(worker_email: str):
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    return build("drive", "v3", credentials=creds.with_subject(worker_email))


def _api_call_with_backoff(callable_fn, max_retries=5):
    """Execute API call with exponential backoff on 403/429/500."""
    import time
    for attempt in range(max_retries):
        try:
            return callable_fn()
        except HttpError as e:
            if e.resp.status in (403, 429, 500, 503) and attempt < max_retries - 1:
                wait = (2 ** attempt) + 0.5
                logger.warning(f"Rate limit ({e.resp.status}), retry in {wait:.1f}s")
                time.sleep(wait)
            else:
                raise


def get_start_page_token(worker_email: str) -> str:
    """Get current Changes page token for this worker."""
    service = _get_service(worker_email)
    result = _api_call_with_backoff(
        lambda: service.changes().getStartPageToken(
            supportsAllDrives=True
        ).execute()
    )
    return result["startPageToken"]


def list_changes(worker_email: str, page_token: str) -> tuple[list[dict], str]:
    """
    Fetch Drive changes since page_token.
    Returns (list of file metadata dicts, new_start_page_token).

    Loop pattern:
        while response.get("nextPageToken"):
            page_token = response["nextPageToken"]
            response = changes.list(pageToken=page_token, ...)
        new_token = response["newStartPageToken"]  # save this for next run
    """
    service = _get_service(worker_email)
    files = []
    new_start_token = page_token

    while True:
        response = _api_call_with_backoff(
            lambda pt=page_token: service.changes().list(
                pageToken=pt,
                pageSize=1000,
                includeItemsFromAllDrives=True,
                supportsAllDrives=True,
                fields="nextPageToken,newStartPageToken,changes(removed,fileId,file(id,name,mimeType,size,md5Checksum,version,parents,driveId,modifiedTime,trashed))"
            ).execute()
        )

        for change in response.get("changes", []):
            if change.get("removed"):
                continue
            file = change.get("file", {})
            if file.get("trashed"):
                continue
            if file.get("mimeType") in TARGET_MIME_TYPES:
                files.append(file)

        if "nextPageToken" in response:
            page_token = response["nextPageToken"]
        else:
            new_start_token = response.get("newStartPageToken", page_token)
            break

    return files, new_start_token


def full_scan(worker_email: str, folder_id: str = "root") -> Generator[dict, None, None]:
    """
    Full Drive scan: enumerate all target files for worker.
    Used for initial backfill.
    Recursively traverses My Drive, Shared Drives, and shared folders.
    """
    service = _get_service(worker_email)

    def _list_folder(fid: str):
        page_token = None
        while True:
            response = _api_call_with_backoff(
                lambda fid=fid, pt=page_token: service.files().list(
                    q=f"'{fid}' in parents and trashed=false",
                    pageSize=1000,
                    pageToken=pt,
                    supportsAllDrives=True,
                    includeItemsFromAllDrives=True,
                    fields="nextPageToken,files(id,name,mimeType,size,md5Checksum,version,parents,driveId,modifiedTime)"
                ).execute()
            )
            for f in response.get("files", []):
                if f["mimeType"] == "application/vnd.google-apps.folder":
                    yield from _list_folder(f["id"])
                elif f["mimeType"] in TARGET_MIME_TYPES:
                    yield f

            if "nextPageToken" not in response:
                break
            page_token = response["nextPageToken"]

    # My Drive
    yield from _list_folder("root")

    # Shared Drives (worker may have access)
    drives_resp = _api_call_with_backoff(
        lambda: service.drives().list(pageSize=100).execute()
    )
    for drive in drives_resp.get("drives", []):
        yield from _list_folder(drive["id"])

    # Shared-with-me folders (top level folders only — must recurse)
    shared_resp = _api_call_with_backoff(
        lambda: service.files().list(
            q="sharedWithMe=true and mimeType='application/vnd.google-apps.folder'",
            pageSize=200,
            supportsAllDrives=True,
            includeItemsFromAllDrives=True,
            fields="files(id,name)"
        ).execute()
    )
    for folder in shared_resp.get("files", []):
        yield from _list_folder(folder["id"])


def download_file(worker_email: str, file_id: str, mime_type: str) -> bytes:
    """
    Download file content. Handles GWS native files via export.
    Returns bytes.
    """
    service = _get_service(worker_email)

    if mime_type in EXPORT_MAP:
        # GWS native file — must use export
        export_mime = EXPORT_MAP[mime_type]
        return _api_call_with_backoff(
            lambda: service.files().export(
                fileId=file_id,
                mimeType=export_mime
            ).execute()
        )
    else:
        # Binary file — direct download
        import io
        from googleapiclient.http import MediaIoBaseDownload
        request = service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        downloader = MediaIoBaseDownload(fh, request)
        done = False
        while not done:
            _, done = _api_call_with_backoff(lambda: downloader.next_chunk())
        return fh.getvalue()
```

---

## Task 4.2 — src/sync_manifest.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/src/sync_manifest.py`

```python
"""
Sync manifest: dedup logic + PostgreSQL write.
Determines if a file is new or already processed.
"""
import logging
import asyncpg
import os

logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://pipeline:pipeline@localhost:5434/trikato"
)


async def is_already_processed(drive_file_id: str, version: int | None, md5: str | None) -> bool:
    """
    Returns True if file is already in documents table and hasn't changed.
    Uses version for GWS native files, md5 for binary files.
    """
    conn = await asyncpg.connect(DATABASE_URL)
    try:
        row = await conn.fetchrow(
            "SELECT drive_version, md5_checksum FROM trikato.documents WHERE drive_file_id = $1",
            drive_file_id
        )
        if not row:
            return False

        if md5 and row["md5_checksum"]:
            return row["md5_checksum"] == md5

        if version and row["drive_version"]:
            return row["drive_version"] >= version

        return False
    finally:
        await conn.close()


async def get_client_by_folder(folder_name: str) -> dict | None:
    """Look up client by Drive folder name using fuzzy match."""
    from src.baserow_client import fuzzy_match_client
    return await fuzzy_match_client(folder_name)


async def record_file(
    file_meta: dict,
    worker_email: str,
    client_id: int | None,
    source: str = "drive_sync"
) -> int:
    """
    Upsert file into documents table.
    Returns document ID.
    """
    from src.baserow_client import upsert_document
    return await upsert_document(
        drive_file_id=file_meta["id"],
        file_name=file_meta.get("name", ""),
        mime_type=file_meta.get("mimeType", ""),
        client_id=client_id,
        worker_email=worker_email,
        source=source,
        file_size=file_meta.get("size"),
        drive_version=file_meta.get("version"),
        md5_checksum=file_meta.get("md5Checksum"),
    )
```

---

## Task 4.3–4.5 — sync_all_workers.py

File: `/home/martin/Trikato/User-tools/accounting-pipeline/sync_all_workers.py`

```python
"""
sync_all_workers.py — Discover all @trikato.ee workers via Admin SDK,
then sync each worker's Drive.

Usage:
  python sync_all_workers.py --mode backfill   # Full scan, run once
  python sync_all_workers.py --mode delta      # Changes since last sync (default)
  python sync_all_workers.py --worker merilin@trikato.ee  # One worker only
"""
import argparse
import asyncio
import logging
import os
import json
import httpx
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build

from src.drive_enumerator import (
    get_start_page_token,
    list_changes,
    full_scan,
)
from src.sync_manifest import is_already_processed, record_file, get_client_by_folder

logger = logging.getLogger(__name__)

SERVICE_ACCOUNT_FILE = os.getenv("DWD_SERVICE_ACCOUNT_FILE", "trikato-service-account.json")
PIPELINE_URL = os.getenv("PIPELINE_URL", "http://localhost:8080")
SYNC_STATE_DIR = Path("data/sync_state")
SYNC_STATE_DIR.mkdir(parents=True, exist_ok=True)


def _get_admin_service():
    """Admin SDK service for listing workspace users."""
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=["https://www.googleapis.com/auth/admin.directory.user.readonly"],
    )
    # Admin SDK must be delegated to an admin user
    admin_email = os.getenv("ADMIN_EMAIL", "martin@trikato.ee")
    delegated = creds.with_subject(admin_email)
    return build("admin", "directory_v1", credentials=delegated)


def discover_workers() -> list[str]:
    """
    Auto-discover all @trikato.ee workers via Admin SDK.
    No hardcoded list — new workers appear automatically.
    """
    service = _get_admin_service()
    users = []
    page_token = None

    while True:
        response = service.users().list(
            domain="trikato.ee",
            maxResults=200,
            pageToken=page_token,
            fields="nextPageToken,users(primaryEmail,suspended)"
        ).execute()

        for user in response.get("users", []):
            if not user.get("suspended"):
                users.append(user["primaryEmail"])

        page_token = response.get("nextPageToken")
        if not page_token:
            break

    logger.info(f"Discovered {len(users)} active workers")
    return users


def _token_path(worker_email: str) -> Path:
    safe = worker_email.replace("@", "_").replace(".", "_")
    return SYNC_STATE_DIR / f"{safe}_pagetoken.txt"


def _load_token(worker_email: str) -> str | None:
    p = _token_path(worker_email)
    if p.exists():
        return p.read_text().strip()
    return None


def _save_token(worker_email: str, token: str):
    _token_path(worker_email).write_text(token)


async def _enqueue_file(file_meta: dict, worker_email: str, client_name: str | None):
    """POST to /intake to queue a file for pipeline processing."""
    async with httpx.AsyncClient() as client:
        await client.post(
            f"{PIPELINE_URL}/intake",
            json={
                "file_id": file_meta["id"],
                "client_name": client_name or "unknown",
                "worker_email": worker_email,
                "source": "drive_sync",
            },
            timeout=10,
        )


async def sync_worker_delta(worker_email: str):
    """Sync one worker: only changes since last run."""
    token = _load_token(worker_email)
    if not token:
        logger.info(f"{worker_email}: No saved token, getting start token")
        token = get_start_page_token(worker_email)
        _save_token(worker_email, token)
        return  # First run: just save token, no files yet

    logger.info(f"{worker_email}: Running delta sync from token {token[:20]}...")
    files, new_token = list_changes(worker_email, token)
    logger.info(f"{worker_email}: {len(files)} changed files")

    new_count = 0
    for f in files:
        already = await is_already_processed(
            f["id"], f.get("version"), f.get("md5Checksum")
        )
        if already:
            continue

        # Infer client from parent folder name (best effort)
        client_name = None
        if f.get("parents"):
            from src.drive_enumerator import _get_service
            service = _get_service(worker_email)
            try:
                folder = service.files().get(
                    fileId=f["parents"][0],
                    fields="name",
                    supportsAllDrives=True
                ).execute()
                client_name = folder.get("name")
            except Exception:
                pass

        doc_id = await record_file(f, worker_email, client_id=None)
        await _enqueue_file(f, worker_email, client_name)
        new_count += 1

    _save_token(worker_email, new_token)
    logger.info(f"{worker_email}: {new_count} new files queued")


async def sync_worker_backfill(worker_email: str):
    """Full scan of worker's entire Drive. Run once during initial setup."""
    logger.info(f"{worker_email}: Starting full backfill scan")
    count = 0

    for f in full_scan(worker_email):
        already = await is_already_processed(
            f["id"], f.get("version"), f.get("md5Checksum")
        )
        if already:
            continue

        doc_id = await record_file(f, worker_email, client_id=None)
        await _enqueue_file(f, worker_email, None)
        count += 1

        if count % 100 == 0:
            logger.info(f"{worker_email}: {count} files queued so far")

    # Save current page token after backfill
    token = get_start_page_token(worker_email)
    _save_token(worker_email, token)
    logger.info(f"{worker_email}: Backfill complete. {count} files queued")


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["delta", "backfill"], default="delta")
    parser.add_argument("--worker", help="Sync only this worker email")
    args = parser.parse_args()

    if args.worker:
        workers = [args.worker]
    else:
        workers = discover_workers()

    sync_fn = sync_worker_backfill if args.mode == "backfill" else sync_worker_delta

    # Run workers sequentially to respect quota (12k QPM per user, shared bucket)
    # For speed, could parallelize with asyncio.gather + semaphore
    for worker in workers:
        try:
            await sync_fn(worker)
        except Exception as e:
            logger.error(f"Failed to sync {worker}: {e}")


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s"
    )
    asyncio.run(main())
```

---

## Task 4.9 — Crontab Entry

Add to crontab (`crontab -e`):

```cron
# Trikato Drive delta sync every 15 minutes (weekdays + light weekend)
*/15 * * * 1-5 cd /home/martin/Trikato/User-tools/accounting-pipeline && python sync_all_workers.py --mode delta >> /home/martin/Trikato/logs/sync.log 2>&1
*/30 * * * 6-7 cd /home/martin/Trikato/User-tools/accounting-pipeline && python sync_all_workers.py --mode delta >> /home/martin/Trikato/logs/sync.log 2>&1
```

Create log dir:
```bash
mkdir -p /home/martin/Trikato/logs
```

---

## Task 4.10 — Run Backfill

```bash
cd /home/martin/Trikato/User-tools/accounting-pipeline/

# First test with Merilin only
python sync_all_workers.py --mode backfill --worker merilin@trikato.ee

# Then all workers
python sync_all_workers.py --mode backfill
```

Watch progress in logs. Expected: ~35,000 files total across all workers (estimate).
Jobs will be queued in PostgreSQL — queue_worker.py processes them at N=3 concurrent.

---

## Verification Checklist

- [ ] `python3 -m py_compile src/drive_enumerator.py` — exit 0
- [ ] `python3 -m py_compile src/sync_manifest.py` — exit 0
- [ ] `python3 -m py_compile sync_all_workers.py` — exit 0
- [ ] `python sync_all_workers.py --worker merilin@trikato.ee --mode delta` — runs without error
- [ ] `SELECT COUNT(*) FROM trikato.documents` — increases after sync run
- [ ] `SELECT COUNT(*) FROM trikato.jobs WHERE status='queued'` — jobs appear
- [ ] Crontab entry active: `crontab -l` shows the entry
- [ ] `data/sync_state/merilin_trikato_ee_pagetoken.txt` exists after first run

---

## Important Notes

- **DWD service account key** (`trikato-service-account.json`) must exist before running. This is admin task P3.
- **ADMIN_EMAIL env var**: Must be set to a Google Workspace admin email (e.g., `martin@trikato.ee`) for Admin SDK user listing to work. Add to `.env`.
- **First run**: `--mode delta` with no saved token will save the current token and exit (no files processed). This is correct behavior — it establishes the baseline. Run `--mode backfill` for the initial full scan.
- **Quota**: Each worker has 12,000 QPM independently (DWD creates separate quota buckets). 19 workers = effectively 228,000 QPM total. No quota concerns at this scale.
- **GWS native files**: Google Docs/Sheets have no `md5Checksum`. Dedup uses `version` integer instead. File content changes increment `version`.
