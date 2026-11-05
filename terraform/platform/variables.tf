variable "project_id" {
  description = "Existing dedicated GCP project with billing enabled."
  type        = string
}
variable "region" {
  description = "Primary region. Confirm service availability and quota before deployment."
  type        = string
  default     = "me-west1"
}
variable "name" {
  description = "Short resource prefix."
  type        = string
  default     = "architect-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}[a-z0-9]$", var.name))
    error_message = "Use 4–20 lowercase letters, digits or hyphens; begin with a letter and end with a letter or digit."
  }
}
variable "node_zones" {
  description = "Worker zones. Default is one zone to limit lab cost; a regional control plane is still created."
  type        = list(string)
  default     = ["me-west1-a"]
  validation {
    condition     = length(var.node_zones) > 0
    error_message = "At least one worker zone is required."
  }
}
variable "node_machine_type" {
  type    = string
  default = "e2-standard-2"
}
variable "min_nodes" {
  description = "Total autoscaler minimum across all selected zones."
  type        = number
  default     = 1
  validation {
    condition     = var.min_nodes >= 1 && floor(var.min_nodes) == var.min_nodes
    error_message = "min_nodes must be a positive integer."
  }
}
variable "max_nodes" {
  description = "Total autoscaler maximum across all selected zones."
  type        = number
  default     = 2
  validation {
    condition     = var.max_nodes >= var.min_nodes && floor(var.max_nodes) == var.max_nodes
    error_message = "max_nodes must be an integer at least min_nodes."
  }
}
variable "admin_cidrs" {
  description = "Private source CIDRs of reachable administrators/agents; does not create connectivity."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for cidr in values(var.admin_cidrs) : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")])
    error_message = "Supply valid IPv4 CIDRs; /0 is not allowed."
  }
}
variable "sql_ha" {
  description = "Enable regional Cloud SQL HA. false is a cheaper, single-zone lab."
  type        = bool
  default     = false
}
variable "sql_tier" {
  type    = string
  default = "db-custom-1-3840"
}
variable "deletion_protection" {
  description = "Protect GKE and SQL from accidental deletion. Explicitly disable and apply before cleanup."
  type        = bool
  default     = true
}
variable "labels" {
  type = map(string)
  default = {
    purpose = "architect-assessment"
    env     = "lab"
  }
}
