# Amma's Kitchen

A full-stack recipe sharing app built with React, FastAPI, PostgreSQL, and deployed on AWS EKS.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Browser                                                            │
│     │  HTTPS                                                        │
│     ▼                                                               │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  AWS Cloud (us-east-1)                                       │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │  VPC  10.0.0.0/16                                    │    │   │
│  │  │                                                      │    │   │
│  │  │  Public Subnets (2 AZs)     Private Subnets (2 AZs) │    │   │
│  │  │  ┌────────────────────┐     ┌─────────────────────┐ │    │   │
│  │  │  │  NAT Gateway       │     │  EKS Cluster        │ │    │   │
│  │  │  │  NLB ◄─────────────┼─────┤  (recipes-cluster)  │ │    │   │
│  │  │  │  (nginx Ingress)   │     │                     │ │    │   │
│  │  │  └────────────────────┘     │  ┌───────────────┐  │ │    │   │
│  │  │                             │  │  Frontend Pod │  │ │    │   │
│  │  │                             │  │  (nginx/React)│  │ │    │   │
│  │  │                             │  └───────┬───────┘  │ │    │   │
│  │  │                             │          │ /api     │ │    │   │
│  │  │                             │  ┌───────▼───────┐  │ │    │   │
│  │  │                             │  │  Backend Pod  │  │ │    │   │
│  │  │                             │  │  (FastAPI)    │  │ │    │   │
│  │  │                             │  └───────┬───────┘  │ │    │   │
│  │  │                             │          │          │ │    │   │
│  │  │                             │  ┌───────▼───────┐  │ │    │   │
│  │  │                             │  │  PostgreSQL   │  │ │    │   │
│  │  │                             │  │  StatefulSet  │  │ │    │   │
│  │  │                             │  └───────────────┘  │ │    │   │
│  │  │                             └─────────────────────┘ │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                              │   │
│  │  ┌──────────────────┐  ┌──────────────────┐                 │   │
│  │  │  ECR: frontend   │  │  ECR: backend    │  (image repos)  │   │
│  │  └──────────────────┘  └──────────────────┘                 │   │
│  │                                                              │   │
│  │  ┌──────────────────────────┐  ┌────────────────────────┐   │   │
│  │  │  S3: recipe images       │  │  Secrets Manager       │   │   │
│  │  │  (presigned URL access)  │  │  (DB credentials)      │   │   │
│  │  └──────────────────────────┘  └────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

CI/CD: GitHub Actions → ECR push → helm upgrade --install → EKS
Auth:  OIDC (no hardcoded AWS credentials anywhere)
S3:    Backend accesses via IRSA (IAM Roles for Service Accounts)
```

## Project Structure

```
recipe-app/
├── frontend/              React SPA (upload form + browse dashboard)
├── backend/               FastAPI service (recipes + S3 image upload)
├── helm/
│   ├── frontend/          Deployment (2 replicas), Service, Ingress
│   ├── backend/           Deployment, Service, Ingress, ConfigMap, Secret
│   └── postgres/          StatefulSet, PVC (10Gi), Service
├── terraform/             VPC, EKS, ECR, S3, IAM/IRSA, nginx ingress
├── .github/workflows/     CI/CD pipeline (test → build → deploy)
├── docker-compose.yml     Local development stack
└── .env.example           Environment variable reference
```

---

## Local Development (Docker Compose)

### Prerequisites
- Docker & Docker Compose
- AWS credentials (for S3 image uploads; optional for local dev)

### Steps

```bash
# 1. Clone and enter the project
cd recipe-app

# 2. Create your local .env from the example
cp .env.example .env
# Edit .env with your values (DB password, optional S3 credentials)

# 3. Start all services
docker compose up --build

# 4. Open the app
open http://localhost:3000

# Backend API docs
open http://localhost:8000/docs
```

> **Tip:** If you don't have an S3 bucket configured locally, photo uploads will be skipped silently — recipes are still saved without images.

---

## AWS Infrastructure (Terraform)

### Prerequisites
- Terraform >= 1.6
- AWS CLI configured with admin credentials
- GitHub OIDC provider registered in your AWS account:
  ```bash
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
  ```

### Steps

```bash
cd terraform

# 1. Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set aws_account_id, db_password, etc.

# 2. Initialise providers and modules
terraform init

# 3. Review the plan
terraform plan

# 4. Apply (takes ~15 minutes for EKS)
terraform apply

# 5. Configure kubectl
$(terraform output -raw kubeconfig_command)

# 6. Note the outputs for GitHub Actions secrets
terraform output frontend_ecr_url
terraform output backend_ecr_url
terraform output s3_bucket_name
terraform output backend_irsa_role_arn
terraform output github_actions_role_arn
```

---

## GitHub Actions Secrets

Add the following secrets to your GitHub repository under
**Settings → Secrets and variables → Actions**:

| Secret name             | Where to get the value                         |
|-------------------------|------------------------------------------------|
| `AWS_ACCOUNT_ID`        | Your 12-digit AWS account ID                   |
| `BACKEND_ECR_REPO`      | `ammas-kitchen/backend` (ECR repo name)        |
| `FRONTEND_ECR_REPO`     | `ammas-kitchen/frontend` (ECR repo name)       |
| `DB_PASSWORD`           | Same password used in `terraform.tfvars`       |
| `DB_SECRET_NAME`        | `ammas-kitchen/db-credentials`                 |
| `S3_BUCKET_NAME`        | `terraform output -raw s3_bucket_name`         |
| `BACKEND_IRSA_ROLE_ARN` | `terraform output -raw backend_irsa_role_arn`  |
| `FRONTEND_HOST`         | Your frontend domain (e.g. `ammas-kitchen.example.com`) |
| `REACT_APP_API_URL`     | Your backend API URL (e.g. `https://api.ammas-kitchen.example.com`) |

The pipeline uses **OIDC** — no static AWS access keys are stored.

---

## Helm: Manual Deployment

```bash
# Configure kubectl first (see Terraform section above)

# Deploy postgres (password injected, never committed)
helm upgrade --install postgres ./helm/postgres \
  --namespace recipes --create-namespace \
  --set dbPassword="<your-db-password>"

# Deploy backend (secrets from CI args)
helm upgrade --install backend ./helm/backend \
  --namespace recipes \
  --set image.repository="<ecr-backend-url>" \
  --set image.tag="<git-sha>" \
  --set secrets.dbSecretName="ammas-kitchen/db-credentials" \
  --set secrets.s3BucketName="<bucket-name>" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=<irsa-arn>"

# Deploy frontend
helm upgrade --install frontend ./helm/frontend \
  --namespace recipes \
  --set image.repository="<ecr-frontend-url>" \
  --set image.tag="<git-sha>"
```

---

## API Reference

| Method | Path              | Description                        |
|--------|-------------------|------------------------------------|
| GET    | `/health`         | Health check                       |
| GET    | `/recipes`        | List all recipes (with presigned image URLs) |
| GET    | `/recipes/{id}`   | Get a single recipe by ID          |
| POST   | `/recipes`        | Create recipe (multipart/form-data) |

**POST /recipes fields:**
- `title` (string, required)
- `ingredients` (string, required)
- `steps` (string, required)
- `photo` (file, optional — JPEG/PNG uploaded to S3)

---

## Security Notes

- **No secrets in source control.** All credentials flow through environment variables, K8s Secrets (set via `--set` at deploy time), or AWS Secrets Manager.
- **IRSA** — backend pods access S3 and Secrets Manager via an IAM role bound to the K8s ServiceAccount. No AWS keys inside pods.
- **GitHub Actions OIDC** — short-lived tokens; no `AWS_ACCESS_KEY_ID` stored in GitHub.
- **S3 bucket** is fully private; images are accessed via presigned URLs that expire after 1 hour.
- **`.gitignore`** blocks `*.tfvars`, `.env`, `values.secret.yaml`, and AWS credentials from being committed.
