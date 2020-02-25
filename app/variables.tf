variable "nginx_ingress_source" {
    type = string
    default = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml"
}
variable "ECR_cheddar" {
    type = string
    default = "146452989591.dkr.ecr.us-west-2.amazonaws.com/cheddar:latest"
}