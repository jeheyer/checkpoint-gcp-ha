# CheckPoint HA Cluster on Google Cloud Platform

## Resources Created

- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [google_compute_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address)
- [random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) 

## Inputs 

### Required Inputs

| Name        | Description                          | Type     |
|-------------|--------------------------------------|----------|
| project\_id | GCP Project ID for all resources     | `string` | 
| region      | GCP Name to create the gateway(s) in | `string` | 
| name        | Name of the Cluster                  | `string` |

### Recommend Inputs

| Name              | Description                                 | Type     | Default |
|-------------------|---------------------------------------------|----------|---------|
| install\_type     | Installation Type                           | `string` | Cluster |
| license\_type     | License Type.  Options are `BYOL` or `PAYG` | `string` | BYOL    |
| software\_version | Checkpoint Software Version                 | `string` | R81.10  |

#### Notes

- Supported Software versions are R80.40, R81.10, and R81.20

### Optional Inputs

| Name                           | Description                                           | Type           | Default                |
|--------------------------------|-------------------------------------------------------|----------------|------------------------|
| machine\_type                  | GCP Machine Type for the VMs                          | `string`       | n1-standard-4          |
| zones                          | Short name of the zones to use in this region         | `list(string)` | ["b","c"]              |
| admin\_shell                   | Shell for the 'admin' user                            | `string`       | /etc/cli.sh            |
| admin\_password                | Password for the 'admin' user                         | `string`       | n/a                    |
| sic\_key                       | Secure Internal Communication passkey                 | `string`       | n/a                    |
| create\_cluster\_external\_ips | Create External IPs for Cluster                       | `bool`         | true                   |
| create\_member\_external\_ips  | Create External IPs for Mgmt Interfaces               | `bool`         | true                   |
| allow_upload_download          | Allow Software updates via Web                        | `bool`         | false                  |
| enable\_monitoring             | Activate StackDriver Monitoring                       | `bool`         | false                  |
| network\_tags                  | Network Tags to apply to gateways                     | `list(string)` | ["checkpoint-gateway"] |
| disk\_type                     | Disk type for gateways                                | `string`       | pd-ssd                 |
| disk\_size                     | Disk size for gateways (in GB)                        | `number`       | 100                    |
| disk\_auto\_delete             | Auto delete disk when VM is deleted                   | `bool`         | true                   |
| description                    | Description for the cluster members                   | `string`       | n/a                    |

### Notes

- default description for Clusters is "CloudGuard Highly Available Security Cluster" 

## Outputs

| Name              | Description                                     | Type     |
|-------------------|-------------------------------------------------|----------|
| cluster\_name     | Name of the Cluster                             | `string` |
| cluster\_address  | Primary Cluster Address of the Cluster          | `string` |
| license\_type     | License type that was deployed                  | `string` |
| software\_version | Software version that was deployed              | `string` |
| admin\_password   | Admin password for the gateways                 | `string` |
| sic\_key          | SIC key for the gateways                        | `string` |
| members           | Information about each Cluster Member (gateway) | `map`    |

## Sample Inputs

### R81.10 PAYG cluster in us-central1

```
project_id             = "my-project-id"
name                   = "my-cluster"
region                 = "us-central1"
license_type           = "PAYG"
```

### R81.10 BYOL cluster in us-east4 with custom options

```
project_id             = "my-project-id"
name                   = "my-cluster"
region                 = "us-east4"
allow_upload_download  = true
enable_monitoring      = true
admin_password         = "abcxyz0123456789"
sic_key                = "abcd1234"
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

### R80.40 BYOL cluster in europe-west4 with custom machine type

```
project_id        = "my-project-id"
name              = "my-cluster"
region            = "us-east4"
machine_type      = "n2d-custom-4-8192"
software_version  = "R80.40"
```

