output "instance_id" {
  description = "ID of the private VM instance"
  value       = aws_instance.vm_instance.id
}

output "private_ip" {
  description = "Private IP of the VM instance"
  value       = aws_instance.vm_instance.private_ip
}

output "security_group_id" {
  description = "Security group ID attached to the VM instance"
  value       = aws_security_group.vm_private_sg.id
}

output "cloud_init_template_path" {
  description = "Cloud-init template path used by this module"
  value       = local.effective_cloud_init_template_path
}
