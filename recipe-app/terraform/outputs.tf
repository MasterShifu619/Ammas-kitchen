output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "frontend_ecr_url" {
  description = "ECR repository URL for the frontend image."
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_url" {
  description = "ECR repository URL for the backend image."
  value       = aws_ecr_repository.backend.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for recipe images."
  value       = aws_s3_bucket.recipes.bucket
  sensitive   = true
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "backend_irsa_role_arn" {
  description = "IAM role ARN to annotate the backend Kubernetes ServiceAccount for IRSA."
  value       = module.backend_irsa.iam_role_arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC authentication."
  value       = aws_iam_role.github_actions.arn
}

output "kubeconfig_command" {
  description = "Command to update local kubeconfig for kubectl access."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
