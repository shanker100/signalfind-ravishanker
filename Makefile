# Main infra components 

.PHONY: tf-fmt tf-validate tf-plan tf-apply tf-destroy app-build app-push app-deploy fe-deploy data-gen data-index

ENV ?= dev
AWS_REGION ?= ap-southeast-2

tf-fmt:
\tcd infra && terraform fmt -recursive

tf-validate:
\tcd infra/envs/$(ENV) && terraform init -upgrade && terraform validate

tf-plan:
\tcd infra/envs/$(ENV) && terraform init -upgrade && terraform plan -var-file="$(ENV).tfvars"

tf-apply:
\tcd infra/envs/$(ENV) && terraform init -upgrade && terraform apply -auto-approve -var-file="$(ENV).tfvars"

tf-destroy:
\tcd infra/envs/$(ENV) && terraform destroy -auto-approve -var-file="$(ENV).tfvars"

app-build:
\tcd app/backend && docker build -t $(ENV)-sf-backend:latest .

app-push:
\t./app/backend/push_ecr.sh $(ENV)

app-deploy:
\t./app/backend/deploy_ecs.sh $(ENV)

fe-deploy:
\t./app/frontend/deploy.sh $(ENV)

data-gen:
\tpython3 data/mock_generator.py

data-index:
\t./data/index_opensearch.sh $(ENV)


# signalfind data componentns 
TF_DIR=infra
TF_VARS=dev.tfvars
BUCKET=signalfind-artifacts-local

.PHONY: init plan apply package upload destroy

init:
	terraform -chdir=$(TF_DIR) init -upgrade

plan:
	terraform -chdir=$(TF_DIR) plan -var-file=$(TF_VARS)

apply:
	terraform -chdir=$(TF_DIR) apply -auto-approve -var-file=$(TF_VARS)

destroy:
	terraform -chdir=$(TF_DIR) destroy -auto-approve -var-file=$(TF_VARS)

package:
	mkdir -p dist
	for f in lambda_functions/*.py; do \
		name=$$(basename $$f .py); \
		zip dist/$$name.zip $$f; \
	done

upload:
	aws s3 mb s3://$(BUCKET) --region ap-southeast-2 || true
	aws s3 cp dist/ s3://$(BUCKET)/lambdas/ --recursive
	aws s3 cp data/transform_job.py s3://$(BUCKET)/glue/
	aws s3 cp data/pipeline.asl.json s3://$(BUCKET)/state_machines/
