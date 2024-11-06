resource "azurerm_app_service_plan" "example" {
  name                = "juiceshop-appserviceplan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind = "Linux"
  reserved = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "random_id" "webappname" {
  byte_length = 2
}
#create web app service for juiceshop and deploy
resource "azurerm_app_service" "appservice" {         
  name                = "juiceshop${random_id.webappname.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.example.id

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
   site_config {
    linux_fx_version = "DOCKER|mohitkusecurity/juice-shop-updated:latest"
    always_on = true
  }
}