# 🌐 Traffic Flow, Routing & Security Guide
## React + FastAPI + nginx + AWS ECS — DevOps Reference

---

## 1. Current Architecture — How Traffic Flows

```
User Browser
     │
     │ https://app.jaiswal.shop/login
     ▼
┌─────────────────────┐
│     Route53         │  DNS: app.jaiswal.shop → ALB IP
│  (Public Hosted     │
│     Zone)           │
└─────────────────────┘
     │
     ▼
┌─────────────────────┐
│   ALB               │  Port 443 (HTTPS) — SSL terminated here
│   (Application      │  Port 80 (HTTP)  → redirect to 443
│   Load Balancer)    │  Certificate: ACM (app.jaiswal.shop)
└─────────────────────┘
     │
     │ HTTP (internal, port 80)
     ▼
┌─────────────────────┐
│  Frontend ECS Task  │
│  nginx (port 80)    │
│                     │
│  /          → React │
│  /health    → 200   │
│  /api/*     → proxy │
└─────────────────────┘
     │
     │ http://127.255.0.1:8000/  (Service Connect)
     ▼
┌─────────────────────┐
│  Backend ECS Task   │
│  FastAPI (port 8000)│
│                     │
│  /upload-resume     │
│  /ask               │
│  /health            │
└─────────────────────┘
```

---

## 2. How a Page Route Works — /login Example

### What happens when user visits `https://app.jaiswal.shop/login`

```
1. Browser → DNS lookup app.jaiswal.shop
2. Route53  → returns ALB IP addresses
3. Browser  → HTTPS request to ALB:443
4. ALB      → terminates SSL, forwards HTTP to frontend target group
5. nginx    → receives GET /login HTTP/1.1
6. nginx    → location / { try_files $uri /index.html; }
              /login does not exist as a file → serves /index.html
7. React    → loads in browser, React Router reads /login from URL
8. React    → renders <LoginPage /> component
```

**Key insight:** nginx serves `index.html` for ALL routes. React Router handles all page navigation client-side. The server never needs to know about `/login`, `/dashboard`, `/profile` etc.

### nginx config for React SPA routing:
```nginx
location / {
    root /usr/share/nginx/html;
    index index.html;
    try_files $uri /index.html;   ← this is the magic line
}
```

`try_files $uri /index.html` means:
- Try to find the exact file (`/login` → no file exists)
- Fall back to `/index.html` → React loads and handles the route

---

## 3. How an API Call Works — /api/upload-resume

```
1. React      → fetch('https://app.jaiswal.shop/api/upload-resume', {method: 'POST'})
2. Browser    → HTTPS POST to ALB:443/api/upload-resume
3. ALB        → forwards to frontend container port 80
4. nginx      → matches location /api/
5. nginx      → proxy_pass http://127.255.0.1:8000/
               strips /api/ → forwards POST /upload-resume to backend
6. Service    → 127.255.0.1 is the Service Connect sidecar proxy
   Connect
7. Backend    → FastAPI receives POST /upload-resume
8. FastAPI    → processes request, returns JSON
9. Response   → travels back through same path to browser
```

---

## 4. Adding a New Page — Step by Step

### Example: Add `/dashboard` page

**Step 1: React** — just add the route (no backend changes needed):
```jsx
// App.jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Dashboard from './pages/Dashboard'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/dashboard" element={<Dashboard />} />
      </Routes>
    </BrowserRouter>
  )
}
```

**Step 2: nginx** — no changes needed. `try_files $uri /index.html` handles it automatically.

**Step 3: ALB** — no changes needed. ALB forwards all traffic to frontend.

That's it. New pages are purely a React concern.

---

## 5. Adding a New API Endpoint

### Example: Add `/api/jobs` endpoint

**Step 1: FastAPI** — add the route:
```python
@app.get("/jobs")
async def get_jobs():
    return {"jobs": [...]}
```

**Step 2: nginx** — no changes needed. `/api/jobs` → `/jobs` automatically.

**Step 3: React** — call the API:
```jsx
const response = await fetch('/api/jobs')
```

---

## 6. Adding a Subdomain — api.jaiswal.shop

### Architecture with separate API subdomain:

```
app.jaiswal.shop    → ALB → Frontend (nginx + React)
api.jaiswal.shop    → ALB → Backend (FastAPI directly)
```

### Steps:

**Step 1: ACM Certificate** — add subdomain:
```hcl
resource "aws_acm_certificate" "app" {
  domain_name               = "app.jaiswal.shop"
  subject_alternative_names = ["api.jaiswal.shop"]
  validation_method         = "DNS"
}
```

**Step 2: Route53** — add A record:
```hcl
resource "aws_route53_record" "api_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.jaiswal.shop"
  type    = "A"
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

**Step 3: ALB Listener Rule** — route by host header:
```hcl
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    host_header {
      values = ["api.jaiswal.shop"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
```

**Step 4: Backend target group** — point directly to FastAPI container port 8000.

**Step 5: nginx** — no longer needs `/api/` proxy block if using subdomain approach.

With subdomain, React calls:
```jsx
// Instead of /api/upload-resume
fetch('https://api.jaiswal.shop/upload-resume')
```

---

## 7. Security Best Practices

### 7.1 Network Security — Security Groups

```
Internet → ALB SG (443, 80 inbound from 0.0.0.0/0)
ALB SG   → Frontend SG (80 inbound ONLY from ALB SG)
Frontend → Backend SG (8000 inbound ONLY from Frontend SG)
Backend  → No inbound from internet
```

```hcl
# ALB Security Group
resource "aws_security_group_rule" "alb_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Frontend: only accepts traffic from ALB
resource "aws_security_group_rule" "frontend_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

# Backend: only accepts traffic from Frontend
resource "aws_security_group_rule" "backend_from_frontend" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.frontend_service.id
}
```

### 7.2 SSL/TLS

- SSL is terminated at ALB — ACM certificate handles it
- ALB → ECS communication is HTTP (internal VPC only — acceptable)
- Use `ELBSecurityPolicy-TLS13-1-2-2021-06` for modern TLS policy:

```hcl
resource "aws_lb_listener" "https" {
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn
}
```

### 7.3 HTTP → HTTPS Redirect

ALB handles this automatically:
```hcl
resource "aws_lb_listener" "http" {
  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### 7.4 Secrets Management

- Never put secrets in environment variables directly — use AWS Secrets Manager
- ECS task pulls secrets at runtime via `secrets` block in task definition:

```json
"secrets": [
  {
    "name": "NVIDIA_API_KEY",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:...:secret:dev/jobgpt/nvidia_api_key"
  }
]
```

- Execution role needs `secretsmanager:GetSecretValue` permission
- Secrets are injected as env vars inside the container — never in logs, never in task definition JSON

### 7.5 IAM Least Privilege

Two separate roles:

**Execution Role** — used by ECS agent to start the task:
- `ecr:GetAuthorizationToken` — pull images
- `ecr:BatchGetImage` — pull images
- `logs:CreateLogStream` — write logs
- `secretsmanager:GetSecretValue` — fetch secrets

**Task Role** — used by the running application:
- Only permissions the app actually needs (e.g. S3, DynamoDB)
- Never give task role admin permissions

### 7.6 CORS Configuration

FastAPI should restrict CORS to your domain only:
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.jaiswal.shop"],  # not ["*"]
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)
```

### 7.7 nginx Security Headers

Add to nginx config:
```nginx
server {
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Hide nginx version
    server_tokens off;
}
```

---

## 8. Recommended Architecture for Production

```
                    ┌──────────────────┐
                    │   CloudFront     │  CDN, WAF, DDoS protection
                    │   + WAF          │  Cache static assets globally
                    └──────────────────┘
                            │
                    ┌──────────────────┐
                    │      ALB         │  SSL termination, routing
                    └──────────────────┘
                     /               \
          ┌──────────────┐    ┌──────────────┐
          │   Frontend   │    │   Backend    │
          │   (nginx +   │    │   (FastAPI)  │
          │    React)    │    │              │
          └──────────────┘    └──────────────┘
                                     │
                    ┌──────────────────────────────┐
                    │  AWS Managed Services        │
                    │  RDS / DynamoDB              │
                    │  ElastiCache (Redis)         │
                    │  S3 (file storage)           │
                    │  Secrets Manager             │
                    └──────────────────────────────┘
```

### Additional recommendations:
- **CloudFront** in front of ALB — caches static assets, provides WAF and DDoS protection globally
- **WAF rules** — block SQL injection, XSS, rate limiting
- **Private subnets** — move backend and databases to private subnets, only ALB in public
- **VPC Endpoints** — access S3, Secrets Manager without internet traffic
- **Container image scanning** — enable ECR image scanning on push
- **CloudWatch alarms** — alert on 5xx rate, task failures, CPU/memory

---

## 9. Quick Reference — Who Handles What

| Concern | Handled By |
|---|---|
| Page routing `/login` `/dashboard` | React Router |
| Serving React files | nginx |
| API proxying `/api/*` | nginx `proxy_pass` |
| SSL termination | ALB + ACM |
| HTTP→HTTPS redirect | ALB listener |
| Domain → IP resolution | Route53 |
| Service-to-service DNS | ECS Service Connect |
| Secrets injection | ECS + Secrets Manager |
| Network isolation | Security Groups |
| Image storage | ECR |
| Log aggregation | CloudWatch Logs |
