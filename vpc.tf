module "eks_vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "eks-${local.cluster_name}"
  cidr                 = "${var.eks_vpc_cidr}"
  azs                  = "${data.aws_availability_zones.available.names}"
  private_subnets      = "${var.eks_private_cidrs}"
  public_subnets       = "${var.eks_public_cidrs}"
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    Environment                                   = "${var.environment}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
