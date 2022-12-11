variable "location" {
  type        = string
  default     = "westeurope"
  description = "Desired Azure Region"
}

variable "log_sku" {
  default     = "PerGB2018"
  description = "Specifies the SKU of the Log Analytics Workspace"
}

variable "log_retention" {
  default     = 30
  description = "The workspace data retention in days"
}

variable "container_apps_umami" {
  default = {
    image           = "ghcr.io/umami-software/umami"
    name            = "umami"
    tag             = "postgresql-v1.38.0"
    containerPort   = 3000
    ingress_enabled = true
    min_replicas    = 0
    max_replicas    = 1
    cpu_requests    = 0.25
    mem_requests    = "0.5Gi"
    rules = [
      {
        name = "http"
        http = {
          metadata : {
            concurrentRequests : "100"
          }
        }
      }
    ]
  }
}
