variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "tictactoe"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory for ECS task (MiB)"
  type        = number
  default     = 512
}

# Auto Scaling Variables
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 70
}

variable "request_count_target" {
  description = "Target request count per target for auto scaling"
  type        = number
  default     = 1000
}

variable "scale_in_cooldown" {
  description = "Cooldown period for scale in (seconds)"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period for scale out (seconds)"
  type        = number
  default     = 300
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled auto scaling"
  type        = bool
  default     = false
}

variable "scheduled_scale_up_min" {
  description = "Minimum capacity during scheduled scale up"
  type        = number
  default     = 2
}

variable "scheduled_scale_up_max" {
  description = "Maximum capacity during scheduled scale up"
  type        = number
  default     = 8
}

variable "scheduled_scale_down_min" {
  description = "Minimum capacity during scheduled scale down"
  type        = number
  default     = 1
}

variable "scheduled_scale_down_max" {
  description = "Maximum capacity during scheduled scale down"
  type        = number
  default     = 3
}
