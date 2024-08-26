variable "Region" {
  type        = string
  description = "AWS Region to work"
  default     = "us-west-2"
}

variable "Instance_type" {
  type        = string
  description = "EC2 Instance type"
  default     = "t3.medium"
}

variable "CIDR_VPC" {
  type        = string
  description = "My CIDR Block of AWS VPC"
  default     = "10.0.0.0/16"
}
