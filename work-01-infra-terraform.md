# Work 01 — Infra + Terraform

> **For the LLM doing this work:** Read START.md first.
> This work package is Terraform only. No Python. No application code.
> All resources go in `trikato-os/infra/`.
>
> **This work is NOT needed to start dev.** PostgreSQL and Baserow already run locally.
> Build this when you're ready to move to production (Cloud Run + Cloud SQL).

---

## What This Builds

```
GCP Project
├── APIs enabled (Drive, Gmail, Admin SDK, Cloud Run, Cloud SQL, etc.)
├── Service account + IAM
├── Artifact Registry (Docker images)
├── Cloud SQL: PostgreSQL 16, db-g1-small, europe-north1
├── Cloud Storage: documents bucket
├── Secret Manager: 5 secrets
├── Cloud Run: trikato-pipeline service (initially empty image)
└── Cloudflare DNS: pipeline.trikato.ee CNAME → Cloud Run URL
```

---

## Prerequisites (Admin does these manually — NOT Terraform)

1. Create GCP project in console → note `PROJECT_ID`
2. Enable billing on the project
3. Run once to authenticate Terraform:
   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```
4. Have Cloudflare API token with DNS edit permissions for trikato.ee zone

---

## Task 1.1 — Directory Structure

Create this layout under `trikato-os/infra/`:

```
infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── modules/
│   ├── cloudrun/
│   │   └── main.tf
│   ├── cloudsql/
│   │   └── main.tf
│   └── secrets/
│       └── main.tf
├── dev.tfvars
└── prod.tfvars
```

---

## Task 1.2 — providers.tf

```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

---

## Task 1.3 — variables.tf

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-north1"
}

variable "environment" {
  description = "dev or prod"
  type        = string
  default     = "prod"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for trikato.ee"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "merit_api_id" {
  description = "Merit Aktiva API ID"
  type        = string
  sensitive   = true
}

variable "merit_api_key" {
  description = "Merit Aktiva API Key"
  type        = string
  sensitive   = true
}

variable "dwd_service_account_json" {
  description = "DWD service account JSON (base64 encoded)"
  type        = string
  sensitive   = true
}
```

---

## Task 1.4 — main.tf

```hcl
# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "admin.googleapis.com",
    "drive.googleapis.com",
    "gmail.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# Service account for pipeline
resource "google_service_account" "pipeline" {
  account_id   = "trikato-pipeline"
  display_name = "Trikato Pipeline Service Account"
  depends_on   = [google_project_service.apis]
}

# IAM: pipeline SA can read secrets
resource "google_project_iam_member" "pipeline_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

# IAM: pipeline SA can write to Cloud SQL
resource "google_project_iam_member" "pipeline_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

# IAM: pipeline SA can read/write Cloud Storage
resource "google_project_iam_member" "pipeline_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "pipeline" {
  location      = var.region
  repository_id = "trikato-pipeline"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# Cloud Storage bucket for documents
resource "google_storage_bucket" "documents" {
  name          = "${var.project_id}-documents"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}
```

---

## Task 1.5 — modules/cloudsql/main.tf

```hcl
resource "google_sql_database_instance" "main" {
  name             = "trikato-postgres"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = "db-g1-small"   # ~€9/mo
    availability_type = "ZONAL"

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = null  # Use Cloud SQL Auth Proxy for connections
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = true
}

resource "google_sql_database" "trikato" {
  name     = "trikato"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "pipeline" {
  name     = "pipeline"
  instance = google_sql_database_instance.main.name
  password = var.db_password
}

output "connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  value = google_sql_database_instance.main.private_ip_address
}
```

---

## Task 1.6 — modules/secrets/main.tf

```hcl
# Secret: DWD service account JSON
resource "google_secret_manager_secret" "dwd_key" {
  secret_id = "trikato-dwd-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dwd_key" {
  secret      = google_secret_manager_secret.dwd_key.id
  secret_data = var.dwd_service_account_json
}

# Secret: Merit API credentials
resource "google_secret_manager_secret" "merit_api_id" {
  secret_id = "trikato-merit-api-id"
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "merit_api_id" {
  secret      = google_secret_manager_secret.merit_api_id.id
  secret_data = var.merit_api_id
}

resource "google_secret_manager_secret" "merit_api_key" {
  secret_id = "trikato-merit-api-key"
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "merit_api_key" {
  secret      = google_secret_manager_secret.merit_api_key.id
  secret_data = var.merit_api_key
}

# Secret: Database URL
resource "google_secret_manager_secret" "database_url" {
  secret_id = "trikato-database-url"
  replication { auto {} }
}

# (version created post-deploy once Cloud SQL IP is known)
```

---

## Task 1.7 — modules/cloudrun/main.tf

```hcl
resource "google_cloud_run_v2_service" "pipeline" {
  name     = "trikato-pipeline"
  location = var.region

  template {
    service_account = var.service_account_email

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/trikato-pipeline/pipeline:latest"

      ports {
        container_port = 8080
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = "trikato-database-url"
            version = "latest"
          }
        }
      }

      env {
        name = "MERIT_API_ID"
        value_source {
          secret_key_ref {
            secret  = "trikato-merit-api-id"
            version = "latest"
          }
        }
      }

      env {
        name = "MERIT_API_KEY"
        value_source {
          secret_key_ref {
            secret  = "trikato-merit-api-key"
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Allow unauthenticated requests (add-on calls come from Google's servers)
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.pipeline.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  value = google_cloud_run_v2_service.pipeline.uri
}
```

---

## Task 1.8 — Cloudflare DNS (in main.tf)

```hcl
# After Cloud Run deploys, get the URL from outputs and add CNAME
resource "cloudflare_record" "pipeline" {
  zone_id = var.cloudflare_zone_id
  name    = "pipeline"
  value   = replace(module.cloudrun.service_url, "https://", "")
  type    = "CNAME"
  proxied = true   # Use Cloudflare proxy for DDoS protection
}
```

---

## Task 1.9 — outputs.tf

```hcl
output "cloud_run_url" {
  value = module.cloudrun.service_url
}

output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/trikato-pipeline"
}

output "cloud_sql_connection" {
  value = module.cloudsql.connection_name
}

output "documents_bucket" {
  value = google_storage_bucket.documents.name
}
```

---

## Task 1.10 — dev.tfvars and prod.tfvars

**dev.tfvars** (NOT committed to git):
```hcl
project_id           = "trikato-dev-XXXXX"
region               = "europe-north1"
environment          = "dev"
cloudflare_api_token = "..."
cloudflare_zone_id   = "..."
db_password          = "dev-password-change-me"
merit_api_id         = ""   # set when you have them
merit_api_key        = ""
dwd_service_account_json = ""  # base64 of service account JSON
```

**prod.tfvars** (NOT committed to git):
```hcl
project_id           = "trikato-prod-XXXXX"
region               = "europe-north1"
environment          = "prod"
cloudflare_api_token = "..."
cloudflare_zone_id   = "..."
db_password          = "..."   # strong password
merit_api_id         = "..."
merit_api_key        = "..."
dwd_service_account_json = "..."
```

Add to `.gitignore`:
```
*.tfvars
*.tfstate
*.tfstate.backup
.terraform/
```

---

## How to Apply

```bash
cd trikato-os/infra/

# Initialize
terraform init

# Plan (dry run)
terraform plan -var-file=prod.tfvars

# Apply
terraform apply -var-file=prod.tfvars

# After apply, check outputs:
terraform output
```

---

## Verification Checklist

- [ ] `terraform plan` shows no errors
- [ ] `terraform apply` completes with 0 errors
- [ ] `terraform output cloud_run_url` returns a `run.app` URL
- [ ] `curl https://pipeline.trikato.ee/health` returns 200 (after first docker push)
- [ ] Cloud SQL instance visible in GCP console
- [ ] `documents` bucket visible in Cloud Storage
- [ ] 4 secrets visible in Secret Manager
- [ ] Cloudflare DNS: `pipeline.trikato.ee` resolves

---

## Important Notes

- **Do NOT run terraform apply before Work 02 (Dockerfile exists)** — Cloud Run needs a valid image
- Cloud SQL uses Cloud SQL Auth Proxy for connections — no public IP needed
- `db-g1-small` is cheapest shared-core instance (~€9/mo). Upgrade if query times suffer.
- Cloud Run `min_instance_count = 0` means it scales to zero when idle (cost saving)
- The add-on manifest URL `pipeline.trikato.ee` never changes whether pointing to Cloudflare Tunnel (dev) or Cloud Run (prod). Workers notice nothing when migrating.
