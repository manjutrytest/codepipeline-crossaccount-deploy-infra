#!/bin/bash

# Validate CloudFormation Templates Script
# This script validates all CloudFormation templates in the project

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Default values
AWS_PROFILE=""
REGION="eu-north-1"
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate all CloudFormation templates in the project.

OPTIONS:
    -p, --profile    AWS CLI profile to use for validation
    --region         AWS region (default: $REGION)
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

EXAMPLES:
    # Validate templates with default AWS credentials
    $0

    # Validate templates with specific AWS profile
    $0 --profile my-aws-profile

    # Validate templates with verbose output
    $0 --verbose

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Build AWS CLI command with optional profile
AWS_CMD="aws"
if [[ -n "$AWS_PROFILE" ]]; then
    AWS_CMD="$AWS_CMD --profile $AWS_PROFILE"
fi
AWS_CMD="$AWS_CMD --region $REGION"

print_status "Starting CloudFormation template validation..."
print_status "Templates directory: $TEMPLATES_DIR"
print_status "AWS Region: $REGION"
if [[ -n "$AWS_PROFILE" ]]; then
    print_status "AWS Profile: $AWS_PROFILE"
fi

# Check if templates directory exists
if [[ ! -d "$TEMPLATES_DIR" ]]; then
    print_error "Templates directory not found: $TEMPLATES_DIR"
    exit 1
fi

# Verify AWS CLI access
print_status "Verifying AWS CLI access..."
if ! $AWS_CMD sts get-caller-identity > /dev/null 2>&1; then
    print_error "Failed to verify AWS CLI access"
    if [[ -n "$AWS_PROFILE" ]]; then
        print_error "Please ensure the profile '$AWS_PROFILE' is configured and has valid credentials"
    else
        print_error "Please ensure AWS credentials are configured"
    fi
    exit 1
fi

ACCOUNT_ID=$($AWS_CMD sts get-caller-identity --query 'Account' --output text)
print_success "Connected to AWS account: $ACCOUNT_ID"

# Find all CloudFormation templates
print_status "Discovering CloudFormation templates..."
TEMPLATES=($(find "$TEMPLATES_DIR" -name "*.yaml" -o -name "*.yml" | sort))

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    print_warning "No CloudFormation templates found in $TEMPLATES_DIR"
    exit 0
fi

print_status "Found ${#TEMPLATES[@]} template(s) to validate"

# Validation counters
VALID_COUNT=0
INVALID_COUNT=0
VALIDATION_ERRORS=()

# Validate each template
for template in "${TEMPLATES[@]}"; do
    template_name=$(basename "$template")
    relative_path=${template#$PROJECT_ROOT/}
    
    echo
    print_status "Validating: $relative_path"
    
    # Run CloudFormation validation
    if [[ "$VERBOSE" == true ]]; then
        validation_output=$($AWS_CMD cloudformation validate-template --template-body file://"$template" 2>&1)
        validation_result=$?
    else
        validation_output=$($AWS_CMD cloudformation validate-template --template-body file://"$template" 2>&1)
        validation_result=$?
    fi
    
    if [[ $validation_result -eq 0 ]]; then
        print_success "✓ $template_name - Valid"
        ((VALID_COUNT++))
        
        if [[ "$VERBOSE" == true ]]; then
            echo "  Template details:"
            echo "$validation_output" | jq -r '.Description // "No description"' | sed 's/^/    Description: /'
            echo "$validation_output" | jq -r '.Parameters // {} | keys | length' | sed 's/^/    Parameters: /'
            echo "$validation_output" | jq -r '.Capabilities // [] | length' | sed 's/^/    Capabilities: /'
        fi
    else
        print_error "✗ $template_name - Invalid"
        ((INVALID_COUNT++))
        VALIDATION_ERRORS+=("$relative_path: $validation_output")
        
        # Show error details
        echo "  Error details:"
        echo "$validation_output" | sed 's/^/    /'
    fi
done

# Summary
echo
echo "=================================="
print_status "Validation Summary"
echo "=================================="
print_success "Valid templates: $VALID_COUNT"
if [[ $INVALID_COUNT -gt 0 ]]; then
    print_error "Invalid templates: $INVALID_COUNT"
else
    print_success "Invalid templates: $INVALID_COUNT"
fi
echo "Total templates: ${#TEMPLATES[@]}"

# Show detailed errors if any
if [[ $INVALID_COUNT -gt 0 ]]; then
    echo
    print_error "Validation Errors:"
    for error in "${VALIDATION_ERRORS[@]}"; do
        echo "  - $error"
    done
    echo
    print_error "Please fix the validation errors before deploying"
    exit 1
fi

# Additional checks
echo
print_status "Running additional checks..."

# Check for common issues
print_status "Checking for common template issues..."

# Check for hardcoded account IDs
print_status "Checking for hardcoded account IDs..."
hardcoded_accounts=$(grep -r -n "arn:aws:iam::[0-9]\{12\}:" "$TEMPLATES_DIR" || true)
if [[ -n "$hardcoded_accounts" ]]; then
    print_warning "Found potential hardcoded account IDs:"
    echo "$hardcoded_accounts" | sed 's/^/  /'
    print_warning "Consider using AWS::AccountId pseudo parameter instead"
fi

# Check for hardcoded regions
print_status "Checking for hardcoded regions..."
hardcoded_regions=$(grep -r -n -E "(us-east-1|us-west-2|eu-west-1|eu-central-1|ap-southeast-1)" "$TEMPLATES_DIR" | grep -v "# region:" || true)
if [[ -n "$hardcoded_regions" ]]; then
    print_warning "Found potential hardcoded regions:"
    echo "$hardcoded_regions" | sed 's/^/  /'
    print_warning "Consider using AWS::Region pseudo parameter instead"
fi

# Check for missing descriptions
print_status "Checking for templates without descriptions..."
templates_without_desc=()
for template in "${TEMPLATES[@]}"; do
    if ! grep -q "^Description:" "$template"; then
        templates_without_desc+=("$(basename "$template")")
    fi
done

if [[ ${#templates_without_desc[@]} -gt 0 ]]; then
    print_warning "Templates without descriptions:"
    for template in "${templates_without_desc[@]}"; do
        echo "  - $template"
    done
fi

# Check for missing metadata
print_status "Checking for templates without metadata..."
templates_without_metadata=()
for template in "${TEMPLATES[@]}"; do
    if ! grep -q "^Metadata:" "$template"; then
        templates_without_metadata+=("$(basename "$template")")
    fi
done

if [[ ${#templates_without_metadata[@]} -gt 0 ]]; then
    print_warning "Templates without metadata (consider adding AWS::CloudFormation::Interface):"
    for template in "${templates_without_metadata[@]}"; do
        echo "  - $template"
    done
fi

echo
if [[ $INVALID_COUNT -eq 0 ]]; then
    print_success "All CloudFormation templates are valid! ✓"
    print_status "Templates are ready for deployment"
else
    print_error "Some templates have validation errors"
    exit 1
fi