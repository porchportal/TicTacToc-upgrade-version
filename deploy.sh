#!/bin/bash

# TicTacToe Full-Stack Application Deployment Script
# This script automates the deployment process for different environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists node; then
        missing_deps+=("Node.js")
    fi
    
    if ! command_exists npm; then
        missing_deps+=("npm")
    fi
    
    if ! command_exists docker; then
        missing_deps+=("Docker")
    fi
    
    if ! command_exists kubectl; then
        missing_deps+=("kubectl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing Node.js dependencies..."
    npm install --omit=dev
    print_success "Dependencies installed successfully"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    if npm test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    docker build -t tictactoe-app:latest .
    print_success "Docker image built successfully"
}

# Function to run with Docker Compose
run_docker_compose() {
    local mode=${1:-production}
    
    if [ "$mode" = "development" ]; then
        print_status "Starting application with Docker Compose (Development mode)..."
        docker compose -f docker-compose.dev.yml up -d
        print_success "Application started with Docker Compose (Development mode)"
        print_status "Hot reload enabled with nodemon"
    else
        print_status "Starting application with Docker Compose (Production mode)..."
        docker compose up -d
        print_success "Application started with Docker Compose (Production mode)"
    fi
    
    print_status "Access the application at: http://localhost:3000"
    print_status "Health check: http://localhost:3000/health"
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    print_status "Deploying to Kubernetes..."
    
    # Check if kubectl is configured
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "kubectl is not configured or cluster is not accessible"
        exit 1
    fi
    
    # Apply namespace
    kubectl apply -f k8s/namespace.yaml
    
    # Apply deployment
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    kubectl rollout status deployment/tictactoe-app -n tictactoe --timeout=300s
    
    print_success "Application deployed to Kubernetes successfully"
    
    # Show deployment status
    print_status "Deployment status:"
    kubectl get pods -n tictactoe
    kubectl get services -n tictactoe
    kubectl get hpa -n tictactoe
}

# Function to run load test
run_load_test() {
    print_status "Running load test..."
    
    if ! command_exists k6; then
        print_warning "k6 is not installed. Skipping load test."
        print_status "To install k6:"
        print_status "  macOS: brew install k6"
        print_status "  Linux: sudo apt-get install k6"
        return
    fi
    
    k6 run load-test.js
    print_success "Load test completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  local       - Run locally with Node.js"
    echo "  docker      - Build and run with Docker"
    echo "  compose     - Run with Docker Compose (Production)"
    echo "  compose-dev - Run with Docker Compose (Development with hot reload)"
    echo "  k8s         - Deploy to Kubernetes"
    echo "  test        - Run tests only"
    echo "  load-test   - Run load tests"
    echo "  all         - Full deployment (test, build, deploy to k8s, load test)"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local"
    echo "  $0 docker"
    echo "  $0 compose"
    echo "  $0 compose-dev"
    echo "  $0 k8s"
    echo "  $0 all"
}

# Main script logic
case "${1:-help}" in
    "local")
        check_prerequisites
        install_dependencies
        run_tests
        print_status "Starting application locally..."
        npm start
        ;;
    "docker")
        check_prerequisites
        install_dependencies
        run_tests
        build_docker_image
        print_status "Starting application with Docker..."
        docker run -p 3000:3000 tictactoe-app:latest
        ;;
    "compose")
        check_prerequisites
        install_dependencies
        run_tests
        build_docker_image
        run_docker_compose "production"
        ;;
    "compose-dev")
        check_prerequisites
        install_dependencies
        run_tests
        build_docker_image
        run_docker_compose "development"
        ;;
    "k8s")
        check_prerequisites
        install_dependencies
        run_tests
        build_docker_image
        deploy_kubernetes
        ;;
    "test")
        check_prerequisites
        install_dependencies
        run_tests
        ;;
    "load-test")
        check_prerequisites
        run_load_test
        ;;
    "all")
        check_prerequisites
        install_dependencies
        run_tests
        build_docker_image
        deploy_kubernetes
        sleep 30  # Wait for deployment to stabilize
        run_load_test
        ;;
    "help"|*)
        show_usage
        ;;
esac
