# Summary
    You'll stand up a test app running on your EKS cluster. This app features three nginx site pages that are load balanced via a nginx ingress controller. In front of the ingress controller is the AWS NLB (Network Load Balancer) that connects the app to the Internet; however, the NLB itself does not load balance in this scenario. 

# Pre-req
  * A running EKS infrastructure that you can access (see `README.md`)

# Runbook
  
1. Stand up the "Cheese" app and service backends ([GitHub](https://github.com/break-free/cheese))
   * `kubectl apply -f https://raw.githubusercontent.com/break-free/cheese/master/cheese-EKS.yaml` 
   * `kubectl apply -f https://raw.githubusercontent.com/break-free/cheese/master/cheese_services.yaml`

2. Install nginx ingress via `kubectl`; you can alternatively install via `helm`
    * `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml`

3. Install AWS NLB (Network Load Balancer)
    * `kubectl apply -f https://raw.githubusercontent.com/cornellanthony/nlb-nginxIngress-eks/master/nlb-service.yaml`

4. Apply nginx ingress rules
    * `kubectl apply -f ingress.yaml`

# Test
1. Determine the VPC ID of the EKS cluster; replace `name` as needed
   * `aws eks describe-cluster --name eks-rd --query 'cluster.resourcesVpcConfig.vpcId'`
2. Determine public DNS for ELB for EKS cluster
   * `aws elbv2 describe-load-balancers --query LoadBalancers[*].[DNSName,VpcId] --output text | grep vpc-0ad407958caf2f18b | awk '{print $1}'`
3. You should be able to pull up these three web pages:
    1. `<DNS_from_step2>\cheddar`
    2. `<DNS_from_step2>\stilton`
    3. `<DNS_from_step2>\wensleydale`


# References
* Primary source:
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

* Secondary source:
https://kubernetes.github.io/ingress-nginx/deploy/
