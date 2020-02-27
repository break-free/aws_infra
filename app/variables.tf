variable "ingress_nginx_source" {
    type = string
    default = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml"
}
variable "ECR_image" {
    type = map
    default = {
        cheddar = "146452989591.dkr.ecr.us-west-2.amazonaws.com/cheddar:latest"
        stilton = "146452989591.dkr.ecr.us-west-2.amazonaws.com/stilton:latest"
        wensleydale = "146452989591.dkr.ecr.us-west-2.amazonaws.com/wensleydale:latest"
    }
}
