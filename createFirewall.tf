
//create fw resources
resource "azurerm_subnet" "fwsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.4.0/24"]
}

//firewall public ip address
resource "azurerm_public_ip" "fwpip" {
  name                = "fwpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

//temporary firewall public ip address
resource "azurerm_public_ip" "fwpip2" {
  name                = "fwpip2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "fwpolicy" {
  name                = "fwpolicy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"

  dns {
      proxy_enabled = "true"

  }
}
//Rule collection Group
resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "example-fwpolicy-rcg"
  firewall_policy_id = azurerm_firewall_policy.fwpolicy.id
  priority           = 500
  application_rule_collection {
    name     = "app_rule_collection1"
    priority = 500
    action   = "Allow"
    rule {
      name = "app_rule_collection1_rule1"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*"]
    }
  }

  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["Any"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
//NAT RULE COLLECTION
  nat_rule_collection {
    name     = "nat_rule_collection1"
    priority = 300
    action   = "Dnat"
    rule {
      name                = "nat_rule_collection1_rule1"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.fwpip2.ip_address
      destination_ports   = ["80"]
      translated_address = azurerm_public_ip.example.ip_address
      translated_port     = "80"
    }
    rule {
      name                = "nat_rule_collection1_rule2"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.fwpip2.ip_address
      destination_ports   = ["3389"]
      translated_address = azurerm_windows_virtual_machine.example.private_ip_address
      translated_port     = "3389"
    }
  }
}

//Create firewall resource
resource "azurerm_firewall" "firewall" { 
  name                = "firewall"
  sku_tier            = "Premium"
  sku_name            = "AZFW_VNet"
  firewall_policy_id  = azurerm_firewall_policy.fwpolicy.id
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fwsubnet.id
    public_ip_address_id = azurerm_public_ip.fwpip.id
  }
}

//route table
resource "azurerm_route_table" "routetable" {
  name                          = "RouteTable"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "DefaultGW"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  }
}
