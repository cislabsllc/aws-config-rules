#!/bin/bash

# AWS Login and Authentication Script
# This script provides various methods to authenticate with AWS

set -e

# Default values
PROFILE="default"
REGION="us-east-1"
MFA_DURATION=3600

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to configure AWS credentials
configure_aws() {
    print_message $YELLOW "Configuring AWS credentials..."
    
    echo "Enter your AWS Access Key ID:"
    read -r access_key
    
    echo "Enter your AWS Secret Access Key:"
    read -s secret_key
    
    echo "Enter your default region [$REGION]:"
    read -r input_region
    REGION=${input_region:-$REGION}
    
    echo "Enter your profile name [$PROFILE]:"
    read -r input_profile
    PROFILE=${input_profile:-$PROFILE}
    
    # Configure AWS CLI
    aws configure set aws_access_key_id "$access_key" --profile "$PROFILE"
    aws configure set aws_secret_access_key "$secret_key" --profile "$PROFILE"
    aws configure set region "$REGION" --profile "$PROFILE"
    aws configure set output "json" --profile "$PROFILE"
    
    print_message $GREEN "AWS credentials configured successfully for profile: $PROFILE"
}

# Function to assume role with MFA
assume_role_with_mfa() {
    local role_arn=$1
    local mfa_device_arn=$2
    local session_name=${3:-"aws-config-session"}
    
    if [ -z "$role_arn" ] || [ -z "$mfa_device_arn" ]; then
        print_message $RED "Error: Role ARN and MFA device ARN are required"
        return 1
    fi
    
    echo "Enter your MFA token:"
    read -r mfa_token
    
    print_message $YELLOW "Assuming role with MFA..."
    
    # Assume role with MFA
    local assume_role_output
    assume_role_output=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "$session_name" \
        --serial-number "$mfa_device_arn" \
        --token-code "$mfa_token" \
        --duration-seconds "$MFA_DURATION" \
        --profile "$PROFILE" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Extract temporary credentials
        local access_key_id
        local secret_access_key
        local session_token
        
        access_key_id=$(echo "$assume_role_output" | jq -r '.Credentials.AccessKeyId')
        secret_access_key=$(echo "$assume_role_output" | jq -r '.Credentials.SecretAccessKey')
        session_token=$(echo "$assume_role_output" | jq -r '.Credentials.SessionToken')
        
        # Set environment variables
        export AWS_ACCESS_KEY_ID="$access_key_id"
        export AWS_SECRET_ACCESS_KEY="$secret_access_key"
        export AWS_SESSION_TOKEN="$session_token"
        export AWS_DEFAULT_REGION="$REGION"
        
        print_message $GREEN "Successfully assumed role. Temporary credentials are set in environment variables."
        print_message $YELLOW "These credentials will expire in $((MFA_DURATION/60)) minutes."
        
        # Save to temporary profile
        local temp_profile="${PROFILE}-mfa"
        aws configure set aws_access_key_id "$access_key_id" --profile "$temp_profile"
        aws configure set aws_secret_access_key "$secret_access_key" --profile "$temp_profile"
        aws configure set aws_session_token "$session_token" --profile "$temp_profile"
        aws configure set region "$REGION" --profile "$temp_profile"
        
        print_message $GREEN "Temporary credentials also saved to profile: $temp_profile"
    else
        print_message $RED "Failed to assume role. Please check your credentials and MFA token."
        return 1
    fi
}

# Function to verify AWS authentication
verify_auth() {
    print_message $YELLOW "Verifying AWS authentication..."
    
    local identity
    identity=$(aws sts get-caller-identity --profile "$PROFILE" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local user_arn
        local account_id
        user_arn=$(echo "$identity" | jq -r '.Arn')
        account_id=$(echo "$identity" | jq -r '.Account')
        
        print_message $GREEN "Authentication successful!"
        print_message $GREEN "User ARN: $user_arn"
        print_message $GREEN "Account ID: $account_id"
        print_message $GREEN "Profile: $PROFILE"
        print_message $GREEN "Region: $REGION"
        return 0
    else
        print_message $RED "Authentication failed. Please check your credentials."
        return 1
    fi
}

# Function to show help
show_help() {
    echo "AWS Login and Authentication Script"
    echo ""
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Commands:"
    echo "  configure           Configure AWS credentials interactively"
    echo "  verify              Verify current AWS authentication"
    echo "  assume-role         Assume IAM role with MFA"
    echo "  help                Show this help message"
    echo ""
    echo "Options:"
    echo "  -p, --profile PROFILE    AWS profile name (default: default)"
    echo "  -r, --region REGION      AWS region (default: us-east-1)"
    echo "  -d, --duration SECONDS   MFA session duration (default: 3600)"
    echo ""
    echo "Examples:"
    echo "  $0 configure"
    echo "  $0 -p myprofile verify"
    echo "  $0 assume-role arn:aws:iam::123456789012:role/MyRole arn:aws:iam::123456789012:mfa/myuser"
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
        -d|--duration)
            MFA_DURATION="$2"
            shift 2
            ;;
        configure|verify|assume-role|help)
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
    configure)
        configure_aws
        verify_auth
        ;;
    verify)
        verify_auth
        ;;
    assume-role)
        if [ $# -lt 2 ]; then
            print_message $RED "Error: assume-role requires ROLE_ARN and MFA_DEVICE_ARN"
            echo "Usage: $0 assume-role ROLE_ARN MFA_DEVICE_ARN [SESSION_NAME]"
            exit 1
        fi
        assume_role_with_mfa "$1" "$2" "$3"
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