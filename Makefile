.PHONY: pack validate

pack: ## Pack src/ into orb.yml
	circleci orb pack src/ > orb.yml

validate: ## Validate orb.yml
	circleci orb validate orb.yml

check: pack validate ## Pack and validate
	@echo "orb.yml is valid."
