#!/bin/bash

# Script to handle npm rate limiting issues with retry logic
# This script provides a robust way to run npm commands with exponential backoff

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

# Function to retry npm commands with exponential backoff
retry_npm() {
    local max_attempts=${NPM_MAX_ATTEMPTS:-3}
    local attempt=1
    local delay=${NPM_INITIAL_DELAY:-5}
    
    print_status "Running npm command: $*"
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt of $max_attempts"
        
        if "$@"; then
            print_success "Command succeeded on attempt $attempt"
            return 0
        else
            print_warning "Command failed on attempt $attempt"
            
            if [ $attempt -eq $max_attempts ]; then
                print_error "All attempts failed"
                return 1
            fi
            
            print_status "Waiting $delay seconds before retry..."
            sleep $delay
            attempt=$((attempt + 1))
            delay=$((delay * 2))
        fi
    done
}

# Configure npm for better rate limiting handling
configure_npm() {
    print_status "Configuring npm for better rate limiting handling..."
    
    npm config set fetch-retry-mintimeout 20000
    npm config set fetch-retry-maxtimeout 120000
    npm config set fetch-retries 5
    npm config set registry https://registry.npmjs.org/
    
    print_success "npm configuration updated"
}

# Check if package-lock.json is in sync
check_package_lock() {
    print_status "Checking if package-lock.json is in sync with package.json..."
    
    if retry_npm npm ci --dry-run; then
        print_success "package-lock.json is in sync"
        return 0
    else
        print_warning "package-lock.json is out of sync"
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if check_package_lock; then
        print_status "package-lock.json is in sync, running npm ci..."
        retry_npm npm ci
    else
        print_status "package-lock.json is out of sync, updating..."
        retry_npm npm install
    fi
    
    print_success "Dependencies installed successfully"
}

# Main script logic
case "${1:-help}" in
    "configure")
        configure_npm
        ;;
    "check")
        check_package_lock
        ;;
    "install")
        configure_npm
        install_dependencies
        ;;
    "retry")
        shift
        retry_npm "$@"
        ;;
    "help"|*)
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  configure  - Configure npm for better rate limiting handling"
        echo "  check      - Check if package-lock.json is in sync"
        echo "  install    - Install dependencies with retry logic"
        echo "  retry CMD  - Run a command with retry logic"
        echo "  help       - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  NPM_MAX_ATTEMPTS    - Maximum retry attempts (default: 3)"
        echo "  NPM_INITIAL_DELAY   - Initial delay in seconds (default: 5)"
        echo ""
        echo "Examples:"
        echo "  $0 install"
        echo "  $0 retry npm install -g eslint"
        echo "  NPM_MAX_ATTEMPTS=5 $0 retry npm ci"
        ;;
esac
