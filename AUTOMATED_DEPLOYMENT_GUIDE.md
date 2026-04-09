# Complete Automated Deployment Guide

## 📋 Overview

The updated `deploy.yaml` workflow now **fully automates** the entire deployment process including:
- ✅ ECS cluster creation (if not exists)
- ✅ Service Connect namespace creation
- ✅ CloudWatch log groups
- ✅ Task definition registration
- ✅ Service creation/updates with Service Connect
- ✅ Automatic VPC and subnet detection
- ✅ Deployment verification

**No manual AWS console steps needed!**

---

## 🔐 GitHub Secrets Required

Add these secrets to your GitHub repository settings:

**Path:** Go to Settings → Secrets and variables → Actions → New repository secret

### Required Secrets:

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ACCOUNT_ID` | Your AWS Account ID | `716608655181` |
| `AWS_ACCESS_KEY_ID` | AWS IAM user access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM user secret key | `wJal...` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `ECR_BACKEND_REPO` | Backend ECR repository name | `jobgpt-backend` |
| `ECR_FRONTEND_REPO` | Frontend ECR repository name | `jobgpt-frontend` |

### How to Add Secrets:

```bash
# Option 1: Using GitHub CLI
gh secret set AWS_ACCOUNT_ID --body "716608655181"
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set AWS_REGION --body "us-east-1"
gh secret set ECR_BACKEND_REPO --body "jobgpt-backend"
gh secret set ECR_FRONTEND_REPO --body "jobgpt-frontend"

# Option 2: Manual in GitHub UI
# 1. Go to your repo
# 2. Settings → Secrets and variables → Actions
# 3. Click "New repository secret"
# 4. Add each secret
```

---

## 📊 Hardcoded Values in Workflow

These values are now hardcoded (no secrets needed):

| Value | Hardcoded | Why |
|-------|-----------|-----|
| Cluster Name | `jobgpt` | Standard cluster name |
| Namespace | `jobgpt` | Service Connect namespace |
| Backend Service | `backend-service` | Standard service name |
| Frontend Service | `frontend-service` | Standard service name |
| Backend Port | `8000` | FastAPI default |
| Frontend Port | `80` | Nginx default |
| Backend DNS | `backend-service.jobgpt` | Service Connect DNS |
| Frontend DNS | `frontend-service.jobgpt` | Service Connect DNS |

---

## 🚀 What the Workflow Does

### Step 1: Configure AWS
```bash
# Authenticates with AWS using provided credentials
```

### Step 2: Create ECS Cluster
```bash
# Creates cluster 'jobgpt' if it doesn't exist
# Tags: Environment=dev, Project=jobgpt
```

### Step 3: Create Service Connect Namespace
```bash
# Creates private DNS namespace 'jobgpt'
# Enables Service-to-Service discovery via DNS
```

### Step 4: Create CloudWatch Log Groups
```bash
# Creates /ecs/jobgpt-backend (7-day retention)
# Creates /ecs/jobgpt-frontend (7-day retention)
```

### Step 5: Build & Push Docker Images
```bash
# Builds backend image from ./backend/Dockerfile
# Pushes to ECR: jobgpt-backend:latest
# Pushes to ECR: jobgpt-backend:$COMMIT_SHA

# Builds frontend image from ./frontend/Dockerfile
# Pushes to ECR: jobgpt-frontend:latest
# Pushes to ECR: jobgpt-frontend:$COMMIT_SHA
```

### Step 6: Register Task Definitions
```bash
# Registers backend task definition from backend/backend-task.json
# Registers frontend task definition from frontend/frontend-task.json
```

### Step 7: Get VPC/Subnet Info
```bash
# Automatically detects:
# - Default VPC
# - Available subnets
# - Security groups

# No manual configuration needed!
```

### Step 8: Create/Update Services with Service Connect
```bash
# Backend Service:
#   - Name: backend-service
#   - Port: 8000
#   - DNS: backend-service.jobgpt
#   - Service Connect enabled

# Frontend Service:
#   - Name: frontend-service
#   - Port: 80
#   - DNS: frontend-service.jobgpt
#   - Service Connect enabled
```

### Step 9: Verify Deployment
```bash
# Checks service status
# Verifies running tasks
# Displays log group info
```

---

## 📝 Complete Deployment Flow

```
Push to 'dev' branch
        ↓
GitHub Actions Triggered
        ↓
AWS Credentials Configured
        ↓
ECS Cluster 'jobgpt' Created (if not exists)
        ↓
Service Connect Namespace 'jobgpt' Created (if not exists)
        ↓
CloudWatch Log Groups Created
        ↓
Docker Images Built & Pushed to ECR
        ↓
Task Definitions Registered
        ↓
VPC/Subnet Info Auto-Detected
        ↓
Backend Service Created/Updated with Service Connect
        ↓
Frontend Service Created/Updated with Service Connect
        ↓
Deployment Verified
        ↓
✅ Ready for Use!
```

---

## 🔗 Service Connection Details

After deployment, your services are automatically connected via Service Connect:

### Backend Service
```
Service Name: backend-service
Port: 8000
Protocol: TCP
DNS Name: backend-service.jobgpt
Region: us-east-1
Namespace: jobgpt
```

### Frontend Service
```
Service Name: frontend-service
Port: 80
Protocol: TCP
DNS Name: frontend-service.jobgpt
Region: us-east-1
Namespace: jobgpt
```

### Communication Flow
```
Frontend (port 80)
  ↓ (via Nginx reverse proxy)
Backend (port 8000)
  Using DNS: backend-service.jobgpt
  Resolved by: Service Connect
```

---

## 💻 How to Deploy

### Option 1: Automatic Push to Dev Branch
```bash
git add .
git commit -m "Deploy to ECS with Service Connect"
git push origin dev

# GitHub Actions will automatically:
# 1. Build images
# 2. Push to ECR
# 3. Create/update cluster and services
# 4. Enable Service Connect
```

### Option 2: Manual Workflow Trigger
```bash
# Go to GitHub UI
# Actions → Deploy to AWS ECS with Service Connect → Run workflow → Select branch
```

### Option 3: Using GitHub CLI
```bash
gh workflow run deploy.yaml --ref dev
```

---

## 📊 Monitoring Deployment

### Check Workflow Status
```bash
# GitHub UI: Actions tab
# or CLI:
gh run list --workflow=deploy.yaml
```

### Monitor CloudWatch Logs
```bash
# Backend logs
aws logs tail /ecs/jobgpt-backend --follow

# Frontend logs
aws logs tail /ecs/jobgpt-frontend --follow
```

### Check Service Status
```bash
# Backend service
aws ecs describe-services \
  --cluster jobgpt \
  --services backend-service \
  --query 'services[0]'

# Frontend service
aws ecs describe-services \
  --cluster jobgpt \
  --services frontend-service \
  --query 'services[0]'
```

---

## 🧪 Test Service Communication

### From Within ECS Container

```bash
# Test backend health
curl http://backend-service.jobgpt:8000/health

# Test frontend health
curl http://frontend-service.jobgpt/health
```

### From Browser

```
Frontend URL: http://frontend-service.jobgpt
   ↓
Nginx serves React app
   ↓
Upload Resume → POST /api/upload-resume
   ↓
Nginx proxies to backend-service.jobgpt:8000/upload-resume
   ↓
Backend processes and responds ✅
```

---

## 🔧 Troubleshooting

### Issue: Workflow Fails at "Create ECS Cluster"

**Cause:** Missing AWS credentials

**Solution:**
```bash
# Verify secrets are set
gh secret list

# Ensure these exist:
# - AWS_ACCOUNT_ID
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY
# - AWS_REGION
```

### Issue: "Fargate requires task definition to have execution role ARN"

**Cause:** Task definition missing execution role

**Solution:** 
✅ Already fixed in task definitions with:
```json
"executionRoleArn": "arn:aws:iam::716608655181:role/AmazonECSTaskExecutionRolePolicy"
```

### Issue: Service stays in "PROVISIONING" state

**Cause:** Health check failing or insufficient resources

**Solution:**
```bash
# Check task logs
aws logs tail /ecs/jobgpt-backend --follow

# Increase task resources
# Edit backend/backend-task.json or frontend/frontend-task.json
# Set higher cpu/memory
# Re-push to trigger deployment
```

### Issue: Service Connect DNS not resolving

**Cause:** Namespace not created or service not in same namespace

**Solution:**
```bash
# Verify namespace exists
aws servicediscovery list-namespaces

# Verify services have Service Connect enabled
aws ecs describe-services \
  --cluster jobgpt \
  --services backend-service frontend-service
```

---

## 📋 Pre-Deployment Checklist

Before pushing to `dev` branch:

- ✅ `backend-task.json` has `executionRoleArn`
- ✅ `frontend-task.json` has `executionRoleArn`
- ✅ Github secrets configured:
  - `AWS_ACCOUNT_ID`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `ECR_BACKEND_REPO`
  - `ECR_FRONTEND_REPO`
- ✅ ECR repositories created
- ✅ Code pushed to `dev` branch
- ✅ IAM user has permissions: ECS, EC2, CloudWatch, Service Discovery

---

## 🎫 Required IAM Permissions

Ensure the AWS user has these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ec2:de*",
        "ec2:describe*",
        "logs:*",
        "servicediscovery:*",
        "ecr:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 🚀 Quick Start Summary

1. **Add GitHub Secrets** (6 required)
   ```bash
   gh secret set AWS_ACCOUNT_ID --body "YOUR_VALUE"
   # ... add remaining 5 secrets
   ```

2. **Verify Files**
   - ✅ `backend/backend-task.json` - has executionRoleArn
   - ✅ `frontend/frontend-task.json` - has executionRoleArn
   - ✅ `.github/workflows/deploy.yaml` - updated with new automation

3. **Deploy**
   ```bash
   git push origin dev
   # Wait for GitHub Actions to complete
   ```

4. **Verify**
   ```bash
   aws ecs describe-services --cluster jobgpt --services backend-service frontend-service
   ```

5. **Access**
   ```
   Frontend: http://frontend-service.jobgpt
   Backend: http://backend-service.jobgpt:8000
   ```

---

## 📚 What Changed in deploy.yaml

### Added Steps:

1. **Create ECS Cluster** - Automated cluster creation
2. **Create Service Connect Namespace** - Service discovery setup
3. **Create CloudWatch Log Groups** - Logging infrastructure
4. **Register Task Definitions** - Update service definitions
5. **Get VPC/Subnet Info** - Auto VPC detection
6. **Create/Update Services with Service Connect** - Full service automation
7. **Verify Deployment** - Status checking
8. **Display Service Details** - Summary output

### Removed Manual Steps:

❌ Manual cluster creation  
❌ Manual namespace creation  
❌ Manual service configuration  
❌ Manual log group creation  

### Result:
✅ **Zero-touch deployment** - Push code and it's fully deployed!

---

**Document Version:** 1.0  
**Last Updated:** April 9, 2026  
**Status:** ✅ Ready for Production
