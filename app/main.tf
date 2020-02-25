//Provider looks at default kubeconfig locaiton, and assumes it is pre-configured (in this case w/ AWS CLI)
provider "kubernetes" {
    version = "~> 1.11"
}

//remote backend
terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "rdtfstate-app"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-state-lock-app"
    encrypt = true    #AES-256 encryption
  }
}

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
                    image = var.ECR_cheddar
                
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

// create namespace so ingress resource has something to call; otherwise, provisioner creates after resources apply
resource "kubernetes_namespace" "nginx_ingress" {
    metadata{
        name = "ingress-nginx"
        labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
            "app.kubernetes.io/part-of" = "ingress-nginx"
        }
    }
    // base ingress component from external repo
    provisioner "local-exec" {
    command = <<EOF
        kubectl apply -f ${var.nginx_ingress_source}
    EOF
    }
    provisioner "local-exec" {
    when = destroy
    // external repo includes namespace, here we manually delete terraform state after kubectl deletes namespace
    command = <<EOF
        kubectl delete -f ${var.nginx_ingress_source}
        terraform state rm ${format("%s",self)}
    EOF
    }
}

//points AWS NLB to ingress controller
resource "kubernetes_service" "nginx_ingress" {
    metadata {
        name = "ingress-nginx"
        namespace = "ingress-nginx"
        labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
            "app.kubernetes.io/part-of" = "ingress-nginx"
        }
        annotations = {
            //by default the type is elb (classic load balancer).
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
    }
    spec {
        //this setting is to make sure the source IP address is preserved.
        external_traffic_policy = "Local"
        type = "LoadBalancer"
        selector = {
            "app.kubernetes.io/name" = "ingress-nginx"
            "app.kubernetes.io/part-of" = "ingress-nginx"
        }
        port {
            name = "http"
            port = 80
            target_port = "http"
        }
        port {
            name = "https"
            port = 443
            target_port = "https"
        }
    }
}

// ingress policies
resource "kubernetes_ingress" "nginx_ingress" {
    metadata {
        name = "cheese"
        annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
        }
    }
    spec {
        rule {
            host = kubernetes_service.nginx_ingress.load_balancer_ingress[0].hostname
            http {
                path {
                    path = "/"
                    backend {
                        service_name = kubernetes_service.cheddar.metadata[0].name
                        service_port = kubernetes_service.cheddar.spec[0].port[0].port
                    }
                }
            }
        }
    }
}

//public DNS for the site
output "hostname" {
  value = formatlist("%s", kubernetes_service.nginx_ingress.load_balancer_ingress[0].hostname)
}