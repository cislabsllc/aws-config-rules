#!/usr/bin/env python3

"""
CloudFormation Template Validator
This script validates CloudFormation YAML templates for syntax errors
"""

import yaml
import json
import sys
import argparse
from pathlib import Path

# Custom YAML loader that handles CloudFormation intrinsic functions
class CloudFormationLoader(yaml.SafeLoader):
    pass

def cloudformation_constructor(loader, tag_suffix, node):
    """Handle CloudFormation intrinsic functions"""
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    elif isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    else:
        return None

# Register CloudFormation intrinsic functions
cf_functions = ['Ref', 'GetAtt', 'Join', 'Select', 'Split', 'Sub', 'Base64', 'Cidr',
               'FindInMap', 'GetAZs', 'ImportValue', 'And', 'Equals', 'If', 'Not', 'Or',
               'Condition', 'Transform']

for func in cf_functions:
    CloudFormationLoader.add_constructor(f'!{func}', 
        lambda loader, node, func=func: cloudformation_constructor(loader, func, node))

def validate_yaml_syntax(file_path):
    """Validate YAML syntax"""
    try:
        with open(file_path, 'r') as file:
            yaml.load(file, Loader=CloudFormationLoader)
        return True, "YAML syntax is valid"
    except yaml.YAMLError as e:
        return False, f"YAML syntax error: {e}"
    except Exception as e:
        return False, f"Error reading file: {e}"

def validate_cloudformation_structure(file_path):
    """Validate basic CloudFormation template structure"""
    try:
        with open(file_path, 'r') as file:
            template = yaml.load(file, Loader=CloudFormationLoader)
        
        if not isinstance(template, dict):
            return False, "Template must be a dictionary/object"
        
        # Check for required sections (at least one should exist)
        valid_sections = ['Parameters', 'Resources', 'Outputs', 'Mappings', 
                         'Conditions', 'Transform', 'AWSTemplateFormatVersion', 'Description']
        
        if not any(section in template for section in valid_sections):
            return False, "Template must contain at least one valid CloudFormation section"
        
        # Validate Resources section if it exists
        if 'Resources' in template:
            resources = template['Resources']
            if not isinstance(resources, dict):
                return False, "Resources section must be a dictionary"
            
            for resource_name, resource_def in resources.items():
                if not isinstance(resource_def, dict):
                    return False, f"Resource '{resource_name}' must be a dictionary"
                
                if 'Type' not in resource_def:
                    return False, f"Resource '{resource_name}' missing required 'Type' property"
        
        # Validate Parameters section if it exists
        if 'Parameters' in template:
            parameters = template['Parameters']
            if not isinstance(parameters, dict):
                return False, "Parameters section must be a dictionary"
            
            for param_name, param_def in parameters.items():
                if not isinstance(param_def, dict):
                    return False, f"Parameter '{param_name}' must be a dictionary"
                
                if 'Type' not in param_def:
                    return False, f"Parameter '{param_name}' missing required 'Type' property"
        
        # Validate Outputs section if it exists
        if 'Outputs' in template:
            outputs = template['Outputs']
            if not isinstance(outputs, dict):
                return False, "Outputs section must be a dictionary"
            
            for output_name, output_def in outputs.items():
                if not isinstance(output_def, dict):
                    return False, f"Output '{output_name}' must be a dictionary"
                
                if 'Value' not in output_def:
                    return False, f"Output '{output_name}' missing required 'Value' property"
        
        return True, "CloudFormation template structure is valid"
        
    except Exception as e:
        return False, f"Error validating template structure: {e}"

def main():
    parser = argparse.ArgumentParser(description='Validate CloudFormation YAML templates')
    parser.add_argument('template_file', help='Path to CloudFormation template file')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    template_path = Path(args.template_file)
    
    if not template_path.exists():
        print(f"Error: Template file not found: {args.template_file}")
        sys.exit(1)
    
    print(f"Validating CloudFormation template: {args.template_file}")
    
    # Validate YAML syntax
    yaml_valid, yaml_message = validate_yaml_syntax(template_path)
    if not yaml_valid:
        print(f"❌ {yaml_message}")
        sys.exit(1)
    else:
        print(f"✅ {yaml_message}")
    
    # Validate CloudFormation structure
    cf_valid, cf_message = validate_cloudformation_structure(template_path)
    if not cf_valid:
        print(f"❌ {cf_message}")
        sys.exit(1)
    else:
        print(f"✅ {cf_message}")
    
    print("🎉 Template validation successful!")
    
    if args.verbose:
        print("\nTemplate summary:")
        with open(template_path, 'r') as file:
            template = yaml.load(file, Loader=CloudFormationLoader)
        
        if 'Parameters' in template:
            print(f"  Parameters: {len(template['Parameters'])}")
        if 'Resources' in template:
            print(f"  Resources: {len(template['Resources'])}")
        if 'Outputs' in template:
            print(f"  Outputs: {len(template['Outputs'])}")
        if 'Conditions' in template:
            print(f"  Conditions: {len(template['Conditions'])}")

if __name__ == '__main__':
    main()