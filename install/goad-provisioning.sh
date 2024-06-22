#!/bin/bash

# Function to extract values from goad.conf
extract_value() {
    grep "$1" goad.conf | cut -d '=' -f2 | tr -d '[:space:]'
}

# Extract values from goad.conf
PROXM_API_URL=$(extract_value PROXM_API_URL)
PROXM_TRF_TOKEN_ID=$(extract_value PROXM_TRF_TOKEN_ID)
PROXM_TRF_TOKEN_VALUE=$(extract_value PROXM_TRF_TOKEN_VALUE)
PROXM_NODE_NAME=$(extract_value PROXM_NODE_NAME)
PROXMOX_GOAD_POOL=$(extract_value PROXMOX_GOAD_POOL)
PROXM_VM_STORAGE=$(extract_value PROXM_VM_STORAGE)

# Get template IDs
get_template_id() {
    pvesh get /cluster/resources --output-format text --noborder 1 --type vm | grep "$1" | cut -d ' ' -f1 | cut -d '/' -f2
}

WIN_SERVER_2019_ID=$(get_template_id WinServer2019x64)
WIN_SERVER_2016_ID=$(get_template_id WinServer2016)
# Uncomment the next line if you use Windows 10 template
# WINDOWS_10_ID=$(get_template_id Windows10)

# Create the goad-provisioning.variables.tf file
cat > files/goad-provisioning.variables.tf << EOF
variable "pm_api_url" {
  default = "$PROXM_API_URL"
}

variable "pm_api_token" {
  default = "$PROXM_TRF_TOKEN_ID=$PROXM_TRF_TOKEN_VALUE"
}

variable "pm_node" {
  default = "$PROXM_NODE_NAME"
}

variable "pm_pool" {
  default = "$PROXMOX_GOAD_POOL"
}

variable "pm_full_clone" {
  default = false
}

# change this value with the id of your templates (win10 can be ignored if not used)
variable "vm_template_id" {
  type = map(number)

  # set the ids according to your templates
  default = {
      "WinServer2019_x64"  = $WIN_SERVER_2019_ID
      "WinServer2016_x64"  = $WIN_SERVER_2016_ID
      #"Windows10_22h2_x64" = $WINDOWS_10_ID
  }
}

variable "storage" {
  # change this with the name of the storage you use
  default = "$PROXM_VM_STORAGE"
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
EOF