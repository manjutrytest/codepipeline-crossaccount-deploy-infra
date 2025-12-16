#!/bin/bash

# Deploy CodePipeline Script
# This script deploys the CodePipeline to the source account

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/templates/pipeline/codepipeline.yaml"

# Default values
TARGET_ACCOUNT_ID=""
SOURCE_ACCOUNT_PROFILE=""
GITHUB_REPO_OWNER="manjutrytest"
GITHUB_REPO_NAME="codepipeline-crossaccount-deploy-infra"
GITHUB_BRANCH="main"
GITHUB_TOKEN=""
CROSS_ACCOUNT_ROLE_NAME="CrossAccountInfraDeploymentRole"
EXTERNAL_ID="cross-account-infra-deploy-2024"
ENVIRONMENT="production"
REGION="eu-north-1"
STACK_NAME="CrossAccount-Pipeline"

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

Deploy CodePipeline for cross-account infrastructure deployment.

OPTIONS:
    -t, --target-account        Target AWS account ID (required)
    -p, --profile              AWS CLI profile for source account (required)
    -g, --github-token         GitHub personal access token (required)
    --github-owner             GitHub repository owner (default: $GITHUB_REPO_OWNER)
    --github-repo              GitHub repository name (default: $GITHUB_REPO_NAME)
    --github-branch            GitHub branch (default: $GITHUB_BRANCH)
    -r, --cross-account-role   Cross-account role name (default: $CROSS_ACCOUNT_ROLE_NAME)
    -e, --external-id          External ID for role assumption (default: $EXTERNAL_ID)
    --environment              Environment name (default: $ENVIRONMENT)
    --region                   AWS region (default: $REGION)
    --stack-name               CloudFormation stack name (default: $STACK_NAME)
    -h, --help                 Show this help message

EXAMPLES:
    # Deploy with required parameters
    $0 --target-account 987654321098 --profile source-account --github-token ghp_xxxxxxxxxxxx

    # Deploy with custom GitHub repository
    $0 -t 987654321098 -p source-account -g ghp_xxxxxxxxxxxx \\
       --github-owner myorg --github-repo my-infra-repo

    # Deploy to staging environment
    $0 -t 987654321098 -p source-account -g ghp_xxxxxxxxxxxx --environment staging

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target-account)
            TARGET_ACCOUNT_ID="$2"
            shift 2
            ;;
        -p|--profile)
            SOURCE_ACCOUNT_PROFILE="$2"
            shift 2
            ;;
        -g|--github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --github-owner)
            GITHUB_REPO_OWNER="$2"
            shift 2
            ;;
        --github-repo)
            GITHUB_REPO_NAME="$2"
            shift 2
            ;;
        --github-branch)
            GITHUB_BRANCH="$2"
            shift 2
            ;;
        -r|--cross-account-role)
            CROSS_ACCOUNT_ROLE_NAME="$2"
            shift 2
            ;;
        -e|--external-id)
            EXTERNAL_ID="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
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
if [[ -z "$TARGET_ACCOUNT_ID" ]]; then
    print_error "Target account ID is required"
    show_usage
    exit 1
fi

if [[ -z "$SOURCE_ACCOUNT_PROFILE" ]]; then
    print_error "Source account AWS profile is required"
    show_usage
    exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    print_error "GitHub token is required"
    show_usage
    exit 1
fi

# Validate target account ID format
if [[ ! "$TARGET_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    print_error "Target account ID must be a 12-digit number"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    print_error "Environment must be one of: development, staging, production"
    exit 1
fi

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

print_status "Starting CodePipeline deployment..."
print_status "Target Account ID: $TARGET_ACCOUNT_ID"
print_status "Source Account Profile: $SOURCE_ACCOUNT_PROFILE"
print_status "GitHub Repository: $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME"
print_status "GitHub Branch: $GITHUB_BRANCH"
print_status "Cross-Account Role: $CROSS_ACCOUNT_ROLE_NAME"
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "Stack Name: $STACK_NAME"

# Verify AWS CLI profile
print_status "Verifying AWS CLI profile..."
if ! aws sts get-caller-identity --profile "$SOURCE_ACCOUNT_PROFILE" > /dev/null 2>&1; then
    print_error "Failed to verify AWS CLI profile: $SOURCE_ACCOUNT_PROFILE"
    print_error "Please ensure the profile is configured and has valid credentials"
    exit 1
fi

SOURCE_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$SOURCE_ACCOUNT_PROFILE" --query 'Account' --output text)
print_success "Connected to source account: $SOURCE_ACCOUNT_ID"

# Validate CloudFormation template
print_status "Validating CloudFormation template..."
if ! aws cloudformation validate-template \
    --template-body file://"$TEMPLATE_FILE" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" > /dev/null 2>&1; then
    print_error "CloudFormation template validation failed"
    aws cloudformation validate-template \
        --template-body file://"$TEMPLATE_FILE" \
        --profile "$SOURCE_ACCOUNT_PROFILE" \
        --region "$REGION"
    exit 1
fi
print_success "Template validation passed"

# Test cross-account role assumption
print_status "Testing cross-account role assumption..."
CROSS_ACCOUNT_ROLE_ARN="arn:aws:iam::${TARGET_ACCOUNT_ID}:role/${CROSS_ACCOUNT_ROLE_NAME}"
if aws sts assume-role \
    --role-arn "$CROSS_ACCOUNT_ROLE_ARN" \
    --role-session-name "test-session-$(date +%s)" \
    --external-id "$EXTERNAL_ID" \
    --profile "$SOURCE_ACCOUNT_PROFILE" > /dev/null 2>&1; then
    print_success "Cross-account role assumption test passed"
else
    print_error "Failed to assume cross-account role: $CROSS_ACCOUNT_ROLE_ARN"
    print_error "Please ensure:"
    print_error "1. The role exists in the target account"
    print_error "2. The role trusts the source account"
    print_error "3. The external ID matches"
    exit 1
fi

# Check if stack already exists
print_status "Checking if stack already exists..."
if aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
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
print_status "Deploying CodePipeline stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        GitHubRepoOwner="$GITHUB_REPO_OWNER" \
        GitHubRepoName="$GITHUB_REPO_NAME" \
        GitHubBranch="$GITHUB_BRANCH" \
        GitHubToken="$GITHUB_TOKEN" \
        TargetAccountId="$TARGET_ACCOUNT_ID" \
        CrossAccountRoleName="$CROSS_ACCOUNT_ROLE_NAME" \
        ExternalId="$EXTERNAL_ID" \
        Environment="$ENVIRONMENT" \
    --tags \
        Environment="$ENVIRONMENT" \
        Project=CrossAccountInfraDeployment \
        ManagedBy=Script \
        DeployedBy="$(whoami)" \
        DeploymentDate="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION"

if [[ $? -eq 0 ]]; then
    print_success "CodePipeline deployed successfully!"
else
    print_error "Deployment failed"
    exit 1
fi

# Get stack outputs
print_status "Retrieving stack outputs..."
PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineName`].OutputValue' \
    --output text)

PIPELINE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineUrl`].OutputValue' \
    --output text)

ARTIFACTS_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucketName`].OutputValue' \
    --output text)

# Check pipeline status
print_status "Checking pipeline status..."
PIPELINE_STATUS=$(aws codepipeline get-pipeline-state \
    --name "$PIPELINE_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" \
    --query 'stageStates[0].latestExecution.status' \
    --output text 2>/dev/null || echo "Unknown")

# Display deployment summary
cat << EOF

${GREEN}✓ CodePipeline deployment completed successfully!${NC}

${BLUE}Pipeline Details:${NC}
- Pipeline Name: ${YELLOW}$PIPELINE_NAME${NC}
- Pipeline URL: ${YELLOW}$PIPELINE_URL${NC}
- Artifacts Bucket: ${YELLOW}$ARTIFACTS_BUCKET${NC}
- Current Status: ${YELLOW}$PIPELINE_STATUS${NC}

${BLUE}Repository Configuration:${NC}
- GitHub Repository: ${YELLOW}$GITHUB_REPO_OWNER/$GITHUB_REPO_NAME${NC}
- Branch: ${YELLOW}$GITHUB_BRANCH${NC}
- Webhook: ${GREEN}Configured${NC}

${BLUE}Cross-Account Configuration:${NC}
- Source Account: ${YELLOW}$SOURCE_ACCOUNT_ID${NC}
- Target Account: ${YELLOW}$TARGET_ACCOUNT_ID${NC}
- Cross-Account Role: ${YELLOW}$CROSS_ACCOUNT_ROLE_ARN${NC}
- Environment: ${YELLOW}$ENVIRONMENT${NC}

${BLUE}Next Steps:${NC}
1. Push your CloudFormation templates to the GitHub repository
2. The pipeline will automatically trigger on push to the main branch
3. Monitor the pipeline execution in the AWS Console: ${YELLOW}$PIPELINE_URL${NC}
4. Check deployed infrastructure in the target account

${BLUE}Monitoring Commands:${NC}
# Check pipeline status
aws codepipeline get-pipeline-state --name $PIPELINE_NAME --profile $SOURCE_ACCOUNT_PROFILE --region $REGION

# List pipeline executions
aws codepipeline list-pipeline-executions --pipeline-name $PIPELINE_NAME --profile $SOURCE_ACCOUNT_PROFILE --region $REGION

# Check deployed stacks in target account
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --profile target-account --region $REGION

EOF

# Trigger initial pipeline execution if repository has content
print_status "Checking if we should trigger an initial pipeline execution..."
if aws codepipeline start-pipeline-execution \
    --name "$PIPELINE_NAME" \
    --profile "$SOURCE_ACCOUNT_PROFILE" \
    --region "$REGION" > /dev/null 2>&1; then
    print_success "Initial pipeline execution triggered"
else
    print_warning "Could not trigger initial pipeline execution. This is normal if the repository is empty."
fi

print_success "Deployment completed successfully!"