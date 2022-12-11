resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.project}-${var.location}"
  location = var.location
  tags     = local.tags
}

# networking
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.project}-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_aca" {
  name                 = "subnet-${local.project}-aca-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/23"]
  service_endpoints    = []
}
resource "azurerm_subnet" "subnet_databases" {
  name                 = "subnet-${local.project}-databases-${var.location}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
# #end  networking

# postgresql
resource "azurerm_private_dns_zone" "private_dns_postgresql" {
  name                = "umami.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zone_virtual_network_link_postgres" {
  name                  = "umami.postgres.database.azure.com"
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_postgresql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
  tags                  = local.tags
}

resource "random_password" "pg_password" {
  length  = 16
  special = true
}

resource "azurerm_postgresql_flexible_server" "pg_umami" {
  name                   = "pg-${local.project}-${var.location}"
  resource_group_name    = azurerm_resource_group.rg.name
  tags                   = local.tags
  location               = azurerm_resource_group.rg.location
  version                = "14"
  delegated_subnet_id    = azurerm_subnet.subnet_databases.id
  private_dns_zone_id    = azurerm_private_dns_zone.private_dns_postgresql.id
  administrator_login    = "psqladmin"
  administrator_password = random_password.pg_password.result
  zone                   = "1"

  storage_mb = 32768

  sku_name   = "B_Standard_B1ms"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.private_dns_zone_virtual_network_link_postgres]

}
resource "azurerm_postgresql_flexible_server_database" "pg_database_umammi" {
  name      = "umami"
  server_id = azurerm_postgresql_flexible_server.pg_umami.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# #end postgresql

# aca
resource "azurerm_log_analytics_workspace" "log" {
  name                = "log-${local.project}-${var.location}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.log_sku
  retention_in_days   = var.log_retention
  tags                = local.tags
}

resource "azapi_resource" "aca_env" {
  type      = "Microsoft.App/managedEnvironments@2022-03-01"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  name      = "aca-${local.project}-${var.location}"
  tags      = local.tags

  body = jsonencode({
    properties = {
      appLogsConfiguration = {
        destination = "log-analytics"
        logAnalyticsConfiguration = {
          customerId = azurerm_log_analytics_workspace.log.workspace_id
          sharedKey  = azurerm_log_analytics_workspace.log.primary_shared_key
        }
      }
      # if you change them it doesn't apply the changes
      vnetConfiguration = {
        internal               = false
        infrastructureSubnetId = azurerm_subnet.subnet_aca.id
        #   # dockerBridgeCidr       = "10.2.0.1/16"
        #   # platformReservedCidr   = "10.1.0.0/16"
        #   # platformReservedDnsIP  = "10.1.0.2"
      }
    }
  })
  depends_on = [
    azurerm_subnet.subnet_aca
  ]
}

resource "azapi_resource" "aca" {
  name      = "aca-${local.project}-${var.location}-001"
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = azurerm_resource_group.rg.id
  location  = azurerm_resource_group.rg.location
  tags      = local.tags

  body = jsonencode({
    properties : {
      managedEnvironmentId = azapi_resource.aca_env.id
      configuration = {
        secrets = [
          { name = "database-url", value = sensitive("postgres://psqladmin:${urlencode(random_password.pg_password.result)}@pg-umami-westeurope.postgres.database.azure.com:5432/umami?sslmode=require") }
        ]
        ingress = {
          external   = var.container_apps_umami.ingress_enabled
          targetPort = var.container_apps_umami.ingress_enabled ? var.container_apps_umami.containerPort : null
        }
      }
      template = {
        containers = [
          {
            name  = var.container_apps_umami.name
            image = "${var.container_apps_umami.image}:${var.container_apps_umami.tag}"
            resources = {
              cpu    = var.container_apps_umami.cpu_requests
              memory = var.container_apps_umami.mem_requests
            }
            args    = []
            command = []
            env = [
              { name = "DATABASE_URL", secretRef = "database-url" },
              { name = "DATABASE_TYPE", value = "postgresql" },
              { name = "UMAMI_HASHSALT", value = "84305ece208c8f375409a0cad10943393b6ce6df2626e84522223ab23c0aecd4" }
            ]
          }
        ]

        scale = {
          minReplicas = var.container_apps_umami.min_replicas
          maxReplicas = var.container_apps_umami.max_replicas
          rules       = var.container_apps_umami.rules
        }
      }
    }
  })
}
#end aca
