#!/bin/bash

# Media Conversion Pipeline Deployment Script
# This script deploys the CloudFormation template for the media conversion pipeline

set -e

# Default values
STACK_NAME="media-conversion-pipeline"
REGION="us-east-1"
ENVIRONMENT="dev"
INPUT_BUCKET=""
OUTPUT_PREFIX="media-output"

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -s, --stack-name STACK_NAME     CloudFormation stack name (default: media-conversion-pipeline)"
    echo "  -r, --region REGION              AWS region (default: us-east-1)"
    echo "  -e, --environment ENV            Environment name (default: dev)"
    echo "  -i, --input-bucket BUCKET        Input S3 bucket name (required)"
    echo "  -o, --output-prefix PREFIX       Output bucket prefix (default: media-output)"
    echo "  -h, --help                       Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -i my-input-bucket -e prod -r us-west-2"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -i|--input-bucket)
            INPUT_BUCKET="$2"
            shift 2
            ;;
        -o|--output-prefix)
            OUTPUT_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$INPUT_BUCKET" ]; then
    echo "Error: Input bucket name is required"
    usage
fi

# Create parameters file with user inputs
PARAMS_FILE="/tmp/media-pipeline-params-$$.json"
cat > "$PARAMS_FILE" << EOF
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "$ENVIRONMENT"
  },
  {
    "ParameterKey": "InputBucketName",
    "ParameterValue": "$INPUT_BUCKET"
  },
  {
    "ParameterKey": "OutputBucketPrefix",
    "ParameterValue": "$OUTPUT_PREFIX"
  }
]
EOF

echo "🚀 Deploying Media Conversion Pipeline..."
echo "   Stack Name: $STACK_NAME"
echo "   Region: $REGION"
echo "   Environment: $ENVIRONMENT"
echo "   Input Bucket: $INPUT_BUCKET"
echo "   Output Prefix: $OUTPUT_PREFIX"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/media-conversion-pipeline.yaml"

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# Validate template
echo "🔍 Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body "file://$TEMPLATE_FILE" \
    --region "$REGION" \
    --no-cli-pager

echo "✅ Template validation successful"

# Check if stack exists
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_EXISTS" = "DOES_NOT_EXIST" ]; then
    echo "📦 Creating new stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters "file://$PARAMS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --no-cli-pager

    echo "⏳ Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
else
    echo "🔄 Updating existing stack..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters "file://$PARAMS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --no-cli-pager

    echo "⏳ Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
fi

# Get stack outputs
echo "📊 Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table \
    --no-cli-pager

# Cleanup temporary files
rm -f "$PARAMS_FILE"

echo ""
echo "✅ Media Conversion Pipeline deployed successfully!"
echo "   Stack Name: $STACK_NAME"
echo "   Region: $REGION"
echo ""
echo "🔗 View in AWS Console:"
echo "   https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks/stackinfo?stackId=$STACK_NAME"