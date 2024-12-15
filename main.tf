# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks" {
  name                 = var.subnet_aks_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "vm" {
  name                 = var.subnet_vm_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = var.subnet_bastion_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                     = var.acr_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  public_network_access_enabled = false
  sku                      = "Premium"
  admin_enabled            = true
  depends_on               = [azurerm_resource_group.rg]
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "aks_private_dns" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks_private_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
  depends_on            = [azurerm_virtual_network.vnet, azurerm_private_dns_zone.aks_private_dns]
}

# Create User-Assigned Managed Identity for AKS
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = var.managed_identity
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_resource_group.rg]
}

# Role Assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
  depends_on           = [azurerm_user_assigned_identity.aks_identity, azurerm_container_registry.acr]
}
resource "azurerm_role_assignment" "aks_acr_pull2" {
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
  depends_on           = [azurerm_user_assigned_identity.aks_identity, azurerm_container_registry.acr]
}
# Role Assignment for AKS to push to ACR
resource "azurerm_role_assignment" "aks_acr_push" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "AcrPush"
  scope                = azurerm_container_registry.acr.id
  depends_on           = [azurerm_user_assigned_identity.aks_identity, azurerm_container_registry.acr]
}

# Role Assignment for DNS Contributor for AKS
resource "azurerm_role_assignment" "dns_contributor" {
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
  role_definition_name = "Contributor"
  scope                = azurerm_private_dns_zone.aks_private_dns.id
  depends_on           = [azurerm_user_assigned_identity.aks_identity, azurerm_private_dns_zone.aks_private_dns]
}


resource "azurerm_public_ip" "bastion_gateway_public_ip" {
  name                = var.bastion_pip_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

# AKS Cluster (Private)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.k8s_dns_prefix
  private_cluster_enabled = true

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = var.node_vmsize
    vnet_subnet_id      = azurerm_subnet.aks.id
    min_count           = 1
    max_count           = 3
    auto_scaling_enabled = true

  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr       = "10.0.10.0/24"
    dns_service_ip     = "10.0.10.10"
  }  

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }
  depends_on = [azurerm_role_assignment.dns_contributor, azurerm_subnet.aks]
}

# Private Endpoints
resource "azurerm_private_endpoint" "aks_private_endpoint" {
  name                = var.aks_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id

  private_service_connection {
    name                           = var.aks_private_service_connection
    private_connection_resource_id = azurerm_kubernetes_cluster.aks.id
    subresource_names              = ["management"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.aks_private_dns.id]
  }

  depends_on = [azurerm_kubernetes_cluster.aks, azurerm_private_dns_zone.aks_private_dns]
}

resource "azurerm_private_endpoint" "acr_private_endpoint" {
  name                = var.acr_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.aks.id

  private_service_connection {
    name                           = var.acr_private_service_connection
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.aks_private_dns.id]
  }

  depends_on = [azurerm_container_registry.acr, azurerm_private_dns_zone.aks_private_dns]
}

resource "azurerm_bastion_host" "bastion" {
  name                = var.bastion_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    subnet_id = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_gateway_public_ip.id
    name = "bastion-gw-cfg"
  }
  sku                  = "Standard"
  depends_on = [azurerm_subnet.bastion_subnet]
}
# Network Interface for VM
resource "azurerm_network_interface" "nic" {
  name                = var.vm_nicname
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.vm]
}

resource "azurerm_linux_virtual_machine" "lvm" {
  name                  = var.vm_name
  computer_name         = var.vm_name
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vmsize
  admin_username        = var.vmadmin_username
  network_interface_ids = [azurerm_network_interface.nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = var.vmpublisher
    offer     = var.vmoffer
    sku       = var.vmsku
    version   = "latest"
  }
  admin_ssh_key {
    username   = var.vmadmin_username
    public_key = file("azlb-vm-1.pub")
  }

  depends_on = [azurerm_network_interface.nic]
}

output "bastion_public_ip" {  value = azurerm_public_ip.bastion_gateway_public_ip.ip_address }