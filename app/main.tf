//Provider looks at default kubeconfig locaiton, and assumes it is pre-configured (in this case w/ AWS CLI)
provider "kubernetes" {}

//create cheddar deployment and service
resource "kubernetes_deployment" "cheddar" {
    metadata {
        name = "cheddar"
        labels = {
            app = "cheese"
            cheese = "cheddar"
        }
    }

    spec {
        replicas = 2
        selector {
            match_labels = {
                app = "cheese"
                task = "cheddar"
            }
        }
        template {
            metadata {
                labels = {
                    app = "cheese"
                    task = "cheddar"
                    version = "0.0.1"
                }
            }
            spec {
                container {
                    name = "cheese"
                    image = "146452989591.dkr.ecr.us-west-2.amazonaws.com/cheddar:latest"
                
                    resources {
                        requests {
                            cpu = "100m"
                            memory = "50Mi"
                        }
                        limits {
                            cpu = "100m"
                            memory = "50Mi"
                        }
                    }
                    port {
                        container_port = 80
                    }
                }
            }
        }
    }
}

resource "kubernetes_service" "cheddar" {
    metadata {
        name = "cheddar"
    }
    spec {
        selector = {
            app = kubernetes_deployment.cheddar.spec[0].template[0].metadata[0].labels.app
        }
        port {
            name = "http"
            target_port = 80
            port = 80
        }
    }
}

//creates nginx ingress controller and AWS NLB rules - reads from external resources
data "http" "nginx_ingress" {
    url = var.nginx_ingress_source
}

data "http" "AWS_NLB_rules" {
    url = var.AWS_NLB_rules_source
}

resource "null_resource" "nginx_ingress" {
  triggers = { //resource to run whenever the source material changes
    nginx_ingress = "${data.http.nginx_ingress.body}"
    AWS_NLB_rules = "${data.http.AWS_NLB_rules.body}"
  }

  provisioner "local-exec" {
    command = <<EOF
        kubectl apply -f ${var.nginx_ingress_source} -f ${var.AWS_NLB_rules_source}
    EOF
  }

  provisioner "local-exec" {
    when = "destroy"
    //deleting ingress controller also deletes AWS NLB rules i.e. no need to touch AWS NLB
    command = <<EOF
        kubectl delete -f ${var.nginx_ingress_source}
    EOF
  }
}

//TODO - automate ingress.yaml lookup of AWS NLB DNS
//IDEA - build AWS_NLB into terraform?
resource "kubernetes_service" "nginx-ingress" {
    
}