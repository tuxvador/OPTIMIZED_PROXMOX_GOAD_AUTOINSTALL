#!/bin/bash

set -e

# Function to print section headers
print_header() {
    echo -e "\n********************************************************************************************"
    echo "$1"
    echo "********************************************************************************************"
}

# Function to create pools on Proxmox
create_pools() {
    local pools=(
        "PROXM_ADMIN:admin_pool:create_admin_pool_for_pfsense"
        "PROXM_TEMPLATE_POOL:template_pool:create_template_pool_for_pfsense"
        "PROXMOX_GOAD_POOL:goad_pool:create_goad_pool_for_pfsense"
    )

    for pool in "${pools[@]}"; do
        local key=${pool%%:*}
        local pool_id
        pool_id=$(grep "$key" goad.conf | cut -d '=' -f2 | tr -d '[:space:]')

        if [ -n "$pool_id" ]; then
            if ! pvesh get /pools --poolid "$pool_id" &> /dev/null; then
                pvesh create /pools --poolid "$pool_id" --comment "${pool##*:}" || {
                    echo "Failed to create pool $pool_id"
                    exit 1
                }
                sleep 3
            else
                echo "Pool $pool_id already exists. Skipping creation."
            fi
        else
            echo "Pool ID for key $key not found in configuration."
        fi
    done
}

# Function to check if a file exists
check_file_exists() {
    [ -f "$1" ] || { echo "File '$1' not found!"; exit 1; }
}

# Function to extract values from goad.conf
extract_value() {
    grep "$1" goad.conf | cut -d '=' -f2 | tr -d '[:space:]'
}

# Function to generate SSH keys
generate_ssh_keys() {
    ssh-keygen -q -t rsa -b 4096 -N "" -f "ssh/$1" <<< "y"
}

# Function to transform values for use in pfSense script
transform_value() {
    echo "$1" | sed 's/./&-/g; s/-$//; s/\./dot/g'
}

# Function to update goad.conf
update_goad_conf() {
    sed -i "s|.*${1}=.*|${1}=${2}|" goad.conf
}

# Function to create Terraform user, role, and API access token
create_terraform_user_and_token() {
    local trf_user=$(extract_value "PROXM_TRF_USER")
    local trf_usr_pwd=$(extract_value "PROXM_TRF_USR_PWD")
    local trf_token_id=$(extract_value "PROXM_TRF_TOKEN_ID")
    local trf_token_name=$(extract_value "PROXM_TRF_TOKEN_NAME")

    pveum user add "$trf_user@pve" --password "$trf_usr_pwd"
    local trf_token_value
    trf_token_value=$(pvesh create /access/users/"$trf_user@pve"/token/"$trf_token_name" --expire 0 --privsep 0 --output-format json | jq -r '.value')

    update_goad_conf "PROXM_TRF_USR_PWD" "$(pwgen -c 16 -n 1)"
    update_goad_conf "PROXM_TRF_TOKEN_VALUE" "$trf_token_value"

    local trf_role=$(extract_value "PROXM_TRF_ROLE")
    pveum role add "$trf_role" -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt VM.Console SDN.Use"
    pveum aclmod / -user "$trf_user@pve" -role "$trf_role"
}

# Function to generate tfvarfile
generate_tfvarfile() {
    cat > files/dev.tfvars << EOF
pm_api = {
  url          = "$(extract_value PROXM_API_URL)"
  token_id     = "$(extract_value PROXM_TRF_TOKEN_ID)"
  token_secret = "$(extract_value PROXM_TRF_TOKEN_VALUE)"
}

pools = {
  admin_pool      = "$(extract_value PROXM_ADMIN_POOL)"
  template_pool   = "$(extract_value PROXM_TEMPLATE_POOL)"
  goad_pool       = "$(extract_value PROXMOX_GOAD_POOL)"
}

pfsense = {
  password     = "$(extract_value PFS_DEFAULT_PWD)"
  new_password = "$(extract_value PFS_PWD)"
  ip           = "$(extract_value PFS_LAN_IP)"
  vmid         = "$(extract_value PROXM_VMID)"
  iso          = "$(extract_value PFS_ISO)"
}

provisioning = {
  vmid          = "$(extract_value PROV_VMID)"
  disk_size     = "$(extract_value PROV_DISK_SIZE)"
  template      = "$(extract_value PROV_TEMPLATE)"
  host          = "$(extract_value PROV_HOSTS)"
  gateway       = "$(extract_value PROV_GATEWAY)"
  private_key   = "$(extract_value PROV_SSH_KEY)"
  public_key    = "$(extract_value PROV_SSH_PUB_KEY)"
  root_password = "$(extract_value PROV_PASSWORD)"
  vlanid        = "$(extract_value PROV_VLANID)"
}
EOF
}

# Function to create Packer configuration file
generate_packer_config() {
    cat > files/config.auto.pkrvars.hcl << EOF
proxmox_url             = "$(extract_value PROXM_API_URL)"
proxmox_username        = "$(extract_value PROXM_TRF_TOKEN_ID)"
proxmox_token           = "$(extract_value PROXM_TRF_TOKEN_VALUE)"
proxmox_skip_tls_verify = "true"
proxmox_node            = "$(extract_value PROXM_NODE_NAME)"
proxmox_pool            = "$(extract_value PROXM_TEMPLATE_POOL)"
proxmox_iso_storage     = "$(extract_value PROXM_ISO_STORAGE)"
proxmox_vm_storage      = "$(extract_value PROXM_VM_STORAGE)"
EOF
}

# Function to update Ansible inventory
update_inventory() {
    sed -i "s|\($2:\s*\).*|\1$(escape_for_sed "$(extract_value "$1")")|" modules/pfsense/scripts/ansible/inventory.yml
}

# Function to escape values for sed
escape_for_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

# Function to update pfSense script with values from goad.conf
update_pfsense_script() {
    cp modules/pfsense/scripts/pfsense.template.sh modules/pfsense/scripts/pfsense.sh
    chmod 755 modules/pfsense/scripts/pfsense.sh

    local keys=(
        "PFS_WAN_INTERFACE:chg_wan_interface"
        "PFS_LAN_INTERFACE:chg_lan_interface"
        "PFS_OPTIONAL_INTERFACE:chg_opt_interface"
        "PFS_WAN_IPV4_ADDRESS:change_pfs_wan_ip"
        "PFS_WAN_GATEWAY:change_pfs_wan_gateway"
        "PFS_LAN_IPV4_ADDRESS:change_pfs_lan_ip"
        "PFS_LAN_GATEWAY:change_pfs_lan_gateway"
        "LAN_DHCP_START:change_pfs_lan_dhcp_start"
        "LAN_DHCP_END:change_pfs_lan_dhcp_end"
    )

    for key in "${keys[@]}"; do
        sed -i "s|${key##*:}|$(transform_value "$(extract_value "${key%%:*}")")|g" modules/pfsense/scripts/pfsense.sh
    done
}

print_header "Destroy before install"
bash install/destroy.sh

# Main script execution starts here
print_header "Create pools on Proxmox"
create_pools

print_header "Check and Backup Configuration Files"
check_file_exists goad.conf
check_file_exists modules/pfsense/scripts/ansible/inventory.yml
cp /etc/network/interfaces /etc/network/interfaces.back

print_header "Create Config"
pmurl="PROXM_API_URL=https://$(ip addr show vmbr0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f 1):8006/api2/json"
update_goad_conf "PROXM_API_URL" "$pmurl"

pfpwd=$(extract_value "PFS_PWD")
pfpwdhash=$(htpasswd -bnBC 10 '' "$pfpwd" | head -n 1 | cut -d ':' -f2)
prov_passwd=$(pwgen -c 16 -n 1)
generate_ssh_keys provisioning_id_rsa
generate_ssh_keys pfsense_id_rsa

update_goad_conf "PFS_HASH" "$pfpwdhash"
update_goad_conf "PROV_PASSWORD" "$prov_passwd"

print_header "Download ISOS"
bash install/download_isos.sh

print_header "Create Terraform User, Role, and API Access Token"
create_terraform_user_and_token

print_header "Generate tfvarfile"
generate_tfvarfile

print_header "Generate Packer Configuration File"
generate_packer_config

print_header "Create Certificates"
bash install/certs.sh

print_header "Install Needed Packages"
bash install/dependencies.sh

print_header "Create Interfaces"
bash install/interface.sh

print_header "Replace Values in Ansible Inventory with Values from goad.conf"
update_inventory 'PFS_LAN_IPV4_ADDRESS' 'ansible_host'
update_inventory 'PFS_DEFAULT_PWD' 'ansible_password'
update_inventory 'PFS_PWD' 'new_pfs_pwd'
update_inventory 'PFS_HASH' 'new_pfs_pwd_hash'
update_inventory 'PFS_WAN_IPV4_ADDRESS' 'PFS_WAN_IP'
update_inventory 'PROXM_DOMAIN' 'PM_DOMAIN'
update_inventory 'PFS_HOSTNAME' 'PFS_HOSTNAME'
update_inventory 'PROXM_DNS_HOSTNAME' 'PM_DNS_HOSTNAME'
update_inventory 'PROXM_DNS_IP' 'PM_DNS_IP'
update_inventory 'PFS_whitelist_ssh_network' 'whitelist_ssh_network'
update_inventory 'PFS_WAN_NETWORK' 'WAN_NETWORK'
update_inventory 'PFS_WAN_MASK' 'WAN_MASK'
update_inventory 'PFS_LAN_NETWORK' 'LAN_NETWORK'
update_inventory 'PFS_LAN_MASK' 'LAN_MASK'
update_inventory 'PFS_WAN_INTERFACE' 'PFS_WAN_INTERFACE'
update_inventory 'PFS_LAN_INTERFACE' 'PFS_LAN_INTERFACE'
update_inventory 'PFS_OPTIONAL_INTERFACE' 'PFS_OPTIONAL_INTERFACE'
update_inventory 'PFS_VLAN10_INTERFACE' 'PFS_VLAN10_INTERFACE'
update_inventory 'PFS_VLAN20_INTERFACE' 'PFS_VLAN20_INTERFACE'
update_inventory 'PFS_WAN_IPV4_ADDRESS' 'PFS_WAN_IPV4_ADDRESS'
update_inventory 'PFS_WAN_GATEWAY' 'PFS_WAN_GATEWAY'
update_inventory 'PFS_LAN_IPV4_ADDRESS' 'PFS_LAN_IPV4_ADDRESS'
update_inventory 'PFS_LAN_GATEWAY' 'PFS_LAN_GATEWAY'
update_inventory 'VLAN10_NETWORK' 'VLAN10_NETWORK'
update_inventory 'VLAN20_NETWORK' 'VLAN20_NETWORK'
update_inventory 'VLANTAG10NAME' 'VLANTAG10NAME'
update_inventory 'VLANTAG10_ipv4' 'VLANTAG10_ipv4'
update_inventory 'VLANTAG20NAME' 'VLANTAG20NAME'
update_inventory 'VLANTAG20_ipv4' 'VLANTAG20_ipv4'
update_inventory 'VLAN10_DHCP_START' 'VLAN10_DHCP_START'
update_inventory 'VLAN10_DHCP_END' 'VLAN10_DHCP_END'
update_inventory 'VLAN20_DHCP_START' 'VLAN20_DHCP_START'
update_inventory 'VLAN20_DHCP_END' 'VLAN20_DHCP_END'
update_inventory 'VLAN10_ID' 'VLAN10_ID'
update_inventory 'VLAN20_ID' 'VLAN20_ID'
update_inventory 'VLAN10_DESC' 'VLAN10_DESC'
update_inventory 'VLAN20_DESC' 'VLAN20_DESC'
update_inventory 'GOAD_VPN_NETWORK' 'GOAD_VPN_NETWORK'
update_inventory 'GOAD_VPN_PORT' 'GOAD_VPN_PORT'

print_header "Modify pfSense Script with Content from goad.conf"
update_pfsense_script

print_header "Install and Auto-Configure pfSense VM"
terraform init
terraform apply -var-file="files/dev.tfvars" --auto-approve

print_header "Provisioning"
# Add provisioning commands here

print_header "Delete Terraform Token, User, and Role"
pvesh delete /access/users/"$trf_user@pve"/token/"$trf_token_name"
pveum user delete "$trf_user@pve"
pveum role delete "$trf_role"