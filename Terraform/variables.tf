#---------------------------
#EKS CI/CD Pipeline Project
#Created by Vladimir Ziulin
#---------------------------

variable "project_name" {
  description = "Project name for tagging and resource naming"
  type        = string
  default     = "EKS CI/CD Pipeline"
}

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
