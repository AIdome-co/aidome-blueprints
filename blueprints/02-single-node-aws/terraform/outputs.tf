output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.aidome.id
}

output "public_ip" {
  description = "Public IP address of the instance."
  value       = aws_instance.aidome.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance."
  value       = aws_instance.aidome.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance."
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.aidome.public_ip}"
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "security_group_id" {
  description = "Security group ID."
  value       = aws_security_group.aidome.id
}
