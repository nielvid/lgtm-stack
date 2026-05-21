output "vm_external_ip" {
  description = "External IP address of the LGTM stack VM"
  value       = google_compute_instance.lgtm_vm.network_interface[0].access_config[0].nat_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${google_compute_instance.lgtm_vm.network_interface[0].access_config[0].nat_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${google_compute_instance.lgtm_vm.network_interface[0].access_config[0].nat_ip}:9090"
}

output "pushgateway_url" {
  description = "Pushgateway URL — set this as the PUSHGATEWAY_URL secret in GitHub Actions"
  value       = "http://${google_compute_instance.lgtm_vm.network_interface[0].access_config[0].nat_ip}:9091"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.ssh_user}@${google_compute_instance.lgtm_vm.network_interface[0].access_config[0].nat_ip}"
}
