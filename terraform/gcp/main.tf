terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "vemps-storage"
    prefix = "lgtm-stack/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ---------------------------------------------------------------
# Data: reference the existing default VPC network
# ---------------------------------------------------------------
data "google_compute_network" "default" {
  name = "default"
}

# ---------------------------------------------------------------
# Firewall rules — allow observability ports inbound
# ---------------------------------------------------------------
resource "google_compute_firewall" "lgtm_allow_observability" {
  name    = "lgtm-allow-observability"
  network = data.google_compute_network.default.name

  description = "Allow access to LGTM stack ports (Grafana, Prometheus, Pushgateway, Blackbox)"

  allow {
    protocol = "tcp"
    ports    = ["22", "3000", "9090", "9091", "9093", "9100", "9115", "8080"]
  }

  # Restrict source ranges in production — open for demo purposes
  source_ranges = var.allowed_cidr_blocks
  target_tags   = ["lgtm-stack"]
}

# ---------------------------------------------------------------
# Compute Engine VM — runs the full LGTM stack as native systemd services
# ---------------------------------------------------------------
resource "google_compute_instance" "lgtm_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["lgtm-stack"]

  labels = {
    environment = "production"
    managed-by  = "terraform"
    project     = "lgtm-stack"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = data.google_compute_network.default.name

    # Ephemeral external IP
    access_config {}
  }

  metadata = {
    ssh-keys               = "${var.ssh_user}:${file(var.ssh_pub_key_path)}"
    startup-script         = file("${path.module}/../startup.sh")
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "FALSE"
  }

  # Allow the VM to call GCP APIs (e.g., for future GCS Loki storage)
  service_account {
    scopes = ["cloud-platform"]
  }

  # Ensure firewall rule exists before the VM
  depends_on = [google_compute_firewall.lgtm_allow_observability]

  lifecycle {
    ignore_changes = [metadata["ssh-keys"]]
  }
}

# ---------------------------------------------------------------
# (Optional) Static external IP — uncomment for a stable IP
# ---------------------------------------------------------------
# resource "google_compute_address" "lgtm_static_ip" {
#   name   = "lgtm-static-ip"
#   region = var.region
# }
# Then reference it in network_interface.access_config:
#   nat_ip = google_compute_address.lgtm_static_ip.address
