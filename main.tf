terraform {
  backend "s3" {}
}

provider "aws" {
  region = "${var.region}"
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

data "external" "admin_ip" {
  program = ["bash", "-c", "curl -s 'https://api.ipify.org?format=json'"]
}

locals {
  cluster_name = "${var.environment}"
  bastion_name = "${var.environment}-bastion"
  admin_ip     = "${data.external.admin_ip.result.ip}"

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${local.cluster_name}"
KUBECONFIG

  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_worker.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "${local.cluster_name}"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}
