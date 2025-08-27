#!/bin/bash

# Local Validation Script
# Tests the application locally before AWS deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to test Node.js application
test_node_app() {
    print_status "Testing Node.js application..."
    
    # Check if Node.js is installed
    if ! node --version >/dev/null 2>&1; then
        print_error "❌ Node.js is not installed"
        return 1
    fi
    
    # Check if npm is installed
    if ! npm --version >/dev/null 2>&1; then
        print_error "❌ npm is not installed"
        return 1
    fi
    
    print_success "✅ Node.js and npm are installed"
    echo "   Node.js version: $(node --version)"
    echo "   npm version: $(npm --version)"
}

# Function to test dependencies
test_dependencies() {
    print_status "Testing dependencies..."
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_error "❌ package.json not found"
        return 1
    fi
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        print_warning "⚠️  node_modules not found, installing dependencies..."
        npm install
    fi
    
    print_success "✅ Dependencies are ready"
}

# Function to test application startup
test_app_startup() {
    print_status "Testing application startup..."
    
    # Start the application in background
    print_status "Starting application..."
    node server.js &
    APP_PID=$!
    
    # Wait for application to start
    sleep 5
    
    # Test health endpoint
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        print_success "✅ Application started successfully"
        echo "   Health endpoint: http://localhost:3000/health"
        echo "   Main application: http://localhost:3000"
    else
        print_error "❌ Application failed to start"
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
    
    # Stop the application
    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
}

# Function to test API endpoints
test_api_endpoints() {
    print_status "Testing API endpoints..."
    
    # Start the application
    node server.js &
    APP_PID=$!
    sleep 5
    
    local all_passed=true
    
    # Test health endpoint
    if curl -f http://localhost:3000/health >/dev/null 2>&1; then
        print_success "✅ Health endpoint: /health"
    else
        print_error "❌ Health endpoint failed"
        all_passed=false
    fi
    
    # Test main application
    if curl -f http://localhost:3000/ >/dev/null 2>&1; then
        print_success "✅ Main application: /"
    else
        print_error "❌ Main application failed"
        all_passed=false
    fi
    
    # Test API endpoints
    if curl -f http://localhost:3000/api/stats >/dev/null 2>&1; then
        print_success "✅ API endpoint: /api/stats"
    else
        print_error "❌ API endpoint /api/stats failed"
        all_passed=false
    fi
    
    # Test game creation
    GAME_RESPONSE=$(curl -s -X POST http://localhost:3000/api/games)
    if echo "$GAME_RESPONSE" | grep -q "id"; then
        print_success "✅ Game creation: POST /api/games"
        GAME_ID=$(echo "$GAME_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo "   Created game ID: $GAME_ID"
    else
        print_error "❌ Game creation failed"
        all_passed=false
    fi
    
    # Stop the application
    kill $APP_PID 2>/dev/null || true
    wait $APP_PID 2>/dev/null || true
    
    if [ "$all_passed" = true ]; then
        print_success "✅ All API endpoints working"
    else
        print_error "❌ Some API endpoints failed"
        return 1
    fi
}

# Function to test Docker build
test_docker_build() {
    print_status "Testing Docker build..."
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "❌ Dockerfile not found"
        return 1
    fi
    
    # Build Docker image
    if docker build -t tictactoe-local-test . >/dev/null 2>&1; then
        print_success "✅ Docker build successful"
        
        # Test Docker container
        print_status "Testing Docker container..."
        docker run -d -p 3001:3000 --name tictactoe-test tictactoe-local-test >/dev/null 2>&1
        
        # Wait for container to start
        sleep 10
        
        # Test health endpoint
        if curl -f http://localhost:3001/health >/dev/null 2>&1; then
            print_success "✅ Docker container working"
        else
            print_error "❌ Docker container failed"
            docker stop tictactoe-test >/dev/null 2>&1 || true
            docker rm tictactoe-test >/dev/null 2>&1 || true
            return 1
        fi
        
        # Clean up
        docker stop tictactoe-test >/dev/null 2>&1 || true
        docker rm tictactoe-test >/dev/null 2>&1 || true
        docker rmi tictactoe-local-test >/dev/null 2>&1 || true
    else
        print_error "❌ Docker build failed"
        return 1
    fi
}

# Function to test database
test_database() {
    print_status "Testing database..."
    
    # Check if database file exists
    if [ -f "data/tictactoe.db" ]; then
        print_success "✅ Database file exists"
    else
        print_warning "⚠️  Database file will be created on first run"
    fi
    
    # Test database initialization
    node -e "
    const sqlite3 = require('sqlite3').verbose();
    const db = new sqlite3.Database('data/tictactoe.db');
    db.run('CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY)', (err) => {
        if (err) {
            console.error('Database test failed:', err.message);
            process.exit(1);
        } else {
            console.log('Database test passed');
            db.close();
        }
    });
    " >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "✅ Database operations working"
    else
        print_error "❌ Database operations failed"
        return 1
    fi
}

# Function to run all local tests
run_all_local_tests() {
    echo "🔍 Local Application Validation Test"
    echo "===================================="
    echo ""
    
    local all_passed=true
    
    # Run all tests
    test_node_app || all_passed=false
    echo ""
    
    test_dependencies || all_passed=false
    echo ""
    
    test_database || all_passed=false
    echo ""
    
    test_app_startup || all_passed=false
    echo ""
    
    test_api_endpoints || all_passed=false
    echo ""
    
    test_docker_build || all_passed=false
    echo ""
    
    if [ "$all_passed" = true ]; then
        print_success "🎉 All local tests passed! Application is ready for AWS deployment."
        echo ""
        echo "🚀 Next steps:"
        echo "   1. Run AWS validation: ./aws/test-deployment.sh test"
        echo "   2. Deploy to AWS: ./aws/deploy-minimal.sh deploy"
        echo ""
        echo "📋 Application features verified:"
        echo "   ✅ Node.js application startup"
        echo "   ✅ API endpoints functionality"
        echo "   ✅ Database operations"
        echo "   ✅ Docker containerization"
        echo "   ✅ Health checks"
    else
        print_error "❌ Some local tests failed. Please fix the issues above before AWS deployment."
        return 1
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 {test|api|docker|db}"
    echo ""
    echo "Commands:"
    echo "  test      - Run all local validation tests"
    echo "  api       - Test API endpoints only"
    echo "  docker    - Test Docker build only"
    echo "  db        - Test database only"
    echo ""
    echo "Example:"
    echo "  $0 test"
}

# Main script logic
case "$1" in
    test)
        run_all_local_tests
        ;;
    api)
        test_node_app
        test_dependencies
        test_api_endpoints
        ;;
    docker)
        test_docker_build
        ;;
    db)
        test_database
        ;;
    *)
        usage
        exit 1
        ;;
esac
