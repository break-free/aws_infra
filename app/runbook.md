# Summary
    You'll stand up a test app running on your EKS cluster. This app is load balanced via a nginx ingress controller. In front of the ingress controller is the AWS NLB (Network Load Balancer) that connects the app to the Internet; however, the NLB itself does not load balance in this scenario, but act as a proxy to the ingress controller.

# Pre-req
  * A running EKS infrastructure that you can access (see `README.md`)

# Runbook
  
1. Stand up the app and service backends ([project source](https://github.com/break-free/cheese))
   * `kubectl apply -f ./Cheddar.yaml`

2. Install nginx ingress controller 
    * `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml`

3. Apply AWS NLB rule
    * `kubectl apply -f https://raw.githubusercontent.com/cornellanthony/nlb-nginxIngress-eks/master/nlb-service.yaml`

4. Modify and apply nginx ingress rules
   <!--TODO-automate the DNS name lookup-->
    * Run `./List-DNS.ps1` 
    * Update `./ingress.yaml` -> `spec` -> `rules` -> `host` with the publich DNS for the NLB
    * `kubectl apply -f ingress.yaml`

# Test
1. Run `./List-DNS.ps1` and note public DNS for AWS NLB
2. You should be able to pull up these three web pages:
    1. `<DNS_from_step1>/cheddar`
    2. `<DNS_from_step1>/stilton`
    3. `<DNS_from_step1>/wensleydale`

# Removal
Undoing the application and ingress controller is almost same as installation
1. Uninstall app
   * `kubectl delete -f ./Cheddar.yaml`
2. Uninstall nginx ingress controller & AWS NLB
   * `kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml`
   * Note - deleting the AWS NLB takes care of the NLB mapping; there's no need to delete `nlb-service.yaml`
3. Un-apply nginx ingress rules
   * `kubectl delete -f ingress.yaml`

# References
* Primary source:
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

* Secondary source:
https://kubernetes.github.io/ingress-nginx/deploy/
