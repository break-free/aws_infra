provider "aws" {
  version = "~> 2.0"
}

 data "aws_availability_zones" "available" {}

#NOTE: The usage of the specific kubernetes.io/cluster/* resource tags below 
#      are required for EKS and Kubernetes to discover and manage networking resources.

resource "aws_vpc" "eks-rapiddeploy-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name"                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "eks-rapiddeploy-subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = aws_vpc.eks-rapiddeploy-vpc.id

  tags = {
    "Name"                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_internet_gateway" "eks-rapiddeploy-gw" {
  vpc_id = aws_vpc.eks-rapiddeploy-vpc.id

  tags = {
    Name = "${var.cluster-name}-gw"
  }
}

resource "aws_route_table" "terraform-eks-rd-routetable" {
  vpc_id = aws_vpc.eks-rapiddeploy-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks-rapiddeploy-gw.id
  }
}