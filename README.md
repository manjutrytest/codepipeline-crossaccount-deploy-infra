# Cross-Account Infrastructure Deployment with CodePipeline

## Overview

This project implements a complete cross-account infrastructure deployment solution using AWS CodePipeline, CodeBuild, and CloudFormation. It allows you to deploy infrastructure from a source AWS account to a target AWS account securely.

## Architecture

```
┌─────────────────┐    ┌──────────────────────────────────────────┐    ┌─────────────────────────────────┐
│                 │    │           SOURCE ACCOUNT                 │    │        TARGET ACCOUNT           │
│   GitHub Repo   │────┤                                          │    │                                 │
│                 │    │  ┌─────────────┐  ┌─────────────────┐   │    │  ┌─────────────────────────┐    │
└─────────────────┘    │  │CodePipeline │  │   CodeBuild     │   │    │  │    CloudFormation       │    │
                       │  │             │──┤                 │───┼────┤  │      Stacks             │    │
                       │  └─────────────┘  └─────────────────┘   │    │  │                         │    │
                       │                                          │    │  │ ┌─────────────────────┐ │    │
                       │  ┌─────────────────────────────────┐    │    │  │ │  VPC, S3, IAM, etc  │ │    │
                       │  │         S3 Artifacts            │    │    │  │ └─────────────────────┘ │    │
                       │  └─────────────────────────────────┘    │    │  └─────────────────────────┘    │
                       └──────────────────────────────────────────┘    │                                 │
                                                                       │  ┌─────────────────────────┐    │
                                                                       │  │  Cross-Account Role     │    │
                                                                       │  └─────────────────────────┘    │
                                                                       └─────────────────────────────────┘
```

## Components

- **Source Account**: Contains CodePipeline, CodeBuild, and artifact storage
- **Target Account**: Contains cross-account deployment role and deployed infrastructure
- **GitHub Repository**: Source code repository with CloudFormation templates
- **Cross-Account Role**: IAM role in target account that allows deployment from source account

## Features

✅ **Secure Cross-Account Deployment**: Uses IAM roles with proper trust policies
✅ **Automated CI/CD**: GitHub integration with webhook triggers
✅ **Infrastructure as Code**: All infrastructure defined in CloudFormation
✅ **Modular Design**: Separate templates for different infrastructure components
✅ **Production Ready**: Includes monitoring, logging, and error handling
✅ **Cost Optimized**: Efficient resource usage and lifecycle policies

## Quick Start

1. **Deploy Cross-Account Role** (Target Account)
2. **Deploy Pipeline** (Source Account)
3. **Push Code to GitHub**
4. **Monitor Deployment**

See detailed instructions in the deployment guide below.

## Repository Structure

```
├── templates/
│   ├── pipeline/                    # Pipeline infrastructure
│   ├── cross-account/              # Cross-account IAM roles
│   └── infrastructure/             # Target infrastructure templates
├── parameters/                     # Parameter files for different environments
├── scripts/                       # Deployment and utility scripts
├── buildspec.yml                  # CodeBuild specification
└── docs/                         # Documentation
```