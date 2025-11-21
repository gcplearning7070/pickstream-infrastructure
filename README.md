# PickStream Infrastructure

Terraform configuration for provisioning Google Kubernetes Engine (GKE) infrastructure for the PickStream microservices application.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         GCP Project: gcp-terraform-demo-474514              │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         VPC Network (pickstream-cluster-network)       │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │      GKE Zonal Cluster (us-central1-a)           │ │ │
│  │  │  ┌───────────────┐    ┌───────────────────────┐ │ │ │
│  │  │  │ System Pool   │    │   Application Pool    │ │ │ │
│  │  │  │ 1x e2-medium  │    │   1x e2-medium        │ │ │ │
│  │  │  │ (1-3 nodes)   │    │   (1-5 nodes)         │ │ │ │
│  │  │  └───────────────┘    └───────────────────────┘ │ │ │
│  │  │                                                  │ │ │
│  │  │  Workload Identity, Network Policy, Private     │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                                                        │ │
│  │  Cloud NAT  ←→  LoadBalancer Services                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │   Artifact Registry: us-central1-docker.pkg.dev       │ │
│  │   Repository: pickstream                               │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Current Configuration

### Project Details
- **Project ID**: `gcp-terraform-demo-474514`
- **Region**: `us-central1`
- **Zone**: `us-central1-a` (zonal cluster for cost optimization)
- **Environment**: `dev`
- **Service Account**: `gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com`

### Infrastructure Components

#### 1. GKE Cluster
- **Name**: `pickstream-cluster`
- **Type**: Zonal (single zone for cost savings)
- **Node Pools**:
  - **System Pool**: 1-3 e2-medium nodes (tainted for system workloads)
  - **Application Pool**: 1-5 e2-medium nodes (for application workloads)
- **Features**:
  - ✅ Workload Identity enabled
  - ✅ Network Policy enabled
  - ✅ Binary Authorization enabled (PROJECT_SINGLETON_POLICY_ENFORCE)
  - ✅ Private nodes with public endpoint
  - ✅ Autoscaling enabled
  - ✅ Auto-repair and auto-upgrade enabled

#### 2. Networking
- **VPC Network**: `pickstream-cluster-network`
- **Subnet**: Private subnet for GKE nodes
- **Cloud NAT**: For internet egress from private nodes
- **Firewall Rules**:
  - Allow internal traffic
  - Allow SSH from specific ranges
  - Allow health checks (35.191.0.0/16, 130.211.0.0/22)
  - Allow HTTP/HTTPS for LoadBalancer services
  - Deny all other ingress (default deny)

#### 3. Artifact Registry
- **Location**: `us-central1`
- **Repository ID**: `pickstream`
- **Format**: Docker
- **URL**: `us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream`
- **IAM**: 
  - GKE nodes have `artifactregistry.reader` role
  - GitHub Actions SA has `artifactregistry.writer` role

#### 4. IAM & Service Accounts

##### GitHub Actions Service Account (Existing)
- **Email**: `gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com`
- **Purpose**: Terraform deployment and CI/CD automation
- **Roles**:
  - `roles/compute.admin`
  - `roles/container.admin`
  - `roles/iam.serviceAccountAdmin`
  - `roles/iam.serviceAccountUser`
  - `roles/resourcemanager.projectIamAdmin`
  - `roles/artifactregistry.admin`
  - `roles/iam.workloadIdentityPoolAdmin`
  - `roles/artifactregistry.writer` (for pushing images)
  - `roles/container.developer` (for kubectl access)

##### GKE Node Service Account (Terraform-managed)
- **Email**: `pickstream-cluster-nodes-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com`
- **Purpose**: GKE nodes runtime
- **Roles**:
  - `roles/logging.logWriter`
  - `roles/monitoring.metricWriter`
  - `roles/monitoring.viewer`
  - `roles/stackdriver.resourceMetadata.writer`
  - `roles/artifactregistry.reader`

##### Workload Identity Service Account (Terraform-managed)
- **Email**: `pickstream-cluster-workload-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com`
- **Purpose**: Kubernetes pods with Workload Identity

##### Artifact Registry Service Account (Terraform-managed)
- **Email**: `pickstream-cluster-artifact-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com`
- **Purpose**: Pulling images from Artifact Registry
- **Roles**: `roles/artifactregistry.reader`

#### 5. Workload Identity Federation (Manual Setup)
**Note**: This is managed manually outside Terraform to avoid deletion conflicts.

After cluster creation, create manually:

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-actions-pool \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions" \
  --project=gcp-terraform-demo-474514

# Create OIDC Provider
gcloud iam workload-identity-pools providers create-oidc github-actions-provider \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'gcpt0801'" \
  --project=gcp-terraform-demo-474514

# Bind service account
gcloud iam service-accounts add-iam-policy-binding gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/gcpt0801/pickstream-app" \
  --project=gcp-terraform-demo-474514
```

## 📁 Repository Structure

```
pickstream-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── artifact-registry/  # Artifact Registry module
│   │   ├── gke/                # GKE cluster module
│   │   ├── iam/                # Service accounts & IAM
│   │   └── networking/         # VPC, subnets, NAT, firewall
│   └── environments/
│       └── dev/
│           ├── main.tf              # Module integration
│           ├── variables.tf         # Input variables
│           ├── outputs.tf           # Output values
│           ├── terraform.tfvars     # Variable values
│           └── backend.tf           # State backend config
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml       # Manual plan workflow
│       ├── terraform-apply.yml      # Manual apply workflow
│       └── terraform-destroy.yml    # Manual destroy workflow
├── docs/
│   ├── SETUP.md                     # Detailed setup guide
│   └── TROUBLESHOOTING.md           # Common issues
└── README.md
```

## 🚀 Quick Start

### Prerequisites

**Tools Required:**
- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) >= 450.0.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28.0
- [Git](https://git-scm.com/downloads)

**GCP Setup:**
- Project: `gcp-terraform-demo-474514` already configured
- Service Account: `gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com` with required roles
- State Bucket: `gcp-tftbk` already created

### Deployment via GitHub Actions

The infrastructure is deployed using GitHub Actions workflows (manual trigger):

1. **Terraform Plan** - Preview changes
   - Go to: Actions → Terraform Plan → Run workflow
   - Select environment: `dev`
   - Review the plan output

2. **Terraform Apply** - Deploy infrastructure
   - Go to: Actions → Terraform Apply → Run workflow
   - Select environment: `dev`
   - Infrastructure will be created

3. **Terraform Destroy** - Cleanup (when needed)
   - Go to: Actions → Terraform Destroy → Run workflow
   - Select environment: `dev`
   - Type `destroy` to confirm

### Local Deployment (Optional)

```bash
# Clone repository
git clone https://github.com/gcpt0801/pickstream-infrastructure.git
cd pickstream-infrastructure/terraform/environments/dev

# Authenticate with GCP
gcloud auth application-default login

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan

# Apply infrastructure
terraform apply

# Get cluster credentials
gcloud container clusters get-credentials pickstream-cluster \
  --zone=us-central1-a \
  --project=gcp-terraform-demo-474514

# Verify cluster
kubectl get nodes
kubectl cluster-info
```

## 📤 Terraform Outputs

After successful deployment, the following outputs are available:

```bash
# View all outputs
terraform output

# Specific outputs
terraform output cluster_name          # pickstream-cluster
terraform output cluster_endpoint       # <sensitive>
terraform output cluster_location       # us-central1-a
terraform output artifact_registry_url  # us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream
terraform output github_service_account_email  # gcp-terraform-demo@...
```

## 🔐 GitHub Secrets Configuration

The following secret is configured in GitHub:

| Secret Name | Description | Value |
|-------------|-------------|-------|
| `GCP_SA_KEY` | Service Account JSON key for `gcp-terraform-demo@...` | JSON key content |

**Note**: `GCP_PROJECT_ID` is not needed as it's hardcoded in `terraform.tfvars`.

## 💰 Cost Estimation (Monthly)

### Development Environment
| Resource | Specification | Estimated Cost |
|----------|--------------|----------------|
| GKE Cluster | Zonal control plane | $0 (free) |
| System Pool | 1x e2-medium | ~$28 |
| App Pool | 1x e2-medium | ~$28 |
| Persistent Disks | 60GB standard | ~$3 |
| Network Egress | ~50GB/month | ~$5 |
| Artifact Registry | <100GB | ~$0.10 |
| Load Balancers | As needed | ~$18/each |
| **Total (estimated)** | | **~$82-100/month** |

### Cost Optimization Features
- ✅ Zonal cluster (vs regional - saves ~$100/month)
- ✅ E2 machine types (cost-optimized)
- ✅ Autoscaling (min 1 node per pool)
- ✅ Standard persistent disks (vs SSD)
- ✅ 30GB disk size per node

## 🔍 Post-Deployment Steps

### 1. Verify Cluster
```bash
# Get credentials
gcloud container clusters get-credentials pickstream-cluster \
  --zone=us-central1-a \
  --project=gcp-terraform-demo-474514

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

### 2. Set Up Workload Identity Federation
Run the gcloud commands in the "Workload Identity Federation" section above.

### 3. Test Artifact Registry Access
```bash
# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Test push (from local)
docker tag myimage:latest us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream/myimage:latest
docker push us-central1-docker.pkg.dev/gcp-terraform-demo-474514/pickstream/myimage:latest
```

### 4. Deploy Applications
Use the `pickstream-app` repository to deploy microservices to the cluster.

## 🔧 Management

### Update Infrastructure
1. Modify Terraform files
2. Commit and push to `main` branch
3. Run Terraform Plan workflow to review
4. Run Terraform Apply workflow to deploy

### Scale Node Pools
Edit `terraform.tfvars`:
```hcl
system_max_nodes = 5  # Scale system pool
app_max_nodes = 10    # Scale app pool
```

### Upgrade Machine Types
Edit `terraform.tfvars`:
```hcl
system_machine_type = "e2-standard-2"  # More CPU/memory
app_machine_type = "e2-standard-4"     # More CPU/memory
```

## 🧹 Cleanup

### Destroy Infrastructure
1. Go to: Actions → Terraform Destroy → Run workflow
2. Select environment: `dev`
3. Type `destroy` to confirm
4. All resources will be deleted

### Manual Cleanup (if needed)
```bash
# Delete cluster
gcloud container clusters delete pickstream-cluster \
  --zone=us-central1-a \
  --project=gcp-terraform-demo-474514 \
  --quiet

# Delete Artifact Registry
gcloud artifacts repositories delete pickstream \
  --location=us-central1 \
  --project=gcp-terraform-demo-474514 \
  --quiet
```

## 📚 Additional Documentation

- [docs/SETUP.md](docs/SETUP.md) - Detailed setup guide
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🤝 Contributing

This is an educational project for learning Terraform and GKE.

## 📝 License

MIT License

## 👥 Maintainers

- GitHub Org: @gcpt0801
- Repository: pickstream-infrastructure

---

**Last Updated**: November 21, 2025  
**Terraform Version**: 1.6.0  
**GCP Provider Version**: ~> 5.0
