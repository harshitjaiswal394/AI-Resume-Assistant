# Terraform Deployment Guide

## Overview

This project now supports Terraform-based deployment for multiple environments on AWS ECS Fargate.

Terraform manages the infrastructure and GitHub Actions manages the deployment flow.

Current Terraform coverage includes:

- ECS cluster
- ECS Service Connect namespace
- ECR repositories
- IAM roles
- Secrets Manager secret for `NVIDIA_API_KEY`
- CloudWatch log groups
- Security groups
- Application Load Balancer
- ECS task definitions
- ECS services

Current environments implemented:

- `dev`
- `test`
- `prod`

Infrastructure code location:

- `infra/`

Terraform environment stacks:

- `infra/envs/dev`
- `infra/envs/test`
- `infra/envs/prod`

GitHub Actions workflows:

- `.github/workflows/terraform-pr-plan.yaml`
- `.github/workflows/terraform-promotion.yaml`
- `.github/workflows/deploy-terraform-dev.yaml`
- `.github/workflows/destroy-terraform-dev.yaml`

---

## Architecture

The deployed `dev` stack uses the following naming:

- ECS cluster: `dev-jobgpt-cluster`
- Service Connect namespace: `dev-jobgpt`
- Backend service: `dev-backend-service`
- Frontend service: `dev-frontend-service`
- Backend ECR repo: `dev-backend-repo`
- Frontend ECR repo: `dev-frontend-repo`

Traffic flow:

```text
Browser
  ->
ALB
  ->
Frontend ECS service (Nginx on port 80)
  ->
Backend ECS service (FastAPI on port 8000)
```

Service-to-service communication:

- frontend calls backend using ECS Service Connect alias
- backend is reached from frontend as `dev-backend-service:8000`

---

## How the Terraform Deployment Works

The deployment is split into two responsibilities.

### Terraform manages infrastructure

Terraform creates and updates:

- networking references to the default VPC and subnets
- ALB and target group
- ECR repositories
- ECS cluster
- Service Connect namespace
- IAM roles
- ECS task definitions
- ECS services
- log groups
- Secrets Manager secret

### GitHub Actions manages delivery

GitHub Actions:

1. initializes Terraform state from S3
2. bootstraps shared infra if needed
3. builds backend and frontend Docker images
4. pushes images to ECR
5. runs `terraform apply`
6. waits for ECS services to stabilize

This means you do not need to create ECS services manually from the AWS console once the setup is in place.

---

## Terraform State

This setup uses an S3 backend for Terraform state.

State object keys:

- `jobgpt/dev/terraform.tfstate`
- `jobgpt/test/terraform.tfstate`
- `jobgpt/prod/terraform.tfstate`

This setup currently uses:

- S3 state storage
- S3 versioning recommended
- no DynamoDB locking

That is acceptable for one-person or low-concurrency usage.

### Create the S3 bucket

If your region is `us-east-1`:

```bash
aws s3api create-bucket \
  --bucket jobgpt-terraform-state \
  --region us-east-1
```

If your region is not `us-east-1`, use:

```bash
aws s3api create-bucket \
  --bucket jobgpt-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket jobgpt-terraform-state \
  --versioning-configuration Status=Enabled
```

Enable encryption:

```bash
aws s3api put-bucket-encryption \
  --bucket jobgpt-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

Block public access:

```bash
aws s3api put-public-access-block \
  --bucket jobgpt-terraform-state \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

Important note:

- do not create folders manually in S3
- Terraform will create the state object automatically under the configured key path

---

## Required GitHub Secrets

Add these repository secrets:

- `AWS_ACCOUNT_ID`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `NVIDIA_API_KEY`
- `TF_STATE_BUCKET`

Example:

- `TF_STATE_BUCKET=jobgpt-terraform-state`

---

## Terraform Directory Structure

```text
infra/
  modules/
    alb/
    app_secrets/
    default_network/
    ecr/
    ecs_cluster/
    ecs_service/
    iam/
    service_security_groups/
  envs/
    dev/
      backend.tf
      main.tf
      outputs.tf
      providers.tf
      terraform.tfvars.example
      variables.tf
      versions.tf
    test/
      backend.tf
      main.tf
      outputs.tf
      providers.tf
      terraform.tfvars.example
      variables.tf
      versions.tf
    prod/
      backend.tf
      main.tf
      outputs.tf
      providers.tf
      terraform.tfvars.example
      variables.tf
      versions.tf
```

### Reusable modules

The modules are reused by:

- `dev`
- `test`
- `prod`

---

## PR Plan Workflow

Workflow file:

- `.github/workflows/terraform-pr-plan.yaml`

Triggers:

- pull requests targeting `main`
- manual `workflow_dispatch`

### Pull request behavior

When a PR is raised to `main`, the workflow does the following:

1. checks out the repository
2. configures AWS credentials
3. initializes Terraform using the S3 backend
4. validates Terraform
5. runs `terraform plan`

The PR plan workflow runs for:

- `dev`
- `test`
- `prod`

### Manual dispatch behavior

The same workflow also supports manual dispatch with:

- `environment`
- `apply`

Allowed environment values:

- `dev`
- `test`
- `prod`

Manual apply is restricted so that:

- only `dev` can be applied directly from this workflow
- `apply=true` must be selected

---

## Promotion Workflow

Workflow file:

- `.github/workflows/terraform-promotion.yaml`

Trigger:

- PR merged into `main`

### Promotion flow

When a PR is merged into `main`, the workflow promotes changes sequentially through:

1. `dev`
2. `test`
3. `prod`

For each environment, it performs:

1. `terraform init`
2. `terraform plan`
3. waits at the apply stage for GitHub Environment approval
4. bootstraps shared infrastructure if needed
5. builds backend and frontend images
6. pushes images to the environment-specific ECR repositories
7. runs `terraform apply`

### Approval model

The apply jobs are attached to GitHub Environments:

- `dev`
- `test`
- `prod`

If required reviewers are configured for those environments, the workflow pauses before apply and waits for approval.

---

## Legacy Dev Deploy Workflow

Workflow file:

- `.github/workflows/deploy-terraform-dev.yaml`

Current trigger:

- push to `dev-infra`
- manual `workflow_dispatch`

This workflow can still be used for direct `dev` deployment, but the main PR-based review and promotion model is now:

- PR to `main` for plan
- merge to `main` for promotion

---

## Destroy Workflow

Workflow file:

- `.github/workflows/destroy-terraform-dev.yaml`

Trigger:

- manual `workflow_dispatch`

What it does:

1. checks out the repository
2. configures AWS credentials
3. initializes Terraform against the same S3 state
4. validates the selected environment
5. runs `terraform destroy -auto-approve`

Supported environment choices:

- `dev`
- `test`
- `prod`

Use this workflow when you want to tear down one selected environment completely.

---

## Manual Terraform Commands

Even though the normal path is workflow-driven, you can still run Terraform locally if needed.

From:

- `infra/envs/dev`
- `infra/envs/test`
- `infra/envs/prod`

Initialize:

```bash
terraform init -reconfigure \
  -backend-config="bucket=jobgpt-terraform-state" \
  -backend-config="key=jobgpt/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"
```

Plan:

```bash
terraform plan -var="nvidia_api_key=YOUR_KEY"
```

Apply:

```bash
terraform apply -var="nvidia_api_key=YOUR_KEY"
```

Destroy:

```bash
terraform destroy -var="nvidia_api_key=YOUR_KEY"
```

---

## Verification After Deployment

### Check ECS services

```bash
aws ecs describe-services \
  --cluster dev-jobgpt-cluster \
  --services dev-backend-service dev-frontend-service
```

### Check running tasks

```bash
aws ecs list-tasks \
  --cluster dev-jobgpt-cluster
```

### Check frontend task definition image

```bash
aws ecs describe-services \
  --cluster dev-jobgpt-cluster \
  --services dev-frontend-service \
  --query 'services[0].taskDefinition' \
  --output text
```

Then:

```bash
aws ecs describe-task-definition \
  --task-definition <FRONTEND_TASK_DEFINITION_ARN> \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text
```

### Check logs

```bash
aws logs tail /ecs/dev-jobgpt-cluster/dev-frontend-service --follow
aws logs tail /ecs/dev-jobgpt-cluster/dev-backend-service --follow
```

### Check application URL

Use the Terraform output:

- `frontend_url`

or open the ALB DNS name in the browser.

---

## Common Troubleshooting

### 1. Terraform state bucket missing

Symptom:

- `terraform init` fails

Fix:

- create the S3 bucket
- enable versioning
- ensure `TF_STATE_BUCKET` secret is correct

### 2. ECS service already exists but Terraform wants to create it

Symptom:

- `Create service is not idempotent`

Cause:

- the service exists in AWS but is not yet in Terraform state

Fix:

```bash
terraform import module.frontend_service.aws_ecs_service.this dev-jobgpt-cluster/dev-frontend-service
terraform import module.backend_service.aws_ecs_service.this dev-jobgpt-cluster/dev-backend-service
```

### 3. Frontend starts but API calls fail

Check:

- frontend logs
- backend logs
- Service Connect config
- Nginx upstream config

### 4. ALB returns 502

Check:

- frontend task health
- target group health
- frontend service logs
- whether frontend container is crashing during startup

### 5. Workflow pushes image but ECS still runs old behavior

Check:

- current ECS task definition image
- running task revision
- workflow completion status
- whether frontend service actually rolled after image push

---

## Merge to Main Branch

Yes, you can merge this into `main`.

There is no inherent issue in merging the Terraform files and workflows into `main`, but keep these points in mind:

### Safe if

- the GitHub secrets are already configured
- the S3 Terraform state bucket exists
- you understand which workflow branch trigger is active
- you are not using the old non-Terraform deploy path for the same environment at the same time

### Important current detail

After merge to `main`:

- the promotion workflow triggers from the merged PR event
- it progresses through `dev`, `test`, and `prod`
- apply is gated by GitHub Environment approval if reviewers are configured

### Recommendation

Merge to `main` if you want the PR-driven Terraform plan and promotion model to be the primary deployment path.

Then configure GitHub Environment approvals for:

1. `dev`
2. `test`
3. `prod`

The important part is to avoid two different deployment systems managing the same `dev` ECS services simultaneously.

---

## Recommended Next Steps

1. Ensure S3 state bucket exists and versioning is enabled
2. Confirm all required GitHub secrets are present
3. Configure GitHub Environment approvals for `dev`, `test`, and `prod`
4. Merge the Terraform files and workflows into `main`
5. Stop using the old non-Terraform deployment path for the same ECS environments

---

## Summary

This Terraform setup gives you:

- reusable infrastructure modules
- a `dev` environment stack
- workflow-driven deploys
- workflow-driven destroy
- ECS Fargate deployment through Terraform
- a cleaner path to `test` and `prod`

It is ready to be merged, reviewed, and extended for the remaining environments.
