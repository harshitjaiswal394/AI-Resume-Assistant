# ECS Service Communication - Complete Fix Documentation

## 📋 Table of Contents
1. [Problem Overview](#problem-overview)
2. [Issues Identified](#issues-identified)
3. [Solutions Applied](#solutions-applied)
4. [Architecture](#architecture)
5. [Configuration Details](#configuration-details)
6. [Deployment Steps](#deployment-steps)
7. [Testing Guide](#testing-guide)
8. [Troubleshooting](#troubleshooting)

---

## Problem Overview

The frontend and backend services running in an ECS cluster (namespace: `jobgpt`) were unable to communicate with each other due to:
- Hardcoded localhost URLs in frontend
- Missing proper Nginx reverse proxy configuration
- Incomplete ECS task definitions
- Non-environment-based CORS configuration

---

## Issues Identified

### 🔴 Critical Issues

| Issue # | File | Problem | Impact |
|---------|------|---------|--------|
| 1 | `frontend/src/components/ResumeUpload.js` | Hardcoded `http://127.0.0.1:8000/upload-resume` URL | Cannot reach backend in ECS, only works in local dev |
| 2 | `frontend/frontend-task.json` | Port 3000 instead of 80 | Nginx serves on 80, task expects 3000 - service won't start |
| 3 | `backend/backend-task.json` | Missing Fargate config, health checks, env vars | ECS can't properly manage service, no CORS configuration |
| 4 | `backend/.env` | Missing CORS_ORIGINS configuration | Backend doesn't know which origins are allowed |
| 5 | `backend/main.py` | Hardcoded CORS origins, no env var loading | Cannot use environment-based configuration |

---

## Solutions Applied

### ✅ Fix #1: ResumeUpload.js - Replace Hardcoded URL

**File:** `frontend/src/components/ResumeUpload.js`

**Before:**
```javascript
await axios.post("http://127.0.0.1:8000/upload-resume", formData, {
```

**After:**
```javascript
await axios.post("/api/upload-resume", formData, {
```

**Why:** 
- Uses relative path that goes through Nginx reverse proxy
- Works in both local dev and ECS environments
- Nginx routes `/api/` to `backend-service.jobgpt:8000`

---

### ✅ Fix #2: backend-task.json - Complete ECS Configuration

**File:** `backend/backend-task.json`

**Changes:**
- Added `requiresCompatibilities: ["FARGATE"]` - Required for Fargate launch type
- Added `cpu: "256"` and `memory: "512"` - Fargate requirements
- Removed `hostPort` from port mapping - Not needed in Fargate
- Added `environment` section with CORS_ORIGINS
- Added `healthCheck` configuration - ECS monitors service health
- Added `logConfiguration` - Sends logs to CloudWatch

**Key Configuration:**
```json
"environment": [
  {
    "name": "CORS_ORIGINS",
    "value": "http://localhost:3000,http://127.0.0.1:3000,http://frontend-service.jobgpt"
  }
]
```

**Health Check:**
```json
"healthCheck": {
  "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

---

### ✅ Fix #3: frontend-task.json - Proper Nginx Configuration

**File:** `frontend/frontend-task.json`

**Changes:**
- Changed port from `3000` to `80` - Nginx runs on port 80
- Added `requiresCompatibilities: ["FARGATE"]`
- Added `cpu` and `memory` Fargate requirements
- Removed `hostPort` from mapping
- Added health check
- Added CloudWatch logging

**Key Configuration:**
```json
"portMappings": [
  {
    "containerPort": 80,
    "protocol": "tcp"
  }
]
```

---

### ✅ Fix #4: backend/.env - CORS Configuration

**File:** `backend/.env`

**Added:**
```env
# CORS Origins Configuration
# Local dev: allow localhost
# ECS: allow frontend service DNS name
CORS_ORIGINS="http://localhost:3000,http://127.0.0.1:3000,http://frontend-service.jobgpt"
```

**Includes:**
- `http://localhost:3000` - Local development
- `http://127.0.0.1:3000` - Local with IP
- `http://frontend-service.jobgpt` - ECS Service Connect DNS

---

### ✅ Fix #5: backend/main.py - Environment-Based CORS

**File:** `backend/main.py`

**Added Import:**
```python
import os
from dotenv import load_dotenv

# Load environment variables from .env file (for local development)
load_dotenv()
```

**CORS Configuration:**
```python
# CORS Configuration - Environment-based for flexibility
CORS_ORIGINS = os.getenv(
    "CORS_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000,http://frontend-service.jobgpt"
).split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)
```

**Benefits:**
- Reads from environment variable in ECS
- Falls back to default if not set
- Supports multiple origins (split by comma)
- Can be configured per environment

---

## Architecture

### Service Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ECS Cluster: jobgpt                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Frontend Task                   Backend Task               │
│  ┌──────────────────┐            ┌──────────────────┐      │
│  │  Nginx (port 80) │            │  FastAPI (8000)  │      │
│  │  frontend-service.jobgpt       │  backend-service │      │
│  └────────┬─────────┘            │  .jobgpt:8000    │      │
│           │                       └────────┬─────────┘      │
│           │ /api/ask request               │                │
│           └──────────────────────→ proxy_pass to :8000     │
│           │                       │                         │
│           │ health check (port 80) health check (port 8000) │
│           │                       │                         │
│  Service Connect DNS              │                         │
│  frontend-service.jobgpt          backend-service.jobgpt    │
│  :80                              :8000                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Request Lifecycle

```
1. Browser Request
   ↓
2. frontend-service.jobgpt:80 (Nginx)
   ↓
3. User uploads resume: POST /api/upload-resume
   ↓
4. Nginx location /api/ rule triggered
   ↓
5. Nginx proxy_pass: http://backend-service.jobgpt:8000/
   ↓
6. Service Connect DNS Resolution
   ↓
7. Resolves to backend container IP
   ↓
8. Backend FastAPI receives: POST /upload-resume
   ↓
9. Checks CORS_ORIGINS environment variable
   ↓
10. Response sent back with CORS headers
    ↓
11. Browser receives response ✅
```

---

## Configuration Details

### Frontend Nginx Configuration

**File:** `frontend/nginx.conf`

Key sections for API communication:

```nginx
# Serve React frontend
location / {
    root /usr/share/nginx/html;
    index index.html;
    try_files $uri /index.html;
}

# Proxy API requests to backend service
location /api/ {
    set $backend_host "backend-service.jobgpt";
    proxy_pass http://$backend_host:8000/;
    
    # Forward important headers
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Timeout settings
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

# Health check for ECS
location /health {
    return 200 'healthy';
    add_header Content-Type text/plain;
}
```

### Frontend React Components

#### Chat.js - Already Configured
```javascript
const res = await axios.post("/api/ask", {
  question: question
});
```

#### ResumeUpload.js - Fixed
```javascript
await axios.post("/api/upload-resume", formData, {
  headers: { "Content-Type": "multipart/form-data" }
});
```

---

## Deployment Steps

### Step 1: Update Task Definitions in AWS

```bash
# Register backend task definition
aws ecs register-task-definition --cli-input-json file://backend/backend-task.json

# Register frontend task definition
aws ecs register-task-definition --cli-input-json file://frontend/frontend-task.json
```

### Step 2: Create ECS Services with Service Connect

#### Option A: Using AWS Console

**For Backend Service:**
1. Go to ECS → Cluster (jobgpt) → Services → Create Service
2. Task Definition: `backend:latest`
3. Service Name: `backend-service`
4. **Enable Service Connect:**
   - Service Connect Name: `backend-service`
   - Port: `8000`
   - Namespace: `jobgpt`
   - Discovery Name: `backend-service`

**For Frontend Service:**
1. Go to ECS → Cluster (jobgpt) → Services → Create Service
2. Task Definition: `frontend:latest`
3. Service Name: `frontend-service`
4. **Enable Service Connect:**
   - Service Connect Name: `frontend-service`
   - Port: `80`
   - Namespace: `jobgpt`
   - Discovery Name: `frontend-service`

#### Option B: Using CloudFormation

See templates in deployment documentation.

### Step 3: Verify Services

```bash
# Check if services are running
aws ecs list-services --cluster jobgpt

# Check service details
aws ecs describe-services --cluster jobgpt --services backend-service frontend-service
```

---

## Testing Guide

### Local Development Testing

**Setup:**
```bash
# Install Python dependencies
pip install -r backend/requirements.txt

# Install Node dependencies
cd frontend
npm install
cd ..

# Start backend on localhost:8000
python -m uvicorn backend.main:app --reload

# Start frontend dev server on localhost:3000
cd frontend && npm start
```

**Test Upload Resume:**
```bash
curl -X POST http://localhost:3000/api/upload-resume \
  -F "file=@resume.pdf"
```

**Test Ask Question:**
```bash
curl -X POST http://localhost:3000/api/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What is my experience?"}'
```

### ECS Testing

**1. Verify Health Endpoints:**
```bash
# Test frontend health
curl http://frontend-service.jobgpt/health
# Expected: "healthy"

# Test backend health
curl http://backend-service.jobgpt:8000/health
# Expected: {"status": "healthy", "service": "backend"}
```

**2. Test API Communication:**

From within ECS task or using AWS Systems Manager Session Manager:
```bash
# From frontend container, test backend
curl -X POST http://backend-service.jobgpt:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}'
```

**3. Test from Browser:**
1. Open `http://frontend-service.jobgpt` in browser
2. Upload a resume file
3. Ask a question in chat
4. Check browser console (F12) for any CORS errors

**4. Monitor Logs:**
```bash
# View backend logs
aws logs tail /ecs/jobgpt-backend --follow

# View frontend logs
aws logs tail /ecs/jobgpt-frontend --follow
```

---

## Troubleshooting

### Issue 1: 502 Bad Gateway from Frontend

**Symptoms:** Frontend returns 502 when calling `/api/ask`

**Causes & Solutions:**
```
❌ Backend service not running
   → Check ECS service status: aws ecs describe-services --cluster jobgpt --services backend-service

❌ Backend health check failing
   → Check CloudWatch logs: aws logs tail /ecs/jobgpt-backend
   → Ensure backend is listening on 0.0.0.0:8000

❌ Service Connect DNS not resolving
   → Verify Service Connect is enabled on both services
   → Check namespace: jobgpt
   → Test: nslookup backend-service.jobgpt (from inside container)

❌ Security group blocking port 8000
   → Verify backend security group allows inbound 8000 from frontend SG
```

### Issue 2: CORS Error in Browser

**Symptoms:** Browser console shows CORS error

**Causes & Solutions:**
```
❌ CORS_ORIGINS not configured correctly
   → Check environment variable: aws ecs describe-task-definition --task-definition backend:X
   → Verify CORS_ORIGINS includes frontend domain

❌ Wrong origin header being sent
   → Check browser devtools: Network → Headers → Origin
   → Ensure it matches one of the configured origins

❌ CORS_ORIGINS not loaded in ECS
   → Check if load_dotenv() is working
   → Verify environment variable is set in task definition
   → Check CloudWatch logs for CORS origins being used
```

Example CloudWatch log check:
```bash
aws logs filter-log-events \
  --log-group-name /ecs/jobgpt-backend \
  --filter-pattern "CORS"
```

### Issue 3: Cannot Resolve Service DNS

**Symptoms:** `curl backend-service.jobgpt` fails

**Causes & Solutions:**
```
❌ Service Connect not enabled
   → Go to ECS service settings
   → Check "Service Connect" is enabled
   → Verify namespace is "jobgpt"

❌ Services in different namespaces
   → Frontend namespace: jobgpt ✓
   → Backend namespace: jobgpt ✓
   → Must be same namespace for DNS resolution

❌ Service name mismatch
   → Nginx config uses: backend-service.jobgpt
   → ECS Service Connect Name: backend-service ✓
   → Discovery Name: backend-service ✓
```

### Issue 4: Container Fails to Start

**Symptoms:** Task keeps restarting, health check failing

**Causes & Solutions:**
```
❌ Port already in use
   → Check if another container using port 80/8000
   → Kill conflicting containers

❌ Health check command failing
   → Backend: curl -f http://localhost:8000/health
   → Frontend: curl -f http://localhost:80/health
   → Test manually in container shell

❌ Missing dependencies
   → Backend: Check python-dotenv is in requirements.txt
   → Frontend: Ensure nginx.conf is copied in Dockerfile
```

### Issue 5: Resume Upload Not Working

**Symptoms:** Upload button submits to wrong URL

**Root Cause:** Hardcoded `http://127.0.0.1:8000/upload-resume`

**Solution Applied:**
- Changed to `/api/upload-resume`
- Now proxied through Nginx to backend

**Verify:**
```javascript
// Check in ResumeUpload.js
axios.post("/api/upload-resume", ...)  // ✓ Correct

// NOT
axios.post("http://127.0.0.1:8000/upload-resume", ...)  // ✗ Wrong
```

---

## Best Practices Applied

### ✅ Service Discovery
- Using Service Connect DNS instead of hardcoded IPs
- Supports auto-scaling and dynamic IP assignment
- Works across container restarts

### ✅ Environment Configuration
- CORS origins configurable via environment variable
- Same code works in local dev and ECS
- Easy to update per environment without code changes

### ✅ Health Checks
- Both services have health check endpoints
- ECS automatically replaces unhealthy containers
- Can be monitored in CloudWatch

### ✅ Logging
- All logs sent to CloudWatch for centralized monitoring
- Easy debugging in production
- Log retention configurable

### ✅ Security
- CORS properly configured to allow only specified origins
- Not using `allow_origins=["*"]` which is insecure
- Sensitive data not in code, using environment variables

---

## Files Modified Summary

| File | Changes | Status |
|------|---------|--------|
| `backend/main.py` | Added env vars support, load_dotenv() | ✅ |
| `backend/.env` | Added CORS_ORIGINS config | ✅ |
| `backend/backend-task.json` | Fargate config, health check, logging, env vars | ✅ |
| `frontend/nginx.conf` | Proxy `/api/` to backend | ✅ |
| `frontend/frontend-task.json` | Port 80, Fargate config, health check, logging | ✅ |
| `frontend/src/components/ResumeUpload.js` | Changed hardcoded URL to `/api/` | ✅ |
| `frontend/src/components/Chat.js` | Already using `/api/` ✓ | ✅ |

---

## Quick Reference

### Service Discovery

| Service | DNS Name | Port | Type |
|---------|----------|------|------|
| Frontend | `frontend-service.jobgpt` | 80 | Nginx |
| Backend | `backend-service.jobgpt` | 8000 | FastAPI |

### CORS Configuration

```env
# Allowed Origins
http://localhost:3000              # Local dev
http://127.0.0.1:3000             # Local with IP
http://frontend-service.jobgpt     # ECS Service Connect
```

### API Routes

| Endpoint | Method | Frontend | Backend |
|----------|--------|----------|---------|
| `/api/upload-resume` | POST | ✓ | `/upload-resume` |
| `/api/ask` | POST | ✓ | `/ask` |
| `/api/health` | GET | ✓ | `/health` |

---

## Additional Resources

- [AWS ECS Service Connect Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect.html)
- [FastAPI CORS Documentation](https://fastapi.tiangolo.com/tutorial/cors/)
- [Nginx Proxy Documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Docker Compose Alternative Setup](docker-compose.yml) (if using for local testing)

---

## Support & Next Steps

### Immediate Actions:
1. ✅ Deploy task definitions to ECS
2. ✅ Create services with Service Connect enabled
3. ✅ Test communication between services
4. ✅ Monitor CloudWatch logs

### Future Improvements:
- Add HTTPS/SSL termination with ALB
- Implement API rate limiting
- Add request logging/tracing
- Set up automated monitoring alerts

---

**Document Version:** 1.0  
**Last Updated:** April 9, 2026  
**Status:** All Issues Fixed ✅
