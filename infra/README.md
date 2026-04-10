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

## Remote State

The `dev` stack is configured to use an S3 backend. The backend configuration is supplied at `terraform init` time by the GitHub Actions workflow.

Required GitHub secrets for the Terraform deployment workflow:

- `AWS_ACCOUNT_ID`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `NVIDIA_API_KEY`
- `TF_STATE_BUCKET`
- `TF_STATE_LOCK_TABLE`
