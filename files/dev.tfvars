pm_api = {
  url          = "PROXM_API_URL"
  token_id     = "terraform@pve!terratoken"
  token_secret = "76c7c8ab-869c-4d0b-8cab-de6946529b5a"
}

pools = {
  admin_pool      = "ADMIN"
  template_pool   = "TEMPLATE"
  goad_pool       = "GOAD"
}

pfsense = {
  password     = "pfsense"
  new_password = "pfsense30*#"
  ip           = "192.168.2.2"
  vmid         = "100"
  iso          = "local:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso"
}

provisioning = {
  vmid          = "101"
  disk_size     = "20G"
  template      = "local:vztmpl/ubuntu-23.10-standard_23.10-1_amd64.tar.zst"
  host          = "provisioning"
  gateway       = "192.168.2.2"
  private_key   = "ssh/provisioning_id_rsa"
  public_key    = "ssh/provisioning_id_rsa.pub"
  root_password = "uChahl5ung3eQuei"
  vlanid        = "10"
}
