#!/bin/bash

rm -rf .terraform/
rm .terraform.lock
rm .terraform.lock.hcl
rm terraform.tfstate
rm .terraform.tfstate.lock.info

sudo iptables -t nat -F
sudo iptables -t nat -X

# Function to remove SSH host keys if they exist
remove_ssh_host_keys() {
    local hosts=("provisioning" "10.0.0.2" "192.168.2.2")
    for host in "${hosts[@]}"; do
        if ssh-keygen -F "$host" > /dev/null; then
            ssh-keygen -f "/root/.ssh/known_hosts" -R "$host"
            echo "Removed SSH host key for $host."
        else
            echo "No SSH host key found for $host."
        fi
    done
}

# Function to restore network interfaces configuration
restore_network_interfaces() {
    cp /etc/network/interfaces.back /etc/network/interfaces
    service networking restart
    ifreload -a
}

# Function to destroy Terraform resources
destroy_terraform_resources() {
    local terraform_user=$(grep "PROXM_TRF_USER" goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
    local terraform_role=$(grep "PROXM_TRF_ROLE" goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
    
    # Uncomment the following line if you need to use Terraform destroy
    # terraform destroy -var-file="files/dev.tfvars" --auto-approve
    
    if pveum user list | grep -q "${terraform_user}@pve"; then
        pveum user delete "${terraform_user}@pve"
        echo "User ${terraform_user}@pve deleted."
    else
        echo "User ${terraform_user}@pve does not exist."
    fi

    if pveum role list | grep -q "${terraform_role}"; then
        pveum role delete "${terraform_role}"
        echo "Role ${terraform_role} deleted."
    else
        echo "Role ${terraform_role} does not exist."
    fi
}

# Function to destroy all VMs in GOAD pool
destroy_all_goad_vms() {
    bash modules/provisioning/scripts/destroy.sh
}

# Function to destroy a VM or container by name
destroy_resource_by_name() {
    local resource_name=$1
    local resource_type=$2

    local resource_id
    if [ "$resource_type" == "vm" ]; then
        resource_id=$(qm list | grep -i "$resource_name" | awk '{print $1}')
    else
        resource_id=$(pct list | grep -i "$resource_name" | awk '{print $1}')
    fi

    if [ -n "$resource_id" ]; then
        echo "Destroying $resource_type with name $resource_name and ID $resource_id..."
        if [ "$resource_type" == "vm" ]; then
            qm stop "$resource_id"
            qm destroy "$resource_id" --purge --skiplock
        else
            pct stop "$resource_id"
            pct destroy "$resource_id"
        fi
        echo "$resource_type $resource_name destroyed."
    else
        echo "No $resource_type found with the name $resource_name."
    fi
}

# Function to delete Proxmox pools if they exist and are empty
delete_proxmox_pools() {
    local pools=("PROXM_ADMIN_POOL" "PROXM_TEMPLATE_POOL" "PROXMOX_GOAD_POOL")
    for pool in "${pools[@]}"; do
        local pool_id=$(grep "$pool" goad.conf | cut -d '=' -f2 | tr -d '[:space:]')
        if [ -n "$pool_id" ] && pvesh get /pools/"$pool_id" > /dev/null 2>&1; then
            local pool_content=$(pvesh get /pools/"$pool_id" --output-format json)
            if [ "$(echo "$pool_content" | jq '.members | length')" -eq 0 ]; then
                pvesh delete /pools/"$pool_id"
                echo "Pool $pool_id deleted."
            else
                echo "Pool $pool_id is not empty and cannot be deleted."
            fi
        else
            echo "Pool $pool_id does not exist or could not be found."
        fi
    done
}


# Main script execution starts here
remove_ssh_host_keys
restore_network_interfaces
destroy_terraform_resources
destroy_all_goad_vms
destroy_resource_by_name "pfsense" "vm"
destroy_resource_by_name "provisioning" "container"
delete_proxmox_pools