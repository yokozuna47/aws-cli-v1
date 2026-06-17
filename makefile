ANSIBLE_DIR := infra/ansible
TF_DIR := infra/terraform
INFO_COLOR := \033[36;1m
NO_COLOR := \033[0m

.PHONY: help tr_lint tr_plan tr_apply tr_output wait play build destroy
.DEFAULT_GOAL := help

help: ## shows this helps
	@grep -E "^[a-zA-Z_-]+.*: ## .*$$" $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "$(INFO_COLOR)%-20s$(NO_COLOR)%s\n", $$1, $$2}'

tr_lint: ## format and validate terraform configs
	@cd $(TF_DIR) && terraform fmt && terraform validate

tr_plan: tr_lint
	@cd $(TF_DIR) && terraform plan

tr_apply: tr_plan
	@cd $(TF_DIR) && terraform apply -auto-approve

tr_output: ## genere l inventaire ansible depuis les outputs terraform
	@echo "[web]" > $(ANSIBLE_DIR)/inventory.ini
	@echo "$$(cd $(TF_DIR) && terraform output -raw instance_public_ip) ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/aicha_key" >> $(ANSIBLE_DIR)/inventory.ini

wait: ## attend que le SSH de la VM reponde
	@echo "Attente du SSH..."
	@IP=$$(cd $(TF_DIR) && terraform output -raw instance_public_ip); \
	for i in $$(seq 1 30); do \
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/aicha_key ubuntu@$$IP true 2>/dev/null && { echo " SSH pret ($$IP)"; exit 0; }; \
	printf '.'; sleep 5; \
	done; echo; echo "SSH toujours injoignable"; exit 1

play: ## runs the playbook
	@ansible-playbook -i $(ANSIBLE_DIR)/inventory.ini $(ANSIBLE_DIR)/nginx.yml

build: tr_apply tr_output wait play ## deploie tout : apply, inventaire, attente SSH, playbook

destroy: ## detruit l infra terraform
	@cd $(TF_DIR) && terraform destroy -auto-approve
