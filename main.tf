#define providel in parent to be able to use depend_on in module définition
#error when put directly in the submodule, provifer.tf has to be created in parent and child
#and required provider only has to be defined in that file
provider "proxmox" {
  pm_parallel         = 3
  pm_tls_insecure     = true
  pm_api_url          = var.pm_api.url
  pm_api_token_id     = var.pm_api.token_id
  pm_api_token_secret = var.pm_api.token_secret
}

#download windows server template files
# module "iso_download" {
#   source = "./modules/iso_download/"
# }

#create PFSENS VM
module "pfsense" {
  source = "./modules/pfsense/"
  pfsense = {
    ip           = var.pfsense.ip
    password     = var.pfsense.password
    new_password = var.pfsense.new_password
    iso          = var.pfsense.iso
    vmid         = var.pfsense.vmid
  }
}

module "provisioning" {
  source = "./modules/provisioning"
  provisioning = {
    vmid          = var.provisioning.vmid
    disk_size     = var.provisioning.disk_size
    template      = var.provisioning.template
    host          = var.provisioning.host
    gateway       = var.provisioning.gateway
    root_password = var.provisioning.root_password
    private_key   = var.provisioning.private_key
    public_key    = var.provisioning.public_key
  }
  depends_on = [module.pfsense]
}

