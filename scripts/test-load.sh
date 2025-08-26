#!/bin/bash

# Load Test Script for TicTacToe Application
# This script runs load tests against the application

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

# Configuration
TARGET_URL=${TARGET_URL:-"http://localhost:3000"}
LOAD_TEST_FILE=${LOAD_TEST_FILE:-"load-test.js"}
DURATION=${DURATION:-"1m"}
USERS=${USERS:-"10"}

# Function to check if k6 is installed
check_k6() {
    print_status "Checking k6 installation..."
    
    if ! command -v k6 >/dev/null 2>&1; then
        print_warning "k6 is not installed. Installing k6..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            brew install k6
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            curl -L https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz | tar xz
            sudo cp k6-v0.47.0-linux-amd64/k6 /usr/local/bin/
        else
            print_error "Unsupported operating system: $OSTYPE"
            exit 1
        fi
    fi
    
    print_success "k6 is available"
}

# Function to check if target is accessible
check_target() {
    print_status "Checking target availability: $TARGET_URL"
    
    if ! curl -s "$TARGET_URL/health" >/dev/null 2>&1; then
        print_error "Target is not accessible. Please ensure the application is running."
        print_status "You can start the application with: npm start"
        exit 1
    fi
    
    print_success "Target is accessible"
}

# Function to run load test
run_load_test() {
    print_status "Running load test..."
    print_status "Target: $TARGET_URL"
    print_status "Duration: $DURATION"
    print_status "Users: $USERS"
    
    # Set environment variable for k6
    export TARGET_URL="$TARGET_URL"
    
    # Run k6 load test
    k6 run \
        --out json=results.json \
        --out influxdb=http://localhost:8086/k6 \
        --duration "$DURATION" \
        --vus "$USERS" \
        "$LOAD_TEST_FILE"
    
    print_success "Load test completed"
}

# Function to show results
show_results() {
    print_status "Load test results:"
    
    if [ -f results.json ]; then
        print_status "Results saved to results.json"
        
        # Extract key metrics
        TOTAL_REQUESTS=$(jq -r '.metrics.http_reqs.total' results.json 2>/dev/null || echo "N/A")
        FAILED_REQUESTS=$(jq -r '.metrics.http_req_failed.total' results.json 2>/dev/null || echo "N/A")
        AVG_RESPONSE_TIME=$(jq -r '.metrics.http_req_duration.avg' results.json 2>/dev/null || echo "N/A")
        
        echo "Total Requests: $TOTAL_REQUESTS"
        echo "Failed Requests: $FAILED_REQUESTS"
        echo "Average Response Time: $AVG_RESPONSE_TIME ms"
    else
        print_warning "No results file found"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --url URL           - Target URL (default: http://localhost:3000)"
    echo "  --duration DURATION - Test duration (default: 1m)"
    echo "  --users USERS       - Number of virtual users (default: 10)"
    echo "  --file FILE         - Load test file (default: load-test.js)"
    echo "  --help              - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  TARGET_URL          - Target URL"
    echo "  DURATION            - Test duration"
    echo "  USERS               - Number of virtual users"
    echo "  LOAD_TEST_FILE      - Load test file"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --url http://localhost:3000 --duration 2m --users 20"
    echo "  TARGET_URL=http://localhost:3000 DURATION=30s USERS=5 $0"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            TARGET_URL="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --users)
            USERS="$2"
            shift 2
            ;;
        --file)
            LOAD_TEST_FILE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main script logic
main() {
    print_status "Starting load test..."
    
    check_k6
    check_target
    run_load_test
    show_results
    
    print_success "Load test process completed!"
}

# Run main function
main
