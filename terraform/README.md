# Terraform Infrastructure as Code

This directory contains all Terraform configuration files for managing the PickStream GKE infrastructure on Google Cloud Platform.

## 📚 What is Terraform?

**Terraform** is an Infrastructure as Code (IaC) tool that allows you to define and provision cloud infrastructure using declarative configuration files. Instead of manually clicking through the GCP Console to create resources, you write code that describes what you want, and Terraform creates it for you.

### Key Benefits:
- ✅ **Reproducible**: Same configuration creates identical infrastructure every time
- ✅ **Version Controlled**: Track changes to infrastructure over time in Git
- ✅ **Automated**: Deploy/update infrastructure with a single command
- ✅ **Safe**: Preview changes before applying them
- ✅ **Collaborative**: Multiple team members can work on infrastructure code

## 📁 Directory Structure

```
terraform/
├── modules/                    # Reusable infrastructure components
│   ├── artifact-registry/      # Docker image repository
│   ├── gke/                    # Kubernetes cluster
│   ├── iam/                    # Service accounts & permissions
│   └── networking/             # VPC, subnets, firewall
└── environments/               # Environment-specific configurations
    └── dev/                    # Development environment
        ├── main.tf             # Main configuration
        ├── variables.tf        # Input variables
        ├── outputs.tf          # Output values
        ├── terraform.tfvars    # Variable values
        └── backend.tf          # State storage config
```

## 🧩 Understanding Modules

**Modules** are like reusable building blocks or functions in programming. Each module encapsulates a specific piece of infrastructure.

### Module: `artifact-registry/`
**Purpose**: Creates a Docker repository for storing container images

**What it does**:
- Creates an Artifact Registry repository named "pickstream"
- Sets up IAM permissions so:
  - GKE nodes can **pull** images (download)
  - GitHub Actions can **push** images (upload)
- Location: `us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream`

**Files**:
- `main.tf`: Creates the registry and IAM bindings
- `variables.tf`: Accepts inputs (project_id, location, repository_id)
- `outputs.tf`: Exports registry URL and repository details

**Real-world analogy**: Like creating a private Docker Hub for your company

---

### Module: `gke/`
**Purpose**: Creates the Google Kubernetes Engine (GKE) cluster

**What it does**:
- Creates a zonal Kubernetes cluster in `us-central1-a`
- Sets up two node pools:
  - **System Pool**: For Kubernetes system components (1-3 e2-medium nodes)
  - **Application Pool**: For your applications (1-5 e2-medium nodes)
- Enables features:
  - Workload Identity (secure authentication for pods)
  - Network Policy (firewall rules between pods)
  - Binary Authorization (only verified images can run)
  - Auto-repair (replaces unhealthy nodes)
  - Auto-upgrade (keeps cluster up to date)

**Files**:
- `main.tf`: Cluster and node pool configuration
- `variables.tf`: Cluster name, region, machine types, node counts
- `outputs.tf`: Cluster endpoint, CA certificate, location

**Key Concepts**:
- **Node Pool**: Group of identical virtual machines that run your containers
- **Machine Type**: `e2-medium` = 2 vCPU, 4GB RAM (cost-optimized)
- **Autoscaling**: Automatically adds/removes nodes based on workload
- **Taints/Tolerations**: System pool is "tainted" so only system pods run there

**Real-world analogy**: Like renting a managed Kubernetes cluster with automatic scaling

---

### Module: `iam/`
**Purpose**: Manages service accounts and permissions

**What it does**:
- References the existing GitHub Actions service account
- Creates service accounts for:
  - **Node SA**: Used by GKE nodes to access GCP services
  - **Workload SA**: Used by application pods with Workload Identity
  - **Artifact SA**: Specialized access for pulling container images
- Assigns IAM roles (permissions) to each service account

**Files**:
- `main.tf`: Service accounts and IAM role bindings
- `variables.tf`: Project ID, cluster name, service account details
- `outputs.tf`: Service account emails

**Key Concepts**:
- **Service Account**: Non-human identity used by applications/services
- **IAM Role**: Collection of permissions (e.g., `roles/logging.logWriter`)
- **Principle of Least Privilege**: Each account gets only the permissions it needs

**IAM Roles Explained**:
```
roles/logging.logWriter           → Can write logs to Cloud Logging
roles/monitoring.metricWriter     → Can send metrics to Cloud Monitoring
roles/container.admin             → Full control over GKE clusters
roles/artifactregistry.reader     → Can download images from Artifact Registry
roles/artifactregistry.writer     → Can upload images to Artifact Registry
```

**Real-world analogy**: Like creating different user accounts with specific access levels

---

### Module: `networking/`
**Purpose**: Creates the network infrastructure

**What it does**:
- Creates a VPC (Virtual Private Cloud) network
- Creates a private subnet for GKE nodes
- Sets up Cloud NAT (for internet access from private nodes)
- Configures firewall rules:
  - Allow internal cluster communication
  - Allow SSH access (for debugging)
  - Allow health checks from Google Load Balancers
  - Allow HTTP/HTTPS traffic to LoadBalancer services
  - Deny all other unsolicited incoming traffic

**Files**:
- `main.tf`: VPC, subnet, NAT, firewall rules
- `variables.tf`: Network names, IP ranges, project details
- `outputs.tf`: Network name, subnet name, NAT gateway info

**Key Concepts**:
- **VPC**: Your private network in GCP (isolated from other customers)
- **Subnet**: IP address range within the VPC (e.g., 10.0.0.0/24)
- **Private Nodes**: GKE nodes with no public IP (more secure)
- **Cloud NAT**: Allows private nodes to reach the internet (for updates, pulling images)
- **Firewall Rules**: Control what traffic is allowed/denied

**Firewall Rules Explained**:
```
allow-internal      → Pods can talk to each other
allow-ssh           → You can SSH into nodes for debugging
allow-health-check  → Google's load balancers can check if pods are healthy
allow-loadbalancer  → External users can reach your web services
deny-all (implicit) → Everything else is blocked by default
```

**Real-world analogy**: Like setting up a corporate network with security controls

---

## 🌍 Understanding Environments

The `environments/` directory contains environment-specific configurations. Currently, we have only `dev/`.

### Environment: `dev/`
**Purpose**: Development/testing environment with cost-optimized settings

**Key Files Explained**:

#### `main.tf` - The Orchestrator
This is the main entry point that ties everything together.

```hcl
# Think of this as the "main()" function in programming
# It calls each module and connects them together

module "networking" {
  source = "../../modules/networking"
  # Passes variables to the networking module
}

module "gke" {
  source = "../../modules/gke"
  # Uses outputs from networking module
  # network_name = module.networking.network_name
}

module "iam" {
  source = "../../modules/iam"
  # Creates service accounts
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"
  # Uses service account emails from IAM module
}
```

**What it does**: Calls each module in the correct order, passing data between them

---

#### `variables.tf` - Input Definitions
Defines what inputs the configuration accepts.

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}
```

**Think of variables as function parameters**. They make the configuration reusable for different projects or environments.

---

#### `terraform.tfvars` - Actual Values
Contains the actual values for the variables.

```hcl
project_id           = "gcp-terraform-demo-474514"
region               = "us-central1"
cluster_name         = "pickstream-cluster"
environment          = "dev"
system_machine_type  = "e2-medium"
app_machine_type     = "e2-medium"
system_node_count    = 1
app_node_count       = 1
```

**Real-world analogy**: Like a configuration file or `.env` file with your settings

**Important**: This file is tracked in Git because GitHub Actions needs these values. Normally, `.tfvars` files with secrets would be in `.gitignore`.

---

#### `outputs.tf` - Export Values
Defines what information to export after Terraform creates resources.

```hcl
output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.endpoint
  sensitive   = true  # Won't show in logs
}
```

**What it does**: Makes important values available for:
- GitHub Actions workflows (e.g., cluster endpoint for `kubectl`)
- Other Terraform configurations
- Documentation/debugging

**View outputs**: Run `terraform output` in the terminal

---

#### `backend.tf` - State Storage
Configures where Terraform stores its state file.

```hcl
terraform {
  backend "gcs" {
    bucket = "gcp-tftbk"
    prefix = "pickstream-infrastructure/dev/terraform/state"
  }
}
```

**What is state?**
- Terraform maintains a "state file" that tracks what resources exist
- Maps real-world resources to your configuration
- Required for Terraform to know what to update/delete

**Why use GCS backend?**
- ✅ Shared state (multiple people can run Terraform)
- ✅ State locking (prevents conflicts)
- ✅ Versioning (can recover from mistakes)
- ❌ Without remote backend, state is stored locally (doesn't work for teams)

**Real-world analogy**: Like a database that tracks what infrastructure exists

---

## 🔄 Terraform Workflow

### 1. **Initialize** (`terraform init`)
```bash
cd terraform/environments/dev
terraform init
```
**What it does**:
- Downloads provider plugins (google, google-beta)
- Connects to remote backend (GCS bucket)
- Prepares the working directory

**When to run**: 
- First time using the configuration
- After changing backend configuration
- After adding new providers

---

### 2. **Plan** (`terraform plan`)
```bash
terraform plan
```
**What it does**:
- Compares desired state (your `.tf` files) with actual state (what exists in GCP)
- Shows what will be created, updated, or destroyed
- **Does NOT make any changes** (safe to run)

**Example output**:
```
Terraform will perform the following actions:

  # google_container_cluster.primary will be created
  + resource "google_container_cluster" "primary" {
      + name     = "pickstream-cluster"
      + location = "us-central1-a"
      ...
    }

Plan: 15 to add, 0 to change, 0 to destroy.
```

**Think of it as**: A preview or dry-run

---

### 3. **Apply** (`terraform apply`)
```bash
terraform apply
```
**What it does**:
- Shows the plan again
- Asks for confirmation
- Creates/updates/deletes resources in GCP
- Updates the state file

**Example**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

google_container_cluster.primary: Creating...
google_container_cluster.primary: Still creating... [10s elapsed]
google_container_cluster.primary: Still creating... [20s elapsed]
...
google_container_cluster.primary: Creation complete after 5m32s

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
```

**Duration**: Creating a GKE cluster takes ~5-10 minutes

---

### 4. **Destroy** (`terraform destroy`)
```bash
terraform destroy
```
**What it does**:
- Deletes all resources managed by Terraform
- Asks for confirmation
- Updates state file to show resources are gone

**⚠️ Warning**: This deletes everything! Use carefully.

---

## 🔧 Common Terraform Commands

```bash
# Format code (make it pretty)
terraform fmt

# Validate configuration (check for errors)
terraform validate

# Show current state
terraform show

# List all resources
terraform state list

# View specific output
terraform output cluster_name

# View all outputs
terraform output

# Import existing resource (if created manually)
terraform import google_container_cluster.primary projects/PROJECT_ID/locations/ZONE/clusters/CLUSTER_NAME

# Refresh state (sync with reality)
terraform refresh

# Show execution plan and save it
terraform plan -out=tfplan

# Apply saved plan
terraform apply tfplan
```

---

## 📝 Terraform File Syntax Basics

### Resource Block
```hcl
# Creates a new resource
resource "google_container_cluster" "primary" {
  name     = "my-cluster"
  location = "us-central1-a"
  
  node_config {
    machine_type = "e2-medium"
  }
}

# Syntax: resource "TYPE" "NAME" { ... }
# TYPE: google_container_cluster (what kind of resource)
# NAME: primary (local name to reference it)
```

### Data Source Block
```hcl
# References an existing resource (doesn't create)
data "google_service_account" "existing" {
  account_id = "gcp-terraform-demo"
}

# Usage: data.google_service_account.existing.email
```

### Variable Block
```hcl
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "my-project"  # optional
}

# Usage: var.project_id
```

### Output Block
```hcl
output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}
```

### Module Block
```hcl
module "networking" {
  source = "../../modules/networking"
  
  project_id = var.project_id
  region     = var.region
}

# Usage: module.networking.network_name
```

### Locals Block
```hcl
locals {
  cluster_name = "${var.environment}-${var.cluster_name}"
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Usage: local.cluster_name
```

---

## 🎯 Best Practices

### 1. **Always Run Plan Before Apply**
```bash
terraform plan   # Review changes
terraform apply  # Only if plan looks good
```

### 2. **Use Version Control**
```bash
git add terraform/
git commit -m "Add GKE cluster configuration"
git push
```

### 3. **Use Remote Backend**
- Already configured with GCS bucket `gcp-tftbk`
- Enables team collaboration
- Provides state locking

### 4. **Use Variables for Reusability**
```hcl
# ❌ Bad: Hardcoded values
resource "google_container_cluster" "primary" {
  name = "pickstream-cluster"
  project = "gcp-terraform-demo-474514"
}

# ✅ Good: Using variables
resource "google_container_cluster" "primary" {
  name = var.cluster_name
  project = var.project_id
}
```

### 5. **Use Modules for Reusability**
```hcl
# ❌ Bad: Everything in one file
# main.tf with 1000+ lines

# ✅ Good: Organized in modules
module "gke" { source = "../../modules/gke" }
module "iam" { source = "../../modules/iam" }
```

### 6. **Use Descriptive Names**
```hcl
# ❌ Bad
resource "google_container_cluster" "c" { ... }

# ✅ Good
resource "google_container_cluster" "primary" { ... }
```

### 7. **Add Comments and Documentation**
```hcl
# Creates the main GKE cluster for the PickStream application
# Uses zonal configuration for cost optimization
resource "google_container_cluster" "primary" {
  name = var.cluster_name
  ...
}
```

---

## 🐛 Troubleshooting

### Issue: `Error: Backend initialization required`
**Solution**: Run `terraform init`

### Issue: `Error: state lock could not be acquired`
**Cause**: Another Terraform process is running or crashed
**Solution**:
```bash
# Wait for other process to finish, or force unlock (careful!)
terraform force-unlock LOCK_ID
```

### Issue: `Error: Provider configuration not present`
**Cause**: Missing provider credentials
**Solution**:
```bash
# Authenticate with GCP
gcloud auth application-default login
```

### Issue: Changes show even when nothing changed
**Cause**: State is out of sync
**Solution**:
```bash
terraform refresh
terraform plan
```

### Issue: `Error: Resource already exists`
**Cause**: Resource was created manually
**Solution**:
```bash
# Import existing resource
terraform import RESOURCE_TYPE.NAME RESOURCE_ID
```

---

## 📚 Learning Resources

### Official Documentation
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Cloud Documentation](https://cloud.google.com/docs)

### Tutorials
- [Terraform Getting Started](https://learn.hashicorp.com/terraform)
- [Provision a GKE Cluster](https://learn.hashicorp.com/tutorials/terraform/gke)

### Key Concepts to Learn
1. **Resources**: The building blocks (VMs, networks, databases)
2. **Providers**: Plugins that interact with APIs (google, aws, azure)
3. **State**: Terraform's knowledge of what exists
4. **Modules**: Reusable components
5. **Variables**: Make configurations flexible
6. **Outputs**: Export information
7. **Dependencies**: How resources depend on each other

---

## 🔐 Security Notes

### Sensitive Data
- **Service Account Keys**: Stored as GitHub secret, never committed to Git
- **Cluster Endpoint**: Marked as `sensitive` in outputs
- **Terraform State**: Contains sensitive data, stored in secure GCS bucket

### IAM Best Practices
- ✅ Use service accounts (not personal accounts) for automation
- ✅ Grant minimum required permissions
- ✅ Regularly audit IAM policies
- ✅ Rotate service account keys periodically

---

## 💡 Quick Reference

```bash
# Common workflow
cd terraform/environments/dev
terraform init          # Setup
terraform fmt          # Format code
terraform validate     # Check syntax
terraform plan         # Preview changes
terraform apply        # Make changes
terraform output       # View outputs

# View what exists
terraform state list
terraform show

# Cleanup
terraform destroy      # Delete everything
```

---

**Need Help?**
- Check [docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)
- Review Terraform documentation
- Check GitHub Actions logs for deployment issues
