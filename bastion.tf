resource "aws_iam_role" "bastion" {
  name = "${local.bastion_name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "bastion_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.bastion.name}"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.bastion_name}"
  role = "${aws_iam_role.bastion.name}"
}

resource "aws_security_group" "bastion" {
  name        = "${local.bastion_name}"
  description = "Security group for bastion nodes"
  vpc_id      = "${module.eks_vpc.vpc_id}"

  tags {
    Name        = "${local.bastion_name}"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group_rule" "bastion_ingress" {
  description       = "Allow SSH in from admin ip address"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${local.admin_ip}/32"]
  security_group_id = "${aws_security_group.bastion.id}"
}

resource "aws_security_group_rule" "bastion_egress" {
  description       = "Allow bastion to connect out to everything"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.bastion.id}"
}

data "aws_ami" "bastion" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  bastion_userdata = <<USERDATA
#!/bin/bash
set -o xtrace
echo "${local.bastion_name} user data complete"
USERDATA
}

resource "aws_launch_configuration" "bastion" {
  associate_public_ip_address = true
  image_id                    = "${data.aws_ami.bastion.id}"
  instance_type               = "${lookup(var.instance_types, "bastion")}"
  name_prefix                 = "${local.bastion_name}"
  security_groups             = ["${aws_security_group.bastion.id}"]
  user_data_base64            = "${base64encode(local.bastion_userdata)}"
  key_name                    = "${aws_key_pair.ssh.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  launch_configuration = "${aws_launch_configuration.bastion.id}"
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  name                 = "eks-${local.bastion_name}-worker"
  vpc_zone_identifier  = ["${module.eks_vpc.public_subnets}"]

  tag {
    key                 = "Name"
    value               = "${local.bastion_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }
}
