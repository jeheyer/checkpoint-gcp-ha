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
}
variable "description" {
  type    = string
  default = null
}
variable "install_type" {
  type    = string
  default = null
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
}
variable "admin_password" {
  type    = string
  default = null
}
variable "expert_password" {
  type    = string
  default = null
}
variable "sic_key" {
  type    = string
  default = null
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

