# Private Azure Kubernetes Cluster (AKS) with Private Azure Container Registry (ACR) and Bastion Host

This project demonstrates how to deploy a secure and private Azure Kubernetes Cluster (AKS) with a private Azure Container Registry (ACR) and a Bastion Host for secure access.

## Prerequisites

* **Azure Account:** An active Azure subscription.
* **Azure CLI:** Installed and configured with your Azure credentials.
* **Terraform:** Installed and configured on your local machine.

## Deployment Steps

### 1. Clone the repository:

```bash
git clone [https://github.com/MShanavas/PrivateAzure-K8s-ACR-Bastion.git]
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

* Create a Kubernetes deployment YAML file that references your private ACR image and uses the secret you created.
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: my-app
  spec:
    replicas: 3
    selector:
      matchLabels:
        app: my-app
    template:
      metadata:
        labels:
          app: my-app
      spec:
        containers:
        - name: my-app
          image: myPrivateACR.azurecr.io/my-app:v1
          ports:
          - containerPort: 80
        imagePullSecrets:
        - name: myacrsecret
  ```
* Apply the deployment to your AKS cluster using kubectl.
  ```bash
  kubectl apply -f deployment.yaml
  ```

## Security Considerations

* **Private ACR:** Ensures that your container images are only accessible within your virtual network.
* **Private AKS Cluster:** Restricts access to the Kubernetes API server, enhancing the security of your cluster.
* **Bastion Host:** Provides a secure and controlled entry point to your virtual network, eliminating the need for public IP addresses on your AKS nodes.
* **Network Security Groups:** Implement Network Security Groups (NSGs) to further restrict traffic flow within your virtual network.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to improve this project.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
```
