locals {
  cluster_name            = coalesce(var.name, substr("ckpt-${var.region}", 0, 16))
  generate_admin_password = var.admin_password == null ? true : false
  generate_sic_key        = var.sic_key == null ? true : false
}

# If Admin password not provided, create random 16 character one
resource "random_string" "admin_password" {
  count   = local.generate_admin_password ? 1 : 0
  length  = 16
  special = false
}

# If SIC key not provided, create random 8 character one
resource "random_string" "sic_key" {
  count   = local.generate_sic_key ? 1 : 0
  length  = 8
  special = false
}

locals {
  cluster_address_names = coalesce(var.address_names, ["primary-cluster-address", "secondary-cluster-address"])
  cluster_member_names  = coalesce(var.member_names, ["member-a", "member-b"])
  cluster_members = { for k, v in local.cluster_member_names : v =>
    {
      name                 = "${local.cluster_name}-${v}"
      zone                 = local.zones[k]
      member_address_name  = "${local.cluster_name}-${v}-address"
      cluster_address_name = "${local.cluster_name}-${local.cluster_address_names[k]}"
    }
  }
  create_cluster_external_ips = coalesce(var.create_cluster_external_ips, true)
  create_member_external_ips  = coalesce(var.create_member_external_ips, true)
}

# Create primary and secondary cluster External addresses
resource "google_compute_address" "cluster_external_ips" {
  for_each     = local.create_cluster_external_ips ? local.cluster_members : {}
  project      = var.project_id
  name         = each.value.cluster_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

# Get status of the the primary and secondary cluster addresses
data "google_compute_address" "cluster_external_ips" {
  for_each = local.cluster_members
  project  = var.project_id
  name     = each.value.cluster_address_name
  region   = var.region
}

# Create member a/b External addresses for nic1 management, if desired
resource "google_compute_address" "member_external_ips" {
  for_each     = local.create_member_external_ips ? local.cluster_members : {}
  project      = var.project_id
  name         = each.value.member_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

locals {
  zones = coalesce(var.zones, ["b", "c"])
  service_account_scopes = coalesce(var.service_account_scopes, [
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloudruntimeconfig"
  ])
  software_version = coalesce(var.software_version, "R81.10")
  template_version = local.software_version == "R80.30" ? "20200220" : "20201206"
  license_type     = upper(coalesce(var.license_type, "BYOL"))
  images = {
    "R81.20" = "checkpoint-public/check-point-r8120-gw-${lower(local.license_type)}-cluster-631-991001245-v20230117"
    "R81.10" = "checkpoint-public/check-point-r8110-gw-${lower(local.license_type)}-cluster-335-985-v20220126"
    "R80.40" = "checkpoint-public/check-point-r8040-gw-${lower(local.license_type)}-cluster-294-904-v20210715"
    "R80.30" = "checkpoint-public/check-point-r8030-gw-${lower(local.license_type)}-273-597-v20200220"
  }
  startup_script_file   = local.software_version == "R80.30" ? "startup-script-r8030.sh" : "startup-script.sh"
  admin_password        = local.generate_admin_password ? random_string.admin_password[0].result : var.admin_password
  sic_key               = local.generate_sic_key ? random_string.sic_key[0].result : var.sic_key
  allow_upload_download = coalesce(var.allow_upload_download, false)
  enable_monitoring     = coalesce(var.enable_monitoring, false)
  admin_shell           = coalesce(var.admin_shell, "/bin/bash")
  install_type          = coalesce(var.install_type, "Cluster")
  subnet_prefix         = "projects/${var.project_id}/regions/${var.region}/subnetworks"
}

# Create Compute Engine Instances
resource "google_compute_instance" "cluster_members" {
  for_each                  = local.cluster_members
  project                   = var.project_id
  name                      = each.value.name
  description               = coalesce(var.description, "CloudGuard Highly Available Security Cluster")
  zone                      = "${var.region}-${each.value.zone}"
  machine_type              = coalesce(var.machine_type, "n1-standard-4")
  tags                      = coalesce(var.network_tags, ["checkpoint-gateway"])
  can_ip_forward            = true
  allow_stopping_for_update = true
  resource_policies         = []
  boot_disk {
    auto_delete = coalesce(var.disk_auto_delete, true)
    initialize_params {
      type  = coalesce(var.disk_type, "pd-ssd")
      size  = coalesce(var.disk_size, 100)
      image = local.images[local.software_version]
    }
  }
  # eth0 / nic0
  network_interface {
    network            = var.vpc_network_names[0]
    subnetwork_project = var.project_id
    subnetwork         = "${local.subnet_prefix}/${var.subnet_names[0]}"
    dynamic "access_config" {
      for_each = local.create_cluster_external_ips && data.google_compute_address.cluster_external_ips[each.key].status == "IN_USE" ? [true] : []
      content {
        nat_ip = google_compute_address.cluster_external_ips[each.key].address
      }
    }
  }
  # eth1 / nic1
  network_interface {
    network            = var.vpc_network_names[1]
    subnetwork_project = var.project_id
    subnetwork         = "${local.subnet_prefix}/${var.subnet_names[1]}"
    dynamic "access_config" {
      for_each = local.create_member_external_ips ? [true] : []
      content {
        nat_ip = google_compute_address.member_external_ips[each.key].address
      }
    }
  }
  # Internal interfaces (eth2-8 / nic2-8)
  dynamic "network_interface" {
    for_each = slice(var.vpc_network_names, 2, length(var.vpc_network_names))
    content {
      network            = network_interface.value
      subnetwork_project = var.project_id
      subnetwork         = "${local.subnet_prefix}/${var.subnet_names[network_interface.key + 2]}"
    }
  }
  service_account {
    email  = var.service_account_email
    scopes = local.service_account_scopes
  }
  metadata = {
    instanceSSHKey              = var.admin_ssh_key
    adminPasswordSourceMetadata = local.admin_password
  }
  metadata_startup_script = templatefile("${path.module}/${local.startup_script_file}", {
    // script's arguments
    generatePassword    = "true" #0 #"True" Setting to 'True' will have the VM pull the password value from adminPasswordSourceMetadata
    config_url          = "https://runtimeconfig.googleapis.com/v1beta1/projects/${var.project_id}/configs/${local.cluster_name}-config"
    config_path         = "projects/${var.project_id}/configs/${local.cluster_name}-config"
    sicKey              = local.sic_key
    allowUploadDownload = local.allow_upload_download
    templateName        = "cluster_tf"
    templateVersion     = local.template_version
    templateType        = "terraform"
    mgmtNIC             = "Private IP (eth1)"
    hasInternet         = "true"
    enableMonitoring    = local.enable_monitoring
    shell               = local.admin_shell
    installationType    = local.install_type
    #installSecurityManagement      = 0
    computed_sic_key               = local.sic_key
    managementGUIClientNetwork     = coalesce(var.allowed_gui_clients, "0.0.0.0/0")
    primary_cluster_address_name   = "${local.cluster_name}-${local.cluster_address_names[0]}"
    secondary_cluster_address_name = "${local.cluster_name}-${local.cluster_address_names[1]}"
    managementNetwork              = coalesce(var.sic_address, "192.0.2.132/32") # This is designed to create a static route to the mgmt server via eth1
    expert_password                = var.expert_password

    /* TODO
    domain_name = 
    admin_password = 
    proxy_host =
    proxy_port = 8080
    mgmt_routes = 
    internal_routes =  coalesce(var.internal_routes, "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16")
    */
  })
}
