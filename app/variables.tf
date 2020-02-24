variable "nginx_ingress_source" {
    type = string
    default = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml"
}
variable "AWS_NLB_rules_source" {
    type = string
    default = "https://raw.githubusercontent.com/cornellanthony/nlb-nginxIngress-eks/master/nlb-service.yaml"
}