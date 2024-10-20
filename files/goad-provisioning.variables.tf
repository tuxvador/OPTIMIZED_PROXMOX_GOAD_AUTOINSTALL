variable "pm_api_url" {
  default = "https://192.168.1.68:8006/api2/json"
}

variable "pm_api_token" {
  default = "terraform@pve!terratoken=a52ae096-f9f0-4a10-9dbd-4529a4da5826"
}

variable "pm_node" {
  default = "windows-perso"
}

variable "pm_pool" {
  default = "GOAD"
}

variable "pm_full_clone" {
  default = false
}

# change this value with the id of your templates (win10 can be ignored if not used)
variable "vm_template_id" {
  type = map(number)

  # set the ids according to your templates
  default = {
      "WinServer2019_x64"  = 102
103
104
      "WinServer2016_x64"  = 105
      #"Windows10_22h2_x64" = 
  }
}

variable "storage" {
  # change this with the name of the storage you use
  default = "local-lvm"
}

variable "network_bridge" {
  default = "vmbr3"
}

variable "network_model" {
  default = "e1000"
}

variable "network_vlan" {
  default = 10
}
