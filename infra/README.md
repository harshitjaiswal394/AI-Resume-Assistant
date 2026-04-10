# Terraform Infrastructure

This directory contains reusable Terraform modules and environment stacks for deploying the application on AWS ECS Fargate.

## Layout

- `modules/` contains reusable building blocks
- `envs/dev/` contains the first modeled environment

## Deployment Model

Terraform manages:

- ECR repositories
- ECS cluster
- Cloud Map namespace for Service Connect
- IAM roles
- Secrets Manager secret for `NVIDIA_API_KEY`
- Security groups
- Application Load Balancer
- ECS task definitions
- ECS services
- CloudWatch log groups

GitHub Actions manages:

- Docker image build
- Docker image push
- Terraform apply with the pushed image tags
- Terraform destroy for the environment when requested

## Remote State

The `dev` stack is configured to use an S3 backend. The backend configuration is supplied at `terraform init` time by the GitHub Actions workflow.

Required GitHub secrets for the Terraform deployment workflow:

- `AWS_ACCOUNT_ID`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `NVIDIA_API_KEY`
- `TF_STATE_BUCKET`

## State Storage

This setup uses an S3 backend for Terraform state.

- Create the S3 bucket before running Terraform
- Enable S3 versioning on the bucket
- No manual folder creation is needed
- The workflow uses the object key `jobgpt/dev/terraform.tfstate`

This repository is currently configured for S3-only state storage without DynamoDB locking, which is acceptable for low-concurrency or single-operator usage.

## GitHub Actions Workflows

### Deploy

Workflow file:

- `.github/workflows/deploy-terraform-dev.yaml`

How it runs:

- automatically on push to `dev`
- manually through `workflow_dispatch`

What it does:

1. Initializes Terraform with the S3 backend
2. Bootstraps shared infrastructure such as ECR, ECS cluster, namespace, security groups, and ALB
3. Builds and pushes backend and frontend Docker images
4. Runs full Terraform apply with the pushed image tags
5. Waits for ECS services to stabilize

### Destroy

Workflow file:

- `.github/workflows/destroy-terraform-dev.yaml`

How it runs:

- manually through `workflow_dispatch`

What it does:

1. Initializes Terraform with the same S3 backend
2. Runs `terraform destroy -auto-approve` for the `dev` stack

## Workflow-Only Usage

You do not need to run Terraform locally once the S3 backend and GitHub secrets are configured.

Normal operating model:

1. Push code to the `dev` branch to deploy
2. Use the `Destroy Dev via Terraform` workflow when you want to tear the environment down

Recommended one-time setup:

1. Create the Terraform state S3 bucket
2. Enable versioning and encryption on the bucket
3. Add the required GitHub secrets
4. Push to `dev` to let the deploy workflow create the environment
