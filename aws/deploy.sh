#!/bin/bash

# AWS ECS Deployment Script for TicTacToe Application
# This script deploys the application to AWS ECS Fargate

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
ECR_REPOSITORY=${ECR_REPOSITORY:-"tictactoe-app"}
ECS_CLUSTER=${ECS_CLUSTER:-"tictactoe-cluster"}
ECS_SERVICE=${ECS_SERVICE:-"tictactoe-service"}
TASK_DEFINITION=${TASK_DEFINITION:-"tictactoe-app"}

# Function to check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to build and push Docker image to ECR
build_and_push_image() {
    print_status "Building and pushing Docker image to ECR..."
    
    # Get ECR login token
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
    
    # Build Docker image
    docker build -t $ECR_REPOSITORY .
    
    # Tag image for ECR
    docker tag $ECR_REPOSITORY:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    
    # Push to ECR
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest
    
    print_success "Docker image pushed to ECR"
}

# Function to update ECS task definition
update_task_definition() {
    print_status "Updating ECS task definition..."
    
    # Register new task definition
    aws ecs register-task-definition \
        --cli-input-json file://aws/ecs-task-definition.json \
        --region $AWS_REGION
    
    print_success "Task definition updated"
}

# Function to update ECS service
update_service() {
    print_status "Updating ECS service..."
    
    # Get latest task definition revision
    TASK_DEFINITION_REVISION=$(aws ecs describe-task-definition \
        --task-definition $TASK_DEFINITION \
        --region $AWS_REGION \
        --query 'taskDefinition.revision' \
        --output text)
    
    # Update service
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --task-definition $TASK_DEFINITION:$TASK_DEFINITION_REVISION \
        --region $AWS_REGION
    
    print_success "Service updated"
}

# Function to wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to complete..."
    
    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $AWS_REGION
    
    print_success "Deployment completed successfully"
}

# Function to show service status
show_status() {
    print_status "Service status:"
    aws ecs describe-services \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $AWS_REGION \
        --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,Events:events[0:3].message}' \
        --output table
}

# Main deployment function
deploy() {
    print_status "Starting AWS ECS deployment..."
    
    check_aws_config
    build_and_push_image
    update_task_definition
    update_service
    wait_for_deployment
    show_status
    
    print_success "Deployment completed successfully!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  deploy      - Deploy to AWS ECS"
    echo "  status      - Show service status"
    echo "  help        - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  AWS_REGION         - AWS region (default: us-east-1)"
    echo "  AWS_ACCOUNT_ID     - AWS account ID (required)"
    echo "  ECR_REPOSITORY     - ECR repository name (default: tictactoe-app)"
    echo "  ECS_CLUSTER        - ECS cluster name (default: tictactoe-cluster)"
    echo "  ECS_SERVICE        - ECS service name (default: tictactoe-service)"
    echo ""
    echo "Examples:"
    echo "  AWS_ACCOUNT_ID=123456789012 $0 deploy"
    echo "  AWS_REGION=us-west-2 $0 status"
}

# Main script logic
case "${1:-help}" in
    "deploy")
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            print_error "AWS_ACCOUNT_ID environment variable is required"
            exit 1
        fi
        deploy
        ;;
    "status")
        show_status
        ;;
    "help"|*)
        show_usage
        ;;
esac
