# Provider 
# Looks at default kubeconfig locaiton, and assumes it is pre-configured (in this case w/ AWS CLI)
provider "kubernetes" {
    version = "~> 1.11"
}

# Remote backend
terraform {
  backend "s3" {
    region = "us-west-2"
    bucket = "rdtfstate-app"
    key = "terraform.tfstate"
    dynamodb_table = "terraform-state-lock-app"
    encrypt = true    #AES-256 encryption
  }
}

# create app deployment and service
resource "kubernetes_deployment" "cheddar" {
    metadata {
        name = "cheddar"
    }

    spec {
        replicas = 2
        selector {
            match_labels = {
                app = "cheddar"
            }
        }
        template {
            metadata {
                labels = {
                    app = "cheddar"
                    version = "0.0.1"
                }
            }
            spec {
                container {
                    name = "cheddar"
                    image = var.ECR_image["cheddar"]
                
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

resource "kubernetes_deployment" "stilton" {
    metadata {
        name = "stilton"
    }

    spec {
        replicas = 2
        selector {
            match_labels = {
                app = "stilton"
            }
        }
        template {
            metadata {
                labels = {
                    app = "stilton"
                    version = "0.0.1"
                }
            }
            spec {
                container {
                    name = "stilton"
                    image = var.ECR_image["stilton"]
                
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

resource "kubernetes_deployment" "wensleydale" {
    metadata {
        name = "wensleydale"
    }

    spec {
        replicas = 2
        selector {
            match_labels = {
                app = "wensleydale"
            }
        }
        template {
            metadata {
                labels = {
                    app = "wensleydale"
                    version = "0.0.1"
                }
            }
            spec {
                container {
                    name = "wensleydale"
                    image = var.ECR_image["wensleydale"]
                
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

resource "kubernetes_service" "stilton" {
    metadata {
        name = "stilton"
    }
    spec {
        selector = {
            app = kubernetes_deployment.stilton.spec[0].template[0].metadata[0].labels.app
        }
        port {
            name = "http"
            target_port = 80
            port = 80
        }
    }
}

resource "kubernetes_service" "wensleydale" {
    metadata {
        name = "wensleydale"
    }
    spec {
        selector = {
            app = kubernetes_deployment.wensleydale.spec[0].template[0].metadata[0].labels.app
        }
        port {
            name = "http"
            target_port = 80
            port = 80
        }
    }
}
# End of app deployment and service

# Create ingress for AWS
#
# Architecture (https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/)
#    [rest of AWS]  <- | -> [EKS cluster]
#                      |
#                      |         --> service/app
#                      |        |
#  internet -> AWS NLB -> Ingress -> service/app
#                      |        |
#                      |         --> service/app
#                      |
#
# Constraints:
# 1. We don't want to maintain ingress components from external sources
# 2. We need the DNS generated by AWS NLB, which typically we'd attach a static DNS
#
# Solution
#   |
#   |
#   \/
# 
# Step - wrap external sources (local provisioner) in namespace resource; it is necessary to create the namespace first 
# because provisioner runs after resource creation and other resource (ingress) requires namespace.
resource "kubernetes_namespace" "ingress-nginx" {
    metadata{
        # name matches resource name for self delete (local-exec destroy), and only punctuations are "-" and "."
        name = "ingress-nginx"
        labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
            "app.kubernetes.io/part-of" = "ingress-nginx"
        }
    }
    # base ingress component from external source
    provisioner "local-exec" {
    command = <<EOF
        kubectl apply -f ${var.ingress_nginx_source}
    EOF
    }
    provisioner "local-exec" {
    when = destroy
    # destroy behavior is opposite creation - provisioner runs before resource.
    # external resource includes namespace, here we manually delete terraform state after kubectl deletes namespace
    # to avoid "can't find resource" error
    command = <<EOF
        kubectl delete -f ${var.ingress_nginx_source}
        terraform state rm ${self.metadata[0].name}
    EOF
    }
}

# points AWS NLB to ingress controller
# this resource generates the NLB DNS entry that we need for k8_ingress
# typically, you would plug in a static DNS entry
resource "kubernetes_service" "NLB" {
    metadata {
        name = "ingress-nginx"
        namespace = "ingress-nginx"
        labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
            "app.kubernetes.io/part-of" = "ingress-nginx"
        }
        annotations = {
            # by default the type is elb (classic load balancer).
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

# ingress policies
resource "kubernetes_ingress" "ingress_nginx" {
    metadata {
        name = "cheese"
        annotations = {
            # nginx 0.22+ requires regex for rewrite-target 
            # https://github.com/kubernetes/ingress-nginx/releases/tag/nginx-0.22.0
            "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
            # defaults to one of the apps
            "nginx.ingress.kubernetes.io/app-root" = "/cheddar/"
        }
    }
    spec {
        rule {
            # hostname/DNS entry
            host = kubernetes_service.NLB.load_balancer_ingress[0].hostname
            http {

                path {
                    # defaults to one of the apps
                    path = "/"
                    backend {
                        service_name = kubernetes_service.cheddar.metadata[0].name
                        service_port = kubernetes_service.cheddar.spec[0].port[0].port
                    }
                }

                path {
                    # updated for nginx 0.22+
                    # redirect chart
                    # /cheddar --> /
                    # /cheddar/ --> /
                    # /cheddar/example --> /example
                    path = "/cheddar(/|$)(.*)"
                    backend {
                        # match service name and port (not target_port)
                        service_name = kubernetes_service.cheddar.metadata[0].name
                        service_port = kubernetes_service.cheddar.spec[0].port[0].port
                    }
                }

                path {
                    # updated for nginx 0.22+
                    path = "/stilton(/|$)(.*)"
                    backend {
                        # match service name and port (not target_port)
                        service_name = kubernetes_service.stilton.metadata[0].name
                        service_port = kubernetes_service.stilton.spec[0].port[0].port
                    }
                }
                
                path {
                    # updated for nginx 0.22+
                    path = "/wensleydale(/|$)(.*)"
                    backend {
                        # match service name and port (not target_port)
                        service_name = kubernetes_service.wensleydale.metadata[0].name
                        service_port = kubernetes_service.wensleydale.spec[0].port[0].port
                    }
                }
            }
        }
    }
}
# end of ingress creation

# Outputs
# public DNS for the site
output "hostname" {
  value = formatlist("%s ", kubernetes_service.NLB.load_balancer_ingress[0].hostname)
}