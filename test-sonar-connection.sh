#!/bin/bash
# Test SonarQube connection and token

echo "🔍 Testing SonarQube Connection..."

# Check if server is running
echo "1. Checking SonarQube server..."
if curl -s http://localhost:9000/api/system/status > /dev/null 2>&1; then
    echo "   ✅ Server is running"
    curl -s http://localhost:9000/api/system/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost:9000/api/system/status
else
    echo "   ❌ Server is not running!"
    echo "   Start with: docker start sonarqube"
    exit 1
fi

# Check token
echo ""
echo "2. Checking token..."
if [ -z "$SONAR_TOKEN" ]; then
    echo "   ❌ SONAR_TOKEN is not set"
    echo "   Get token from: http://localhost:9000 → My Account → Security"
    echo "   Then run: export SONAR_TOKEN=your_token"
    exit 1
else
    echo "   ✅ Token is set (length: ${#SONAR_TOKEN} characters)"
    
    # Test token validity
    echo "   Testing token validity..."
    response=$(curl -s -u "${SONAR_TOKEN}:" http://localhost:9000/api/authentication/validate)
    if echo "$response" | grep -q '"valid":true'; then
        echo "   ✅ Token is valid"
    else
        echo "   ❌ Token is invalid or expired"
        echo "   Response: $response"
        exit 1
    fi
fi

# Check required files
echo ""
echo "3. Checking required files..."
if [ -f "coverage/lcov.info" ]; then
    echo "   ✅ Coverage report exists"
else
    echo "   ⚠️  Coverage report missing (will generate if needed)"
fi

if [ -f "sonar-project.properties" ]; then
    echo "   ✅ sonar-project.properties exists"
else
    echo "   ❌ sonar-project.properties missing!"
    exit 1
fi

echo ""
echo "✅ All checks passed! Ready to run scanner."
