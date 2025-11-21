# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for automating infrastructure deployment using Terraform.

## 📚 What is GitHub Actions?

**GitHub Actions** is a CI/CD (Continuous Integration / Continuous Deployment) platform that automates software workflows. Instead of manually running Terraform commands on your laptop, GitHub Actions runs them automatically when certain events happen (like pushing code or clicking a button).

### Key Benefits:
- ✅ **Automation**: Deploy infrastructure with a button click
- ✅ **Consistency**: Same steps every time, no human error
- ✅ **Auditability**: All changes logged in GitHub
- ✅ **Security**: No need for local GCP credentials
- ✅ **Collaboration**: Team members can deploy without local setup

## 📁 Directory Structure

```
.github/
└── workflows/                      # Workflow definitions
    ├── terraform-plan.yml          # Preview infrastructure changes
    ├── terraform-apply.yml         # Deploy infrastructure
    └── terraform-destroy.yml       # Destroy infrastructure
```

## 🔄 Understanding Workflows

A **workflow** is an automated process defined in a YAML file. Each workflow contains:
- **Trigger**: When to run (push, pull request, manual button)
- **Jobs**: What to do (checkout code, run tests, deploy)
- **Steps**: Individual commands within a job
- **Actions**: Reusable commands (like functions)

---

## 📄 Workflow Files Explained

### 1. `terraform-plan.yml` - Preview Changes

**Purpose**: Shows what changes Terraform will make WITHOUT actually making them. Think of it as a "preview" or "dry run".

**When it runs**: 
- ⚡ **Manual trigger only** (you click "Run workflow" button)

**What it does**:
```
1. Checks out your code from GitHub
2. Authenticates with GCP using service account
3. Sets up Terraform
4. Initializes Terraform (downloads providers)
5. Validates configuration (checks for errors)
6. Formats check (ensures code is properly formatted)
7. Runs terraform plan (shows what will change)
```

**How to run**:
1. Go to GitHub repository
2. Click "Actions" tab
3. Click "Terraform Plan" workflow
4. Click "Run workflow" button
5. Select environment: `dev`
6. Click green "Run workflow" button
7. Wait for completion (~2-3 minutes)
8. Review the plan output

**Example output**:
```
Terraform will perform the following actions:

  # google_container_cluster.primary will be updated in-place
  ~ resource "google_container_cluster" "primary" {
      ~ initial_node_count = 1 -> 2
        name              = "pickstream-cluster"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**Key sections of the file**:

```yaml
name: 'Terraform Plan'
# The display name you see in GitHub Actions

on:
  workflow_dispatch:
# Trigger: Manual button click only

inputs:
  environment:
    description: 'Environment to plan'
    required: true
    default: 'dev'
# Asks which environment when you click the button

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    # Runs on GitHub's Ubuntu servers
    
    steps:
    - uses: actions/checkout@v4
      # Downloads your repository code
    
    - id: 'auth'
      uses: 'google-github-actions/auth@v2'
      with:
        credentials_json: '${{ secrets.GCP_SA_KEY }}'
      # Logs into GCP using secret service account key
    
    - uses: 'google-github-actions/setup-gcloud@v2'
      # Installs gcloud CLI
    
    - uses: hashicorp/setup-terraform@v3
      # Installs Terraform
    
    - name: Terraform Init
      run: terraform init
      # Prepares Terraform
    
    - name: Terraform Plan
      run: terraform plan
      # Shows what will change
```

---

### 2. `terraform-apply.yml` - Deploy Infrastructure

**Purpose**: Actually creates/updates the infrastructure in GCP. This makes REAL changes.

**When it runs**: 
- ⚡ **Manual trigger only** (you click "Run workflow" button)

**What it does**:
```
1. Checks out your code from GitHub
2. Authenticates with GCP using service account
3. Sets up Terraform and gcloud
4. Initializes Terraform
5. Runs terraform apply (creates/updates resources)
6. Configures kubectl (for accessing the cluster)
7. Displays important outputs (cluster name, endpoint, etc.)
```

**How to run**:
1. **IMPORTANT**: Run `terraform-plan.yml` first to review changes!
2. Go to GitHub repository
3. Click "Actions" tab
4. Click "Terraform Apply" workflow
5. Click "Run workflow" button
6. Select environment: `dev`
7. Click green "Run workflow" button
8. Wait for completion (~10-15 minutes for first run, faster for updates)

**⚠️ Warning**: This workflow makes REAL changes to your GCP infrastructure. Always review the plan first!

**Key sections**:

```yaml
name: 'Terraform Apply'

on:
  workflow_dispatch:
# Manual trigger only (safety measure)

env:
  TF_VAR_project_id: ${{ secrets.GCP_PROJECT_ID || 'gcp-terraform-demo-474514' }}
# Sets environment variables for Terraform

steps:
  - name: Terraform Apply
    run: terraform apply -auto-approve
    # -auto-approve skips confirmation (since you already clicked the button)
  
  - name: Get cluster credentials
    run: |
      PROJECT_ID=$(terraform output -raw project_id)
      gcloud container clusters get-credentials pickstream-cluster \
        --zone=us-central1-a \
        --project=${PROJECT_ID}
    # Configures kubectl to access the new cluster
  
  - name: Verify cluster
    run: |
      kubectl get nodes
      kubectl cluster-info
    # Tests that the cluster is working
```

**What happens during apply**:
```
Terraform Apply Progress:

[1/15] Creating VPC network...                    ✓ (30s)
[2/15] Creating subnet...                         ✓ (20s)
[3/15] Creating Cloud NAT...                      ✓ (45s)
[4/15] Creating firewall rules...                 ✓ (30s)
[5/15] Creating service accounts...               ✓ (10s)
[6/15] Creating IAM bindings...                   ✓ (15s)
[7/15] Creating Artifact Registry...              ✓ (25s)
[8/15] Creating GKE cluster...                    ✓ (5m 30s)
[9/15] Creating system node pool...               ✓ (2m)
[10/15] Creating app node pool...                 ✓ (2m)
...

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:
cluster_name = "pickstream-cluster"
cluster_endpoint = <sensitive>
artifact_registry_url = "us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream"
```

---

### 3. `terraform-destroy.yml` - Destroy Infrastructure

**Purpose**: Deletes ALL infrastructure created by Terraform. Use this to clean up when you're done or to start fresh.

**When it runs**: 
- ⚡ **Manual trigger only** (you click "Run workflow" button)

**What it does**:
```
1. Checks out your code from GitHub
2. Authenticates with GCP
3. Sets up Terraform
4. Initializes Terraform
5. Runs terraform destroy (deletes all resources)
```

**How to run**:
1. Go to GitHub repository
2. Click "Actions" tab
3. Click "Terraform Destroy" workflow
4. Click "Run workflow" button
5. Select environment: `dev`
6. Type: `destroy` (confirmation)
7. Click green "Run workflow" button
8. Wait for completion (~10 minutes)

**⚠️ CRITICAL WARNING**: 
- This PERMANENTLY DELETES all infrastructure
- GKE cluster will be destroyed
- All deployed applications will be lost
- Data will be lost (unless backed up)
- This action CANNOT be undone

**Key sections**:

```yaml
name: 'Terraform Destroy'

on:
  workflow_dispatch:
    inputs:
      confirmation:
        description: 'Type "destroy" to confirm'
        required: true
# Extra safety: Must type "destroy" to proceed

steps:
  - name: Verify confirmation
    run: |
      if [ "${{ github.event.inputs.confirmation }}" != "destroy" ]; then
        echo "Confirmation failed. You must type 'destroy' to proceed."
        exit 1
      fi
    # Checks that you typed "destroy" correctly
  
  - name: Terraform Destroy
    run: terraform destroy -auto-approve
    # Deletes everything
```

**What happens during destroy**:
```
Terraform Destroy Progress:

[1/15] Destroying app node pool...                ✓ (2m)
[2/15] Destroying system node pool...             ✓ (2m)
[3/15] Destroying GKE cluster...                  ✓ (5m)
[4/15] Destroying Artifact Registry...            ✓ (20s)
[5/15] Destroying IAM bindings...                 ✓ (15s)
[6/15] Destroying service accounts...             ✓ (10s)
[7/15] Destroying firewall rules...               ✓ (20s)
[8/15] Destroying Cloud NAT...                    ✓ (30s)
[9/15] Destroying subnet...                       ✓ (20s)
[10/15] Destroying VPC network...                 ✓ (30s)

Destroy complete! Resources: 15 destroyed.
```

---

## 🔐 GitHub Secrets

Workflows use **secrets** to store sensitive information securely. Secrets are never shown in logs.

### Required Secret:

| Secret Name | Purpose | How to Get |
|-------------|---------|------------|
| `GCP_SA_KEY` | Service account JSON key for authentication | Created in GCP Console → IAM & Admin → Service Accounts → Keys |

### How to Add a Secret:
1. Go to your GitHub repository
2. Click "Settings" tab
3. Click "Secrets and variables" → "Actions"
4. Click "New repository secret"
5. Name: `GCP_SA_KEY`
6. Value: Paste the entire JSON key file contents
7. Click "Add secret"

**Security Notes**:
- ✅ Secrets are encrypted at rest
- ✅ Secrets are masked in logs
- ✅ Only workflows can access secrets
- ❌ Never commit secrets to Git
- ❌ Never print secrets in logs

---

## 🎯 Common Workflows

### Workflow 1: Initial Infrastructure Setup
```
1. Review code locally
2. Commit and push to GitHub
3. Run "Terraform Plan" workflow → Review output
4. Run "Terraform Apply" workflow → Creates infrastructure
5. Wait ~10-15 minutes
6. Check outputs for cluster details
```

### Workflow 2: Making Changes
```
1. Modify Terraform files locally
2. Commit and push to GitHub
3. Run "Terraform Plan" workflow → Review what will change
4. If plan looks good, run "Terraform Apply" workflow
5. Wait for completion
6. Verify changes in GCP Console
```

### Workflow 3: Cleanup
```
1. Run "Terraform Destroy" workflow
2. Type "destroy" to confirm
3. Wait ~10 minutes
4. Verify in GCP Console that resources are gone
```

---

## 🔧 Workflow Components Explained

### Actions (Reusable Steps)

#### `actions/checkout@v4`
Downloads your repository code to the GitHub runner.
```yaml
- uses: actions/checkout@v4
```

#### `google-github-actions/auth@v2`
Authenticates with Google Cloud using a service account key.
```yaml
- uses: google-github-actions/auth@v2
  with:
    credentials_json: '${{ secrets.GCP_SA_KEY }}'
```

#### `google-github-actions/setup-gcloud@v2`
Installs and configures the gcloud CLI with GKE auth plugin.
```yaml
- uses: google-github-actions/setup-gcloud@v2
  with:
    install_components: 'gke-gcloud-auth-plugin'
```

#### `hashicorp/setup-terraform@v3`
Installs Terraform.
```yaml
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.6.0
```

### Expressions and Variables

#### Secrets Reference
```yaml
${{ secrets.GCP_SA_KEY }}
# Accesses the GCP_SA_KEY secret
```

#### Input Reference
```yaml
${{ github.event.inputs.environment }}
# Gets the environment selected when clicking "Run workflow"
```

#### Environment Variables
```yaml
env:
  GOOGLE_APPLICATION_CREDENTIALS: /tmp/gcp-key.json
  TF_VAR_project_id: gcp-terraform-demo-474514
```

#### Working Directory
```yaml
defaults:
  run:
    working-directory: terraform/environments/dev
# All commands run in this directory
```

---

## 📊 Viewing Workflow Runs

### How to View a Running Workflow:
1. Go to GitHub repository
2. Click "Actions" tab
3. Click on the workflow run (you'll see a yellow dot while running)
4. Click on the job name (e.g., "terraform-apply")
5. Watch real-time logs

### Log Sections:
```
Set up job                  ✓ (5s)
Run actions/checkout@v4     ✓ (2s)
Authenticate to GCP         ✓ (3s)
Set up gcloud CLI          ✓ (10s)
Setup Terraform            ✓ (5s)
Terraform Init             ✓ (30s)
Terraform Plan             ✓ (45s)
Terraform Apply            ⏳ (running...)
Get cluster credentials    ⏳ (pending)
Verify cluster             ⏳ (pending)
```

### Understanding Icons:
- ✓ Green check: Step succeeded
- ✗ Red X: Step failed
- ⏳ Yellow dot: Step running
- ⊙ Gray circle: Step pending

---

## 🐛 Troubleshooting

### Issue: Workflow fails with "Error: Failed to get existing workspaces"
**Cause**: GCS bucket doesn't exist or no access
**Solution**: 
- Check that bucket `gcp-tftbk` exists
- Verify service account has `roles/storage.admin`

### Issue: "Error: Error creating Cluster: googleapi: Error 403"
**Cause**: Service account lacks permissions
**Solution**:
```bash
# Grant required roles
gcloud projects add-iam-policy-binding gcp-terraform-demo-474514 \
  --member="serviceAccount:gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com" \
  --role="roles/container.admin"
```

### Issue: "Error: executable gke-gcloud-auth-plugin not found"
**Cause**: GKE auth plugin not installed
**Solution**: Already fixed in workflow with:
```yaml
- uses: google-github-actions/setup-gcloud@v2
  with:
    install_components: 'gke-gcloud-auth-plugin'
```

### Issue: Workflow stuck on "Terraform Init"
**Cause**: Backend already initialized by another run
**Solution**: Wait or cancel and retry

### Issue: Apply fails with "state lock could not be acquired"
**Cause**: Another workflow is running
**Solution**: Wait for other workflow to finish

### How to Debug:
1. Click on the failed step in GitHub Actions
2. Expand the log
3. Look for error messages (usually at the end)
4. Copy error message and search documentation

---

## 📚 YAML Syntax Basics

### Basic Structure
```yaml
name: 'My Workflow'           # Display name
on: push                       # When to trigger
jobs:                          # What to do
  my-job:                      # Job name
    runs-on: ubuntu-latest     # What machine
    steps:                     # Steps in the job
      - name: Step 1           # Step name
        run: echo "Hello"      # Command to run
```

### Lists
```yaml
steps:
  - name: First step
  - name: Second step
  - name: Third step
```

### Multi-line Strings
```yaml
run: |
  echo "Line 1"
  echo "Line 2"
  echo "Line 3"
```

### Conditionals
```yaml
- name: Only on main branch
  if: github.ref == 'refs/heads/main'
  run: echo "Main branch"
```

### Outputs
```yaml
- id: get_value
  run: echo "value=hello" >> $GITHUB_OUTPUT

- name: Use output
  run: echo "${{ steps.get_value.outputs.value }}"
```

---

## 🎓 Learning Resources

### GitHub Actions Documentation
- [GitHub Actions Quickstart](https://docs.github.com/en/actions/quickstart)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)

### Google Cloud Actions
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
- [google-github-actions/setup-gcloud](https://github.com/google-github-actions/setup-gcloud)

### Terraform with GitHub Actions
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [Terraform Automation Tutorial](https://learn.hashicorp.com/tutorials/terraform/github-actions)

---

## 🔄 Workflow Decision Tree

```
Do you want to see what will change?
└─→ YES → Run "Terraform Plan"
    └─→ Changes look good?
        └─→ YES → Run "Terraform Apply"
        └─→ NO → Fix Terraform code, commit, push, repeat

Do you want to deploy infrastructure?
└─→ YES → Run "Terraform Plan" first, then "Terraform Apply"

Do you want to delete everything?
└─→ YES → Run "Terraform Destroy" (type "destroy" to confirm)
    └─→ Are you REALLY sure?
        └─→ YES → Proceeds with deletion
        └─→ NO → Workflow exits safely
```

---

## 💡 Best Practices

### 1. Always Plan Before Apply
```
❌ Bad: Directly run terraform apply
✅ Good: terraform plan → review → terraform apply
```

### 2. Use Meaningful Commit Messages
```
❌ Bad: "update files"
✅ Good: "feat: increase GKE node pool from 1 to 2 nodes"
```

### 3. Review Workflow Logs
Even if successful, check logs for warnings:
```yaml
Warning: This resource is deprecated
Warning: Large initial_node_count can be expensive
```

### 4. Use Manual Triggers for Infrastructure
```yaml
on:
  workflow_dispatch:  # ✅ Explicit, intentional
  
# Avoid automatic triggers for infrastructure
on:
  push:               # ❌ Too risky for infrastructure
```

### 5. Add Confirmations for Destructive Actions
```yaml
- name: Verify confirmation
  if: github.event.inputs.confirmation != 'destroy'
  run: exit 1
```

---

## 📋 Quick Reference

### Running Workflows
1. Go to GitHub → Actions tab
2. Select workflow from left sidebar
3. Click "Run workflow" button
4. Fill in inputs (environment, confirmation)
5. Click green "Run workflow"
6. Monitor progress in real-time

### Checking Results
```bash
# After Terraform Apply completes:
- Check "Outputs" section for cluster details
- Verify in GCP Console (Kubernetes Engine)
- Test with kubectl commands
```

### When Things Go Wrong
1. Check workflow logs (click on failed step)
2. Read error message carefully
3. Check GCP quotas and permissions
4. Review Terraform state
5. Manually fix in GCP Console if needed
6. Run `terraform refresh` to sync state

---

**Need Help?**
- Check workflow logs in GitHub Actions
- Review [Terraform README](../terraform/README.md)
- Check [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
- GitHub Actions documentation
