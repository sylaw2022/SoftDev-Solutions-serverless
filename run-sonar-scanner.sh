#!/bin/bash
# Quick script to run SonarQube scanner locally

set -e

echo "🔍 Running SonarQube Scanner..."

# Check if SonarQube server is running
if ! curl -s http://localhost:9000/api/system/status > /dev/null 2>&1; then
    echo "❌ Error: SonarQube server is not running!"
    echo "   Start it with: docker start sonarqube"
    exit 1
fi

# Check if token is set
if [ -z "$SONAR_TOKEN" ]; then
    echo "⚠️  Warning: SONAR_TOKEN environment variable is not set"
    echo "   Get your token from: http://localhost:9000 → My Account → Security"
    echo "   Then run: export SONAR_TOKEN=your_token_here"
    echo ""
    read -p "   Enter your SonarQube token (or press Ctrl+C to exit): " token
    if [ -z "$token" ]; then
        echo "❌ Error: Token cannot be empty!"
        exit 1
    fi
    export SONAR_TOKEN="$token"
fi

# Validate token format (should start with sqa_ or sqp_)
if [[ ! "$SONAR_TOKEN" =~ ^sq[ap]_ ]]; then
    echo "⚠️  Warning: Token format looks incorrect (should start with sqa_ or sqp_)"
    echo "   Please verify your token is correct"
fi

# Generate coverage if it doesn't exist
if [ ! -f "coverage/lcov.info" ]; then
    echo "📊 Generating coverage report..."
    npm run test:coverage
fi

# Run SonarQube scanner
echo "🚀 Starting analysis..."
npx --yes sonarqube-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token="${SONAR_TOKEN}"

echo "✅ Analysis complete! View results at: http://localhost:9000"
