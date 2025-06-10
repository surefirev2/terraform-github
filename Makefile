# Makefile

# Docker image
TERRAFORM_IMAGE = terraform

# Terraform directory
TERRAFORM_DIR = terraform
PLAN_DIR = $(TERRAFORM_DIR)/plan

# User and group IDs
USER_ID = $(shell id -u)
GROUP_ID = $(shell id -g)

# Function to load environment variables from .env file if it exists
ifeq (exists,$(shell [ -f .env ] && echo exists))
include .env
export $(shell sed 's/=.*//' .env)
endif

.PHONY: build-image
build-image:
	docker build -t $(TERRAFORM_IMAGE) .

.PHONY: init
init: build-image
	docker run --rm \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) init -input=false -lockfile=readonly

.PHONY: validate
validate: init
	docker run --rm \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) validate

.PHONY: plan
plan: init
	mkdir -p $(PLAN_DIR)
	docker run --rm \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) plan -out=/workspace/plan/terraform.plan
	docker run --rm --entrypoint /bin/sh \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) -c "terraform show -json /workspace/plan/terraform.plan > /workspace/plan/terraform.json"
	docker run --rm --entrypoint /bin/sh \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) -c "terraform show -no-color /workspace/plan/terraform.plan > /workspace/plan/terraform.txt"

.PHONY: apply
apply: init
	docker run --rm \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) apply -auto-approve

.PHONY: destroy
destroy: init
	docker run --rm \
        --env-file .env \
        -u $(USER_ID):$(GROUP_ID) \
        -v $(PWD)/$(TERRAFORM_DIR):/workspace \
        -w /workspace \
        $(TERRAFORM_IMAGE) destroy -auto-approve

.PHONY: run-pre-commit
run-pre-commit:
	pre-commit run --all-files
