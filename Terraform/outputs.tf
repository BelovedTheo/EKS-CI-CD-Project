#---------------------------
#EKS CI/CD Pipeline Project
#Created by Vladimir Ziulin
#---------------------------

output "VPC_ID" {
  value       = aws_vpc.VPC.id
  description = "My VPC ID"
}

output "VPC_CIDR" {
  value       = aws_vpc.VPC.cidr_block
  description = "My VPC CIDR Block"
}

output "EKS_ID" {
  value       = aws_eks_cluster.EKS.id
  description = "EKS Cluster Id"
}
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.kubeconfig
}

#output "config_map_aws_auth" {
#  description = "A kubernetes configuration to authenticate to this EKS cluster."
#  value       = module.eks.config_map_aws_auth
#}

output "Region" {
  description = "AWS region."
  value       = var.Region
}

output "Public_A_ID" {
  value       = aws_subnet.Public_A.id
  description = "Public Subnet A ID of VPC"
}

output "Public_B_ID" {
  value       = aws_subnet.Public_B.id
  description = "Public Subnet B ID of VPC"
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}