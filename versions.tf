terraform {
  required_version = ">= 0.13.7"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
    #template = {
    #  version = "~> 2.0"
    #}
  }
}

/* Not needed; we set these are resource level
provider "google" {
  project = var.project_id
  region  = var.region
}
*/
