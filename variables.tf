variable "project_id" {
  description = "Project ID to deploy cluster in"
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
    condition     = var.install_type != null ? var.install_type == "Cluster" || var.install_type == "Standalone" : true
    error_message = "Install type should be 'Cluster' or 'Standalone'."
  }
}
variable "member_names" {
  type    = list(string)
  default = null
}
variable "address_names" {
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
variable "vpc_network_names" {
  type = list(string)
}
variable "subnet_names" {
  type    = list(string)
  default = null
}
variable "create_cluster_external_ips" {
  type    = bool
  default = true
}
variable "create_member_external_ips" {
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

