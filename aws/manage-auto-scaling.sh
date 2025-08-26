#!/bin/bash

# AWS Auto Scaling Management Script for TicTacToe Application
# This script helps manage auto-scaling policies and configurations

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
ECS_CLUSTER=${ECS_CLUSTER:-"tictactoe-cluster"}
ECS_SERVICE=${ECS_SERVICE:-"tictactoe-service"}
RESOURCE_ID="service/$ECS_CLUSTER/$ECS_SERVICE"

# Function to check AWS CLI configuration
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to show current auto-scaling status
show_status() {
    print_status "Current auto-scaling status:"
    
    # Show current capacity
    aws ecs describe-services \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $AWS_REGION \
        --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}' \
        --output table
    
    # Show auto-scaling target
    aws application-autoscaling describe-scalable-targets \
        --service-namespace ecs \
        --resource-ids $RESOURCE_ID \
        --region $AWS_REGION \
        --query 'ScalableTargets[0].{MinCapacity:MinCapacity,MaxCapacity:MaxCapacity,CurrentCapacity:CurrentCapacity}' \
        --output table
    
    # Show auto-scaling policies
    print_status "Auto-scaling policies:"
    aws application-autoscaling describe-scaling-policies \
        --service-namespace ecs \
        --resource-id $RESOURCE_ID \
        --region $AWS_REGION \
        --query 'ScalingPolicies[].{PolicyName:PolicyName,PolicyType:PolicyType,TargetValue:TargetTrackingScalingPolicyConfiguration.TargetValue}' \
        --output table
}

# Function to update auto-scaling capacity
update_capacity() {
    local min_capacity=$1
    local max_capacity=$2
    
    print_status "Updating auto-scaling capacity to min: $min_capacity, max: $max_capacity"
    
    aws application-autoscaling register-scalable-target \
        --service-namespace ecs \
        --resource-id $RESOURCE_ID \
        --scalable-dimension ecs:service:DesiredCount \
        --min-capacity $min_capacity \
        --max-capacity $max_capacity \
        --region $AWS_REGION
    
    print_success "Auto-scaling capacity updated"
}

# Function to update CPU target
update_cpu_target() {
    local target_value=$1
    
    print_status "Updating CPU target to $target_value%"
    
    aws application-autoscaling put-scaling-policy \
        --service-namespace ecs \
        --resource-id $RESOURCE_ID \
        --scalable-dimension ecs:service:DesiredCount \
        --policy-name tictactoe-cpu-autoscaling \
        --policy-type TargetTrackingScaling \
        --target-tracking-scaling-policy-configuration "PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageCPUUtilization},TargetValue=$target_value,ScaleInCooldown=300,ScaleOutCooldown=300" \
        --region $AWS_REGION
    
    print_success "CPU target updated"
}

# Function to update memory target
update_memory_target() {
    local target_value=$1
    
    print_status "Updating memory target to $target_value%"
    
    aws application-autoscaling put-scaling-policy \
        --service-namespace ecs \
        --resource-id $RESOURCE_ID \
        --scalable-dimension ecs:service:DesiredCount \
        --policy-name tictactoe-memory-autoscaling \
        --policy-type TargetTrackingScaling \
        --target-tracking-scaling-policy-configuration "PredefinedMetricSpecification={PredefinedMetricType=ECSServiceAverageMemoryUtilization},TargetValue=$target_value,ScaleInCooldown=300,ScaleOutCooldown=300" \
        --region $AWS_REGION
    
    print_success "Memory target updated"
}

# Function to enable/disable scheduled scaling
toggle_scheduled_scaling() {
    local enabled=$1
    
    if [ "$enabled" = "true" ]; then
        print_status "Enabling scheduled auto-scaling..."
        
        # Scale up at 8 AM
        aws application-autoscaling put-scheduled-action \
            --service-namespace ecs \
            --resource-id $RESOURCE_ID \
            --scalable-dimension ecs:service:DesiredCount \
            --scheduled-action-name tictactoe-scale-up \
            --schedule "cron(0 8 * * ? *)" \
            --scalable-target-action MinCapacity=2,MaxCapacity=8 \
            --region $AWS_REGION
        
        # Scale down at 10 PM
        aws application-autoscaling put-scheduled-action \
            --service-namespace ecs \
            --resource-id $RESOURCE_ID \
            --scalable-dimension ecs:service:DesiredCount \
            --scheduled-action-name tictactoe-scale-down \
            --schedule "cron(0 22 * * ? *)" \
            --scalable-target-action MinCapacity=1,MaxCapacity=3 \
            --region $AWS_REGION
        
        print_success "Scheduled auto-scaling enabled"
    else
        print_status "Disabling scheduled auto-scaling..."
        
        aws application-autoscaling delete-scheduled-action \
            --service-namespace ecs \
            --resource-id $RESOURCE_ID \
            --scalable-dimension ecs:service:DesiredCount \
            --scheduled-action-name tictactoe-scale-up \
            --region $AWS_REGION
        
        aws application-autoscaling delete-scheduled-action \
            --service-namespace ecs \
            --resource-id $RESOURCE_ID \
            --scalable-dimension ecs:service:DesiredCount \
            --scheduled-action-name tictactoe-scale-down \
            --region $AWS_REGION
        
        print_success "Scheduled auto-scaling disabled"
    fi
}

# Function to show CloudWatch alarms
show_alarms() {
    print_status "CloudWatch alarms:"
    
    aws cloudwatch describe-alarms \
        --alarm-names tictactoe-cpu-high tictactoe-memory-high \
        --region $AWS_REGION \
        --query 'MetricAlarms[].{AlarmName:AlarmName,State:StateValue,Threshold:Threshold,MetricName:MetricName}' \
        --output table
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status                    - Show current auto-scaling status"
    echo "  update-capacity MIN MAX   - Update min and max capacity"
    echo "  update-cpu-target VALUE   - Update CPU target percentage"
    echo "  update-memory-target VALUE - Update memory target percentage"
    echo "  enable-scheduled          - Enable scheduled auto-scaling"
    echo "  disable-scheduled         - Disable scheduled auto-scaling"
    echo "  alarms                    - Show CloudWatch alarms"
    echo "  help                      - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  AWS_REGION     - AWS region (default: us-east-1)"
    echo "  ECS_CLUSTER    - ECS cluster name (default: tictactoe-cluster)"
    echo "  ECS_SERVICE    - ECS service name (default: tictactoe-service)"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 update-capacity 2 8"
    echo "  $0 update-cpu-target 60"
    echo "  $0 enable-scheduled"
}

# Main script logic
case "${1:-help}" in
    "status")
        check_aws_config
        show_status
        show_alarms
        ;;
    "update-capacity")
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_error "Usage: $0 update-capacity MIN MAX"
            exit 1
        fi
        check_aws_config
        update_capacity $2 $3
        ;;
    "update-cpu-target")
        if [ -z "$2" ]; then
            print_error "Usage: $0 update-cpu-target VALUE"
            exit 1
        fi
        check_aws_config
        update_cpu_target $2
        ;;
    "update-memory-target")
        if [ -z "$2" ]; then
            print_error "Usage: $0 update-memory-target VALUE"
            exit 1
        fi
        check_aws_config
        update_memory_target $2
        ;;
    "enable-scheduled")
        check_aws_config
        toggle_scheduled_scaling true
        ;;
    "disable-scheduled")
        check_aws_config
        toggle_scheduled_scaling false
        ;;
    "alarms")
        check_aws_config
        show_alarms
        ;;
    "help"|*)
        show_usage
        ;;
esac
