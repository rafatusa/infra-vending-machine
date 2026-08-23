# Outputs for request-1
output "instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.private_ip
}
