variable "region" {
  type = "string"
}

variable "environment" {
  type = "string"
}

variable "eks_vpc_cidr" {
  type = "string"
}

variable "eks_public_cidrs" {
  type = "list"
}

variable "eks_private_cidrs" {
  type = "list"
}

variable "eks_worker_count" {
  type    = "string"
  default = 2
}

variable "instance_types" {
  description = "Instance types/sizes"
  type        = "map"

  default = {
    bastion = "t2.micro"
    worker  = "t2.small"
  }
}
