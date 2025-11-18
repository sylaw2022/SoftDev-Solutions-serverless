#!/bin/bash

# Script to create GitHub repository using GitHub API
# Requires GitHub Personal Access Token with repo scope

REPO_NAME="SoftDev-Solutions-serverless"
GITHUB_USERNAME="sylaw2022"
GITHUB_TOKEN=""  # You'll need to provide this

echo "=========================================="
echo "Creating GitHub Repository"
echo "=========================================="
echo ""
echo "Repository: $GITHUB_USERNAME/$REPO_NAME"
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GitHub Personal Access Token required"
    echo ""
    echo "To create a token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Select 'repo' scope"
    echo "4. Copy the token"
    echo "5. Run: export GITHUB_TOKEN='your-token-here'"
    echo "6. Then run this script again"
    echo ""
    exit 1
fi

# Create repository using GitHub API
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user/repos \
  -d "{
    \"name\": \"$REPO_NAME\",
    \"description\": \"Serverless Next.js application with PostgreSQL database\",
    \"private\": false,
    \"auto_init\": false
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Repository created successfully!"
    echo ""
    echo "Repository URL: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    echo ""
    echo "Now you can push your code:"
    echo "  git push -u origin main"
    exit 0
elif [ "$HTTP_CODE" -eq 422 ]; then
    echo "⚠️  Repository might already exist (HTTP 422)"
    echo "Trying to push anyway..."
    echo ""
    git push -u origin main 2>&1
    exit 0
else
    echo "❌ Failed to create repository"
    echo "HTTP Code: $HTTP_CODE"
    echo "Response: $BODY"
    echo ""
    echo "You can create it manually at: https://github.com/new"
    exit 1
fi

