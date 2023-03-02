locals {
  install_type            = coalesce(var.install_type, "Cluster")
  is_cluster              = local.install_type == "Cluster" ? true : false
  is_mig                  = local.install_type == "AutoScale" ? true : false
  is_gateway              = local.is_cluster || local.is_mig || length(regexall("Gateway", local.install_type)) > 0 ? true : false
  is_standalone           = local.is_cluster || local.is_mig ? false : true
  is_management           = !local.is_cluster && length(regexall("Management", local.install_type)) > 0 ? true : false
  name                    = coalesce(var.name, substr("chkp-${local.install_code}-${var.region}", 0, 16))
  generate_admin_password = var.admin_password == null ? true : false
  generate_sic_key        = var.sic_key == null ? true : false
  network_project_id      = coalesce(var.network_project_id, var.project_id)
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
  instance_suffixes  = coalesce(var.instance_suffixes, local.is_cluster ? ["member-a", "member-b"] : ["gateway"])
  instance_zones     = coalesce(var.zones, ["b", "c"])
  nic0_address_names = local.is_cluster ? ["primary-cluster", "secondary-cluster"] : local.instance_suffixes
  address_names = {
    nic0 = local.is_gateway ? [for n in local.nic0_address_names : "${local.name}-${n}"] : [local.name]
    nic1 = local.is_gateway ? [for n in local.instance_suffixes : "${local.name}-${n}"] : ["${local.name}-2"]
  }
  # Create a list of objects so it's easier to iterate over
  instances = [for i, v in local.instance_suffixes : {
    name              = "${local.name}-${v}"
    zone              = "${var.region}-${local.instance_zones[i]}"
    nic0_address_name = "${local.address_names["nic0"][i]}-address"
    nic1_address_name = "${local.address_names["nic1"][i]}-nic1-address"
    }
  ]
  create_nic0_external_ips = coalesce(var.create_nic0_external_ips, true)
  create_nic1_external_ips = coalesce(var.create_nic1_external_ips, true)
}

# Create External Addresses to assign to nic0
resource "google_compute_address" "nic0_external_ips" {
  count        = local.create_nic0_external_ips ? length(local.instances) : 0
  project      = var.project_id
  name         = local.instances[count.index].nic0_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

# For clusters, get status of the the primary and secondary addresses so we don't lose them after configuration
data "google_compute_address" "nic0_external_ips" {
  count   = local.is_cluster ? length(local.instances) : 0
  project = var.project_id
  name    = local.instances[count.index].nic0_address_name
  region  = var.region
}

# Create External Addresses to assign to nic0
resource "google_compute_address" "nic1_external_ips" {
  count        = local.create_nic1_external_ips ? length(local.instances) : 0
  project      = var.project_id
  name         = local.instances[count.index].nic1_address_name
  region       = var.region
  address_type = "EXTERNAL"
}

locals {
  service_account_scopes = coalescelist(var.service_account_scopes,
    concat(["https://www.googleapis.com/auth/monitoring.write"], local.is_gateway ?
    ["https://www.googleapis.com/auth/compute", "https://www.googleapis.com/auth/cloudruntimeconfig"] : [])
  )
  software_version  = coalesce(var.software_version, "R81.10")
  software_code     = lower(replace(local.software_version, ".", ""))
  template_name     = local.is_cluster ? "${lower(local.install_type)}_tf" : "single_tf"
  license_type      = lower(coalesce(var.license_type, "BYOL"))
  checkpoint_prefix = "projects/checkpoint-public/global/images/check-point-${local.software_code}"
  image_type        = local.is_gateway ? "-gw" : ""
  image_prefix      = "${local.checkpoint_prefix}${local.image_type}-${local.license_type}"
  image_versions = {
    "R81.20" = "631-${local.is_management ? "991001243-v20230112" : "991001245-v20230117"}"
    "R81.10" = "335-${local.is_management ? "991001174-v20221110" : "991001234-v20230117"}"
    "R81"    = "392-${local.is_management ? "991001174-v20221108" : "991001234-v20230117"}"
    "R80.40" = "294-${local.is_management ? "991001174-v20221107" : "991001234-v20230117"}"
  }
  image_version         = lookup(local.image_versions, local.software_version, "error")
  install_code          = local.is_management ? "" : (local.is_standalone ? "single-" : "${lower(local.install_type)}-")
  default_image         = "${local.image_prefix}-${local.install_code}${local.image_version}"
  image                 = coalesce(var.software_image, local.default_image)
  template_version      = "20230117"
  startup_script_file   = "startup-script.sh"
  admin_password        = local.generate_admin_password ? random_string.admin_password[0].result : var.admin_password
  sic_key               = local.generate_sic_key ? random_string.sic_key[0].result : var.sic_key
  allow_upload_download = coalesce(var.allow_upload_download, false)
  enable_monitoring     = coalesce(var.enable_monitoring, false)
  admin_shell           = coalesce(var.admin_shell, "/etc/cli.sh")
  subnet_prefix         = "projects/${var.project_id}/regions/${var.region}/subnetworks"
  network_names         = coalesce(var.network_names, [var.network_name])
  subnet_names          = coalesce(var.subnet_names, [var.subnet_name])
  descriptions = {
    "Cluster"   = "CloudGuard Highly Available Security Cluster"
    "AutoScale" = "None"
  }
  description = coalesce(var.description, lookup(local.descriptions, local.install_type, "Check Point Security Gateway"))
}

# Create Compute Engine Instances
resource "google_compute_instance" "default" {
  count                     = length(local.instances)
  project                   = var.project_id
  name                      = local.instances[count.index].name
  description               = local.description
  zone                      = local.instances[count.index].zone
  machine_type              = coalesce(var.machine_type, "n1-standard-4")
  tags                      = coalescelist(var.network_tags, local.is_gateway ? ["checkpoint-gateway"] : ["checkpoint-management"])
  can_ip_forward            = true
  allow_stopping_for_update = true
  resource_policies         = []
  boot_disk {
    auto_delete = coalesce(var.disk_auto_delete, true)
    device_name = "${local.name}-boot"
    initialize_params {
      type  = coalesce(var.disk_type, "pd-ssd")
      size  = coalesce(var.disk_size, 100)
      image = local.image
    }
  }
  # eth0 / nic0
  network_interface {
    network            = local.network_names[0]
    subnetwork_project = var.project_id
    subnetwork         = "${local.subnet_prefix}/${local.subnet_names[0]}"
    dynamic "access_config" {
      for_each = local.create_nic0_external_ips && (local.is_cluster ? data.google_compute_address.nic0_external_ips[count.index].status == "IN_USE" : true) ? [true] : []
      content {
        nat_ip = google_compute_address.nic0_external_ips[count.index].address
      }
    }
  }
  # eth1 / nic1
  dynamic "network_interface" {
    for_each = local.is_gateway ? [true] : []
    content {
      network            = local.network_names[1]
      subnetwork_project = var.project_id
      subnetwork         = "${local.subnet_prefix}/${local.subnet_names[1]}"
      dynamic "access_config" {
        for_each = local.create_nic1_external_ips ? [true] : []
        content {
          nat_ip = google_compute_address.nic1_external_ips[count.index].address
        }
      }
    }
  }
  # Internal interfaces (eth2-8 / nic2-8)
  dynamic "network_interface" {
    for_each = local.is_gateway ? slice(local.network_names, 2, length(local.network_names)) : []
    content {
      network            = network_interface.value
      subnetwork_project = var.project_id
      subnetwork         = "${local.subnet_prefix}/${local.subnet_names[network_interface.key + 2]}"
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
  metadata_startup_script = local.is_management ? null : templatefile("${path.module}/${local.startup_script_file}", {
    // script's arguments
    generatePassword               = "true"
    config_url                     = "https://runtimeconfig.googleapis.com/v1beta1/projects/${var.project_id}/configs/${local.name}-config"
    config_path                    = "projects/${var.project_id}/configs/${local.name}-config"
    sicKey                         = local.sic_key
    allowUploadDownload            = local.allow_upload_download
    templateName                   = local.template_name
    templateVersion                = local.template_version
    templateType                   = "terraform"
    mgmtNIC                        = local.is_management ? "Private IP (eth0)" : "Private IP (eth1)"
    hasInternet                    = "true"
    enableMonitoring               = local.enable_monitoring
    shell                          = local.admin_shell
    installationType               = local.install_type
    installSecurityManagement      = local.is_management ? "true" : "false"
    computed_sic_key               = local.sic_key
    managementGUIClientNetwork     = coalesce(var.allowed_gui_clients, "0.0.0.0/0") # Controls access GAIA web interface
    primary_cluster_address_name   = local.is_cluster ? local.instances[0].nic0_address_name : ""
    secondary_cluster_address_name = local.is_cluster ? local.instances[1].nic0_address_name : ""
    managementNetwork              = coalesce(var.sic_address, "192.0.2.132/32") # creates a static route to the mgmt server via mgmt nic

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

# Unmanaged Instance Group for each gateway
resource "google_compute_instance_group" "default" {
  count       = var.create_instance_groups ? length(local.instances) : 0
  project     = var.project_id
  name        = google_compute_instance.default[count.index].name
  description = "Unmanaged Instance Group for ${local.instances[count.index].name}"
  network     = "projects/${local.network_project_id}/global/networks/${local.network_names[0]}"
  instances   = [google_compute_instance.default[count.index].self_link]
  zone        = local.instances[count.index].zone
}
