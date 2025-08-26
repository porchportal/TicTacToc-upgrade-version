#!/bin/bash

# Script to check if package-lock.json is in sync with package.json
# This helps prevent npm ci failures in CI/CD pipelines

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

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    print_error "package.json not found. Please run this script from the project root."
    exit 1
fi

print_status "Checking if package-lock.json is in sync with package.json..."

# Try a dry run of npm ci to check for sync issues
if npm ci --dry-run >/dev/null 2>&1; then
    print_success "package-lock.json is in sync with package.json"
    exit 0
else
    print_warning "package-lock.json is out of sync with package.json"
    print_status "This will cause npm ci to fail in CI/CD pipelines"
    
    if [ "$1" = "--fix" ]; then
        print_status "Fixing package-lock.json..."
        npm install
        print_success "package-lock.json has been updated"
    else
        print_status "To fix this issue, run: $0 --fix"
        exit 1
    fi
fi
