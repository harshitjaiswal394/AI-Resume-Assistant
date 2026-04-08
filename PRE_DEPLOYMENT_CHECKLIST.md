# ✅ Pre-Deployment Checklist

## 1. AWS Account & Credentials ✓

- [ ] AWS Account ID known (e.g., 716608655181)
- [ ] AWS IAM user created with API keys
- [ ] IAM user has permissions:
  - [ ] ECS full access
  - [ ] EC2 describe access
  - [ ] CloudWatch Logs full access
  - [ ] Service Discovery full access
  - [ ] ECR full access
  - [ ] IAM PassRole

**Setup:** Get credentials from AWS IAM Console

---

## 2. GitHub Repository Setup ✓

- [ ] Repository created on GitHub
- [ ] Code pushed to repository
- [ ] `dev` branch exists
- [ ] GitHub CLI installed (`gh --version`)
- [ ] Authenticated with GitHub (`gh auth login`)

**Verify:**
```bash
gh auth status
gh repo view
```

---

## 3. ECR Repositories ✓

Create ECR repositories before deployment:

```bash
# Replace region if needed
AWS_REGION="us-east-1"

aws ecr create-repository \
  --repository-name jobgpt-backend \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true \
  --tag-mutability IMMUTABLE

aws ecr create-repository \
  --repository-name jobgpt-frontend \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true \
  --tag-mutability IMMUTABLE
```

**Verify:**
```bash
aws ecr describe-repositories --region $AWS_REGION
```

---

## 4. GitHub Secrets Configuration ✓

Run the setup script appropriate for your OS:

### Linux/macOS:
```bash
chmod +x setup-secrets.sh
./setup-secrets.sh
```

### Windows PowerShell:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\setup-secrets.ps1
```

### Manual Setup (if scripts don't work):
```bash
gh secret set AWS_ACCOUNT_ID --body "YOUR_ACCOUNT_ID"
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_REGION --body "us-east-1"
gh secret set ECR_BACKEND_REPO --body "jobgpt-backend"
gh secret set ECR_FRONTEND_REPO --body "jobgpt-frontend"
```

**Verify:**
```bash
gh secret list
```

---

## 5. Task Definitions ✓

### backend/backend-task.json
- [ ] Contains `executionRoleArn`:
  ```json
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/AmazonECSTaskExecutionRolePolicy"
  ```
- [ ] CORS_ORIGINS configured:
  ```json
  "environment": [
    {
      "name": "CORS_ORIGINS",
      "value": "http://localhost:3000,http://127.0.0.1:3000,http://frontend-service.jobgpt"
    }
  ]
  ```
- [ ] Port 8000 exposed
- [ ] Health check configured
- [ ] CloudWatch logging configured

### frontend/frontend-task.json
- [ ] Contains `executionRoleArn`:
  ```json
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/AmazonECSTaskExecutionRolePolicy"
  ```
- [ ] Port 80 (not 3000!)
- [ ] Health check configured
- [ ] CloudWatch logging configured

**Verify:**
```bash
# Check if executionRoleArn exists
grep -q "executionRoleArn" backend/backend-task.json && echo "✅ Backend has executionRoleArn" || echo "❌ Missing executionRoleArn"
grep -q "executionRoleArn" frontend/frontend-task.json && echo "✅ Frontend has executionRoleArn" || echo "❌ Missing executionRoleArn"
```

---

## 6. Dockerfiles ✓

### backend/Dockerfile
- [ ] Uses `python:3.10-slim`
- [ ] Installs `curl` and `wget` (for health checks)
- [ ] Exposes port 8000
- [ ] Runs: `uvicorn main:app --host 0.0.0.0 --port 8000`
- [ ] Copies requirements.txt

### frontend/Dockerfile
- [ ] Multi-stage build (node:18 as build)
- [ ] Second stage uses `nginx:alpine`
- [ ] Copies nginx.conf to `/etc/nginx/conf.d/default.conf`
- [ ] Exposes port 80
- [ ] Runs: `nginx -g daemon off;`

**Test:**
```bash
# Build images locally
docker build -t backend ./backend
docker build -t frontend ./frontend

# Check if they start
docker run --rm backend echo "✅ Backend builds"
docker run --rm frontend echo "✅ Frontend builds"
```

---

## 7. Application Code ✓

### backend/main.py
- [ ] Has `from dotenv import load_dotenv`
- [ ] Has `load_dotenv()` at startup
- [ ] CORS uses environment variable:
  ```python
  CORS_ORIGINS = os.getenv("CORS_ORIGINS", "...").split(",")
  ```
- [ ] Has `/health` endpoint
- [ ] Has `/upload-resume` endpoint
- [ ] Has `/ask` endpoint

### frontend/nginx.conf
- [ ] Listens on port 80
- [ ] Has `location /api/` with `proxy_pass http://backend-service.jobgpt:8000/`
- [ ] Has `/health` endpoint
- [ ] Forwards proper headers (X-Real-IP, X-Forwarded-For, etc.)

### frontend/src components
- [ ] Chat.js uses `/api/ask`
- [ ] ResumeUpload.js uses `/api/upload-resume`
- [ ] JobApply.js uses `/api/job?url={jobUrl}`

**Verify:**
```bash
# Check URLs
grep -r "axios.post" frontend/src/components/

# Should show:
# - /api/ask
# - /api/upload-resume
# - /api/job
# NOT http://127.0.0.1:8000
```

---

## 8. GitHub Workflow ✓

- [ ] `.github/workflows/deploy.yaml` exists
- [ ] Triggers on `push` to `dev` branch
- [ ] Has these steps:
  - [ ] Checkout code
  - [ ] Configure AWS
  - [ ] Create ECS cluster
  - [ ] Create Service Connect namespace
  - [ ] Create CloudWatch log groups
  - [ ] Login to ECR
  - [ ] Build backend image
  - [ ] Push backend image
  - [ ] Build frontend image
  - [ ] Push frontend image
  - [ ] Register task definitions
  - [ ] Get VPC/subnet info
  - [ ] Create/update backend service
  - [ ] Create/update frontend service
  - [ ] Verify deployment

---

## 9. IAM Role (AmazonECSTaskExecutionRolePolicy) ✓

Ensure the role exists:

```bash
aws iam get-role --role-name AmazonECSTaskExecutionRolePolicy
```

If it doesn't exist, create it:

```bash
# Create trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name AmazonECSTaskExecutionRolePolicy \
  --assume-role-policy-document file://trust-policy.json

# Attach policy
aws iam attach-role-policy \
  --role-name AmazonECSTaskExecutionRolePolicy \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

---

## 10. Final Verification ✓

Run these commands before pushing:

```bash
# 1. Check all required files exist
echo "Checking files..."
test -f backend/backend-task.json && echo "✅ backend-task.json" || echo "❌ backend-task.json"
test -f frontend/frontend-task.json && echo "✅ frontend-task.json" || echo "❌ frontend-task.json"
test -f .github/workflows/deploy.yaml && echo "✅ deploy.yaml" || echo "❌ deploy.yaml"
test -f backend/Dockerfile && echo "✅ backend/Dockerfile" || echo "❌ backend/Dockerfile"
test -f frontend/Dockerfile && echo "✅ frontend/Dockerfile" || echo "❌ frontend/Dockerfile"
test -f frontend/nginx.conf && echo "✅ frontend/nginx.conf" || echo "❌ frontend/nginx.conf"
test -f backend/main.py && echo "✅ backend/main.py" || echo "❌ backend/main.py"

# 2. Check executionRoleArn in task definitions
echo ""
echo "Checking task definitions..."
grep -q "executionRoleArn" backend/backend-task.json && echo "✅ Backend has executionRoleArn" || echo "❌ Backend missing executionRoleArn"
grep -q "executionRoleArn" frontend/frontend-task.json && echo "✅ Frontend has executionRoleArn" || echo "❌ Frontend missing executionRoleArn"

# 3. Check secrets
echo ""
echo "Checking GitHub secrets..."
gh secret list | grep -q "AWS_ACCOUNT_ID" && echo "✅ AWS_ACCOUNT_ID" || echo "❌ AWS_ACCOUNT_ID"
gh secret list | grep -q "AWS_ACCESS_KEY_ID" && echo "✅ AWS_ACCESS_KEY_ID" || echo "❌ AWS_ACCESS_KEY_ID"
gh secret list | grep -q "AWS_SECRET_ACCESS_KEY" && echo "✅ AWS_SECRET_ACCESS_KEY" || echo "❌ AWS_SECRET_ACCESS_KEY"
gh secret list | grep -q "AWS_REGION" && echo "✅ AWS_REGION" || echo "❌ AWS_REGION"
gh secret list | grep -q "ECR_BACKEND_REPO" && echo "✅ ECR_BACKEND_REPO" || echo "❌ ECR_BACKEND_REPO"
gh secret list | grep -q "ECR_FRONTEND_REPO" && echo "✅ ECR_FRONTEND_REPO" || echo "❌ ECR_FRONTEND_REPO"

# 4. Test Docker builds
echo ""
echo "Testing Docker builds..."
docker build -t test-backend ./backend >/dev/null 2>&1 && echo "✅ Backend builds" || echo "❌ Backend build failed"
docker build -t test-frontend ./frontend >/dev/null 2>&1 && echo "✅ Frontend builds" || echo "❌ Frontend build failed"

echo ""
echo "✅ Pre-flight checks complete!"
```

---

## 11. Deploy! 🚀

Once all checks pass:

```bash
# 1. Commit changes
git add .
git commit -m "Automated ECS deployment with Service Connect"

# 2. Push to dev branch
git push origin dev

# 3. Watch the deployment
gh run list --workflow=deploy.yaml
gh run watch [RUN_ID]

# 4. Check logs
aws logs tail /ecs/jobgpt-backend --follow
aws logs tail /ecs/jobgpt-frontend --follow
```

---

## 12. Verify Deployment ✓

After workflow completes:

```bash
# 1. Check cluster
aws ecs describe-clusters --clusters jobgpt --query 'clusters[0].{name:clusterName,status:status,services:registeredContainerInstancesCount}'

# 2. Check services
aws ecs describe-services \
  --cluster jobgpt \
  --services backend-service frontend-service \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]'

# 3. Check tasks
aws ecs list-tasks --cluster jobgpt --service-name backend-service
aws ecs list-tasks --cluster jobgpt --service-name frontend-service

# 4. Check logs
aws logs tail /ecs/jobgpt-backend --follow --since 5m
aws logs tail /ecs/jobgpt-frontend --follow --since 5m

# 5. Test services
# From within ECS or an EC2 instance in the same VPC:
curl http://backend-service.jobgpt:8000/health
curl http://frontend-service.jobgpt/health
```

---

## Troubleshooting ❓

### Workflow fails at "Create ECS Cluster"
- Check AWS credentials in GitHub secrets
- Verify IAM user has ECS permissions

### "Fargate requires task definition to have execution role ARN"
- Ensure `executionRoleArn` is in task definitions
- Check role exists: `aws iam get-role --role-name AmazonECSTaskExecutionRolePolicy`

### Services stay in "PROVISIONING"
- Check CloudWatch logs for errors
- Verify health check command works
- Increase task CPU/memory if needed

### Can't resolve backend-service.jobgpt
- Verify Service Connect namespace created: `aws servicediscovery list-namespaces`
- Check service has Service Connect enabled

### Images not pushing to ECR
- Verify ECR repositories exist
- Check IAM permissions for ECR
- Verify repository names in GitHub secrets

---

## Summary ✅

When all checkboxes are complete, you have:
- ✅ AWS account configured
- ✅ ECR repositories created
- ✅ GitHub secrets configured
- ✅ Task definitions with execution roles
- ✅ Code properly configured
- ✅ Docker builds working
- ✅ Workflow ready to trigger

**Next:** Push to dev branch and watch it deploy! 🚀
