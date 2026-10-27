# Variable definition for EC2 instance type
variable "instance_type" {
  type        = string
  description = "Instance type for the EC2 instance"
  default     = "t2.micro"  # Default to t2.micro if no value is provided
}

variable "key_name" {
  description = "EC2 SSH key name"
  type        = string
  sensitive   = true
}

variable "region" {
  type = string
}

variable "bucket_id" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "availability_zone_a" {
  type = string
}

variable "availability_zone_b" {
  type = string
}