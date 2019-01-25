# EKS Cluster

This repo creates a simple EKS cluster using the following resources:

* VPC
* Public/Private subnets
* Internet gateway
* NAT gateway
* IAM roles/policies
* Bastion host in public subnet (ASG)
* Kubernetes control plane (cluster)
* Kubernetes worker nodes in private subnets (ASG)

## Prerequisites

* Install curl (See below, re. administrator IP)
* Set your remote state bucket, region and S3 state key in `vars/[env]-backend.tfvars`
* Set your region in `vars/[env].tfvars`


## Create the Cluster

```
make ENV=test eks-cluster
```

If you need to ssh to any of the worker nodes, you need to go via the bastion:

```
make ENV=test ssh-bastion
```

## Destroy it all

This will destroy all resources and locally created files

```
make ENV=test destroy-cluster
```

## Administrator Public IP

To lock down the bastion security group and cluster API, the following command is used within terraform to obtain the public IP, and may not work for you depending on your network:

```
$ curl -s 'https://api.ipify.org?format=json'
{"ip":"85.255.234.28"}
```
