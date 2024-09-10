#---------------------------
#EKS CI/CD Pipeline Project
#Created by Vladimir Ziulin
#---------------------------

#Work with AWS

provider "aws" {
  region = var.Region
  default_tags {
    tags = {
      Owner   = "Vladimir Ziulin"
      Created = "Terraform"
    }
  }
}

# Create VPC

resource "aws_vpc" "VPC_Pipeline" {
  cidr_block = var.CIDR_VPC
  tags = {
    Name = "VPC EKS CI/CD"
  }
}

# Create  Public Subnet in Availability Zones: A

resource "aws_subnet" "Public_Subnet_A" {
  vpc_id            = aws_vpc.VPC_Pipeline.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.Region}a"
  # Enable Auto-assigned IPv4
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

# Create  Public Subnet in Availability Zones: B

resource "aws_subnet" "Public_Subnet_B" {
  vpc_id            = aws_vpc.VPC_Pipeline.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.Region}b"
  # Enable Auto-assigned IPv4
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}


#Create  Private Subnet in Availability Zones: A

resource "aws_subnet" "Private_Subnet_A" {
  vpc_id            = aws_vpc.VPC_Pipeline.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.Region}a"
  # Disable Auto-assigned IPv4
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet 1"
  }
}

# Create Internet Gateway and NAT Gateway

resource "aws_internet_gateway" "IG_Pipeline" {
  vpc_id = aws_vpc.VPC_Pipeline.id
  tags = {
    Name = "IG EKS CI/CD"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.Public_Subnet_A.id
}

# Create Route Table for Subnet

resource "aws_route_table" "Public_RouteTable" {
  vpc_id = aws_vpc.VPC_Pipeline.id
  route {
    cidr_block = var.CIDR_VPC
    gateway_id = "local"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG_Pipeline.id
  }
  tags = {
    Name = "Public RouteTable"
  }
}

resource "aws_route_table" "Private_RouteTable" {
  vpc_id = aws_vpc.VPC_Pipeline.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# Attach Subnets to Route Table

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.Public_Subnet_A.id
  route_table_id = aws_route_table.Public_RouteTable.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.Private_Subnet_A.id
  route_table_id = aws_route_table.Private_RouteTable.id
}

# Security Groups

resource "aws_security_group" "sg_eks_cluster" {
  name        = "SG EKS Cluster"
  description = "Security Group for EKS Cluster, Nodes, ALB, and Monitoring"
  vpc_id      = aws_vpc.VPC_Pipeline.id

  dynamic "ingress" {
    for_each = [
      {port = "80", description = "HTTP for ALB"},
      {port = "27017", description = "MongoDB"},
      {port = "443", description = "HTTPS"},
      {port = "10250", description = "Kubelet API"},
      {port = "30000-32767", description = "NodePort Services"},
      {port = "9090", description = "Prometheus"},
      {port = "3000", description = "Grafana"}
    ]
    content {
      from_port   = tonumber(split("-", ingress.value.port)[0])
      to_port     = length(split("-", ingress.value.port)) > 1 ? tonumber(split("-", ingress.value.port)[1]) : tonumber(split("-", ingress.value.port)[0])
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = ingress.value.description
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all internal traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "SG EKS Cluster ${var.project_name}"
    Project = var.project_name
  }
}

# Security Group MongoDB

resource "aws_security_group" "sg_mongodb" {
  name        = "SGMongoDB"
  description = "Security Group for MongoDB"
  vpc_id      = aws_vpc.VPC_Pipeline.id

  ingress {
    from_port       = 27017  
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_eks_cluster.id]
    description     = "Allow MongoDB access from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "SG MongoDB ${var.project_name}"
    Project = var.project_name
  }
}

# EKS cluster with IAM roles

resource "aws_eks_cluster" "main" {
  name     = "EKScluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.Public_Subnet_A.id, aws_subnet.Public_Subnet_B.id, aws_subnet.Private_Subnet_A.id]
  }

  tags = {
    "kubernetes.io/cluster/EKScluster" = "shared"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks-nodes-role" {
  name = "eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-nodes-role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::767397938697:policy/EKS_ECRaccess"
  role       = aws_iam_role.eks-nodes-role.name
}


resource "aws_eks_node_group" "public" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "public-node-group"
  node_role_arn   = aws_iam_role.eks-nodes-role.arn
  subnet_ids      = [aws_subnet.Public_Subnet_A.id, aws_subnet.Public_Subnet_B.id]

  scaling_config {
    desired_size = 0
    max_size     = 0
    min_size     = 0
  }

  instance_types = ["t3.medium"]

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}

resource "aws_eks_node_group" "private" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "private-node-group"
  node_role_arn   = aws_iam_role.eks-nodes-role.arn
  subnet_ids      = [aws_subnet.Private_Subnet_A.id]

  scaling_config {
    desired_size = 0
    max_size     = 0
    min_size     = 0
  }

  instance_types = ["t3.medium"]

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.main.name}" = "owned"
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

