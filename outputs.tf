output "endpoint" {
  value = "${aws_eks_cluster.cluster.endpoint}"
}

output "kubeconfig_certificate_authority_data" {
  value = "${aws_eks_cluster.cluster.certificate_authority.0.data}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

output "config_map_aws_auth" {
  value = "${local.config_map_aws_auth}"
}

output "ssh_public_key" {
  value = "${aws_key_pair.ssh.public_key}"
}

output "ssh_private_key" {
  value = "${tls_private_key.ssh.private_key_pem}"
}

output "admin_ip" {
  value = "${local.admin_ip}"
}

output "region" {
  value = "${var.region}"
}
