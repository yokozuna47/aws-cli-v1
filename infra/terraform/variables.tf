variable "aws_region" {
  type        = string
  description = "Region par default"
  default     = "eu-west-3"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vm_image" {
  type        = string
  description = "AMI for VMs"
}

variable "vm_instance_type" {
  type        = string
  description = "Instance type for VMs"
  default     = "t2.micro"
}

variable "admin_ip" {
  type        = string
  description = "Ton IP publique personnelle pour SSH vers le bastion (sans /32, ex: 203.0.113.42)"
}
