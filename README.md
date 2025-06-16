# Private Azure Kubernetes Cluster (AKS) with Private Azure Container Registry (ACR) and Bastion Host

This project demonstrates how to deploy a secure, private Azure Kubernetes Service (AKS) cluster with a private Azure Container Registry (ACR) and a Bastion Host for secure, auditable access. This setup is ideal for organizations looking to restrict public access to their workloads and container images while maintaining operational flexibility.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Deployment Steps](#deployment-steps)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Navigate to the Project Directory](#2-navigate-to-the-project-directory)
  - [3. Provision the Infrastructure Using Terraform](#3-provision-the-infrastructure-using-terraform)
  - [4. Access the VM Through the Bastion Host](#4-access-the-vm-through-the-bastion-host)
  - [5. Run the Installation Script](#5-run-the-installation-script)
  - [6. Configure kubectl](#6-configure-kubectl)
  - [7. Login to Your Private ACR](#7-login-to-your-private-acr)
  - [8. Build and Push Your Docker Image](#8-build-and-push-your-docker-image)
  - [9. Create a Kubernetes Secret for Your Private ACR](#9-create-a-kubernetes-secret-for-your-private-acr)
  - [10. Deploy Your Application to AKS](#10-deploy-your-application-to-aks)
- [Troubleshooting & Tips](#troubleshooting--tips)
- [Cleanup](#cleanup)
- [References](#references)

---

## Prerequisites

- **Azure Subscription:** An active Azure subscription with sufficient permissions.
- **Azure CLI:** [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and login using `az login`.
- **Terraform:** [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (latest version recommended).
- **Git:** Ensure git is installed on your machine.
- **Basic Knowledge:** Familiarity with the basics of Azure, networking, containers, and Kubernetes is helpful.

---

## Architecture Overview

This project provisions and configures the following Azure resources:

- **Resource Group:** Logical container for all resources.
- **Virtual Network (VNet):** Isolated network with subnets for AKS, ACR, Bastion, and VM.
- **Azure Container Registry (ACR):** Private registry for storing and managing container images.
- **Azure Kubernetes Service (AKS):** Private Kubernetes cluster, integrated with ACR.
- **Bastion Host:** Secure, browser-based RDP/SSH access to VMs without exposing them to the public internet.
- **Virtual Machine (VM):** Jumpbox with installation tools for administration and deployment.

All components are isolated from the public internet except for controlled Bastion host ingress.

---

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/MShanavas/PrivateAzure-K8s-ACR-Bastion.git
```

### 2. Navigate to the project directory:

```bash
cd PrivateAzure-K8s-ACR-Bastion
```

### 3. Provision the infrastructure using Terraform:

* **Initialize Terraform:**
  ```bash
  terraform init
  ```

* **Deploy the resources:**
  ```bash
  terraform apply -auto-approve
  ```
  This will create the following resources in Azure:
    * Resource Group
    * Virtual Network with subnets for AKS, ACR, and Bastion host
    * Private ACR
    * AKS Cluster (configured for private access and integrated with ACR)
    * Bastion Host
    * Virtual Machine (for running installation script and kubectl)

### 4. Access the VM through the Bastion host:

* Use the Azure portal to connect to the Bastion host.
* From the Bastion host, SSH into the virtual machine using its private IP address.

### 5. Run the installation script:

```bash
chmod +x installation.sh
./installation.sh
```
This script will install the necessary tools:
* Update the package index.
* Install prerequisite packages (`apt-transport-https`, `ca-certificates`, `curl`, `software-properties-common`, `gnupg`).
* Install Docker.
* Install kubectl.
* Install Azure CLI.

### 6. Configure kubectl:

Download the kubeconfig file for your AKS cluster and set the `KUBECONFIG` environment variable:

```bash
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### 7.  Login to your private ACR:

```bash
docker login myPrivateACR.azurecr.io -u <your-acr-username> -p <your-acr-password>
```

### 8. Build and push your Docker image:

* Build your Docker image and tag it appropriately for your private ACR.
  ```bash
  docker build -t myPrivateACR.azurecr.io/my-app:v1 .
  ```
* Push the image to your private ACR.
  ```bash
  docker push myPrivateACR.azurecr.io/my-app:v1
  ```

### 9. Create a Kubernetes secret for your private ACR:

```bash
kubectl create secret docker-registry myacrsecret \
  --docker-server=myPrivateACR.azurecr.io \
  --docker-username=<your-acr-username> \
  --docker-password=<your-acr-password>
```

### 10. Deploy your application to AKS:
