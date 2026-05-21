output "vm_external_ip" {
  description = "External IP address of the LGTM stack VM"
  value       = aws_instance.lgtm_stack.public_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_instance.lgtm_stack.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.lgtm_stack.public_ip}:9090"
}

output "pushgateway_url" {
  description = "Pushgateway URL — set this as the PUSHGATEWAY_URL secret in GitHub Actions"
  value       = "http://${aws_instance.lgtm_stack.public_ip}:9091"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ubuntu@${aws_instance.lgtm_stack.public_ip}"
}
