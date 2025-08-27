#!/bin/bash

# AWS Deployment Testing Script
# Validates all components before actual deployment

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
AWS_REGION=${AWS_REGION:-"us-east-1"}
ECR_REPOSITORY=${ECR_REPOSITORY:-"tictactoe-app-minimal"}
ECS_CLUSTER=${ECS_CLUSTER:-"tictactoe-cluster-minimal"}
ECS_SERVICE=${ECS_SERVICE:-"tictactoe-service-minimal"}
TASK_DEFINITION=${TASK_DEFINITION:-"tictactoe-app-minimal"}

# Function to test AWS CLI configuration
test_aws_config() {
    print_status "Testing AWS CLI configuration..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "❌ AWS CLI is not configured properly"
        echo "   Run: aws configure"
        return 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    print_success "✅ AWS CLI configured"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User: $USER_ARN"
    
    # Set AWS_ACCOUNT_ID if not already set
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        export AWS_ACCOUNT_ID=$ACCOUNT_ID
        print_status "Set AWS_ACCOUNT_ID to: $AWS_ACCOUNT_ID"
    fi
}

# Function to test AWS permissions
test_aws_permissions() {
    print_status "Testing AWS permissions..."
    
    # Test ECS permissions
    if ! aws ecs list-clusters --region $AWS_REGION >/dev/null 2>&1; then
        print_error "❌ No ECS permissions"
        return 1
    fi
    
    # Test ECR permissions
    if ! aws ecr describe-repositories --region $AWS_REGION >/dev/null 2>&1; then
        print_error "❌ No ECR permissions"
        return 1
    fi
    
    # Test IAM permissions
    if ! aws iam list-roles --query 'Roles[?RoleName==`ecsTaskExecutionRole`]' --output text >/dev/null 2>&1; then
        print_warning "⚠️  ecsTaskExecutionRole not found (will be created during deployment)"
    fi
    
    print_success "✅ AWS permissions verified"
}

# Function to test Docker
test_docker() {
    print_status "Testing Docker..."
    
    if ! docker --version >/dev/null 2>&1; then
        print_error "❌ Docker is not installed or not running"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "❌ Docker daemon is not running"
        return 1
    fi
    
    print_success "✅ Docker is working"
}

# Function to test Docker build
test_docker_build() {
    print_status "Testing Docker build..."
    
    if ! docker build -t tictactoe-test . >/dev/null 2>&1; then
        print_error "❌ Docker build failed"
        echo "   Testing build locally..."
        docker build -t tictactoe-test .
        return 1
    fi
    
    print_success "✅ Docker build successful"
    
    # Clean up test image
    docker rmi tictactoe-test >/dev/null 2>&1 || true
}

# Function to validate configuration files
validate_config_files() {
    print_status "Validating configuration files..."
    
    # Check if files exist
    if [ ! -f "aws/ecs-task-definition-minimal.json" ]; then
        print_error "❌ aws/ecs-task-definition-minimal.json not found"
        return 1
    fi
    
    if [ ! -f "aws/auto-scaling-config-minimal.json" ]; then
        print_error "❌ aws/auto-scaling-config-minimal.json not found"
        return 1
    fi
    
    if [ ! -f "aws/deploy-minimal.sh" ]; then
        print_error "❌ aws/deploy-minimal.sh not found"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty aws/ecs-task-definition-minimal.json 2>/dev/null; then
        print_error "❌ Invalid JSON in aws/ecs-task-definition-minimal.json"
        return 1
    fi
    
    if ! jq empty aws/auto-scaling-config-minimal.json 2>/dev/null; then
        print_error "❌ Invalid JSON in aws/auto-scaling-config-minimal.json"
        return 1
    fi
    
    print_success "✅ Configuration files validated"
}

# Function to test ECR connectivity
test_ecr_connectivity() {
    print_status "Testing ECR connectivity..."
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "❌ AWS_ACCOUNT_ID not set"
        return 1
    fi
    
    # Test ECR login
    if ! aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com >/dev/null 2>&1; then
        print_error "❌ ECR login failed"
        return 1
    fi
    
    print_success "✅ ECR connectivity verified"
}

# Function to check existing resources
check_existing_resources() {
    print_status "Checking existing AWS resources..."
    
    # Check ECR repository
    if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION >/dev/null 2>&1; then
        print_warning "⚠️  ECR repository '$ECR_REPOSITORY' already exists"
    else
        print_success "✅ ECR repository '$ECR_REPOSITORY' will be created"
    fi
    
    # Check ECS cluster
    if aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION >/dev/null 2>&1; then
        print_warning "⚠️  ECS cluster '$ECS_CLUSTER' already exists"
    else
        print_success "✅ ECS cluster '$ECS_CLUSTER' will be created"
    fi
    
    # Check ECS service
    if aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --region $AWS_REGION >/dev/null 2>&1; then
        print_warning "⚠️  ECS service '$ECS_SERVICE' already exists"
    else
        print_success "✅ ECS service '$ECS_SERVICE' will be created"
    fi
}

# Function to simulate deployment
simulate_deployment() {
    print_status "Simulating deployment process..."
    
    echo "   📋 Deployment steps that will be executed:"
    echo "   1. Create ECR repository: $ECR_REPOSITORY"
    echo "   2. Build and push Docker image"
    echo "   3. Create ECS cluster: $ECS_CLUSTER"
    echo "   4. Register task definition: $TASK_DEFINITION"
    echo "   5. Create ECS service: $ECS_SERVICE"
    echo "   6. Deploy with minimal resources (128 vCPU, 256 MB RAM)"
    echo "   7. Configure auto-scaling (1-3 instances)"
    
    print_success "✅ Deployment simulation completed"
}

# Function to show cost estimate
show_cost_estimate() {
    print_status "Cost estimation..."
    
    echo "   💰 Estimated monthly costs:"
    echo "   • ECS Fargate (1 instance): ~$15-20 USD"
    echo "   • ECR Storage: ~$0.10 USD"
    echo "   • CloudWatch Logs: ~$1-5 USD"
    echo "   • Total: ~$15-25 USD/month"
    echo ""
    echo "   💡 Cost-saving tips:"
    echo "   • Scale to 0 instances when not in use"
    echo "   • Use cleanup command to remove all resources"
    echo "   • Monitor costs with AWS Cost Explorer"
}

# Function to run all tests
run_all_tests() {
    echo "🔍 AWS Deployment Validation Test"
    echo "=================================="
    echo ""
    
    local all_passed=true
    
    # Run all tests
    test_aws_config || all_passed=false
    echo ""
    
    test_aws_permissions || all_passed=false
    echo ""
    
    test_docker || all_passed=false
    echo ""
    
    test_docker_build || all_passed=false
    echo ""
    
    validate_config_files || all_passed=false
    echo ""
    
    test_ecr_connectivity || all_passed=false
    echo ""
    
    check_existing_resources
    echo ""
    
    simulate_deployment
    echo ""
    
    show_cost_estimate
    echo ""
    
    if [ "$all_passed" = true ]; then
        print_success "🎉 All tests passed! Ready for deployment."
        echo ""
        echo "🚀 To deploy, run:"
        echo "   export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID"
        echo "   ./aws/deploy-minimal.sh deploy"
        echo ""
        echo "🧹 To cleanup later:"
        echo "   ./aws/deploy-minimal.sh cleanup"
    else
        print_error "❌ Some tests failed. Please fix the issues above before deploying."
        return 1
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 {test|validate|simulate}"
    echo ""
    echo "Commands:"
    echo "  test      - Run all validation tests"
    echo "  validate  - Validate configuration files only"
    echo "  simulate  - Simulate deployment process"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCOUNT_ID     - AWS account ID (optional, will be auto-detected)"
    echo "  AWS_REGION         - AWS region (default: us-east-1)"
    echo ""
    echo "Example:"
    echo "  $0 test"
}

# Main script logic
case "$1" in
    test)
        run_all_tests
        ;;
    validate)
        validate_config_files
        test_aws_config
        test_aws_permissions
        ;;
    simulate)
        simulate_deployment
        show_cost_estimate
        ;;
    *)
        usage
        exit 1
        ;;
esac
