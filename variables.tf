variable "project_id" {
  description = "Project ID to deploy cluster in"
  type        = string
  default     = null
}
variable "network_project_id" {
  description = "Host Network's Project ID (if using Shared VPC)"
  type        = string
  default     = null
}
variable "region" {
  description = "Default region name to deploy in"
  type        = string
}
variable "name" {
  type    = string
  default = null
  validation {
    condition     = var.name != null ? length(var.name) < 23 : true
    error_message = "Cluster name cannot exceed 16 characters."
  }
}
variable "description" {
  type    = string
  default = null
}
variable "install_type" {
  type    = string
  default = null
  validation {
    condition     = var.install_type != null ? var.install_type == "Cluster" || var.install_type == "Gateway only" || var.install_type == "AutoScale" || var.install_type == "Management only" : true
    error_message = "Install type should be 'Cluster' or 'Gateway only' or 'AutoScale' or 'Management only'."
  }
}
variable "instance_suffixes" {
  type    = list(string)
  default = null
}
variable "zones" {
  type    = list(string)
  default = null
}
variable "machine_type" {
  type    = string
  default = null
}
variable "disk_auto_delete" {
  type    = bool
  default = null
}
variable "disk_type" {
  type    = string
  default = null
}
variable "disk_size" {
  type    = number
  default = null
  validation {
    condition     = var.disk_size != null ? var.disk_size >= 40 && var.disk_size <= 200 : true
    error_message = "Disk size should be between 40 and 200 GB."
  }
}
variable "admin_password" {
  type    = string
  default = null
  validation {
    condition     = var.admin_password != null ? length(var.admin_password) >= 8 && length(var.admin_password) <= 32 : true
    error_message = "Admin password should be 8 to 32 characters."
  }
}
variable "expert_password" {
  type    = string
  default = null
}
variable "sic_key" {
  type    = string
  default = null
  validation {
    condition     = var.sic_key != null ? length(var.sic_key) >= 8 && length(var.sic_key) <= 32 : true
    error_message = "SIC Key should be 8 to 32 characters."
  }
}
variable "allow_upload_download" {
  type    = bool
  default = null
}
variable "enable_monitoring" {
  type    = bool
  default = null
}
variable "license_type" {
  type    = string
  default = null
  validation {
    condition     = var.license_type != null ? upper(var.license_type) == "PAYG" || upper(var.license_type) == "PAYG" : true
    error_message = "License type should be 'BYOL' or 'PAYG'."
  }
}
variable "software_image" {
  type    = string
  default = null
  validation {
    condition     = var.software_image != null ? startswith(var.software_image, "checkpoint") || startswith(var.software_image, "projects/checkpoint") : true
    error_message = "Software image should be from Checkpoint."
  }
}
variable "software_version" {
  type    = string
  default = null
}
variable "ssh_key" {
  type    = string
  default = null
}
variable "startup_script" {
  type    = string
  default = null
}
variable "admin_shell" {
  type    = string
  default = null
}
variable "admin_ssh_key" {
  type    = string
  default = null
}
variable "service_account_email" {
  type    = string
  default = null
}
variable "service_account_scopes" {
  type    = list(string)
  default = null
}
variable "network_tags" {
  type    = list(string)
  default = null
}
variable "network_names" {
  type    = list(string)
  default = null
}
variable "network_name" {
  type    = string
  default = "default"
}
variable "subnet_names" {
  type    = list(string)
  default = null
}
variable "subnet_name" {
  type    = string
  default = "default"
}
variable "create_nic0_external_ips" {
  type    = bool
  default = true
}
variable "create_nic1_external_ips" {
  type    = bool
  default = true
}
variable "create_instance_groups" {
  type    = bool
  default = false
}
variable "allowed_gui_clients" {
  type    = string
  default = null
}
variable "sic_address" {
  type    = string
  default = null
}
variable "auto_scale" {
  type    = bool
  default = false
}
variable "domain_name" {
  type    = string
  default = null
}
variable "proxy_host" {
  type    = string
  default = null
}
variable "proxy_port" {
  type    = number
  default = 8080
}
variable "mgmt_routes" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}
variable "internal_routes" {
  type    = list(string)
  default = []
}

