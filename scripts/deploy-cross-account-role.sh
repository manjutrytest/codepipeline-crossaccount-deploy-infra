#!/bin/bash

# Deploy Cross-Account Role Script
# This script deploys the cross-account deployment role to the target account

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/templates/cross-account/deployment-role.yaml"

# Default values
SOURCE_ACCOUNT_ID=""
TARGET_ACCOUNT_PROFILE=""
ROLE_NAME="CrossAccountInfraDeploymentRole"
EXTERNAL_ID="cross-account-infra-deploy-2024"
REGION="eu-north-1"
STACK_NAME="CrossAccount-Deployment-Role"

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

Deploy cross-account deployment role to target account.

OPTIONS:
    -s, --source-account     Source AWS account ID (required)
    -p, --profile           AWS CLI profile for target account (required)
    -r, --role-name         Name of the cross-account role (default: $ROLE_NAME)
    -e, --external-id       External ID for role assumption (default: $EXTERNAL_ID)
    --region                AWS region (default: $REGION)
    --stack-name            CloudFormation stack name (default: $STACK_NAME)
    -h, --help              Show this help message

EXAMPLES:
    # Deploy with required parameters
    $0 --source-account 123456789012 --profile target-account

    # Deploy with custom role name and external ID
    $0 -s 123456789012 -p target-account -r MyCustomRole -e my-external-id

    # Deploy to different region
    $0 -s 123456789012 -p target-account --region us-west-2

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source-account)
            SOURCE_ACCOUNT_ID="$2"
            shift 2
            ;;
        -p|--profile)
            TARGET_ACCOUNT_PROFILE="$2"
            shift 2
            ;;
        -r|--role-name)
            ROLE_NAME="$2"
            shift 2
            ;;
        -e|--external-id)
            EXTERNAL_ID="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --stack-name)
            STACK_NAME="$2"
            shift 2
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

# Validate required parameters
if [[ -z "$SOURCE_ACCOUNT_ID" ]]; then
    print_error "Source account ID is required"
    show_usage
    exit 1
fi

if [[ -z "$TARGET_ACCOUNT_PROFILE" ]]; then
    print_error "Target account AWS profile is required"
    show_usage
    exit 1
fi

# Validate source account ID format
if [[ ! "$SOURCE_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    print_error "Source account ID must be a 12-digit number"
    exit 1
fi

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

print_status "Starting cross-account role deployment..."
print_status "Source Account ID: $SOURCE_ACCOUNT_ID"
print_status "Target Account Profile: $TARGET_ACCOUNT_PROFILE"
print_status "Role Name: $ROLE_NAME"
print_status "External ID: $EXTERNAL_ID"
print_status "Region: $REGION"
print_status "Stack Name: $STACK_NAME"

# Verify AWS CLI profile
print_status "Verifying AWS CLI profile..."
if ! aws sts get-caller-identity --profile "$TARGET_ACCOUNT_PROFILE" > /dev/null 2>&1; then
    print_error "Failed to verify AWS CLI profile: $TARGET_ACCOUNT_PROFILE"
    print_error "Please ensure the profile is configured and has valid credentials"
    exit 1
fi

TARGET_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$TARGET_ACCOUNT_PROFILE" --query 'Account' --output text)
print_success "Connected to target account: $TARGET_ACCOUNT_ID"

# Validate CloudFormation template
print_status "Validating CloudFormation template..."
if ! aws cloudformation validate-template \
    --template-body file://"$TEMPLATE_FILE" \
    --profile "$TARGET_ACCOUNT_PROFILE" \
    --region "$REGION" > /dev/null 2>&1; then
    print_error "CloudFormation template validation failed"
    aws cloudformation validate-template \
        --template-body file://"$TEMPLATE_FILE" \
        --profile "$TARGET_ACCOUNT_PROFILE" \
        --region "$REGION"
    exit 1
fi
print_success "Template validation passed"

# Check if stack already exists
print_status "Checking if stack already exists..."
if aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$TARGET_ACCOUNT_PROFILE" \
    --region "$REGION" > /dev/null 2>&1; then
    print_warning "Stack $STACK_NAME already exists. This will update the existing stack."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
fi

# Deploy the CloudFormation stack
print_status "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        SourceAccountId="$SOURCE_ACCOUNT_ID" \
        RoleName="$ROLE_NAME" \
        ExternalId="$EXTERNAL_ID" \
    --tags \
        Environment=Production \
        Project=CrossAccountInfraDeployment \
        ManagedBy=Script \
        DeployedBy="$(whoami)" \
        DeploymentDate="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --profile "$TARGET_ACCOUNT_PROFILE" \
    --region "$REGION"

if [[ $? -eq 0 ]]; then
    print_success "Cross-account role deployed successfully!"
else
    print_error "Deployment failed"
    exit 1
fi

# Get stack outputs
print_status "Retrieving stack outputs..."
ROLE_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$TARGET_ACCOUNT_PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`CrossAccountRoleArn`].OutputValue' \
    --output text)

if [[ -n "$ROLE_ARN" ]]; then
    print_success "Cross-account role ARN: $ROLE_ARN"
else
    print_warning "Could not retrieve role ARN from stack outputs"
fi

# Test role assumption (optional)
print_status "Testing role assumption from current AWS credentials..."
if aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "test-session-$(date +%s)" \
    --external-id "$EXTERNAL_ID" > /dev/null 2>&1; then
    print_success "Role assumption test passed"
else
    print_warning "Role assumption test failed. This might be expected if current credentials don't have permission to assume the role."
fi

# Display next steps
cat << EOF

${GREEN}✓ Deployment completed successfully!${NC}

${BLUE}Next Steps:${NC}
1. Note the role ARN: ${YELLOW}$ROLE_ARN${NC}
2. Use this ARN when deploying the CodePipeline in the source account
3. Ensure the source account has permission to assume this role

${BLUE}Role Details:${NC}
- Role Name: $ROLE_NAME
- External ID: $EXTERNAL_ID
- Stack Name: $STACK_NAME
- Region: $REGION

${BLUE}To deploy the pipeline in the source account, use:${NC}
./scripts/deploy-pipeline.sh \\
    --target-account $TARGET_ACCOUNT_ID \\
    --cross-account-role-name $ROLE_NAME \\
    --external-id $EXTERNAL_ID \\
    --profile source-account

EOF