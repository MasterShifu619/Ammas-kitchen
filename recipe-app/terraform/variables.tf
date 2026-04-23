variable "aws_account_id" {
  description = "AWS Account ID — injected at plan/apply time, never hardcoded."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "recipes-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "db_password" {
  description = "Password for the PostgreSQL database stored in Secrets Manager."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment tag (e.g. production, staging)."
  type        = string
  default     = "production"
}

variable "namespace" {
  description = "Kubernetes namespace for app workloads."
  type        = string
  default     = "recipes"
}
