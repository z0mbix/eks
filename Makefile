.DEFAULT_GOAL := help

eks-cluster: check-env ## Create the infrastructure/resources
	@test -f "vars/${ENV}-backend.tfvars"
	@test -f "vars/${ENV}.tfvars"
	terraform init -backend-config="vars/${ENV}-backend.tfvars"
	terraform apply -var-file="vars/${ENV}.tfvars"
	terraform output kubeconfig > kubeconfig-${ENV}
	terraform output ssh_private_key > ssh-${ENV}.key
	chmod 600 ssh-${ENV}.key
	terraform output config_map_aws_auth > config_map_aws_auth-${ENV}.yaml
	KUBECONFIG=kubeconfig-${ENV} kubectl get cs
	KUBECONFIG=kubeconfig-${ENV} kubectl apply -f config_map_aws_auth-${ENV}.yaml
	KUBECONFIG=kubeconfig-${ENV} kubectl get nodes --watch

destroy-cluster: check-env ## Destroy all resources
	terraform destroy -var-file="vars/${ENV}.tfvars"
	rm config_map_aws_auth-${ENV}.yaml
	rm kubeconfig-${ENV}
	rm ssh-${ENV}.key
	rm .terraform/terraform.tfstate

ssh-bastion: AWS_REGION=$(shell terraform output region)
ssh-bastion: IP=$(shell aws ec2 --region ${AWS_REGION} describe-instances --output=text --query 'Reservations[*].Instances[*].[PublicIpAddress]' --filters "Name=tag:Name,Values=${ENV}-bastion")
ssh-bastion: check-env ## SSH to the bastion
	ssh -l ec2-user -i ssh-${ENV}.key ${IP}

check-env:
ifndef ENV
	$(error ENV environment variable is undefined)
endif

help: ## See all the Makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: eks-cluster destroy-cluster ssh-bastion check-env help

