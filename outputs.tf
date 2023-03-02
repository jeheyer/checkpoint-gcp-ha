output "name" { value = local.name }
output "cluster_address" {
  value = local.is_cluster && local.create_nic0_external_ips ? google_compute_address.nic0_external_ips[0].address : null
}
output "license_type" { value = upper(local.license_type) }
output "install_type" { value = local.install_type }
output "software_version" { value = local.software_version }
output "sic_key" { value = local.sic_key }
output "admin_password" { value = local.admin_password }
output "admin_shell" { value = local.admin_shell }
output "image" { value = local.image }
output "instances" {
  value = { for k, v in local.instances : k =>
    {
      name             = google_compute_instance.default[k].name
      zone             = google_compute_instance.default[k].zone
      mgmt_ip          = local.is_gateway ? google_compute_instance.default[k].network_interface.1.network_ip : google_compute_instance.default[k].network_interface.0.network_ip
      nic0_external_ip = local.create_nic0_external_ips && !local.is_cluster ? google_compute_instance.default[k].network_interface.0.access_config.0.nat_ip : null
      nic1_external_ip = local.create_nic1_external_ips ? google_compute_instance.default[k].network_interface.1.access_config.0.nat_ip : null
    }
  }
}
output "instance_group_ids" { value = google_compute_instance_group.default[*].id }
output "instance_groups" {
  value = [for ig in google_compute_instance_group.default[*] : {
    id   = ig.id
    name = ig.name
    zone = ig.zone
  }]
}