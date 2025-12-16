# 🚀 Quick Deployment Instructions

## Overview

This project provides a complete cross-account infrastructure deployment solution using AWS CodePipeline and CloudFormation. Deploy infrastructure from a source AWS account to a target AWS account securely and automatically.

## 📋 Prerequisites

- AWS CLI v2.x installed
- Two AWS accounts (source and target)
- GitHub repository access
- GitHub Personal Access Token
- Administrator permissions in both AWS accounts

## 🎯 Quick Start (5 Steps)

### Step 1: Configure AWS Profiles

```bash
# Configure source account
aws configure --profile source-account

# Configure target account  
aws configure --profile target-account

# Verify access
aws sts get-caller-identity --profile source-account
aws sts get-caller-identity --profile target-account
```

### Step 2: Clone Repository

```bash
git clone https://github.com/manjutrytest/codepipeline-crossaccount-deploy-infra.git
cd codepipeline-crossaccount-deploy-infra
chmod +x scripts/*.sh
```

### Step 3: Deploy Cross-Account Role (Target Account)

```bash
./scripts/deploy-cross-account-role.sh \
  --source-account YOUR_SOURCE_ACCOUNT_ID \
  --profile target-account
```

### Step 4: Deploy Pipeline (Source Account)

```bash
./scripts/deploy-pipeline.sh \
  --target-account YOUR_TARGET_ACCOUNT_ID \
  --profile source-account \
  --github-token YOUR_GITHUB_TOKEN
```

### Step 5: Push Code and Monitor

```bash
# Push code to trigger pipeline
git add .
git commit -m "Initial deployment"
git push origin main

# Monitor pipeline (URL provided in Step 4 output)
```

## 🏗️ What Gets Deployed

### In Target Account:
- ✅ **VPC**: Multi-AZ VPC with public/private subnets
- ✅ **Security Groups**: Web, database, bastion, cache, EFS, Lambda, ECS
- ✅ **S3 Storage**: Application data, backups, static website, access logs
- ✅ **Monitoring**: CloudWatch logs, VPC Flow Logs, S3 event processing
- ✅ **Networking**: NAT Gateways, VPC Endpoints, Internet Gateway

### In Source Account:
- ✅ **CodePipeline**: Automated deployment pipeline
- ✅ **CodeBuild**: Build and deployment project
- ✅ **S3 Artifacts**: Pipeline artifact storage
- ✅ **IAM Roles**: Pipeline and build service roles

## 📊 Expected Results

After successful deployment:

### Source Account Resources:
```
✓ CodePipeline: cross-account-infra-pipeline-production
✓ CodeBuild: cross-account-infra-deployment-production  
✓ S3 Bucket: cross-account-pipeline-artifacts-*
✓ IAM Roles: Pipeline and CodeBuild service roles
```

### Target Account Resources:
```
✓ CloudFormation Stacks:
  - CrossAccount-VPC-production
  - CrossAccount-SecurityGroups-production
  - CrossAccount-S3Storage-production
  
✓ VPC Infrastructure:
  - VPC with 2 public + 2 private subnets
  - NAT Gateway for internet access
  - VPC Endpoints for S3 and DynamoDB
  
✓ S3 Buckets:
  - Application data bucket (encrypted)
  - Backup bucket with lifecycle policies
  - Static website bucket
  - Access logs bucket
  
✓ Security Groups:
  - ALB, WebApp, Database, Bastion
  - Cache, EFS, Lambda, ECS security groups
```

## 🔧 Troubleshooting

### Common Issues:

#### Pipeline Fails to Assume Cross-Account Role
```bash
# Test role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountInfraDeploymentRole \
  --role-session-name test \
  --external-id cross-account-infra-deploy-2024 \
  --profile source-account
```

#### GitHub Webhook Not Working
```bash
# Manually trigger pipeline
aws codepipeline start-pipeline-execution \
  --name cross-account-infra-pipeline-production \
  --profile source-account
```

#### CloudFormation Stack Fails
```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name CrossAccount-VPC-production \
  --profile target-account
```

## 💰 Cost Estimate

### Monthly Costs (eu-north-1):
- **Production Environment**: ~$38/month
  - CodePipeline: $1.00
  - CodeBuild: $1.00  
  - NAT Gateway: $32.85
  - S3 Storage: $2.30
  - Other: $0.85

- **Development Environment**: ~$5/month
  - Same as production but no NAT Gateway

## 🔒 Security Features

- ✅ **Cross-Account IAM Roles** with external ID
- ✅ **Least-Privilege Policies** for all resources
- ✅ **S3 Bucket Encryption** with AES-256
- ✅ **VPC Flow Logs** for network monitoring
- ✅ **Private Subnets** for sensitive resources
- ✅ **VPC Endpoints** to avoid internet traffic

## 📚 Additional Resources

- **Detailed Guide**: `docs/deployment-guide.md`
- **Template Validation**: `./scripts/validate-templates.sh`
- **Parameter Files**: `parameters/` directory
- **Architecture Details**: `README.md`

## 🎛️ Environment Configurations

### Development Environment:
```bash
./scripts/deploy-pipeline.sh \
  --target-account YOUR_TARGET_ACCOUNT_ID \
  --profile source-account \
  --github-token YOUR_GITHUB_TOKEN \
  --environment development
```

### Staging Environment:
```bash
./scripts/deploy-pipeline.sh \
  --target-account YOUR_TARGET_ACCOUNT_ID \
  --profile source-account \
  --github-token YOUR_GITHUB_TOKEN \
  --environment staging
```

## ✅ Success Verification

### Check Pipeline Status:
```bash
aws codepipeline get-pipeline-state \
  --name cross-account-infra-pipeline-production \
  --profile source-account
```

### Check Deployed Infrastructure:
```bash
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --profile target-account
```

### Check VPC Resources:
```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=CrossAccountInfraDeployment" \
  --profile target-account
```

## 🔄 Next Steps

1. **Customize Infrastructure**: Modify templates in `templates/infrastructure/`
2. **Add More Resources**: Create additional CloudFormation templates
3. **Set Up Monitoring**: Configure CloudWatch dashboards
4. **Implement Backups**: Set up automated backup strategies
5. **Security Review**: Audit IAM permissions and security groups

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error messages
3. Validate templates using `./scripts/validate-templates.sh`
4. Refer to the detailed deployment guide in `docs/`

---

**🎉 Congratulations!** You now have a fully automated cross-account infrastructure deployment pipeline!