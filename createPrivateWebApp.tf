

resource "azurerm_subnet" "endpointsubnet" {
  name                 = "endpointsubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.3.0/24"]
  //enforce_private_link_endpoint_network_policies = true
}
/*
resource "azurerm_app_service_environment" "example" {
  name                         = "example-ase"
  subnet_id                    = azurerm_subnet.endpointsubnet.id
  pricing_tier                 = "I1"
  front_end_scale_factor       = 5
  internal_load_balancing_mode = "Web, Publishing"
  allowed_user_ip_cidrs        = ["10.0.0.0/16"]

  cluster_setting {
    name  = "DisableTls1.0"
    value = "1"
  }
}
*/

//app service plan!!
resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "private-juiceshop-appserviceplan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name 
  kind = "Linux"
  reserved = true

  sku {
    tier = "Premium"
    //tier = "Isolated"
    //size = "I1"
    size = "P1V2"
  }
}
resource "random_id" "private-webappname" {
  byte_length = 2
}
//create private JuiceShop webapp for security reasons and deploy full stack
resource "azurerm_app_service" "privatewebapp" {
  name                = "private-juiceshop${random_id.private-webappname.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id

  app_settings = {
    "WEBSITE_DNS_SERVER": "168.63.129.16",
    "WEBSITE_VNET_ROUTE_ALL": "1"
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
    site_config {
    linux_fx_version = "DOCKER|mohitkusecurity/juice-shop-updated:latest"
    always_on = true
  }
}

resource "azurerm_private_dns_zone" "dnsprivatezone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dnszonelink" {
  name = "dnszonelink"
  resource_group_name = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsprivatezone.name
  virtual_network_id = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "privateendpoint" {
  name                = "juiceshopappprivateendpoint"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.endpointsubnet.id

  private_dns_zone_group {
    name = "privatednszonegroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsprivatezone.id]
  }

  private_service_connection {
    name = "privateendpointconnection"
    private_connection_resource_id = azurerm_app_service.privatewebapp.id
    subresource_names = ["sites"]
    is_manual_connection = false
  }
}