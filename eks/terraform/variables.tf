variable "region" {
  default = "us-west-2"
  type    = string
}

#note that "rd" here stands for "rapid deploy"
variable "cluster-name" {
  default = "somename"
  type    = string
}

variable "workstation_ips" {
  type = list(object({
    name = string
    ip   = string
  }))
  default = [
    {
      name = "Carlos"
      ip   = "71.239.129.162/32"
    },
    {
      name = "Vince"
      ip   = "71.57.76.171/32"
    },
    {
      name = "Han"
      ip   = "104.159.208.240/32"
    }
  ]
}