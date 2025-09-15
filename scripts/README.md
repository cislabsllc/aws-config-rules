# AWS Authentication and CloudFormation Deployment Scripts

This directory contains scripts to facilitate AWS authentication and CloudFormation template deployment for the AWS Config Rules repository.

## Scripts Overview

### 1. AWS Login Script (`aws-login.sh`)

Provides various methods to authenticate with AWS, including basic credential configuration and MFA-based role assumption.

#### Features
- Interactive AWS credential configuration
- MFA-based role assumption
- Profile management
- Authentication verification
- Support for temporary credentials

#### Usage

```bash
# Configure AWS credentials interactively
./scripts/aws-login.sh configure

# Verify current authentication
./scripts/aws-login.sh verify

# Assume role with MFA
./scripts/aws-login.sh assume-role arn:aws:iam::123456789012:role/MyRole arn:aws:iam::123456789012:mfa/myuser

# Use specific profile
./scripts/aws-login.sh -p myprofile verify

# Get help
./scripts/aws-login.sh help
```

#### Options
- `-p, --profile PROFILE`: AWS profile name (default: default)
- `-r, --region REGION`: AWS region (default: us-east-1)
- `-d, --duration SECONDS`: MFA session duration (default: 3600)

### 2. CloudFormation Deployment Script (`cloudformation-deploy.sh`)

Provides comprehensive CloudFormation stack management capabilities including deployment, updates, validation, and deletion.

#### Features
- Template validation
- Stack creation and updates with changeset preview
- Interactive confirmation for changes
- Stack deletion with confirmation
- Stack description and resource listing
- Parameter file support
- Capability management

#### Usage

```bash
# Deploy a stack
./scripts/cloudformation-deploy.sh deploy my-stack template.yaml

# Deploy with parameters file
./scripts/cloudformation-deploy.sh deploy my-stack template.yaml parameters.json

# Deploy with IAM capabilities
./scripts/cloudformation-deploy.sh -c CAPABILITY_IAM deploy my-stack template.yaml

# Validate template
./scripts/cloudformation-deploy.sh validate template.yaml

# Delete stack
./scripts/cloudformation-deploy.sh delete my-stack

# Describe stack
./scripts/cloudformation-deploy.sh describe my-stack

# List all stacks
./scripts/cloudformation-deploy.sh list

# Get help
./scripts/cloudformation-deploy.sh help
```

#### Options
- `-p, --profile PROFILE`: AWS profile name (default: default)
- `-r, --region REGION`: AWS region (default: us-east-1)
- `-c, --capabilities CAPS`: CloudFormation capabilities (e.g., CAPABILITY_IAM)
- `--no-wait`: Don't wait for stack operations to complete

## Enhanced CloudFormation Template

The `custom-conformance-pack.yaml` template has been enhanced with the following improvements:

### New Features
1. **Environment-aware naming**: All resources are now named with environment prefixes
2. **SNS notifications**: Added SNS topic and subscription for compliance notifications
3. **Enhanced parameters**: Added Environment and NotificationEmail parameters
4. **Improved tagging**: Enhanced volume tagging rules with environment-specific tags
5. **Outputs**: Added stack outputs for easy reference and cross-stack dependencies
6. **Conditions**: Added conditional logic for optional email notifications

### Parameters
- `CustomConfigRuleLambdaArn`: ARN of the custom config rule Lambda function
- `Environment`: Environment name (dev, staging, prod)
- `NotificationEmail`: Email address for compliance notifications (optional)

### Resources Created
- Custom Config Rule for EC2 volumes
- Volume tags compliance rule
- CloudTrail enabled rule
- SNS topic for notifications
- Email subscription (if email provided)

### Usage Example

```bash
# Authenticate with AWS
./scripts/aws-login.sh configure

# Deploy the enhanced conformance pack
./scripts/cloudformation-deploy.sh deploy \
  my-config-stack \
  aws-config-conformance-packs/custom-conformance-pack.yaml \
  aws-config-conformance-packs/custom-conformance-pack-parameters.json

# Update the stack (will show changeset preview)
./scripts/cloudformation-deploy.sh deploy \
  my-config-stack \
  aws-config-conformance-packs/custom-conformance-pack.yaml \
  aws-config-conformance-packs/custom-conformance-pack-parameters.json
```

## Prerequisites

### Required Tools
- AWS CLI v2 (install with `pip install awscli`)
- jq (JSON processor for parsing responses)
- bash shell

### AWS Permissions
The following AWS permissions are required:

#### For Authentication Script
- `sts:GetCallerIdentity`
- `sts:AssumeRole` (if using role assumption)

#### For CloudFormation Script
- `cloudformation:ValidateTemplate`
- `cloudformation:CreateStack`
- `cloudformation:UpdateStack`
- `cloudformation:DeleteStack`
- `cloudformation:DescribeStacks`
- `cloudformation:DescribeStackResources`
- `cloudformation:ListStacks`
- `cloudformation:CreateChangeSet`
- `cloudformation:DescribeChangeSet`
- `cloudformation:ExecuteChangeSet`
- `cloudformation:DeleteChangeSet`

#### For Config Rules
- `config:PutConfigRule`
- `config:DescribeConfigRules`
- `sns:CreateTopic`
- `sns:Subscribe`
- `lambda:AddPermission` (for custom rules)

## Security Best Practices

1. **Credentials**: Never hardcode credentials in scripts or templates
2. **MFA**: Use MFA for sensitive operations
3. **Least Privilege**: Grant minimum required permissions
4. **Temporary Credentials**: Use temporary credentials when possible
5. **Profile Isolation**: Use separate profiles for different environments

## Troubleshooting

### Common Issues

1. **AWS CLI not found**: Install AWS CLI v2
2. **jq not found**: Install jq package (`apt-get install jq` or `brew install jq`)
3. **Permission denied**: Ensure scripts are executable (`chmod +x scripts/*.sh`)
4. **Invalid credentials**: Run `./scripts/aws-login.sh configure` to set up credentials
5. **Template validation fails**: Check CloudFormation template syntax

### Error Messages
- `Error: AWS CLI is not installed`: Install AWS CLI
- `Error: Template file not found`: Check file path
- `Authentication failed`: Verify credentials and permissions
- `Stack does not exist`: Check stack name and region

## Examples

### Complete Workflow Example

```bash
# 1. Configure AWS credentials
./scripts/aws-login.sh configure

# 2. Verify authentication
./scripts/aws-login.sh verify

# 3. Validate template
./scripts/cloudformation-deploy.sh validate \
  aws-config-conformance-packs/custom-conformance-pack.yaml

# 4. Deploy stack
./scripts/cloudformation-deploy.sh deploy \
  dev-config-rules \
  aws-config-conformance-packs/custom-conformance-pack.yaml \
  aws-config-conformance-packs/custom-conformance-pack-parameters.json

# 5. Check stack status
./scripts/cloudformation-deploy.sh describe dev-config-rules

# 6. List all stacks
./scripts/cloudformation-deploy.sh list
```

### Environment-Specific Deployment

```bash
# Deploy to development
./scripts/cloudformation-deploy.sh -r us-east-1 deploy \
  dev-config-rules \
  aws-config-conformance-packs/custom-conformance-pack.yaml \
  parameters/dev-parameters.json

# Deploy to production
./scripts/cloudformation-deploy.sh -r us-west-2 deploy \
  prod-config-rules \
  aws-config-conformance-packs/custom-conformance-pack.yaml \
  parameters/prod-parameters.json
```

## Contributing

When adding new functionality:
1. Follow the existing script structure and patterns
2. Add appropriate error handling and validation
3. Include help documentation
4. Test with different AWS profiles and regions
5. Update this README with any new features