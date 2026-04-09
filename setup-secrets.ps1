# GitHub Secrets Setup Script for Windows
# This script sets up all required GitHub secrets for automated ECS deployment

Write-Host "🔐 GitHub Secrets Setup for AI-Resume-Assistant" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if GitHub CLI is installed
try {
    $null = gh --version
    Write-Host "✅ GitHub CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI not found. Please install it:" -ForegroundColor Red
    Write-Host "   https://cli.github.com/"
    exit 1
}

# Verify authenticated with GitHub
try {
    $null = gh auth status 2>$null
    Write-Host "✅ GitHub CLI authenticated" -ForegroundColor Green
} catch {
    Write-Host "❌ Not authenticated with GitHub. Please run:" -ForegroundColor Red
    Write-Host "   gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Get repository info
try {
    $REPO = gh repo view --json nameWithOwner --jq '.nameWithOwner'
    Write-Host "📦 Repository: $REPO" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Could not determine repository. Make sure you're in a Git repository." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Please provide the following values:" -ForegroundColor Yellow
Write-Host ""

# Collect user input
$AWS_ACCOUNT_ID = Read-Host "AWS Account ID (e.g., 716608655181)"
if ([string]::IsNullOrEmpty($AWS_ACCOUNT_ID)) {
    Write-Host "❌ AWS Account ID cannot be empty" -ForegroundColor Red
    exit 1
}

$AWS_REGION = Read-Host "AWS Region (default: us-east-1)"
if ([string]::IsNullOrEmpty($AWS_REGION)) {
    $AWS_REGION = "us-east-1"
}

$AWS_ACCESS_KEY_ID = Read-Host "AWS Access Key ID"
if ([string]::IsNullOrEmpty($AWS_ACCESS_KEY_ID)) {
    Write-Host "❌ AWS Access Key ID cannot be empty" -ForegroundColor Red
    exit 1
}

$secureString = Read-Host "AWS Secret Access Key" -AsSecureString
$AWS_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new("", $secureString).Password
if ([string]::IsNullOrEmpty($AWS_SECRET_ACCESS_KEY)) {
    Write-Host "❌ AWS Secret Access Key cannot be empty" -ForegroundColor Red
    exit 1
}

$ECR_BACKEND_REPO = Read-Host "ECR Backend Repository Name (default: jobgpt-backend)"
if ([string]::IsNullOrEmpty($ECR_BACKEND_REPO)) {
    $ECR_BACKEND_REPO = "jobgpt-backend"
}

$ECR_FRONTEND_REPO = Read-Host "ECR Frontend Repository Name (default: jobgpt-frontend)"
if ([string]::IsNullOrEmpty($ECR_FRONTEND_REPO)) {
    $ECR_FRONTEND_REPO = "jobgpt-frontend"
}

Write-Host ""
Write-Host "📝 Review before setting secrets:" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Yellow
Write-Host "AWS Account ID: $AWS_ACCOUNT_ID"
Write-Host "AWS Region: $AWS_REGION"
Write-Host "AWS Access Key ID: $($AWS_ACCESS_KEY_ID.Substring(0, [Math]::Min(10, $AWS_ACCESS_KEY_ID.Length)))..."
Write-Host "AWS Secret Access Key: ••••••••••"
Write-Host "ECR Backend Repo: $ECR_BACKEND_REPO"
Write-Host "ECR Frontend Repo: $ECR_FRONTEND_REPO"
Write-Host ""

$CONFIRM = Read-Host "Continue setting secrets? (y/n)"
if ($CONFIRM -ne "y" -and $CONFIRM -ne "Y") {
    Write-Host "❌ Cancelled" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🔐 Setting GitHub secrets..." -ForegroundColor Cyan
Write-Host ""

# Set secrets
try {
    gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID" 2>$null
    Write-Host "✅ AWS_ACCOUNT_ID set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AWS_ACCOUNT_ID (may already exist)" -ForegroundColor Yellow
}

try {
    gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID" 2>$null
    Write-Host "✅ AWS_ACCESS_KEY_ID set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AWS_ACCESS_KEY_ID (may already exist)" -ForegroundColor Yellow
}

try {
    gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY" 2>$null
    Write-Host "✅ AWS_SECRET_ACCESS_KEY set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AWS_SECRET_ACCESS_KEY (may already exist)" -ForegroundColor Yellow
}

try {
    gh secret set AWS_REGION --body "$AWS_REGION" 2>$null
    Write-Host "✅ AWS_REGION set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AWS_REGION (may already exist)" -ForegroundColor Yellow
}

try {
    gh secret set ECR_BACKEND_REPO --body "$ECR_BACKEND_REPO" 2>$null
    Write-Host "✅ ECR_BACKEND_REPO set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  ECR_BACKEND_REPO (may already exist)" -ForegroundColor Yellow
}

try {
    gh secret set ECR_FRONTEND_REPO --body "$ECR_FRONTEND_REPO" 2>$null
    Write-Host "✅ ECR_FRONTEND_REPO set" -ForegroundColor Green
} catch {
    Write-Host "⚠️  ECR_FRONTEND_REPO (may already exist)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Secrets setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Create ECR repositories if they don't exist:" -ForegroundColor Cyan
Write-Host "   aws ecr create-repository --repository-name $ECR_BACKEND_REPO --region $AWS_REGION"
Write-Host "   aws ecr create-repository --repository-name $ECR_FRONTEND_REPO --region $AWS_REGION"
Write-Host ""
Write-Host "2. Verify task definitions have executionRoleArn:" -ForegroundColor Cyan
Write-Host "   ✅ backend/backend-task.json"
Write-Host "   ✅ frontend/frontend-task.json"
Write-Host ""
Write-Host "3. Push code to 'dev' branch:" -ForegroundColor Cyan
Write-Host "   git push origin dev"
Write-Host ""
Write-Host "4. Monitor deployment:" -ForegroundColor Cyan
Write-Host "   gh run list --workflow=deploy.yaml"
Write-Host ""
Write-Host "5. View logs:" -ForegroundColor Cyan
Write-Host "   aws logs tail /ecs/jobgpt-backend --follow"
Write-Host "   aws logs tail /ecs/jobgpt-frontend --follow"
Write-Host ""
