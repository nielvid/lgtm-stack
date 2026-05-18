variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lgtm-stack"
}

variable "instance_type" {
  description = "AWS EC2 instance type"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4GB RAM. Consider t3.large for full stack if needed.
}

variable "key_name" {
  description = "AWS SSH Key Pair Name"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the observability ports. Restrict in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open for demo — restrict to your IP in production
}
