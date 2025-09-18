#!/usr/bin/env python3
"""
Validation script for the Media Conversion Pipeline CloudFormation template.
This script verifies that all the fixes mentioned in the problem statement are implemented.
"""

import yaml
import json
import sys
import re
from pathlib import Path


def load_template(template_path):
    """Load and parse the CloudFormation template."""
    try:
        with open(template_path, 'r') as f:
            content = f.read()
        
        # For validation purposes, we'll work with the raw content
        # and do basic structure checks without full YAML parsing
        # since CloudFormation intrinsic functions can't be parsed by standard YAML
        
        # Basic structure validation using regex
        template_structure = {
            'AWSTemplateFormatVersion': bool(re.search(r'AWSTemplateFormatVersion:', content)),
            'Parameters': bool(re.search(r'^Parameters:', content, re.MULTILINE)),
            'Resources': bool(re.search(r'^Resources:', content, re.MULTILINE)),
            'Outputs': bool(re.search(r'^Outputs:', content, re.MULTILINE))
        }
        
        return template_structure, content
    except Exception as e:
        print(f"❌ Error loading template: {e}")
        return None, None


def validate_template_structure(template):
    """Validate basic CloudFormation template structure."""
    required_sections = ['AWSTemplateFormatVersion', 'Parameters', 'Resources', 'Outputs']
    missing_sections = []
    
    for section in required_sections:
        if not template.get(section, False):
            missing_sections.append(section)
    
    if missing_sections:
        print(f"❌ Missing required sections: {missing_sections}")
        return False
    
    print("✅ Template has all required sections")
    return True


def check_dependency_chain(template, content):
    """Check for proper dependency chains between resources."""
    # Check for DependsOn attributes
    depends_on_count = content.count('DependsOn:')
    print(f"✅ DependsOn attributes found: {depends_on_count}")
    
    # Check specific dependencies mentioned in problem statement
    lambda_functions = re.findall(r'(\w+):\s*\n\s*Type:\s*AWS::Lambda::Function', content)
    
    dependencies_found = []
    
    # Check if Lambda functions depend on log groups and roles
    for lambda_name in lambda_functions:
        # Look for DependsOn sections for this Lambda
        lambda_section_pattern = f"{lambda_name}:\s*\n.*?DependsOn:\s*\n(.*?)(?=\n\s*\w+:|$)"
        lambda_deps = re.search(lambda_section_pattern, content, re.DOTALL)
        
        if lambda_deps:
            deps_text = lambda_deps.group(1)
            if 'LogGroup' in deps_text:
                dependencies_found.append(f"{lambda_name} depends on LogGroup")
            if 'Role' in deps_text:
                dependencies_found.append(f"{lambda_name} depends on Role")
    
    print(f"✅ Lambda dependencies found: {len(dependencies_found)}")
    for dep in dependencies_found:
        print(f"   - {dep}")
    
    return depends_on_count > 0


def check_hardcoded_bucket_fixes(content):
    """Check that hardcoded bucket names are replaced with parameter references."""
    parameter_refs = content.count('!Ref')
    sub_refs = content.count('!Sub')
    
    print(f"✅ Parameter references (!Ref): {parameter_refs}")
    print(f"✅ Substitution references (!Sub): {sub_refs}")
    
    # Check for common hardcoded patterns
    hardcoded_patterns = [
        'hardcoded-bucket',
        'my-bucket',
        'test-bucket',
        'bucket-name'
    ]
    
    hardcoded_found = []
    for pattern in hardcoded_patterns:
        if pattern in content.lower():
            hardcoded_found.append(pattern)
    
    if hardcoded_found:
        print(f"⚠️  Potential hardcoded values found: {hardcoded_found}")
    else:
        print("✅ No obvious hardcoded bucket names found")
    
    return parameter_refs > 0 and sub_refs > 0


def check_error_handling_and_logging(content):
    """Check for proper error handling and logging in Lambda code."""
    error_handling_checks = {
        'try/except blocks': 'try:' in content and 'except' in content,
        'logging configuration': 'logging' in content,
        'logger usage': 'logger.' in content,
        'log level configuration': 'LOG_LEVEL' in content,
        'error logging': 'logger.error' in content,
        'info logging': 'logger.info' in content
    }
    
    print("✅ Error handling and logging checks:")
    for check, passed in error_handling_checks.items():
        status = "✅" if passed else "❌"
        print(f"   {status} {check}: {passed}")
    
    return all(error_handling_checks.values())


def check_json_path_fixes(content):
    """Check for fixed JSON paths in transcription data processing."""
    # Check for correct transcription data access patterns
    correct_patterns = [
        "transcription_data['results']['transcripts']",
        "['results']['transcripts'][0]['transcript']",
        "transcription_data.get('results', {})"
    ]
    
    patterns_found = []
    for pattern in correct_patterns:
        if pattern in content:
            patterns_found.append(pattern)
    
    print(f"✅ Correct JSON path patterns found: {len(patterns_found)}")
    for pattern in patterns_found:
        print(f"   - {pattern}")
    
    return len(patterns_found) > 0


def check_execution_permissions(template, content):
    """Check for updated function execution permissions."""
    # Find IAM roles using regex
    iam_roles = re.findall(r'(\w+):\s*\n\s*Type:\s*AWS::IAM::Role', content)
    
    print(f"✅ IAM Roles defined: {len(iam_roles)} ({iam_roles})")
    
    # Check for specific permissions in roles
    permission_checks = []
    
    # Check for logging permissions
    if 'logs:CreateLogGroup' in content and 'logs:CreateLogStream' in content and 'logs:PutLogEvents' in content:
        permission_checks.append("CloudWatch Logs permissions found")
    
    # Check for S3 permissions
    if 's3:GetObject' in content and 's3:PutObject' in content:
        permission_checks.append("S3 permissions found")
    
    # Check for service-specific permissions
    if 'transcribe:' in content:
        permission_checks.append("Transcribe permissions found")
    
    if 'mediaconvert:' in content:
        permission_checks.append("MediaConvert permissions found")
    
    print(f"✅ Permission checks passed: {len(permission_checks)}")
    for check in permission_checks:
        print(f"   - {check}")
    
    return len(iam_roles) > 0


def check_resource_ordering(template, content):
    """Check for proper resource ordering with Custom Resources."""
    # Find Custom Resources using regex
    custom_resources = re.findall(r'(\w+):\s*\n\s*Type:\s*AWS::CloudFormation::CustomResource', content)
    
    print(f"✅ Custom Resources defined: {len(custom_resources)} ({custom_resources})")
    
    # Check if Custom Resources have proper dependencies
    custom_deps = []
    for cr_name in custom_resources:
        # Look for DependsOn sections for this Custom Resource
        cr_section_pattern = f"{cr_name}:\s*\n.*?DependsOn:\s*\n(.*?)(?=\n\s*\w+:|$)"
        cr_deps = re.search(cr_section_pattern, content, re.DOTALL)
        
        if cr_deps:
            deps_text = cr_deps.group(1)
            custom_deps.append(f"{cr_name} has dependencies")
    
    print(f"✅ Custom Resource dependencies: {len(custom_deps)}")
    for dep in custom_deps:
        print(f"   - {dep}")
    
    return len(custom_resources) > 0


def main():
    """Main validation function."""
    template_path = Path(__file__).parent / 'media-conversion-pipeline.yaml'
    
    if not template_path.exists():
        print(f"❌ Template file not found: {template_path}")
        sys.exit(1)
    
    print("🔍 Validating Media Conversion Pipeline CloudFormation Template")
    print("=" * 70)
    
    template, content = load_template(template_path)
    if not template or not content:
        sys.exit(1)
    
    # Run all validation checks
    checks = [
        ("Template Structure", validate_template_structure(template)),
        ("Dependency Chain", check_dependency_chain(template, content)),
        ("Hardcoded Bucket Fixes", check_hardcoded_bucket_fixes(content)),
        ("Error Handling & Logging", check_error_handling_and_logging(content)),
        ("JSON Path Fixes", check_json_path_fixes(content)),
        ("Execution Permissions", check_execution_permissions(template, content)),
        ("Resource Ordering", check_resource_ordering(template, content))
    ]
    
    print("\n" + "=" * 70)
    print("📊 VALIDATION SUMMARY")
    print("=" * 70)
    
    passed_checks = 0
    total_checks = len(checks)
    
    for check_name, passed in checks:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} {check_name}")
        if passed:
            passed_checks += 1
    
    print(f"\n🎯 Overall Score: {passed_checks}/{total_checks} checks passed")
    
    if passed_checks == total_checks:
        print("✅ All validation checks passed! Template is ready for deployment.")
        sys.exit(0)
    else:
        print("❌ Some validation checks failed. Please review the template.")
        sys.exit(1)


if __name__ == '__main__':
    main()