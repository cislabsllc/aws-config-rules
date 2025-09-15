#!/bin/bash

# CloudFormation Template Deployment Script
# This script provides functionality to deploy, update, and manage CloudFormation templates

set -e

# Default values
PROFILE="default"
REGION="us-east-1"
STACK_NAME=""
TEMPLATE_FILE=""
PARAMETERS_FILE=""
CAPABILITIES=""
WAIT_FOR_COMPLETION=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_message $RED "Error: AWS CLI is not installed. Please install it first."
        print_message $YELLOW "Install with: pip install awscli"
        exit 1
    fi
}

# Function to validate template
validate_template() {
    local template_file=$1
    
    if [ ! -f "$template_file" ]; then
        print_message $RED "Error: Template file not found: $template_file"
        return 1
    fi
    
    print_message $YELLOW "Validating CloudFormation template..."
    
    if aws cloudformation validate-template \
        --template-body "file://$template_file" \
        --profile "$PROFILE" \
        --region "$REGION" &>/dev/null; then
        print_message $GREEN "Template validation successful!"
        return 0
    else
        print_message $RED "Template validation failed!"
        return 1
    fi
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --profile "$PROFILE" \
        --region "$REGION" &>/dev/null
}

# Function to get stack status
get_stack_status() {
    local stack_name=$1
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "STACK_NOT_FOUND"
}

# Function to wait for stack operation to complete
wait_for_stack() {
    local stack_name=$1
    local operation=$2
    
    if [ "$WAIT_FOR_COMPLETION" = "false" ]; then
        return 0
    fi
    
    print_message $YELLOW "Waiting for stack $operation to complete..."
    
    case $operation in
        "create")
            aws cloudformation wait stack-create-complete \
                --stack-name "$stack_name" \
                --profile "$PROFILE" \
                --region "$REGION"
            ;;
        "update")
            aws cloudformation wait stack-update-complete \
                --stack-name "$stack_name" \
                --profile "$PROFILE" \
                --region "$REGION"
            ;;
        "delete")
            aws cloudformation wait stack-delete-complete \
                --stack-name "$stack_name" \
                --profile "$PROFILE" \
                --region "$REGION"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "Stack $operation completed successfully!"
    else
        print_message $RED "Stack $operation failed or timed out!"
        return 1
    fi
}

# Function to build parameters string
build_parameters() {
    local params_file=$1
    local params_string=""
    
    if [ -n "$params_file" ] && [ -f "$params_file" ]; then
        params_string="--parameters file://$params_file"
    fi
    
    echo "$params_string"
}

# Function to build capabilities string
build_capabilities() {
    local caps_string=""
    
    if [ -n "$CAPABILITIES" ]; then
        caps_string="--capabilities $CAPABILITIES"
    fi
    
    echo "$caps_string"
}

# Function to deploy stack (create or update)
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters_file=$3
    
    # Validate template first
    if ! validate_template "$template_file"; then
        return 1
    fi
    
    # Build command arguments
    local params_string
    local caps_string
    params_string=$(build_parameters "$parameters_file")
    caps_string=$(build_capabilities)
    
    if stack_exists "$stack_name"; then
        print_message $YELLOW "Stack exists. Updating stack: $stack_name"
        
        # Check if update is needed
        local changeset_name="changeset-$(date +%s)"
        
        print_message $BLUE "Creating changeset to preview changes..."
        
        eval aws cloudformation create-change-set \
            --stack-name "$stack_name" \
            --change-set-name "$changeset_name" \
            --template-body "file://$template_file" \
            $params_string \
            $caps_string \
            --profile "$PROFILE" \
            --region "$REGION" &>/dev/null
        
        # Wait for changeset creation
        aws cloudformation wait change-set-create-complete \
            --stack-name "$stack_name" \
            --change-set-name "$changeset_name" \
            --profile "$PROFILE" \
            --region "$REGION"
        
        # Get changeset details
        local changes
        changes=$(aws cloudformation describe-change-set \
            --stack-name "$stack_name" \
            --change-set-name "$changeset_name" \
            --profile "$PROFILE" \
            --region "$REGION" \
            --query 'Changes' \
            --output json)
        
        if [ "$changes" = "[]" ]; then
            print_message $YELLOW "No changes detected. Deleting changeset."
            aws cloudformation delete-change-set \
                --stack-name "$stack_name" \
                --change-set-name "$changeset_name" \
                --profile "$PROFILE" \
                --region "$REGION" &>/dev/null
            return 0
        fi
        
        print_message $BLUE "Changes to be applied:"
        echo "$changes" | jq -r '.[] | "- \(.Action) \(.ResourceChange.ResourceType) \(.ResourceChange.LogicalResourceId)"'
        
        echo "Do you want to execute this changeset? (y/N):"
        read -r confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            aws cloudformation execute-change-set \
                --stack-name "$stack_name" \
                --change-set-name "$changeset_name" \
                --profile "$PROFILE" \
                --region "$REGION"
            
            wait_for_stack "$stack_name" "update"
        else
            print_message $YELLOW "Changeset execution cancelled. Deleting changeset."
            aws cloudformation delete-change-set \
                --stack-name "$stack_name" \
                --change-set-name "$changeset_name" \
                --profile "$PROFILE" \
                --region "$REGION" &>/dev/null
        fi
    else
        print_message $YELLOW "Creating new stack: $stack_name"
        
        eval aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            $params_string \
            $caps_string \
            --profile "$PROFILE" \
            --region "$REGION"
        
        wait_for_stack "$stack_name" "create"
    fi
}

# Function to delete stack
delete_stack() {
    local stack_name=$1
    
    if ! stack_exists "$stack_name"; then
        print_message $YELLOW "Stack does not exist: $stack_name"
        return 0
    fi
    
    print_message $RED "WARNING: This will delete the stack '$stack_name' and all its resources!"
    echo "Are you sure you want to proceed? (y/N):"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_message $YELLOW "Deleting stack: $stack_name"
        
        aws cloudformation delete-stack \
            --stack-name "$stack_name" \
            --profile "$PROFILE" \
            --region "$REGION"
        
        wait_for_stack "$stack_name" "delete"
    else
        print_message $YELLOW "Stack deletion cancelled."
    fi
}

# Function to describe stack
describe_stack() {
    local stack_name=$1
    
    if ! stack_exists "$stack_name"; then
        print_message $RED "Stack does not exist: $stack_name"
        return 1
    fi
    
    print_message $BLUE "Stack Information:"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output table
    
    print_message $BLUE "\nStack Resources:"
    aws cloudformation describe-stack-resources \
        --stack-name "$stack_name" \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output table
}

# Function to list stacks
list_stacks() {
    print_message $BLUE "CloudFormation Stacks:"
    aws cloudformation list-stacks \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --profile "$PROFILE" \
        --region "$REGION" \
        --output table \
        --query 'StackSummaries[*].[StackName,StackStatus,CreationTime]'
}

# Function to show help
show_help() {
    echo "CloudFormation Template Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Commands:"
    echo "  deploy STACK_NAME TEMPLATE_FILE [PARAMS_FILE]  Deploy (create/update) stack"
    echo "  delete STACK_NAME                              Delete stack"
    echo "  describe STACK_NAME                            Describe stack"
    echo "  validate TEMPLATE_FILE                         Validate template"
    echo "  list                                           List stacks"
    echo "  help                                           Show this help message"
    echo ""
    echo "Options:"
    echo "  -p, --profile PROFILE          AWS profile name (default: default)"
    echo "  -r, --region REGION            AWS region (default: us-east-1)"
    echo "  -c, --capabilities CAPS        CloudFormation capabilities (e.g., CAPABILITY_IAM)"
    echo "  --no-wait                      Don't wait for stack operations to complete"
    echo ""
    echo "Examples:"
    echo "  $0 deploy my-stack template.yaml"
    echo "  $0 deploy my-stack template.yaml parameters.json"
    echo "  $0 -c CAPABILITY_IAM deploy my-stack template.yaml"
    echo "  $0 delete my-stack"
    echo "  $0 validate template.yaml"
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -c|--capabilities)
            CAPABILITIES="$2"
            shift 2
            ;;
        --no-wait)
            WAIT_FOR_COMPLETION=false
            shift
            ;;
        deploy|delete|describe|validate|list|help)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if AWS CLI is installed
check_aws_cli

# Execute command
case $COMMAND in
    deploy)
        if [ $# -lt 2 ]; then
            print_message $RED "Error: deploy requires STACK_NAME and TEMPLATE_FILE"
            echo "Usage: $0 deploy STACK_NAME TEMPLATE_FILE [PARAMETERS_FILE]"
            exit 1
        fi
        deploy_stack "$1" "$2" "$3"
        ;;
    delete)
        if [ $# -lt 1 ]; then
            print_message $RED "Error: delete requires STACK_NAME"
            echo "Usage: $0 delete STACK_NAME"
            exit 1
        fi
        delete_stack "$1"
        ;;
    describe)
        if [ $# -lt 1 ]; then
            print_message $RED "Error: describe requires STACK_NAME"
            echo "Usage: $0 describe STACK_NAME"
            exit 1
        fi
        describe_stack "$1"
        ;;
    validate)
        if [ $# -lt 1 ]; then
            print_message $RED "Error: validate requires TEMPLATE_FILE"
            echo "Usage: $0 validate TEMPLATE_FILE"
            exit 1
        fi
        validate_template "$1"
        ;;
    list)
        list_stacks
        ;;
    help|"")
        show_help
        ;;
    *)
        print_message $RED "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac