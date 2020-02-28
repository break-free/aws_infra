ingress_nginx_source = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml"

ECR_image = {
    cheddar = "146452989591.dkr.ecr.us-west-2.amazonaws.com/cheddar:latest",
    stilton = "146452989591.dkr.ecr.us-west-2.amazonaws.com/stilton:latest",
    wensleydale = "146452989591.dkr.ecr.us-west-2.amazonaws.com/wensleydale:latest"
}

cluster-name = "default_project_name"
region = "us-west-2"