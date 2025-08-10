terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = ">=1.0"
    }
  }
}

resource "ovh_vps" "vps" {
  ovh_subsidiary = ""
}
