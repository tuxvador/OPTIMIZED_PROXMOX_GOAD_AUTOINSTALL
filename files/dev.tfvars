pm_api = {
  url          = "PROXM_API_URL"
  token_id     = "terraform@pve!terratoken"
  token_secret = "9c2f97a9-d817-4bbf-b4ee-33a897b6f1bf"
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
  root_password = "osha2Aefiech4aex"
  vlanid        = "10"
}
