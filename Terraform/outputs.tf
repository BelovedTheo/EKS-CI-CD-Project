#---------------------------
#EKS CI/CD Pipeline Project
#Created by Vladimir Ziulin
#---------------------------

output "VPC_ID" {
  value = aws_vpc.VPC_Pipeline.id
  description = "The ID of the VPC"
}

output "VPC_CIDR" {
  value = aws_vpc.VPC_Pipeline.cidr_block
  description = "My VPC CIDR Block"
}

output "EKS_ID" {
  value       = aws_eks_cluster.main
  description = "EKS Cluster Id"
}

output "Region" {
  description = "AWS region."
  value       = var.Region
}

output "Public_A_ID" {
  value       = aws_subnet.Public_Subnet_A.id
  description = "Public Subnet A ID of VPC"
}

output "Private_A_ID" {
  value       = aws_subnet.Private_Subnet_A.id
  description = "Public Subnet B ID of VPC"
}
