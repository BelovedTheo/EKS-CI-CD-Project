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


#Create  Private Subnet in Availability Zones: A

resource "aws_subnet" "Private_Subnet_A" {
  vpc_id            = aws_vpc.VPC_Pipeline.id
  cidr_block        = "10.0.2.0/24"
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
      {port = 80, description = "HTTP for ALB"},
      {port = 443, description = "HTTPS"},
      {port = 10250, description = "Kubelet API"},
      {port = "30000-32767", description = "NodePort Services"},
      {port = 9090, description = "Prometheus"},
      {port = 3000, description = "Grafana"}
    ]
    content {
      from_port   = split("-", ingress.value.port)[0]
      to_port     = split("-", ingress.value.port)[1] == null ? split("-", ingress.value.port)[0] : split("-", ingress.value.port)[1]
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "ingress.value.description"
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
  name        = "SG MongoDB"
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
  name     = "EKS cluster name"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.Public_Subnet_A.id, aws_subnet.Private_Subnet_A.id]
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

resource "aws_iam_role" "eks_nodes" {
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
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_eks_node_group" "public" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-public-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [aws_subnet.public.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [aws_iam_role_policy_attachment.eks_worker_node_policy]
}

resource "aws_eks_node_group" "private" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-private-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [aws_subnet.private.id]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [aws_iam_role_policy_attachment.eks_worker_node_policy]
}

# ALB Configuration
resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.VPC_Pipeline.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.VPC_Pipeline.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}