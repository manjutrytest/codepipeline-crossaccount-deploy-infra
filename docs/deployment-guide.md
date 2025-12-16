# Cross-Account Infrastructure Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying infrastructure from a source AWS account to a target AWS account using CodePipeline and CloudFormation.

## Prerequisites

### Required Tools
- AWS CLI v2.x installed and configured
- Git client
- Bash shell (Linux/macOS/WSL)
- jq (for JSON processing)

### AWS Accounts Setup
- **Source Account**: Where CodePipeline will run
- **Target Account**: Where infrastructure will be deployed
- Administrator access to both accounts
- AWS CLI profiles configured for both accounts

### GitHub Repository
- GitHub repository created and accessible
- GitHub Personal Access Token with repository permissions

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────────────────────────────┐    ┌─────────────────────────────────┐
│                 │    │           SOURCE ACCOUNT                 │    │        TARGET ACCOUNT           │
│   GitHub Repo   │────┤                                          │    │                                 │
│                 │    │  ┌─────────────┐  ┌─────────────────┐   │    │  ┌─────────────────────────┐    │
└─────────────────┘    │  │CodePipeline │  │   CodeBuild     │   │    │  │    CloudFormation       │    │
                       │  │             │──┤                 │───┼────┤  │      Stacks             │    │
                       │  └─────────────┘  └─────────────────┘   │    │  │                         │    │
                       │                                          │    │  │ ┌─────────────────────┐ │    │
                       │  ┌─────────────────────────────────┐    │    │  │ │  VPC, S3, SG, etc   │ │    │
                       │  │         S3 Artifacts            │    │    │  │ └─────────────────────┘ │    │
                       │  └─────────────────────────────────┘    │    │  └─────────────────────────┘    │
                       └──────────────────────────────────────────┘    │                                 │
                                                                       │  ┌─────────────────────────┐    │
                                                                       │  │  Cross-Account Role     │    │
                                                                       │  └─────────────────────────┘    │
                                                                       └─────────────────────────────────┘
```

## Step-by-Step Deployment

### Step 1: Configure AWS CLI Profiles

Configure AWS CLI profiles for both accounts:

```bash
# Configure source account profile
aws configure --profile source-account
# Enter:
# - AWS Access Key ID: [Your source account access key]
# - AWS Secret Access Key: [Your source account secret key]
# - Default region name: eu-north-1
# - Default output format: json

# Configure target account profile
aws configure --profile target-account
# Enter:
# - AWS Access Key ID: [Your target account access key]
# - AWS Secret Access Key: [Your target account secret key]
# - Default region name: eu-north-1
# - Default output format: json
```

### Step 2: Verify Account Access

```bash
# Verify source account access
aws sts get-caller-identity --profile source-account

# Verify target account access
aws sts get-caller-identity --profile target-account
```

Expected output should show the correct account IDs.

### Step 3: Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/manjutrytest/codepipeline-crossaccount-deploy-infra.git
cd codepipeline-crossaccount-deploy-infra

# Make scripts executable
chmod +x scripts/*.sh
```

### Step 4: Validate CloudFormation Templates

```bash
# Validate all templates
./scripts/validate-templates.sh --profile target-account

# Or validate with verbose output
./scripts/validate-templates.sh --profile target-account --verbose
```

### Step 5: Deploy Cross-Account Role (Target Account)

```bash
# Deploy the cross-account deployment role
./scripts/deploy-cross-account-role.sh \
  --source-account 123456789012 \
  --profile target-account
```

Replace `123456789012` with your actual source account ID.

**Expected Output:**
```
✓ Deployment completed successfully!

Next Steps:
1. Note the role ARN: arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountInfraDeploymentRole
2. Use this ARN when deploying the CodePipeline in the source account
```

### Step 6: Deploy CodePipeline (Source Account)

```bash
# Deploy the CodePipeline
./scripts/deploy-pipeline.sh \
  --target-account 987654321098 \
  --profile source-account \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxx
```

Replace:
- `987654321098` with your target account ID
- `ghp_xxxxxxxxxxxxxxxxxxxx` with your GitHub Personal Access Token

**Expected Output:**
```
✓ CodePipeline deployment completed successfully!

Pipeline Details:
- Pipeline Name: cross-account-infra-pipeline-production
- Pipeline URL: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/...
```

### Step 7: Push Code to GitHub Repository

```bash
# Add all files to git
git add .

# Commit the changes
git commit -m "Initial commit: Cross-account infrastructure deployment"

# Push to GitHub (this will trigger the pipeline)
git push origin main
```

### Step 8: Monitor Pipeline Execution

1. **AWS Console**: Go to the pipeline URL provided in the deployment output
2. **CLI**: Use the monitoring commands provided in the deployment output

```bash
# Check pipeline status
aws codepipeline get-pipeline-state \
  --name cross-account-infra-pipeline-production \
  --profile source-account \
  --region eu-north-1

# List pipeline executions
aws codepipeline list-pipeline-executions \
  --pipeline-name cross-account-infra-pipeline-production \
  --profile source-account \
  --region eu-north-1
```

### Step 9: Verify Infrastructure Deployment

Check the deployed infrastructure in the target account:

```bash
# List deployed stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `CrossAccount`)].{Name:StackName,Status:StackStatus,Created:CreationTime}' \
  --output table \
  --profile target-account \
  --region eu-north-1
```

**Expected Stacks:**
- `CrossAccount-VPC-production`
- `CrossAccount-SecurityGroups-production`
- `CrossAccount-S3Storage-production`

## Verification Checklist

### ✅ Pipeline Verification

- [ ] Pipeline shows "Succeeded" status in AWS Console
- [ ] GitHub webhook is configured and working
- [ ] CodeBuild project executes successfully
- [ ] No errors in CodeBuild logs

### ✅ Infrastructure Verification

- [ ] VPC created with public and private subnets
- [ ] Security groups created with proper rules
- [ ] S3 buckets created with encryption enabled
- [ ] All resources properly tagged

### ✅ Cross-Account Verification

- [ ] Cross-account role exists in target account
- [ ] Role can be assumed from source account
- [ ] CloudFormation stacks deployed in target account
- [ ] Pipeline artifacts stored in source account

## Troubleshooting

### Common Issues

#### Issue 1: Cross-Account Role Assumption Fails
**Error**: `AccessDenied` when assuming cross-account role

**Solutions**:
1. Verify role exists in target account
2. Check trust policy allows source account
3. Ensure external ID matches
4. Verify source account has permission to assume role

```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountInfraDeploymentRole \
  --role-session-name test-session \
  --external-id cross-account-infra-deploy-2024 \
  --profile source-account
```

#### Issue 2: Pipeline Fails at Build Stage
**Error**: CodeBuild fails with permission errors

**Solutions**:
1. Check CodeBuild service role permissions
2. Verify S3 bucket access
3. Check CloudWatch logs for detailed errors

```bash
# Check CodeBuild logs
aws logs describe-log-groups \
  --log-group-name-prefix /aws/codebuild/cross-account-infra-deployment \
  --profile source-account
```

#### Issue 3: CloudFormation Stack Creation Fails
**Error**: Stack creation/update fails in target account

**Solutions**:
1. Validate templates locally first
2. Check parameter values
3. Verify resource limits and quotas
4. Check stack events for detailed errors

```bash
# Validate template
aws cloudformation validate-template \
  --template-body file://templates/infrastructure/vpc.yaml \
  --profile target-account

# Check stack events
aws cloudformation describe-stack-events \
  --stack-name CrossAccount-VPC-production \
  --profile target-account
```

#### Issue 4: GitHub Webhook Not Working
**Error**: Pipeline doesn't trigger on push

**Solutions**:
1. Verify GitHub token permissions
2. Check webhook configuration in GitHub
3. Manually trigger pipeline for testing

```bash
# Manually trigger pipeline
aws codepipeline start-pipeline-execution \
  --name cross-account-infra-pipeline-production \
  --profile source-account
```

### Debug Commands

```bash
# Check all CloudFormation stacks in both accounts
aws cloudformation list-stacks --profile source-account --region eu-north-1
aws cloudformation list-stacks --profile target-account --region eu-north-1

# Check CodePipeline execution history
aws codepipeline list-pipeline-executions \
  --pipeline-name cross-account-infra-pipeline-production \
  --profile source-account --region eu-north-1

# Check CodeBuild project configuration
aws codebuild batch-get-projects \
  --names cross-account-infra-deployment-production \
  --profile source-account --region eu-north-1

# Check S3 artifacts bucket
aws s3 ls s3://cross-account-pipeline-artifacts-SOURCE_ACCOUNT-eu-north-1 \
  --profile source-account
```

## Environment-Specific Deployments

### Development Environment

```bash
# Deploy to development environment
./scripts/deploy-pipeline.sh \
  --target-account 987654321098 \
  --profile source-account \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxx \
  --environment development
```

### Staging Environment

```bash
# Deploy to staging environment
./scripts/deploy-pipeline.sh \
  --target-account 987654321098 \
  --profile source-account \
  --github-token ghp_xxxxxxxxxxxxxxxxxxxx \
  --environment staging
```

## Cost Optimization

### Estimated Monthly Costs (eu-north-1)

- **CodePipeline**: $1.00/month (1 active pipeline)
- **CodeBuild**: $0.005/minute (estimated 20 builds/month × 10 minutes) = $1.00/month
- **S3 Artifact Storage**: $0.023/GB (estimated 5GB) = $0.12/month
- **CloudWatch Logs**: $0.50/GB (estimated 1GB) = $0.50/month
- **VPC NAT Gateway**: $32.85/month (production only)
- **S3 Storage**: $0.023/GB (estimated 100GB) = $2.30/month

**Total Production**: ~$37.77/month
**Total Development**: ~$4.92/month (no NAT Gateway)

### Cost Reduction Tips

1. **Use development environment** for testing (no NAT Gateway)
2. **Set up S3 lifecycle policies** for automatic cleanup
3. **Use smaller CodeBuild instance types** for simple builds
4. **Enable S3 Intelligent Tiering** for cost optimization
5. **Set up budget alerts** to monitor spending

## Security Best Practices

### IAM Security
- Use least-privilege IAM policies
- Regularly rotate GitHub tokens
- Enable MFA for AWS accounts
- Use external ID for cross-account roles

### Network Security
- Deploy resources in private subnets when possible
- Use VPC endpoints to avoid internet traffic
- Implement proper security group rules
- Enable VPC Flow Logs for monitoring

### Data Protection
- Enable S3 bucket encryption
- Use HTTPS for all communications
- Implement backup strategies
- Enable CloudTrail for audit logging

## Maintenance

### Regular Tasks
- [ ] Update CloudFormation templates as needed
- [ ] Review and update IAM permissions quarterly
- [ ] Monitor costs and optimize resources
- [ ] Update documentation
- [ ] Test disaster recovery procedures

### Updates and Changes
1. Make changes in feature branches
2. Test in development environment first
3. Create pull requests for review
4. Deploy to staging for validation
5. Deploy to production after approval

## Support and Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [Cross-Account IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)

## Next Steps

After successful deployment:

1. **Customize Infrastructure**: Modify templates for your specific needs
2. **Add More Environments**: Create additional environment configurations
3. **Implement Monitoring**: Set up CloudWatch dashboards and alarms
4. **Security Hardening**: Review and tighten security policies
5. **Automation**: Add more automation for operational tasks