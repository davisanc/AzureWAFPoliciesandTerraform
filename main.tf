terraform {
  backend "azurerm" {
    resource_group_name   = "WAF-DevOps"
    storage_account_name  = "wafdevopssaint"
    container_name        = "tstate"
  }

  required_providers {
    azurerm = {
      # Specify what version of the provider we are going to utilise
      source = "hashicorp/azurerm"
      # version = ">= 2.4.1"
    }
  }
}
provider "azurerm" {
  features {
      key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}
# Create our Resource Group - WAF-DevOps-RG
resource "azurerm_resource_group" "rg" {
  name     = "WAF-DevOps-app"
  location = "UK South"
}
#Create WAF policy
resource "azurerm_web_application_firewall_policy" "WAF-Devops-waf" {
  name                = "WAF-Devops-wafpolicy"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  custom_rules {
    name      = "Rule1"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24", "10.0.0.0/24"]
    }

    action = "Block"
  }

  custom_rules {
    name      = "Rule2"
    priority  = 2
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24"]
    }

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "UserAgent"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["Windows"]
    }

    action = "Block"
  }

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestHeaderNames"
      selector                = "x-company-secret-header"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestCookieNames"
      selector                = "too-tasty"
      selector_match_operator = "EndsWith"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.1"
      rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        disabled_rules = [
          "920300",
          "920440"
        ]
      }
    }
  }

}
#Create storage account
resource "random_id" "storage_account" {
  byte_length = 2
}
#create Storage Account!
resource "azurerm_storage_account" "wafdevopssaapp" {
  name                     = "wafdevopssaapp${lower(random_id.storage_account.hex)}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    environment = "WAF-DevOps-tag-v2"
  }
}