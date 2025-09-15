#!/bin/bash

# Example: Complete AWS Config Rules Deployment Workflow
# This script demonstrates how to use the AWS login and CloudFormation deployment scripts

set -e

# Configuration
STACK_NAME="dev-aws-config-rules"
TEMPLATE_FILE="aws-config-conformance-packs/custom-conformance-pack.yaml"
PARAMETERS_FILE="aws-config-conformance-packs/custom-conformance-pack-parameters.json"
REGION="us-east-1"
PROFILE="default"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 AWS Config Rules Deployment Example${NC}"
echo -e "${BLUE}=======================================${NC}"

echo -e "\n${YELLOW}Step 1: Validate CloudFormation Template${NC}"
echo "Using local validation to check template syntax..."
python3 scripts/validate-template.py "$TEMPLATE_FILE" --verbose

echo -e "\n${YELLOW}Step 2: Check AWS Authentication (Optional)${NC}"
echo "You can configure AWS credentials if needed:"
echo "  ./scripts/aws-login.sh configure"
echo "  ./scripts/aws-login.sh verify"
echo ""
echo "For this example, we'll assume credentials are already configured."

echo -e "\n${YELLOW}Step 3: Preview Template Parameters${NC}"
echo "Template will be deployed with these parameters:"
if [ -f "$PARAMETERS_FILE" ]; then
    cat "$PARAMETERS_FILE" | python3 -m json.tool
else
    echo "No parameters file found. Template will use default values."
fi

echo -e "\n${YELLOW}Step 4: Deploy CloudFormation Stack${NC}"
echo "Stack Name: $STACK_NAME"
echo "Template: $TEMPLATE_FILE"
echo "Parameters: $PARAMETERS_FILE"
echo "Region: $REGION"
echo ""
echo "To deploy this stack, run:"
echo "  ./scripts/cloudformation-deploy.sh -r $REGION deploy $STACK_NAME $TEMPLATE_FILE $PARAMETERS_FILE"
echo ""
echo "The deployment script will:"
echo "  1. Validate the template with AWS CloudFormation"
echo "  2. Create a changeset if the stack exists"
echo "  3. Show you exactly what changes will be made"
echo "  4. Ask for confirmation before applying changes"
echo "  5. Wait for the deployment to complete"

echo -e "\n${YELLOW}Step 5: Verify Deployment${NC}"
echo "After deployment, you can verify the stack:"
echo "  ./scripts/cloudformation-deploy.sh describe $STACK_NAME"
echo "  ./scripts/cloudformation-deploy.sh list"

echo -e "\n${YELLOW}Step 6: Cleanup (Optional)${NC}"
echo "To delete the stack when no longer needed:"
echo "  ./scripts/cloudformation-deploy.sh delete $STACK_NAME"

echo -e "\n${GREEN}✅ Example workflow complete!${NC}"
echo -e "${GREEN}Use the commands above to deploy your AWS Config Rules.${NC}"