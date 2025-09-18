# Media Conversion Pipeline CloudFormation Template

This CloudFormation template creates a complete media conversion pipeline with Translation and Video Processing Lambda functions.

## Issues Fixed

This template addresses the following issues that were present in the original pipeline:

### 1. ✅ Proper Dependency Chain
- Added `DependsOn` attributes to ensure resources are created in the correct order
- TranslationLambda depends on TranslationLambdaLogGroup and TranslationLambdaRole
- VideoProcessingLambda depends on VideoProcessingLambdaLogGroup, VideoProcessingLambdaRole, and OutputBucket
- PipelineInitializer (Custom Resource) depends on both Lambda functions and OutputBucket

### 2. ✅ Fixed Hardcoded Bucket Names
- Replaced hardcoded bucket names with parameter references using `!Ref OutputBucket` and `!Ref InputBucketName`
- Added parameters for flexible bucket naming with environment-specific prefixes
- Used CloudFormation intrinsic functions for dynamic bucket naming

### 3. ✅ Added Proper Error Handling and Logging
- Implemented comprehensive logging using Python's logging module
- Added try-catch blocks in all Lambda functions
- Set appropriate log levels via environment variables
- Added detailed error messages and context logging

### 4. ✅ Fixed JSON Path for Transcription Data Processing
- Corrected the JSON path to access transcription results: `transcription_data['results']['transcripts'][0]['transcript']`
- Added proper error handling for missing or malformed transcription data
- Implemented confidence score extraction from the correct path in the transcription results

### 5. ✅ Updated Function Execution Permissions
- Created specific IAM roles for each Lambda function with minimal required permissions
- Added CloudWatch Logs permissions for proper log group access
- Included S3 permissions for input/output bucket access
- Added service-specific permissions (Transcribe, MediaConvert)

### 6. ✅ Added DependsOn for Correct Resource Ordering
- Explicit dependencies ensure CloudWatch Log Groups are created before Lambda functions
- IAM roles are created before Lambda functions that use them
- Output bucket is created before Lambda functions that write to it

### 7. ✅ Fixed Resource Dependencies Between Lambda and Custom Resources
- Custom Resource (PipelineInitializer) depends on all Lambda functions and buckets
- Proper ServiceToken reference to the initializer Lambda
- Clean separation of concerns between pipeline setup and business logic

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Input Bucket  │───▶│ TranslationLambda │───▶│  Output Bucket  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        ▲
                                ▼                        │
                       ┌──────────────────┐              │
                       │VideoProcessingLam│──────────────┘
                       │bda               │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │ CloudWatch Logs  │
                       └──────────────────┘
```

## Resources Created

1. **S3 Bucket (OutputBucket)**
   - Encrypted at rest with AES256
   - Versioning enabled
   - Public access blocked

2. **IAM Roles**
   - TranslationLambdaRole: Permissions for Transcribe, S3, and CloudWatch Logs
   - VideoProcessingLambdaRole: Permissions for MediaConvert, S3, and CloudWatch Logs
   - PipelineInitializerLambdaRole: Permissions for S3 notifications and Lambda permissions

3. **CloudWatch Log Groups**
   - TranslationLambdaLogGroup: Logs for translation function
   - VideoProcessingLambdaLogGroup: Logs for video processing function
   - 14-day retention policy for cost optimization

4. **Lambda Functions**
   - TranslationLambda: Handles transcription jobs using AWS Transcribe
   - VideoProcessingLambda: Processes videos with MediaConvert and handles transcription completion
   - PipelineInitializerLambda: Custom resource for pipeline setup

5. **Custom Resource (PipelineInitializer)**
   - Orchestrates pipeline initialization
   - Sets up S3 event notifications
   - Manages Lambda permissions

## Parameters

- `EnvironmentName`: Environment identifier (default: 'dev')
- `InputBucketName`: Name of the existing input S3 bucket
- `OutputBucketPrefix`: Prefix for the output bucket name

## Outputs

- `OutputBucketName`: Name of the created output bucket
- `TranslationLambdaArn`: ARN of the Translation Lambda function
- `VideoProcessingLambdaArn`: ARN of the Video Processing Lambda function
- `TranslationLambdaLogGroup`: CloudWatch Log Group for Translation Lambda
- `VideoProcessingLambdaLogGroup`: CloudWatch Log Group for Video Processing Lambda

## Deployment

```bash
aws cloudformation create-stack \
  --stack-name media-conversion-pipeline \
  --template-body file://media-conversion-pipeline.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## Monitoring

- CloudWatch Logs are automatically created for each Lambda function
- Logs include detailed information about processing steps
- Error handling ensures failed operations are logged with context
- Log retention is set to 14 days to manage costs

## Security Features

- IAM roles follow the principle of least privilege
- S3 bucket has public access blocked by default
- Encryption at rest enabled for the output bucket
- All AWS service interactions use IAM roles (no hardcoded credentials)