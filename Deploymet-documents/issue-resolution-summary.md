# 🛠️ Issue & Resolution Summary — JobGPT ECS Deployment

## Overview

This document captures all issues encountered and resolved during the deployment of the JobGPT application on AWS ECS Fargate using Service Connect for service-to-service communication.

---

## Issue 1: YAML Heredoc Conflict in GitHub Actions

### Problem
Using `<<EOF` heredoc syntax inside a GitHub Actions `run: |` block caused the YAML parser to throw:
```
Nested mappings are not allowed in compact mappings
Implicit keys need to be on a single line
```

### Root Cause
GitHub Actions workflows are YAML files. The `<<` characters conflict with YAML's merge key syntax.

### Resolution
Replaced heredoc with `jq` for JSON construction, and moved all `${{ secrets.* }}` and `${{ github.event.inputs.* }}` values into the step's `env:` block instead of interpolating them directly into shell scripts.

```yaml
- name: Prepare Task Definition
  env:
    ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
    NVIDIA_API_KEY: ${{ secrets.NVIDIA_API_KEY }}
  run: |
    jq --arg ENV "$ENVIRONMENT" --arg KEY "$NVIDIA_API_KEY" \
      '.containerDefinitions[0].environment = [...]' \
      task.json > task-final.json
```

---

## Issue 2: jq Parse Error — Invalid Numeric Literal

### Problem
```
jq: parse error: Invalid numeric literal at line 21, column 34
```

### Root Cause
`backend-task.json` contained an unquoted placeholder `"environment": __ENV_VARS__` which made the file invalid JSON. jq failed to parse the input file before even running the filter.

### Resolution
Replaced all unquoted placeholders in task definition JSON files with valid defaults:
```json
"environment": []
```
jq overwrites this at runtime via the filter.

---

## Issue 3: Service Connect DNS Not Resolving

### Problem
nginx inside the frontend container could not resolve `dev-backend-service`:
```
dev-backend-service could not be resolved (3: Host not found)
```

### Root Cause — Multiple Layers

**Layer 1:** Both ECS services had `serviceConnect: null` — Service Connect was never attached. The workflow used `update-service` for existing services, but Service Connect configuration can only be set at `create-service` time.

**Layer 2:** The Cloud Map namespace was created as `Type: HTTP` with empty `DnsConfig: {}` — no DNS records were registered, only HTTP routing.

**Layer 3:** The namespace was created using `Vpcs[0]` instead of filtering for the default VPC explicitly.

**Layer 4:** Namespace creation is async but the workflow only did a blind `sleep 30` without waiting for the operation to complete.

**Layer 5:** The frontend service had a `service {}` block in its Service Connect config, making it register itself as a server instead of acting as a client-only consumer.

### Resolution

1. Always delete and recreate ECS services — never use `update-service` to change Service Connect config
2. Poll the namespace creation operation until `SUCCESS`:
```bash
OP_ID=$(aws servicediscovery create-private-dns-namespace ... --query 'OperationId' --output text)
until [ "$(aws servicediscovery get-operation --operation-id $OP_ID --query 'Operation.Status' --output text)" = "SUCCESS" ]; do sleep 10; done
```
3. Frontend service: client-only config (no `service {}` block):
```json
{"enabled": true, "namespace": "arn:..."}
```
4. Backend service: full registration with `service {}` block:
```json
{
  "enabled": true,
  "namespace": "arn:...",
  "services": [{"portName": "backend-8000", "clientAliases": [{"port": 8000, "dnsName": "dev-backend-service"}]}]
}
```

---

## Issue 4: nginx envsubst Conflicting with nginx Variables

### Problem
Using the official nginx template mechanism (`/etc/nginx/templates/`) with `${BACKEND_URL}` caused:
```
unknown "backend_url" variable
```

### Root Cause
`envsubst` replaces `${BACKEND_URL}` correctly, but nginx then interprets `$backend_url` as one of its own internal variables (all lowercase), which don't exist.

### Resolution
Replaced the template mechanism with a custom `entrypoint.sh` that uses `sed` to replace plain text placeholders — no `$` signs involved:

```bash
sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf
```

---

## Issue 5: nginx Using Explicit Resolver Bypasses /etc/hosts

### Problem
After Service Connect was correctly configured, nginx still couldn't resolve `dev-backend-service` even though `curl` from the same container worked perfectly.

### Root Cause
Service Connect injects backend addresses into `/etc/hosts`:
```
127.255.0.1      dev-backend-service    ← IPv4 Service Connect proxy
2600:f0f0::1     dev-backend-service    ← IPv6 (unreachable)
```

`curl` uses the system resolver which checks `/etc/hosts` first — so it finds `127.255.0.1` and works.

nginx with an explicit `resolver` directive bypasses `/etc/hosts` entirely and goes straight to DNS (`172.31.0.2`) which has no record for `dev-backend-service` → `NXDOMAIN`.

When `set $backend` was used with the resolver, nginx resolved the IPv6 address `2600:f0f0::1` which was network unreachable.

### Resolution
Read the IPv4 address directly from `/etc/hosts` at container startup and hardcode it into the nginx config:

```bash
BACKEND_IP=$(grep "$BACKEND_SERVICE_NAME" /etc/hosts | grep -v ':' | awk '{print $1}' | head -1)
BACKEND_URL="http://${BACKEND_IP}:8000"
sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" /etc/nginx/conf.d/default.conf
```

`grep -v ':'` filters out the IPv6 line, leaving only the IPv4 `127.255.0.1` address.

---

## Issue 6: nginx 404 on /api/ Routes

### Problem
After DNS was resolved, requests returned `404`:
```
POST /api/upload-resume HTTP/1.1" 404
```

### Root Cause
nginx `proxy_pass` without a trailing slash forwards the full path including `/api/` to the backend. FastAPI routes are defined without the `/api/` prefix (e.g. `/upload-resume`), so `/api/upload-resume` → 404.

### Resolution
Add trailing slash to `proxy_pass` so nginx strips the `/api/` prefix:

```nginx
location /api/ {
    proxy_pass http://127.255.0.1:8000/;  # trailing slash strips /api/
}
```

Result: `/api/upload-resume` → `/upload-resume` ✅

---

## Issue 7: Terraform Frontend Service Not Created with Service Connect

### Problem
```
Error: creating ECS Service (dev-frontend-service): InvalidParameterException:
Create service is not idempotent
```

### Root Cause
The frontend ECS service existed in AWS (created manually) but was not in Terraform state. Terraform tried to create it fresh, but AWS rejected it because a service with that name already existed.

Additionally, the `ecs_service` module always added a `service {}` block to Service Connect config regardless of whether the service was a server or client-only.

### Resolution

1. Import existing resources into Terraform state:
```bash
terraform import module.frontend_service.aws_ecs_service.this dev-jobgpt-cluster/dev-frontend-service
terraform import module.frontend_service.aws_ecs_task_definition.this arn:aws:ecs:...:task-definition/dev-frontend-service-task:12
```

2. Added `service_connect_client_only` variable to the ECS service module to control whether a `service {}` block is included:
```hcl
variable "service_connect_client_only" {
  type    = bool
  default = false
}
```

3. Frontend uses `service_connect_client_only = true` — joins namespace but does not register itself.

---

## Issue 8: Terraform Apply Using Stale Plan with Different Image Tags

### Problem
The `terraform-plan` job built and pushed images with `GITHUB_SHA` tag, but the `terraform-apply` job downloaded a stale `tfplan` and then tried to override vars — causing a plan/apply mismatch where the task definition wasn't updated.

### Resolution
Removed the stale `tfplan` artifact from the apply stage. Instead, saved the `GITHUB_SHA` as a separate artifact and used it in the apply stage to run a fresh `terraform apply` with the correct image tag:

```yaml
- name: Save image tag
  run: echo "${GITHUB_SHA}" > /tmp/image-tag.txt

- name: Upload image tag
  uses: actions/upload-artifact@v4
  with:
    name: image-tag
    path: /tmp/image-tag.txt
```

---

## Final Working Architecture

```
Browser
  ↓ HTTPS
Route53 (app.jaiswal.shop)
  ↓
ALB (HTTPS:443 → HTTP:80 redirect, SSL termination)
  ↓ HTTP
Frontend ECS Task (nginx on port 80)
  ├── /          → React static files
  ├── /health    → 200 OK
  └── /api/      → proxy_pass http://127.255.0.1:8000/
                          ↓
              Service Connect sidecar proxy
                          ↓
              Backend ECS Task (FastAPI on port 8000)
```

## Key Lessons

- Service Connect config can only be set at `create-service` time — `update-service` cannot change it
- nginx explicit `resolver` bypasses `/etc/hosts` — use system resolver or hardcode IPs from `/etc/hosts`
- Service Connect injects both IPv4 (`127.255.x.x`) and IPv6 (`2600:f0f0::x`) into `/etc/hosts` — always filter for IPv4 with `grep -v ':'`
- Frontend should be Service Connect **client-only** — no `service {}` block
- `proxy_pass` trailing slash controls path stripping — always verify with `curl` from inside the container
