# EKS with Terraform
You'll deploy the AWS Elastice Kubernetes Service (EKS) control plan with one node group via Terraform. At the end of this tutorial, you should have a EKS cluster ready for Kubernetes (K8) deployment. Additionally, Terraform instance is created with [Remote State](https://www.terraform.io/docs/state/remote.html) running on AWS S3, so you may share this EKS build with others.

This package contains a `buildspec.yaml` for AWS CodeBuild that will create EKS cluster and a sample `/app`; see section *Manual EKS Cluster Creation* if you want to run the package by hand.

# Automated EKS Cluster Creation
You may create an AWS CodeBuild and let it read `buildspec.yaml`. You could assign full access to the CodeBuild service role; otherwise, you'll need permissions to manage S3, DynamoDB, EKS, EC2, amoungst others.

* Things to know about `buildspec.yaml`:
** please assign an unique variable `PROJECT_NAME` in *lowercase alphasnumeric with hyphens* 
** The K8 RBAC are automatically read from IAM `ADMIN` group; you may modify the groups in `./eks/terraform/main.tf` under `data "aws_iam_group" "admin-members"`

# Manual EKS Cluster Creation
## Workstation Pre-requisite
* Configure AWS CLI & AWS account capable of creating S3 and EKS cluster
* Kubectl
* Terraform
## Workflow
### Create Terraform Remote State Backend
1. Move into `/remote-backend`
    `cd ./remote-backend`
2. Modify `main.tf` variables
   * `provider "aws"` > `region`
   * `resource "aws_s3_bucket" "tf-state-storage"` > `bucket`
3. Initiate and apply Terraform
   1. `terraform init`
   2. `terraform apply`

### Create EKS Cluster and Node Group
1. Move into `/eks/terraform`
    `cd ../eks/terraform`
2. Modify `variables.tf`
   * `region`
   * `cluster-name`
   * \<optional> `workstation_ips` if you wish to directly access EC2 instance from your workstation 
3. Initiate and apply Terraform 
   1. `terraform init`
   2. `terraform apply` - go grab a drink, this takes a while!

### Cluster Configuration
1. Point `kubectl` to your EKS instance
`aws eks --region <region> update-kubeconfig --name <cluster_name>`
1. Join node group to cluster
   1. Redirect Terraform output into an `.yaml`
    `terraform output config_map_aws_auth > config_map_aws_auth.yaml`
   2. Apply mapping
    `kubectl apply -f config_map_aws_auth.yaml`
   3. Smoke test
      1. Log into EKS with an IAM identify you just added
        `aws eks --region <region> update-kubeconfig --name <cluster_name> --profile <AWS_profile>` 
      2. Try running `kubectl get nodes`; this will tell you the following
         1. if a list of nodes return - congrats! cluster config is good!
         2. if no error but nothing returns - your permission works, but nodes aren't/haven't joined
         3. if error about no permission - your IAM profile have no access to K8; investigate with the profile that created EKS cluster
2. \<optional> add permissions to EKS cluster
   * K8 automatically grants `system:masters` to user that creates the cluster; you may grant RBAC to other using the same `config_map` uploaded in step 2
    1. Open `aws-auth` config map
    `kubectl edit -n kube-system configmap/aws-auth`
    1. Add or Modify `mapUsers` section; your map might look like this
    ```
    apiVersion: v1
    data:
    mapRoles: |
        - rolearn: arn:aws:iam::555555555555:role/devel-worker-nodes-NodeInstanceRole-74RF4UBDUKL6
        username: system:node:{{EC2PrivateDNSName}}
        groups:
            - system:bootstrappers
            - system:nodes
    mapUsers: |
        - userarn: arn:aws:iam::555555555555:user/admin
        username: admin
        groups:
            - system:masters
        - userarn: arn:aws:iam::111122223333:user/ops-user
        username: ops-user
        groups:
            - system:masters
    ```
# Next step
You should now be able to deploy K8 apps with `kubectl`

A sample app and with public ingress is provided in `/app`

# Resource
* [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/eks-ug.pdf)
* [Terraform - AWS EKS Introduction](https://learn.hashicorp.com/terraform/aws/eks-intro)
* [Create Kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
* [Manage Users or IAM Roles for your Cluster](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
* [Terraform - Remote State](https://www.terraform.io/docs/state/remote.html)
