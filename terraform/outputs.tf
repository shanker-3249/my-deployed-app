output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Elastic IP – open this in your browser"
  value       = aws_eip.app_eip.public_ip
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://${aws_eip.app_eip.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.app_eip.public_ip}"
}
