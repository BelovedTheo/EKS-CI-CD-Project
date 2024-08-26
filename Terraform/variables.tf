#---------------------------
#EKS CI/CD Pipeline Project
#Created by Vladimir Ziulin
#---------------------------
variable "Region" {
  type        = string
  description = "AWS Region to work"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "eks-cluster-${random_string.suffix.result}"
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

variable "Capacity" {
  description = "Desired number of worker nodes"
  default     = 2
}
