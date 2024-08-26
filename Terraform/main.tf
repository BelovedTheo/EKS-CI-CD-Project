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

#-----------VPC-------------

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
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.Public_Subnet_A.id
  route_table_id = aws_route_table.Public_RouteTable.id
}

resource "aws_route_table_association" "private_subnet" {
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
