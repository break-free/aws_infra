# Pre-req
  * A running EKS infrastructure that you can access (see `README.md`)

# Runbook
  
1. Stand up the "Cheese" app backend ([GitHub](https://github.com/break-free/cheese))
   * apply `kubectl apply -f <file>` to both `cheese-EKS.yaml` and `cheese_services.yaml`

2. Install nginx ingress via `kubectl`; you can alternatively install via `helm`
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml

3. Install AWS NLB (Network Load Balancer)
kubectl apply -f https://raw.githubusercontent.com/cornellanthony/nlb-nginxIngress-eks/master/nlb-service.yaml

4. Apply nginx ingress rules
kubectl apply -f ingress.yaml


# References
* Primary source:
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

* Secondary source:
https://kubernetes.github.io/ingress-nginx/deploy/
