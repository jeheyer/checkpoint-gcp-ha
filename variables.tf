variable "project_id" {
  description = "Project ID to deploy cluster in"
  type        = string
  default     = null
}
variable "region" {
  description = "Default region name to deploy in"
  type        = string
  default     = "us-central1"
}
variable "name" {
  type = string
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
variable "image" {
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
variable "configured" {
  type    = bool
  default = false
}