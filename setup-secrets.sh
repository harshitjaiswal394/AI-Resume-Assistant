#!/bin/bash

# GitHub Secrets Setup Script
# This script sets up all required GitHub secrets for automated ECS deployment

set -e

echo "🔐 GitHub Secrets Setup for AI-Resume-Assistant"
echo "================================================"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Please install it:"
    echo "   macOS: brew install gh"
    echo "   Linux: sudo apt install gh"
    echo "   Windows: choco install gh"
    exit 1
fi

# Verify authenticated with GitHub
echo "Checking GitHub authentication..."
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Please run:"
    echo "   gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"
echo ""

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

if [ -z "$REPO" ]; then
    echo "❌ Could not determine repository. Make sure you're in a Git repository."
    exit 1
fi

echo "📦 Repository: $REPO"
echo ""

# Collect user input
echo "Please provide the following values:"
echo ""

read -p "AWS Account ID (e.g., 716608655181): " AWS_ACCOUNT_ID
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ AWS Account ID cannot be empty"
    exit 1
fi

read -p "AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "❌ AWS Access Key ID cannot be empty"
    exit 1
fi

read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ AWS Secret Access Key cannot be empty"
    exit 1
fi

read -p "ECR Backend Repository Name (default: jobgpt-backend): " ECR_BACKEND_REPO
ECR_BACKEND_REPO=${ECR_BACKEND_REPO:-jobgpt-backend}

read -p "ECR Frontend Repository Name (default: jobgpt-frontend): " ECR_FRONTEND_REPO
ECR_FRONTEND_REPO=${ECR_FRONTEND_REPO:-jobgpt-frontend}

echo ""
echo "📝 Review before setting secrets:"
echo "=================================="
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "AWS Access Key ID: ${AWS_ACCESS_KEY_ID:0:10}..."
echo "AWS Secret Access Key: ${AWS_SECRET_ACCESS_KEY:0:10}..."
echo "ECR Backend Repo: $ECR_BACKEND_REPO"
echo "ECR Frontend Repo: $ECR_FRONTEND_REPO"
echo ""

read -p "Continue setting secrets? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "❌ Cancelled"
    exit 0
fi

echo ""
echo "🔐 Setting GitHub secrets..."
echo ""

# Set secrets
gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID" 2>/dev/null && echo "✅ AWS_ACCOUNT_ID set" || echo "⚠️  AWS_ACCOUNT_ID (may already exist)"
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID" 2>/dev/null && echo "✅ AWS_ACCESS_KEY_ID set" || echo "⚠️  AWS_ACCESS_KEY_ID (may already exist)"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY" 2>/dev/null && echo "✅ AWS_SECRET_ACCESS_KEY set" || echo "⚠️  AWS_SECRET_ACCESS_KEY (may already exist)"
gh secret set AWS_REGION --body "$AWS_REGION" 2>/dev/null && echo "✅ AWS_REGION set" || echo "⚠️  AWS_REGION (may already exist)"
gh secret set ECR_BACKEND_REPO --body "$ECR_BACKEND_REPO" 2>/dev/null && echo "✅ ECR_BACKEND_REPO set" || echo "⚠️  ECR_BACKEND_REPO (may already exist)"
gh secret set ECR_FRONTEND_REPO --body "$ECR_FRONTEND_REPO" 2>/dev/null && echo "✅ ECR_FRONTEND_REPO set" || echo "⚠️  ECR_FRONTEND_REPO (may already exist)"

echo ""
echo "✅ Secrets setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Create ECR repositories if they don't exist:"
echo "   aws ecr create-repository --repository-name $ECR_BACKEND_REPO --region $AWS_REGION"
echo "   aws ecr create-repository --repository-name $ECR_FRONTEND_REPO --region $AWS_REGION"
echo ""
echo "2. Verify task definitions have executionRoleArn:"
echo "   ✅ backend/backend-task.json"
echo "   ✅ frontend/frontend-task.json"
echo ""
echo "3. Push code to 'dev' branch:"
echo "   git push origin dev"
echo ""
echo "4. Monitor deployment:"
echo "   gh run list --workflow=deploy.yaml"
echo ""
echo "5. View logs:"
echo "   aws logs tail /ecs/jobgpt-backend --follow"
echo "   aws logs tail /ecs/jobgpt-frontend --follow"
echo ""
