# Terraform AWS S3 Bucket Provisioning

## Table of Contents
- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [What This Module Does](#what-this-module-does)
- [Terraform Files Explained](#terraform-files-explained)
  - [1. main.tf](#1-maintf)
  - [2. variables.tf](#2-variablestf)
  - [3. outputs.tf](#3-outputstf)
- [Component Breakdown](#component-breakdown)
- [Execution Flow](#execution-flow)
- [Prerequisites](#prerequisites)
- [Usage Instructions](#usage-instructions)
- [Integration with Choreo](#integration-with-choreo)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

---

## Overview

This Terraform module automates the provisioning of AWS infrastructure for S3-based storage access. It creates a complete, secure setup that includes:

- **S3 Bucket**: A storage bucket for your files/objects
- **IAM User**: A dedicated user with programmatic access
- **Access Credentials**: AWS access keys for the IAM user
- **Security Policy**: Bucket-level permissions that grant the IAM user read/write access
- **Remote State Management**: Terraform state stored in S3 with DynamoDB locking

This setup is ideal for automation pipelines (like Choreo) that need to interact with S3 buckets programmatically.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud Environment                      │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Terraform State Management               │    │
│  │                                                             │    │
│  │  ┌──────────────────┐         ┌──────────────────┐          │    │
│  │  │   S3 Bucket      │         │  DynamoDB Table  │          │    │
│  │  │ (State Storage)  │◄────────┤  (State Locking) │          │    │
│  │  │ terraform-state- │         │ terraform-lock-  │          │    │ 
│  │  │ bucket-lakshans-1│         │     table-1      │          │    │
│  │  └──────────────────┘         └──────────────────┘          │    │
│  │         │                                                   │    │
│  │         │ Stores: terraform.tfstate                         │    │
│  │         │                                                   │    │
│  └─────────┼───────────────────────────────────────────────────┘    │
│            │                                                        │
│            ▼                                                        │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Resources Created by This Module               │    │
│  │                                                             │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  IAM User (Programmatic Access)                      │   │    │
│  │  │  ┌────────────────────────────────────────────────┐  │   │    │
│  │  │  │  Name: {var.aws_user_name}                     │  │   │    │
│  │  │  │  ARN: arn:aws:iam::ACCOUNT_ID:user/USERNAME    │  │   │    │
│  │  │  └────────────────────────────────────────────────┘  │   │    │
│  │  │                                                      │   │    │
│  │  │  ┌────────────────────────────────────────────────┐  │   │    │
│  │  │  │  IAM Access Key                                │  │   │    │
│  │  │  │  - Access Key ID                               │  │   │    │
│  │  │  │  - Secret Access Key                           │  │   │    │
│  │  │  └────────────────────────────────────────────────┘  │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                           │                                 │    │
│  │                           │ Has Permissions                 │    │
│  │                           ▼                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  S3 Bucket: {var.bucket_name}                        │   │    │
│  │  │                                                      │   │    │
│  │  │  ┌──────────────────────────────────────────────┐    │   │    │
│  │  │  │  Bucket Policy                               │    │   │    │
│  │  │  │  Grants IAM User permissions:                │    │   │    │
│  │  │  │  ✓ s3:PutObject    (Upload files)            │    │   │    │
│  │  │  │  ✓ s3:GetObject    (Download files)          │    │   │    │
│  │  │  │  ✓ s3:DeleteObject (Delete files)            │    │   │    │
│  │  │  └──────────────────────────────────────────────┘    │   │    │
│  │  │                                                      │   │    │
│  │  │  Region: {var.aws_region}                            │   │    │
│  │  │  ARN: arn:aws:s3:::{bucket_name}                     │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ Uses credentials to access S3
                                ▼
                    ┌───────────────────────────┐
                    │   External Applications   │
                    │                           │
                    │                           │
                    │   Uses:                   │
                    │   - Access Key ID         │
                    │   - Secret Access Key     │
                    │   - Bucket Name           │
                    └───────────────────────────┘
```

---

## What This Module Does

This Terraform configuration creates a **complete S3 access infrastructure** that allows external applications (like Choreo automation pipelines) to securely read, write, and delete objects in an S3 bucket.

### Key Features:

1. **Automated Infrastructure**: One command deploys all necessary AWS resources
2. **Secure Access**: IAM-based authentication with least-privilege permissions
3. **State Management**: Terraform state is stored remotely in S3 with DynamoDB locking to prevent concurrent modifications
4. **Programmatic Access**: Generates access keys for API/SDK usage
5. **Clean Destruction**: `force_destroy = true` ensures the bucket can be deleted even with objects inside

---

## Terraform Files Explained

### 1. main.tf

**Purpose**: This is the core infrastructure definition file that declares all AWS resources and their configurations.

#### File Structure Breakdown:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-lakshans-1"
    key            = "s3-writer-example/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table-1"
  }
}
```

**What this does:**
- **Backend Configuration**: Tells Terraform where to store its state file (the record of what infrastructure exists)
- **Why S3 Backend?**:
  - Enables team collaboration (multiple people can work on the same infrastructure)
  - Provides state locking via DynamoDB to prevent conflicts
  - Encrypts state data at rest for security
  - Allows state to persist beyond your local machine
- **State File Path**: `s3://terraform-state-bucket-lakshans-1/s3-writer-example/terraform.tfstate`
- **Locking**: Uses DynamoDB table `terraform-lock-table-1` to prevent concurrent Terraform operations

**Important**: This backend bucket and DynamoDB table must already exist before running Terraform.

---

```hcl
provider "aws" {
  region = var.aws_region
}
```

**What this does:**
- **Provider Configuration**: Sets up the AWS provider plugin that Terraform uses to communicate with AWS APIs
- **Region**: Uses the value from the `aws_region` variable (defined in variables.tf)
- **Authentication**: Expects AWS credentials to be configured (via environment variables, AWS CLI config, or IAM role)

---

```hcl
resource "aws_iam_user" "writer" {
  name = var.aws_user_name
}
```

**What this does:**
- **Creates IAM User**: A new AWS Identity and Access Management user for programmatic access
- **Purpose**: This user will have credentials that your automation pipeline (Choreo) can use
- **Naming**: Uses the value from `var.aws_user_name` variable
- **Resource Reference**: Can be referenced elsewhere as `aws_iam_user.writer`

**Example**: If `aws_user_name = "choreo-s3-writer"`, this creates a user named "choreo-s3-writer"

---

```hcl
resource "aws_iam_access_key" "writer_key" {
  user = aws_iam_user.writer.name
}
```

**What this does:**
- **Generates Access Keys**: Creates an access key ID and secret access key pair for the IAM user
- **Purpose**: These credentials allow programmatic access to AWS services
- **Link**: Automatically associates the keys with the IAM user created above
- **Output**: The keys are available as `aws_iam_access_key.writer_key.id` and `aws_iam_access_key.writer_key.secret`

**Security Note**: The secret key is only available in Terraform state and outputs. It cannot be retrieved later from AWS.

---

```hcl
resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}
```

**What this does:**
- **Creates S3 Bucket**: Provisions a new S3 bucket with the specified name
- **Bucket Name**: Uses the value from `var.bucket_name` (must be globally unique across all AWS)
- **force_destroy = true**:
  - Allows Terraform to delete the bucket even if it contains objects
  - **Warning**: Without this, `terraform destroy` would fail if the bucket has files
  - Makes cleanup easier but use with caution in production

**Example**: If `bucket_name = "my-choreo-data-bucket"`, creates bucket: `s3://my-choreo-data-bucket`

---

```hcl
resource "aws_s3_bucket_policy" "write_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ],
        Resource = "${aws_s3_bucket.bucket.arn}/*",
        Principal = {
          AWS = aws_iam_user.writer.arn
        }
      }
    ]
  })
}
```

**What this does:**
- **Attaches Bucket Policy**: Defines who can access the bucket and what they can do
- **Policy Type**: Resource-based policy (attached to the bucket itself)
- **Version**: Uses the AWS IAM policy language version 2012-10-17

**Policy Components**:

1. **Effect**: `"Allow"` - This is a permissive rule (grants access)

2. **Action**: The specific S3 operations permitted:
   - `s3:PutObject` - Upload/write new files to the bucket
   - `s3:GetObject` - Download/read files from the bucket
   - `s3:DeleteObject` - Remove files from the bucket

3. **Resource**: `"${aws_s3_bucket.bucket.arn}/*"`
   - Applies to all objects (`/*`) inside the bucket
   - Example: `arn:aws:s3:::my-bucket/*`

4. **Principal**: `{AWS = aws_iam_user.writer.arn}`
   - Specifies WHO can perform these actions
   - Only the IAM user created by this module
   - Example: `arn:aws:iam::123456789012:user/choreo-s3-writer`

**Security**: This policy implements the principle of least privilege - the user can only interact with objects in this specific bucket, nowhere else.

---

### 2. variables.tf

**Purpose**: Defines input variables that make this module reusable and configurable. Variables allow you to customize the infrastructure without modifying the code.

#### File Structure Breakdown:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
}
```

**What this does:**
- **Variable Name**: `aws_region`
- **Purpose**: Specifies which AWS region to create resources in
- **Type**: `string` - must be a text value
- **Description**: Human-readable explanation shown in documentation and CLI help
- **Required**: Yes (no `default` value specified)
- **Example Values**: `"us-east-1"`, `"eu-west-1"`, `"ap-southeast-1"`

**Why configurable?**: Different teams/projects may want resources in different geographic regions for latency, compliance, or cost reasons.

---

```hcl
variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}
```

**What this does:**
- **Variable Name**: `bucket_name`
- **Purpose**: The name for the S3 bucket to create
- **Type**: `string`
- **Required**: Yes
- **Constraints**:
  - Must be globally unique across all AWS accounts
  - Must follow S3 naming rules: lowercase, no spaces, 3-63 characters
  - Can contain letters, numbers, hyphens

**Example Values**: `"my-company-data-bucket"`, `"choreo-pipeline-storage-2024"`

---

```hcl
variable "aws_user_name" {
  description = "IAM user name"
  type        = string
}
```

**What this does:**
- **Variable Name**: `aws_user_name`
- **Purpose**: The name for the IAM user that will be created
- **Type**: `string`
- **Required**: Yes
- **Constraints**: Must follow IAM user naming rules (alphanumeric plus `+=,.@_-`)

**Example Values**: `"choreo-automation-user"`, `"s3-writer-bot"`

---

### 3. outputs.tf

**Purpose**: Defines output values that Terraform displays after applying the configuration. These outputs expose important information about the created resources that you'll need to use them.

#### File Structure Breakdown:

```hcl
output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}
```

**What this does:**
- **Output Name**: `bucket_name`
- **Value**: The actual name of the created S3 bucket
- **Source**: Reads from the `bucket` attribute of the `aws_s3_bucket.bucket` resource
- **Purpose**: Confirms the bucket name (useful when names are auto-generated)
- **Usage**: Can be referenced by other Terraform modules or displayed to users

**Example Output**: `bucket_name = "my-choreo-data-bucket"`

---

```hcl
output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}
```

**What this does:**
- **Output Name**: `bucket_arn`
- **Value**: The Amazon Resource Name (ARN) of the bucket
- **ARN Format**: `arn:aws:s3:::bucket-name`
- **Purpose**: Used for IAM policies, CloudFormation, and other AWS integrations
- **Unique Identifier**: ARNs uniquely identify AWS resources

**Example Output**: `bucket_arn = "arn:aws:s3:::my-choreo-data-bucket"`

---

```hcl
output "access_key" {
  value     = aws_iam_access_key.writer_key.id
  sensitive = true
}
```

**What this does:**
- **Output Name**: `access_key`
- **Value**: The AWS access key ID for the IAM user
- **Sensitive**: `true` - Terraform will hide this value in logs and standard output
- **Purpose**: This is one half of the credentials needed to authenticate with AWS
- **Format**: 20 characters, looks like `AKIAIOSFODNN7EXAMPLE`

**Important**:
- To view: Run `terraform output access_key`
- Store securely: This is a credential that grants access to your bucket
- For Choreo: Set this as the `AWS_ACCESS_KEY_ID` environment variable

---

```hcl
output "secret_key" {
  value     = aws_iam_access_key.writer_key.secret
  sensitive = true
}
```

**What this does:**
- **Output Name**: `secret_key`
- **Value**: The AWS secret access key for the IAM user
- **Sensitive**: `true` - Hidden from logs and console output
- **Purpose**: The second half of the credentials (paired with access_key)
- **Format**: 40 characters, looks like `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

**Critical Security Notes**:
- **Never commit this to version control**
- **Never log or display publicly**
- To view: Run `terraform output secret_key`
- For Choreo: Set this as the `AWS_SECRET_ACCESS_KEY` environment variable
- If compromised: Delete and regenerate the IAM access key immediately

---

```hcl
output "s3_connection_url" {
  value = "s3://${aws_s3_bucket.bucket.bucket}"
}
```

**What this does:**
- **Output Name**: `s3_connection_url`
- **Value**: A formatted S3 URL for the bucket
- **Format**: `s3://bucket-name`
- **Purpose**: Convenient connection string for S3 CLI tools and SDKs
- **String Interpolation**: Uses `${}` to embed the bucket name into the string

**Example Output**: `s3_connection_url = "s3://my-choreo-data-bucket"`

**Usage Examples**:
```bash
# AWS CLI
aws s3 ls s3://my-choreo-data-bucket

# Upload file
aws s3 cp file.txt s3://my-choreo-data-bucket/

# In code (Python)
bucket_url = "s3://my-choreo-data-bucket"
```

---

## Component Breakdown

### How the Resources Work Together

1. **IAM User** (`aws_iam_user.writer`)
   - Identity that represents your application/automation
   - Has no permissions by itself

2. **Access Keys** (`aws_iam_access_key.writer_key`)
   - Credentials for the IAM user
   - Enables API/SDK authentication
   - Think of it like a username (access key ID) and password (secret key)

3. **S3 Bucket** (`aws_s3_bucket.bucket`)
   - Storage container for your objects/files
   - Exists independently but needs access control

4. **Bucket Policy** (`aws_s3_bucket_policy.write_policy`)
   - **The glue that connects everything**
   - Says: "The IAM user can read/write/delete objects in this bucket"
   - Without this, the IAM user would have access keys but no permissions

### Permission Flow

```
IAM User + Access Keys → Bucket Policy → S3 Bucket Access
     │                        │               │
     │                        │               ▼
     │                        │         Read/Write/Delete
     │                        │         Objects
     │                        │
     └────────────────────────┴───────────────┘
           Authentication         Authorization
```

---

## Execution Flow

### What Happens When You Run Terraform

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: terraform init                                          │
│ ─────────────────────────────────────────────────────────────── │
│ • Downloads AWS provider plugin                                 │
│ • Connects to S3 backend (terraform-state-bucket-lakshans-1)    │
│ • Initializes working directory                                 │
│ • Downloads any required modules                                │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: terraform plan                                          │
│ ─────────────────────────────────────────────────────────────── │
│ • Reads current state from S3 backend                           │
│ • Compares desired state (your .tf files) with actual state     │
│ • Calculates what changes are needed                            │
│ • Shows you a preview of resources to be created/modified       │
│                                                                 │
│ Expected Plan Output:                                           │
│   + aws_iam_user.writer                    (to be created)      │
│   + aws_iam_access_key.writer_key          (to be created)      │
│   + aws_s3_bucket.bucket                   (to be created)      │
│   + aws_s3_bucket_policy.write_policy      (to be created)      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 3: terraform apply                                         │
│ ─────────────────────────────────────────────────────────────── │
│ • Executes the plan                                             │
│ • Creates resources in this order:                              │
│                                                                 │
│   1. IAM User (aws_iam_user.writer)                             │
│      └─> API Call: CreateUser                                   │
│                                                                 │
│   2. IAM Access Key (aws_iam_access_key.writer_key)             │
│      └─> API Call: CreateAccessKey                              │
│      └─> Depends on: IAM User must exist first                  │
│                                                                 │
│   3. S3 Bucket (aws_s3_bucket.bucket)                           │
│      └─> API Call: CreateBucket                                 │
│      └─> Independent: Can be created in parallel with IAM       │
│                                                                 │
│   4. Bucket Policy (aws_s3_bucket_policy.write_policy)          │
│      └─> API Call: PutBucketPolicy                              │
│      └─> Depends on: Bucket and IAM user must exist             │
│                                                                 │
│ • Updates state file in S3 backend                              │
│ • Displays outputs                                              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Output Display                                          │
│ ─────────────────────────────────────────────────────────────── │
│ Outputs:                                                        │
│                                                                 │
│ bucket_name = "my-choreo-data-bucket"                           │
│ bucket_arn = "arn:aws:s3:::my-choreo-data-bucket"               │
│ s3_connection_url = "s3://my-choreo-data-bucket"                │
│ access_key = <sensitive>                                        │
│ secret_key = <sensitive>                                        │
│                                                                 │
│ (Use 'terraform output access_key' to view credentials)         │
└─────────────────────────────────────────────────────────────────┘
```

### Dependency Graph

Terraform automatically determines the order of resource creation based on dependencies:

```
aws_iam_user.writer
    │
    ├──> aws_iam_access_key.writer_key
    │         │
    │         └──> (Used in outputs)
    │
    └──> aws_s3_bucket_policy.write_policy
              │
              ▲
              │
aws_s3_bucket.bucket
```

---

## Prerequisites

Before you can use this Terraform configuration, ensure you have:

### 1. AWS Account Setup

- **AWS Account**: Active AWS account with appropriate permissions
- **IAM Permissions**: Your AWS user/role needs:
  - `iam:CreateUser`
  - `iam:CreateAccessKey`
  - `s3:CreateBucket`
  - `s3:PutBucketPolicy`
  - Full access to the state bucket and DynamoDB table

### 2. Backend Infrastructure (Must Exist First)

These resources are referenced in `main.tf` but **NOT created by this module**:

```
✓ S3 Bucket: terraform-state-bucket-lakshans-1 (in us-east-1)
✓ DynamoDB Table: terraform-lock-table-1 (in us-east-1)
```

**To create backend resources** (one-time setup):

```bash
# Create state bucket
aws s3 mb s3://terraform-state-bucket-lakshans-1 --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket terraform-state-bucket-lakshans-1 \
  --versioning-configuration Status=Enabled

# Create lock table
aws dynamodb create-table \
  --table-name terraform-lock-table-1 \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### 3. Software Requirements

- **Terraform**: Version 0.12+ (download from https://www.terraform.io/downloads)
- **AWS CLI**: (Optional) For backend setup and testing
- **Git**: For version control

### 4. AWS Credentials Configuration

Configure AWS credentials using one of these methods:

**Option A: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option B: AWS CLI Configuration**
```bash
aws configure
```

**Option C: IAM Role** (if running in EC2, ECS, Lambda, or Choreo with IRSA)
- No explicit credentials needed
- Terraform will use the instance/task role automatically

---

## Usage Instructions

### Step-by-Step Deployment

#### 1. Clone and Navigate to Repository

```bash
git clone <your-repo-url>
cd terraform-aws-s3
```

#### 2. Create Variable Values File

Create a file named `terraform.tfvars`:

```hcl
aws_region     = "us-east-1"
bucket_name    = "my-choreo-data-bucket-2024"
aws_user_name  = "choreo-s3-automation-user"
```

**Important**:
- Change `bucket_name` to something unique (S3 bucket names are globally unique)
- Choose a descriptive `aws_user_name` that identifies the purpose

#### 3. Initialize Terraform

```bash
terraform init
```

**Expected Output**:
```
Initializing the backend...
Successfully configured the backend "s3"!
Initializing provider plugins...
- Installing hashicorp/aws...
Terraform has been successfully initialized!
```

#### 4. Preview Changes

```bash
terraform plan
```

**Review the output carefully**:
- Ensure 4 resources will be created
- Verify variable values are correct
- Check that no unexpected changes appear

#### 5. Apply Configuration

```bash
terraform apply
```

**Interactive Prompt**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Type `yes` and press Enter.

**Expected Duration**: 10-30 seconds

#### 6. Retrieve Outputs

```bash
# View all outputs
terraform output

# View specific sensitive outputs
terraform output access_key
terraform output secret_key
```

**Example Output**:
```
bucket_name = "my-choreo-data-bucket-2024"
bucket_arn = "arn:aws:s3:::my-choreo-data-bucket-2024"
s3_connection_url = "s3://my-choreo-data-bucket-2024"
access_key = "AKIAIOSFODNN7EXAMPLE"
secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

#### 7. Test Access

```bash
# Configure AWS CLI with new credentials
export AWS_ACCESS_KEY_ID=$(terraform output -raw access_key)
export AWS_SECRET_ACCESS_KEY=$(terraform output -raw secret_key)

# Test upload
echo "Hello from Terraform!" > test.txt
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/

# Test download
aws s3 cp s3://$(terraform output -raw bucket_name)/test.txt downloaded.txt

# Test delete
aws s3 rm s3://$(terraform output -raw bucket_name)/test.txt
```

---


### Setup Steps for Choreo

#### 1. Run Terraform (One-Time Setup)


```bash
terraform init
terraform apply
```

#### 2. Extract Credentials

```bash
# Save outputs to a secure file (DO NOT COMMIT)
terraform output -json > terraform-outputs.json

# Or copy individually
terraform output access_key
terraform output secret_key
terraform output bucket_name
```


## Security Considerations

### 🔐 Credential Management

**DO**:
- ✅ Store credentials in Choreo's secret management system
- ✅ Rotate access keys periodically (every 90 days recommended)
- ✅ Use different credentials for dev/staging/production environments
- ✅ Monitor access key usage in AWS CloudTrail
- ✅ Enable MFA on your AWS account

**DON'T**:
- ❌ Commit `terraform.tfstate` to version control (contains secrets)
- ❌ Commit `terraform.tfvars` if it contains sensitive data
- ❌ Share access keys via email, chat, or unencrypted channels
- ❌ Use the same credentials across multiple projects
- ❌ Log or print secret keys in application code

### 🛡️ Least Privilege

The bucket policy grants only these permissions:
- `s3:PutObject` - Write files
- `s3:GetObject` - Read files
- `s3:DeleteObject` - Delete files

**Not granted** (good):
- `s3:DeleteBucket` - Cannot delete the bucket itself
- `s3:PutBucketPolicy` - Cannot change permissions
- Access to other buckets or AWS services

### 📊 Auditing

**Enable CloudTrail** to log all S3 API calls:

```hcl
# Add to main.tf if needed
resource "aws_cloudtrail" "s3_audit" {
  name                          = "s3-audit-trail"
  s3_bucket_name                = "<logging-bucket>"
  include_global_service_events = true
}
```

**Monitor Access**:
```bash
# Check who accessed your bucket
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<bucket-name>
```

### 🔒 Encryption

**At-Rest Encryption** (add to `main.tf`):

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**In-Transit Encryption**:
- AWS SDK uses HTTPS by default
- Enforce HTTPS-only access with bucket policy

### 🚨 What to Do If Credentials Are Compromised

1. **Immediately delete the access key**:
   ```bash
   aws iam delete-access-key \
     --access-key-id <COMPROMISED_KEY_ID> \
     --user-name <USER_NAME>
   ```

2. **Review CloudTrail logs** for unauthorized activity

3. **Create new access key**:
   ```bash
   terraform apply -replace=aws_iam_access_key.writer_key
   ```

4. **Update credentials in Choreo** with new values

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Backend Initialization Failed

**Error**:
```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**Cause**: The S3 bucket for Terraform state doesn't exist.

**Solution**:
```bash
# Create the backend bucket first
aws s3 mb s3://terraform-state-bucket-lakshans-1 --region us-east-1
aws dynamodb create-table \
  --table-name terraform-lock-table-1 \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

---

#### 2. Bucket Name Already Exists

**Error**:
```
Error: Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Cause**: S3 bucket names are globally unique. Someone else is using that name.

**Solution**:
```hcl
# In terraform.tfvars, change bucket_name to something unique
bucket_name = "my-company-choreo-bucket-2024-abc123"
```

---

#### 3. Access Denied in Choreo Pipeline

**Error**:
```
botocore.exceptions.ClientError: An error occurred (AccessDenied) when calling the PutObject operation
```

**Cause**:
- Wrong credentials configured
- Bucket policy not yet applied
- Bucket doesn't exist

**Solution**:
```bash
# Verify credentials are correct
terraform output access_key
terraform output secret_key

# Check if bucket exists
aws s3 ls s3://$(terraform output -raw bucket_name)/

# Verify bucket policy
aws s3api get-bucket-policy --bucket $(terraform output -raw bucket_name)
```

---

#### 4. State Locking Error

**Error**:
```
Error: Error acquiring the state lock
```

**Cause**: Another Terraform process is running or crashed without releasing the lock.

**Solution**:
```bash
# Wait for other Terraform process to complete, or force unlock
terraform force-unlock <LOCK_ID>
```

---

#### 5. Permission Denied During Apply

**Error**:
```
Error: Error creating IAM User: AccessDenied: User is not authorized to perform: iam:CreateUser
```

**Cause**: Your AWS credentials don't have permission to create IAM resources.

**Solution**:
- Ask your AWS administrator to grant IAM permissions
- Or use an AWS account where you have admin access
- Required permissions: `iam:*`, `s3:*` (or more granular policies)

---

#### 6. Cannot Destroy Bucket with Objects

**Error**:
```
Error: Error deleting S3 Bucket: BucketNotEmpty: The bucket you tried to delete is not empty
```

**Cause**: Even with `force_destroy = true`, sometimes AWS API timing can cause issues.

**Solution**:
```bash
# Manually empty the bucket first
aws s3 rm s3://$(terraform output -raw bucket_name)/ --recursive

# Then retry destroy
terraform destroy
```

---

## Maintenance and Updates

### Updating the Infrastructure

```bash
# 1. Pull latest code
git pull

# 2. Review what changed
terraform plan

# 3. Apply updates
terraform apply
```

### Rotating Access Keys

```bash
# Force recreation of access key
terraform apply -replace=aws_iam_access_key.writer_key

# Update credentials in Choreo immediately
```

### Cleaning Up

To destroy all resources:

```bash
# Preview what will be deleted
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

**Note**: This will:
- Delete the S3 bucket and all its contents (due to `force_destroy = true`)
- Delete the IAM user and access keys
- Remove the bucket policy

---

## Summary

This Terraform module provides a **production-ready, secure, and automated** way to provision S3 infrastructure for Choreo pipelines. It handles:

✅ **Infrastructure as Code**: All resources defined in version-controlled Terraform
✅ **Security**: IAM-based access with least-privilege permissions
✅ **State Management**: Remote state in S3 with DynamoDB locking
✅ **Automation-Ready**: Outputs provide everything needed for CI/CD integration
✅ **Reusable**: Variables make it easy to deploy multiple environments

### Quick Reference

| File | Purpose |
|------|---------|
| `main.tf` | Resource definitions (IAM user, S3 bucket, policies) |
| `variables.tf` | Input parameters (region, bucket name, user name) |
| `outputs.tf` | Output values (credentials, bucket info) |

### Key Outputs for Choreo

```bash
terraform output access_key        # AWS_ACCESS_KEY_ID
terraform output secret_key        # AWS_SECRET_ACCESS_KEY
terraform output bucket_name       # S3_BUCKET_NAME
terraform output s3_connection_url # s3://bucket-name
```

---

**Need Help?**
- AWS Terraform Documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Terraform Language Docs: https://www.terraform.io/language
- AWS S3 Documentation: https://docs.aws.amazon.com/s3/
- Choreo Documentation: https://wso2.com/choreo/docs/

---

*Generated for Choreo automation pipeline integration*
