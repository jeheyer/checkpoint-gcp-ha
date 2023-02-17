output "cluster_name" { value = local.cluster_name }
output "cluster_address" {
  value = local.create_cluster_external_ips ? google_compute_address.cluster_external_ips[0].address : data.google_compute_address.cluster_external_ips[0].address
}
output "license_type" { value = upper(local.license_type) }
output "software_version" { value = local.software_version }
output "sic_key" { value = local.sic_key }
output "admin_password" { value = local.admin_password }
output "admin_shell" { value = local.admin_shell }
output "members" {
  value = { for k, v in local.cluster_members : local.cluster_member_names[k] =>
    {
      name        = google_compute_instance.cluster_members[k].name
      zone        = google_compute_instance.cluster_members[k].zone
      mgmt_ip     = google_compute_instance.cluster_members[k].network_interface.1.network_ip
      external_ip = local.create_member_external_ips ? google_compute_instance.cluster_members[k].network_interface.1.access_config.0.nat_ip : null
    }
  }
}
