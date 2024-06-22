pm_api = {
  url          = "https://192.168.1.68:8006/api2/json"
  token_id     = "terraform@pve!terratoken"
  token_secret = "e5c82469-3632-4f28-901a-353f702aef47"
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
  root_password = "neimoh2eoSh7chou"
  vlanid        = "10"
}
