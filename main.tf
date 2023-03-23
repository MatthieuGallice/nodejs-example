terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }
  
  backend "azurerm" {
    
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_postgresql_server" "postgres-srv" {
  name                = "postgresql-${var.project_name}${var.environment_suffix}"
  resource_group_name          = data.azurerm_resource_group.rg-maalsi.name
  location                     = data.azurerm_resource_group.rg-maalsi.location

  sku_name = "B_Gen5_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = data.azurerm_key_vault_secret.database-login.value
  administrator_login_password = data.azurerm_key_vault_secret.database-password.value
  version                      = "11"
  ssl_enforcement_enabled      = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

resource "azurerm_postgresql_database" "postgres-db" {
  name                = "Soleil"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  server_name         = azurerm_postgresql_server.postgres-srv.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "postgres-srv" {
  name                = "AllowAzureServices"
  server_name         = azurerm_postgresql_server.postgres-srv.name
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurerm_container_group" "pgadmin" {
  name                = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  location            = data.azurerm_resource_group.rg-maalsi.location
  ip_address_type     = "Public"
  dns_name_label      = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  os_type             = "Linux"

  container {
    name   = "pgadmin"
    image  = "dpage/pgadmin4"
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      "PGADMIN_DEFAULT_EMAIL" = data.azurerm_key_vault_secret.pgadmin-login.value
      "PGADMIN_DEFAULT_PASSWORD" = data.azurerm_key_vault_secret.pgadmin-password.value
    }
  }

  restart_policy = "Never"
}

resource "azurerm_service_plan" "app-plan" {
  name                = "plan-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  location            = data.azurerm_resource_group.rg-maalsi.location
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "web-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg-maalsi.name
  location            = data.azurerm_resource_group.rg-maalsi.location
  service_plan_id     = azurerm_service_plan.app-plan.id

  site_config {
    application_stack {
      node_version = "16-lts"
    }
  }

  
 app_settings = {
    "PORT"        = "3000"
    "DB_HOST"     = "postgresql-${var.project_name}${var.environment_suffix}"
    "DB_USERNAME" = "${data.azurerm_key_vault_secret.database-login.value}@${azurerm_postgresql_server.postgres-srv.name}"
    "DB_PASSWORD" = data.azurerm_key_vault_secret.database-password.value
    "DB_DATABASE" = "${var.DB_DATABASE}"
    "DB_DAILECT"  = "${var.DB_DAILECT}"
    "DB_PORT"     = "5432"
  }
}

