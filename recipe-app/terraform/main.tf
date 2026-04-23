provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = {
    Environment = var.environment
    Project     = "ammas-kitchen"
    ManagedBy   = "terraform"
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }

  tags = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────────────────

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  enable_irsa                            = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      name           = "${var.cluster_name}-nodes"
      instance_types = [var.node_instance_type]

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        role = "worker"
      }
    }
  }

  tags = local.common_tags
}

# ── ECR ───────────────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "frontend" {
  name                 = "ammas-kitchen/frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "backend" {
  name                 = "ammas-kitchen/backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ── S3 ────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "recipes" {
  # Account ID suffix ensures global uniqueness without guessing a name
  bucket = "ammas-kitchen-recipes-${var.aws_account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "recipes" {
  bucket = aws_s3_bucket.recipes.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recipes" {
  bucket = aws_s3_bucket.recipes.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "recipes" {
  bucket                  = aws_s3_bucket.recipes.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "recipes" {
  bucket = aws_s3_bucket.recipes.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

# ── IAM / IRSA for backend pod ─────────────────────────────────────────────────

data "aws_iam_policy_document" "backend_s3" {
  statement {
    sid     = "ReadWriteRecipeBucket"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.recipes.arn}/*"]
  }
  statement {
    sid       = "ListRecipeBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.recipes.arn]
  }
}

resource "aws_iam_policy" "backend_s3" {
  name        = "ammas-kitchen-backend-s3"
  description = "Allow backend pods to read/write the recipe images bucket"
  policy      = data.aws_iam_policy_document.backend_s3.json
}

data "aws_iam_policy_document" "backend_secretsmanager" {
  statement {
    sid       = "ReadDBSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_credentials.arn]
  }
}

resource "aws_iam_policy" "backend_secretsmanager" {
  name        = "ammas-kitchen-backend-secretsmanager"
  description = "Allow backend pods to read DB credentials from Secrets Manager"
  policy      = data.aws_iam_policy_document.backend_secretsmanager.json
}

module "backend_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "ammas-kitchen-backend"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:backend"]
    }
  }

  role_policy_arns = {
    s3             = aws_iam_policy.backend_s3.arn
    secretsmanager = aws_iam_policy.backend_secretsmanager.arn
  }

  tags = local.common_tags
}

# ── AWS Secrets Manager ────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "ammas-kitchen/db-credentials"
  description = "PostgreSQL credentials for Amma's Kitchen"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "postgres"
    password = var.db_password
    host     = "release-postgres.${var.namespace}.svc.cluster.local"
    port     = "5432"
    dbname   = "recipes"
  })
}

# ── GitHub Actions OIDC trust ─────────────────────────────────────────────────

data "aws_iam_openid_connect_provider" "github" {
  # Assumes the OIDC provider for GitHub Actions is already registered.
  # Run: aws iam create-open-id-connect-provider if not present.
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:*:ref:refs/heads/main"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "ammas-kitchen-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "ECRAuth"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = ["*"]
  }
  statement {
    sid = "EKSAccess"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "ammas-kitchen-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

# nginx ingress controller is installed via helm CLI after terraform apply.
# See README: "Step 3 — install nginx ingress" section.
