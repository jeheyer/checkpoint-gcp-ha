locals {
  install_type            = coalesce(var.install_type, "Cluster")
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
  cluster_address_names = coalescelist(var.address_names, ["primary-cluster-address", "secondary-cluster-address"])
  cluster_member_names  = coalescelist(var.member_names, ["member-a", "member-b"])
  # Create a list of objects so it's easier to iterate over
  cluster_members = [for i, v in local.cluster_member_names : {
    name                 = "${local.cluster_name}-${v}"
    zone                 = local.zones[i]
    member_address_name  = "${local.cluster_name}-${v}-address"
    cluster_address_name = "${local.cluster_name}-${local.cluster_address_names[i]}"
    }
  ]
  create_cluster_external_ips = coalesce(var.create_cluster_external_ips, true)
  create_member_external_ips  = coalesce(var.create_member_external_ips, true)
}

# Create primary and secondary cluster External addresses
resource "google_compute_address" "cluster_external_ips" {
  count        = local.create_cluster_external_ips ? length(local.cluster_members) : 0
  project      = var.project_id
  name         = local.cluster_members[count.index].cluster_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

# Get status of the the primary and secondary cluster addresses
data "google_compute_address" "cluster_external_ips" {
  count   = length(local.cluster_members)
  project = var.project_id
  name    = local.cluster_members[count.index].cluster_address_name
  region  = var.region
}

# Create member a/b External addresses for nic1 management, if desired
resource "google_compute_address" "member_external_ips" {
  count        = local.create_member_external_ips ? length(local.cluster_members) : 0
  project      = var.project_id
  name         = local.cluster_members[count.index].member_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

locals {
  zones = coalescelist(var.zones, ["b", "c"])
  service_account_scopes = coalescelist(var.service_account_scopes, [
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloudruntimeconfig"
  ])
  software_version = coalesce(var.software_version, "R81.10")
  template_name    = local.install_type == "Cluster" ? "cluster_tf" : "single_tf"
  license_type     = lower(coalesce(var.license_type, "BYOL"))
  image_prefix     = "checkpoint-public/check-point-${lower(replace(local.software_version, ".", ""))}-gw"
  image_type       = local.install_type == "Cluster" ? "cluster" : "single"
  template_version = "20230117"
  images = {
    "R81.20" = "${local.image_prefix}-${local.license_type}-${local.image_type}-631-991001245-v${local.template_version}"
    "R81.10" = "${local.image_prefix}-${local.license_type}-${local.image_type}-335-991001234-v${local.template_version}"
    "R80.40" = "${local.image_prefix}-${local.license_type}-${local.image_type}-294-991001234-v${local.template_version}"
  }
  image                 = local.images[local.software_version]
  startup_script_file   = local.software_version == "R80.30" ? "startup-script-r8030.sh" : "startup-script.sh"
  admin_password        = local.generate_admin_password ? random_string.admin_password[0].result : var.admin_password
  sic_key               = local.generate_sic_key ? random_string.sic_key[0].result : var.sic_key
  allow_upload_download = coalesce(var.allow_upload_download, false)
  enable_monitoring     = coalesce(var.enable_monitoring, false)
  admin_shell           = coalesce(var.admin_shell, "/etc/cli.sh")
  subnet_prefix         = "projects/${var.project_id}/regions/${var.region}/subnetworks"
}

# Create Compute Engine Instances
resource "google_compute_instance" "cluster_members" {
  count                     = length(local.cluster_members)
  project                   = var.project_id
  name                      = local.cluster_members[count.index].name
  description               = coalesce(var.description, "CloudGuard Highly Available Security Cluster")
  zone                      = "${var.region}-${local.cluster_members[count.index].zone}"
  machine_type              = coalesce(var.machine_type, "n1-standard-4")
  tags                      = coalescelist(var.network_tags, ["checkpoint-gateway"])
  can_ip_forward            = true
  allow_stopping_for_update = true
  resource_policies         = []
  boot_disk {
    auto_delete = coalesce(var.disk_auto_delete, true)
    device_name = "${local.cluster_name}-boot"
    initialize_params {
      type  = coalesce(var.disk_type, "pd-ssd")
      size  = coalesce(var.disk_size, 100)
      image = local.image
    }
  }
  # eth0 / nic0
  network_interface {
    network            = var.vpc_network_names[0]
    subnetwork_project = var.project_id
    subnetwork         = "${local.subnet_prefix}/${var.subnet_names[0]}"
    dynamic "access_config" {
      for_each = local.create_cluster_external_ips && data.google_compute_address.cluster_external_ips[count.index].status == "IN_USE" ? [true] : []
      content {
        nat_ip = google_compute_address.cluster_external_ips[count.index].address
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
        nat_ip = google_compute_address.member_external_ips[count.index].address
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
    generatePassword               = "true"
    config_url                     = "https://runtimeconfig.googleapis.com/v1beta1/projects/${var.project_id}/configs/${local.cluster_name}-config"
    config_path                    = "projects/${var.project_id}/configs/${local.cluster_name}-config"
    sicKey                         = local.sic_key
    allowUploadDownload            = local.allow_upload_download
    templateName                   = local.template_name
    templateVersion                = local.template_version
    templateType                   = "terraform"
    mgmtNIC                        = local.install_type == "Cluster" ? "Private IP (eth1)" : "Private IP (eth0)"
    hasInternet                    = "true"
    enableMonitoring               = local.enable_monitoring
    shell                          = local.admin_shell
    installationType               = local.install_type
    installSecurityManagement      = local.install_type == "Cluster" ? "false" : "true"
    computed_sic_key               = local.sic_key
    managementGUIClientNetwork     = coalesce(var.allowed_gui_clients, "0.0.0.0/0") # Controls access GAIA web interface
    primary_cluster_address_name   = local.install_type == "Cluster" ? "${local.cluster_name}-${local.cluster_address_names[0]}" : ""
    secondary_cluster_address_name = local.install_type == "Cluster" ? "${local.cluster_name}-${local.cluster_address_names[1]}" : ""
    managementNetwork              = coalesce(var.sic_address, "192.0.2.132/32") # This is designed to create a static route to the mgmt server via eth1

    /* TODO - Need to add these parameters to bash startup script
    domain_name = var.domain_name
    expert_password                = var.expert_password
    proxy_host = var.proxy_host
    proxy_port = coalesce(var.proxy_port, 8080)
    mgmt_routes = coalesce(var.mgmt_routes, "199.36.8/30")
    internal_routes =  coalesce(var.internal_routes, "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16")
    */
  })
}
