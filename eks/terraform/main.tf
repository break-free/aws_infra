provider "aws" {
  version = "~> 2.2"
  region     = var.region
}

terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "rdtfstate2"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-state-lock"
    encrypt = true    #AES-256 encryption
  }
}


data "aws_availability_zones" "available" {}

#NOTE: The usage of the specific kubernetes.io/cluster/* resource tags below 
#      are required for EKS and Kubernetes to discover and manage networking resources.

# Also note we are using Terraform's new interpolation syntax: https://www.terraform.io/docs/configuration-0-11/interpolation.html

data "aws_ami" "eks-worker" {
   filter {
     name   = "name"
     values = ["amazon-eks-node-${aws_eks_cluster.rd-eks-cluster.version}-v*"]
   }

   most_recent = true
   owners      = ["602401143452"] # Amazon EKS AMI Account ID for AMI image
 }

# This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_region" "current" {
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We implement a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  rd-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.rd-eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.rd-eks-cluster.certificate_authority[0].data}' '${var.cluster-name}'
USERDATA

}

resource "aws_vpc" "eks-rd-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "eks-rd-subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = aws_vpc.eks-rd-vpc.id

  tags = {
    Name                                      = "terraform-eks-rd-node"
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

resource "aws_route_table_association" "terraform-eks-rd" {
  count = 2

  subnet_id      = aws_subnet.eks-rd-subnet[count.index].id
  route_table_id = aws_route_table.terraform-eks-rd-routetable.id
}

# IAM Master Cluster and Service Role
resource "aws_iam_role" "rd-cluster" {
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
  role       = aws_iam_role.rd-cluster.name
}

resource "aws_iam_role_policy_attachment" "rd-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.rd-cluster.name
}
# IAM node role
resource "aws_iam_role" "rd-node" {
  name = "eks-node-group-rd"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "rd-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.rd-node.name
}

resource "aws_iam_role_policy_attachment" "rd-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.rd-node.name
}

resource "aws_iam_role_policy_attachment" "rd-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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
#           to the Kubernetes cluster.
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

# EKS Node Security Group

resource "aws_security_group" "rd-node" {
  name        = "terraform-eks-rd-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.eks-rd-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"                                      = "terraform-eks-rd-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "owned"
  }
}

# allow Nodes communication with each other and the control plane

resource "aws_security_group_rule" "rd-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.rd-node.id
  source_security_group_id = aws_security_group.rd-node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "rd-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control      plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rd-node.id
  source_security_group_id = aws_security_group.rd-cluster.id
  to_port                  = 65535
  type                     = "ingress"
 }

resource "aws_security_group_rule" "rd-cluster-ingress-node-https" {
  
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rd-cluster.id
  source_security_group_id = aws_security_group.rd-node.id
  to_port                  = 443
  type                     = "ingress"
}
# The EKS Master Cluster

resource "aws_eks_cluster" "rd-eks-cluster" {
  name            = var.cluster-name
  role_arn        = aws_iam_role.rd-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.rd-cluster.id]
    subnet_ids         = aws_subnet.eks-rd-subnet.*.id
  }

  depends_on = [
    aws_iam_role_policy_attachment.rd-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.rd-cluster-AmazonEKSServicePolicy,
  ]
}

resource "aws_eks_node_group" "rd-eks-node-group"{
  cluster_name    = aws_eks_cluster.rd-eks-cluster.name
  node_group_name = "rd-node-group"
  node_role_arn   = aws_iam_role.rd-node.arn
  subnet_ids      = aws_subnet.eks-rd-subnet[*].id

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.rd-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.rd-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.rd-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_launch_configuration" "rd" {
  associate_public_ip_address = true
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = "t3.small"
  name_prefix                 = "terraform-eks-rd"
  security_groups  = [aws_security_group.rd-node.id]
  user_data_base64 = base64encode(local.rd-node-userdata)

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "rd" {
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.rd.id
  max_size             = 2
  min_size             = 1
  name                 = "terraform-eks-rd"
  vpc_zone_identifier = aws_subnet.eks-rd-subnet.*.id

  tag {
    key                 = "Name"
    value               = "terraform-eks-rd"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
# Join Node to Cluster:
# 1. Run terraform output config_map_aws_auth and save the configuration into a file, e.g. config_map_aws_auth.yaml
# 2. Run kubectl apply -f config_map_aws_auth.yaml
# 3. You can verify the worker nodes are joining the cluster via: kubectl get nodes --watch

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.rd-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

}

output "config_map_aws_auth" {
  value = local.config_map_aws_auth
}