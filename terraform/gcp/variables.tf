variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name of the Compute Engine VM"
  type        = string
  default     = "lgtm-stack-vm"
}

variable "machine_type" {
  description = "GCP Compute Engine machine type"
  type        = string
  default     = "e2-standard-2"  # 2 vCPU, 8GB RAM — sufficient for the full stack
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "ssh_user" {
  description = "SSH user for the VM"
  type        = string
  default     = "ubuntu"
}

variable "ssh_pub_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/google_compute_engine.pub"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the observability ports. Restrict in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open for demo — restrict to your IP in production
}

variable "backend_bucket" {
  description = "GCS bucket for Terraform state"
  type        = string
  default     = "your-gcp-terraform-state-bucket"
}

