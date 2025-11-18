#!/bin/bash

# Script to set up GitHub repository for SoftDev-Solutions-serverless
# Run this after creating the repository on GitHub

REPO_NAME="SoftDev-Solutions-serverless"
GITHUB_USERNAME=""  # Replace with your GitHub username

echo "=========================================="
echo "GitHub Repository Setup"
echo "=========================================="
echo ""
echo "Step 1: Create the repository on GitHub"
echo "----------------------------------------"
echo "1. Go to https://github.com/new"
echo "2. Repository name: $REPO_NAME"
echo "3. Description: Serverless Next.js application with PostgreSQL"
echo "4. Visibility: Choose Public or Private"
echo "5. DO NOT initialize with README, .gitignore, or license"
echo "6. Click 'Create repository'"
echo ""
echo "Step 2: After creating the repository, run:"
echo "----------------------------------------"
echo ""
echo "  cd /home/sylaw/SoftDev-Solutions_serverless"
echo "  git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "Or if you prefer SSH:"
echo "  git remote add origin git@github.com:YOUR_USERNAME/$REPO_NAME.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "=========================================="

