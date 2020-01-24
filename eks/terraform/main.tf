provider "aws" {
  version = "~> 2.2"
  region     = "us-west-1"
}

terraform {
  backend "s3" {
    region = "us-west-1"
    bucket = "rdtfstate"
    key = "terraform.tfstate"
    encrypt = true    #AES-256 encryption
  }
}


data "aws_availability_zones" "available" {}

#NOTE: The usage of the specific kubernetes.io/cluster/* resource tags below 
#      are required for EKS and Kubernetes to discover and manage networking resources.

# Also note we are using Terraform's new interpolation syntax: https://www.terraform.io/docs/configuration-0-11/interpolation.html

resource "aws_vpc" "eks-rd-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name"                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "eks-rd-subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = aws_vpc.eks-rd-vpc.id

  tags = {
    "Name"                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks-rd-gw" {
  vpc_id = aws_vpc.eks-rd-vpc.id

  tags = {
    Name = "${var.cluster-name}-gw"
  }
}

resource "aws_route_table" "terraform-eks-rd-routetable" {
  vpc_id = aws_vpc.eks-rd-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks-rd-gw.id
  }
}

# The following is required manage or retrieve data from other AWS Services

resource "aws_iam_role" "rd-node" {
  name = "terraform-eks-rd-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "rd-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.rd-node.name
}

resource "aws_iam_role_policy_attachment" "rd-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.rd-node.name
}

# EKS Master Cluster Security Group

resource "aws_security_group" "rd-cluster" {
  name        = "terraform-eks-rd-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.eks-rd-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-rd"
  }
}

# OPTIONAL: Allow inbound traffic from your local workstation external IP
#           to the Kubernetes. You will need to replace A.B.C.D below with
#           your real IP. Services like icanhazip.com can help you find this.
resource "aws_security_group_rule" "rd-cluster-ingress-workstation-https" {
  count             = length(var.workstation_ips)
  
  cidr_blocks       = ["${var.workstation_ips[count.index].ip}"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.rd-cluster.id
  to_port           = 443
  type              = "ingress"
}