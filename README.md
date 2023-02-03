# for CheckPoint HA Cluster on Google Cloud Platform

## Resources Created

- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [google_compute_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address)
- [random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)


## Inputs 

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| project\_id | GCP Project ID to create the gateway(s) in | `string` | 
| region | GCP Name to create the gateway(s) in | `string` | 
| name | Name of the Cluster | `string` |

### Recommend Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| install\_type | Installation Type | `string` | "Cluster" |
| license\_type | License Type.  Options are `BYOL` or `PAYG` | `string` | "BYOL" |
| software\_version | Checkpoint Software Version | `string` | "R81.10" |

### Optional Inputs

| Name | Description                                         | Type | Default |
|------|-----------------------------------------------------|------|---------|
| machine\_type | GCP Machine Type for the VMs | `string` | "n1-standard-4" |
| zones | Short name of the zones to use in this region | `list(string)` | ["b","c"] |
| admin\_shell | Shell for the 'admin' user | `string` | "/bin/bash" |
| admin\_password | Password for the 'admin' user | `string` | n/a |
| sic\_key | Secure Internal Communication passkey | `string` | n/a |
| create\_cluster\_external\_ips | Create External IPs for Cluster | `bool` | true |
| create\_member\_external\_ips | Create External IPs for Mgmt Interfaces | `bool` | true |
| allow_upload_download | Allow Software updates via Web | `bool` | true |
| enable\_monitoring | Activate StackDriver Monitoring | `bool` | true |
| network\_tags | Network Tags to apply to gateways | `list(string)` | ["checkpoint-gateway"] |
| disk\_type | Disk type for gateways | `string` | "pd-ssd" |
| disk\_size | Disk size for gateways (in GB) | `number` | 100 |
| disk\_auto\_delete | Delete Disk  | `bool` | true |
| description | Description for the cluster members | `string` | "CheckPoint CloudGuard IaaS Gateway" |

### Notes


## Outputs

| Name | Description | Type |
|------|-------------|------|
| cluster | Information about the Cluster | `map` |
| member | Information about each Cluster Member | `map` |

## Sample Inputs

### R81.10 PAYG cluster in us-central1

```
project_id     = "my-project-id"
name           = "my-cluster"
region         = "us-central1"
license_type   = "PAYG"
```

### R81.10 BYOL cluster in us-central1 with custom zone selection and no external IP for mgmt interfaces

```
project_id                 = "my-project-id"
name                       = "my-cluster"
region                     = "us-central1"
zones                      = ["c","f"]
license_type               = "BYOL"
create_member_external_ips = false
```

### R80.40 BYOL cluster in europe-west4 with custom machine type (AMD EPYC Rome with 8 GB RAM)

```
project_id        = "my-project-id"
name              = "my-cluster"
region            = "us-east4"
machine_type      = "n2d-custom-4-8192"
software_version  = "R80.40"
```

