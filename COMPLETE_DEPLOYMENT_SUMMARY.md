# Complete Deployment Summary

## Overview

This project is deployed on AWS ECS Fargate with two services:

- `dev-frontend-service`
- `dev-backend-service`

The frontend serves the React application through Nginx on port `80`, and the backend runs FastAPI on port `8000`. Service-to-service communication is handled through ECS Service Connect in the namespace `dev-jobgpt`.

The deployment is driven by the GitHub Actions workflow in `.github/workflows/deploy-destroy.yaml`, which builds images, pushes them to ECR, registers task definitions, and creates or updates ECS services.

---

## Final Working Architecture

```text
Browser
  ->
Frontend ECS Service
  Service: dev-frontend-service
  Container: frontend-container
  Port: 80
  Stack: React + Nginx

Nginx
  ->
Backend ECS Service
  Service: dev-backend-service
  Container: backend-container
  Port: 8000
  Stack: FastAPI

Service Discovery:
  Namespace: dev-jobgpt
  Backend alias: dev-backend-service:8000
  Frontend alias: dev-frontend-service:80
```

---

## Deployment Flow

### 1. Build and Push Images

The workflow builds:

- backend image from `backend/Dockerfile`
- frontend image from `frontend/Dockerfile`

Then pushes them to the backend and frontend ECR repositories.

### 2. Register Task Definitions

The workflow prepares and registers:

- `backend-task-final.json`
- `frontend-task-final.json`

These include:

- image URI
- log group configuration
- runtime environment variables
- ECS health checks

### 3. Create or Update ECS Services

The workflow then:

- checks whether backend and frontend services are already `ACTIVE`
- updates them if active
- creates them if missing or inactive

### 4. Verify Deployment

After deployment, the workflow verifies:

- ECS service status
- running task counts
- Service Connect configuration
- CloudWatch logs

---

## Important Runtime Configuration

### Backend

- Port: `8000`
- Health endpoint: `/health`
- Task definition: `backend`
- Service Connect alias: `dev-backend-service:8000`

### Frontend

- Port: `80`
- Health endpoint: `/health`
- Nginx proxies `/api/` requests to backend
- Task definition: `frontend`
- Service Connect alias: `dev-frontend-service:80`

---

## Major Issues Found and Fixed

### 1. Nginx Could Not Resolve Backend During Upload

#### Symptom

Frontend logs showed:

```text
dev-backend-service could not be resolved (3: Host not found)
POST /api/upload-resume -> 502
```

#### Root Cause

The frontend container could resolve the backend using `curl`, but Nginx was using a variable-based `proxy_pass`:

```nginx
set $backend "...";
proxy_pass $backend/;
```

That forced Nginx to do runtime DNS resolution differently from normal shell resolution.

#### Fix

Use direct `proxy_pass` generation at container startup instead of variable-based upstream resolution.

#### Result

Nginx now proxies API traffic correctly to the backend service.

---

### 2. Frontend Worked but Upload API Failed

#### Symptom

- App loaded successfully
- `/health` returned `200`
- Upload failed with `502`

#### Root Cause

Static assets were being served correctly by Nginx, but the backend reverse proxy target was failing.

#### Fix

Corrected the Nginx backend upstream handling and ensured frontend API calls route through `/api/...`.

#### Result

Frontend and backend communication now works as expected.

---

### 3. ECS Service Update Failed with `ServiceNotActiveException`

#### Symptom

GitHub Actions failed while updating backend service with:

```text
ServiceNotActiveException: Service was not ACTIVE
```

#### Root Cause

The workflow checked whether the service name existed, not whether the ECS service was in `ACTIVE` state.

Example of incorrect logic:

```sh
--query 'services[0].serviceName'
```

This can return a name even for a non-updatable service.

#### Fix

Changed service checks to use:

```sh
--query 'services[0].status'
```

and only call `update-service` when status is exactly `ACTIVE`.

#### Result

The workflow now handles stale or inactive ECS services more safely.

---

### 4. Workflow Failed with `--tags: command not found`

#### Symptom

Backend service creation succeeded, but the workflow still failed with:

```text
--tags: command not found
```

#### Root Cause

A duplicate `--tags` line existed in the multiline `aws ecs create-service` command, and one line was no longer escaped properly.

#### Fix

Kept only one valid `--tags` line in the `create-service` command.

#### Result

The backend service step completed cleanly.

---

### 5. Frontend Workflow Failed with `syntax error: unexpected end of file`

#### Symptom

The `Create/Update Frontend Service` step failed in GitHub Actions.

#### Root Cause

The shell `if / else` block in the frontend service creation step was missing a closing `fi`.

#### Fix

Added the missing `fi` and aligned the service-state check with the backend logic.

#### Result

The frontend workflow step now parses and runs correctly.

---

### 6. Service Connect Was Working, but Nginx Was the Real Problem

#### Proof Collected

From inside the frontend container:

```sh
curl http://dev-backend-service:8000/docs
```

returned the FastAPI Swagger UI successfully.

#### Conclusion

This proved:

- ECS Service Connect was healthy
- backend was reachable from frontend
- the issue was specifically inside Nginx config behavior, not AWS networking

---

## Deployment Verification Checklist

Use these checks after every deployment.

### ECS Services

```bash
aws ecs describe-services \
  --cluster dev-jobgpt-cluster \
  --services dev-backend-service dev-frontend-service
```

### Running Tasks

```bash
aws ecs list-tasks --cluster dev-jobgpt-cluster
```

### Frontend Logs

```bash
aws logs tail /ecs/dev-jobgpt-cluster/dev-frontend-service --follow
```

### Backend Logs

```bash
aws logs tail /ecs/dev-jobgpt-cluster/dev-backend-service --follow
```

### Health Check

```bash
curl http://<frontend-public-url>/health
curl http://dev-backend-service:8000/health
```

### Nginx Live Config Check

From inside the frontend container:

```sh
nginx -T | grep -n "proxy_pass\|location /api/"
```

Expected result after deployment should show a direct backend `proxy_pass`, not `proxy_pass $backend/;`.

---

## Common Issues That May Still Happen

### 1. Old Frontend Container Still Running Old Nginx Config

#### Symptom

You fix repo code, but logs still show the old Nginx behavior.

#### Cause

The ECS task is still using an older image.

#### Fix

Force a new frontend deployment and verify live config using:

```sh
nginx -T
```

---

### 2. Service Exists but Is Not Usable

#### Symptom

Workflow finds the service but update fails.

#### Cause

The service may be:

- `DRAINING`
- `INACTIVE`
- `DEPROVISIONING`

#### Fix

Always branch on ECS `status`, not just the existence of a service record.

---

### 3. Health Checks Pass but App Feature Still Fails

#### Symptom

`/health` works but resume upload or chat fails.

#### Cause

Health checks only prove the container is alive. They do not guarantee backend proxying is correct.

#### Fix

Always test:

- `/api/upload-resume`
- `/api/ask`

after deployment.

---

### 4. Workflow Shell Syntax Breaks Easily

#### Cause

Long multiline AWS CLI commands in GitHub Actions are sensitive to:

- missing `\`
- duplicate flags
- broken JSON quoting
- missing `fi`

#### Recommendation

When editing workflow shell blocks:

- check every multiline command carefully
- keep one flag per line
- avoid duplicate flags
- validate `if / else / fi` structure before rerunning

---

## Best Practices Applied

- Use ECS Service Connect for service discovery
- Use health endpoints for both services
- Route frontend API traffic through Nginx
- Keep frontend talking to backend through relative `/api/...` paths
- Verify live runtime config, not just repo files
- Use ECS service `status` for update/create decisions
- Keep workflow shell commands minimal and explicit

---

## Key Files Involved

- `frontend/nginx.conf`
- `frontend/entrypoint.sh`
- `frontend/frontend-task.json`
- `backend/backend-task.json`
- `.github/workflows/deploy-destroy.yaml`
- `ECS_COMMUNICATION_FIX.md`
- `DEPLOYMENT_SUMMARY.md`
- `AUTOMATED_DEPLOYMENT_GUIDE.md`

---

## Final Status

Current deployment status:

- backend service creation works
- frontend service creation and update workflow is fixed
- ECS Service Connect is working
- backend is reachable from frontend container
- Nginx upstream issue was identified and corrected in source
- application is now working end to end

---

## Recommended Next Improvements

- add ALB in front of frontend service
- add HTTPS termination
- add deployment smoke test for `/api/upload-resume`
- add a workflow step to print `nginx -T` for debugging when frontend fails
- add rollback guidance for failed ECS deployments
- add separate docs for `dev`, `test`, and `prod` environment differences
