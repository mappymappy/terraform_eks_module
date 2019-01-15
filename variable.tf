# variables

variable "cluster-name" {
  type = "string"
}

variable "vpc_id" {
  type = "string"
}

variable "worker-instance-type" {
  type    = "string"
  default = "c5.large"
}

# master subnets
variable "master-subnet-ids" {
  type = "list"
}

# allow master access ips
variable "allow-access-master-ips" {
  type    = "list"
}

# eks optimized worker ami
variable "eks-optimized-ami-id" {
  default = "ami-063650732b3e8b38c" # for ap-north-east1
}

# region
variable "region" {
  default = "ap-northeast-1"
}

# worker asg vars
variable "worker-asg-desired" {
  default = 2
}

variable "worker-asg-max" {
  default = 2
}

variable "worker-asg-min" {
  default = 2
}

variable "worker-vpc-zone-identifiers" {
  type = "list"
}

variable "cluster-node-sg-ids" {
  type = "list"
}
