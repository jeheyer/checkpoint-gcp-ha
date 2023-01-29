# for CheckPoint HA Cluster on Google Cloud Platform

## Important Notes

After cluster has been configured in SmartConsole, set **configured = true** 

Otherwise, re-running apply may remove cluster IP addresses

## Sample Inputs

### R81.10 PAYG cluster in us-central1

```
project_id = "my-project-id"
cluster = {
  name              = "my-cluster"
  region            = "us-central1"
  license_type      = "PAYG"
}
```

### R81.10 BYOL cluster in us-central1 with custom zone selection and no external IP for mgmt interfaces

```
project_id = "my-project-id"
cluster = {
  name                       = "my-cluster"
  region                     = "us-central1"
  zones                      = ["c","f"]
  license_type               = "BYOL"
  create_member_external_ips = false
}
```

### R80.40 BYOL cluster in europe-west4 with custom machine type (AMD EPYC Rome with 8 GB RAM)

```
project_id = "my-project-id"
cluster = {
  name              = "my-cluster"
  region            = "us-east4"
  machine_type      = "n2d-custom-4-8192"
  software_version  = "R80.40"
}
```

## Default Behavior

Creates an R81.10 BYOL HA cluster in us-central1 with machine type n1-standard-4 on default networks and subnets

## IMPORT examples

### An import example

```
```

### Another import example

```
```
