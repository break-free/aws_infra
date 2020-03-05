# Summary
    You'll stand up a test app running on your EKS cluster. This app is load balanced via a nginx ingress controller. In front of the ingress controller is the AWS NLB (Network Load Balancer) that connects the app to the Internet; however, the NLB itself does not load balance in this scenario, but act as a proxy to the ingress controller.

**Note** - this app is created with default `buildspec.yaml` for AWS CodeBuild

# Pre-req
  * A running EKS infrastructure that you can access (see `README.md`)

# App Creation
  
1. update remote backend variables in `main.tf`
2. `terraform apply`

# Test
1. `terraform output` will give you the app DNS for the apps
2. You should be able to pull up these three web pages:
    1. `<DNS_from_step1>/cheddar`
    2. `<DNS_from_step1>/stilton`
    3. `<DNS_from_step1>/wensleydale`

# Removal
1. `terraform destroy`

# References
* Primary source:
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

* Secondary source:
https://kubernetes.github.io/ingress-nginx/deploy/
