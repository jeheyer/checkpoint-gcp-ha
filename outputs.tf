output "cluster" {
  value = {
    name             = local.cluster_name
    cluster_address  = google_compute_address.cluster_external_ips[0].address
    license_type     = local.license_type
    software_version = local.software_version
    sic_key          = local.sic_key
    admin_password   = local.admin_password
  }
}
output "members" {
  value = { for k, v in local.cluster_members : k =>
    {
      name        = google_compute_instance.cluster_members[k].name
      zone        = google_compute_instance.cluster_members[k].zone
      mgmt_ip     = google_compute_instance.cluster_members[k].network_interface.1.network_ip
      external_ip = local.create_member_external_ips ? google_compute_instance.cluster_members[k].network_interface.1.access_config.0.nat_ip : null
    }
  }
}
