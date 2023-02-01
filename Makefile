.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: campus
campus: ## Build Campus Configs
	ansible-playbook -i inventories/l2ls-campus/inventory.yml playbooks/campus.yml

.PHONY: evpn
evpn: ## Build Campus Configs
	ansible-playbook -i inventories/l3ls-evpn-vxlan/inventory.yml playbooks/evpn.yml
