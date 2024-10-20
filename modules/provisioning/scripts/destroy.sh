#!/bin/bash

# Define the pool ID and node name
POOL_ID="GOAD"
NODE_NAME="windows-perso"

# Get the list of VM IDs in the pool
VM_IDS=$(pvesh get /pools/${POOL_ID} --output-format json | jq -r '.members[] | select(.type == "qemu") | .vmid')

# Loop through each VM ID, stop the VM, and then destroy it
for VMID in $VM_IDS; do
  echo "Stopping VM ID: $VMID"
  pvesh create /nodes/${NODE_NAME}/qemu/${VMID}/status/stop
  
  echo "Destroying VM ID: $VMID"
  pvesh delete /nodes/${NODE_NAME}/qemu/${VMID}
done

# Get the ID of the PROVISIONING container
PROV_ID=$(pvesh get /nodes/windows-perso/lxc --output-format json | jq -r '.[] | select(.name == "PROVISIONING") | .vmid')

# Check if PROV_ID is not empty
if [ -n "$PROV_ID" ]; then
    echo "PROVISIONING container found with ID: $PROV_ID"
    
    # Stop the container
    pvesh create /nodes/windows-perso/lxc/$PROV_ID/status/stop
    echo "Stopping LXC container $PROV_ID."

    # Delete the container
    pvesh delete /nodes/windows-perso/lxc/$PROV_ID
    echo "LXC container $PROV_ID deleted."
else
    echo "No container named PROVISIONING found."
fi

echo "All VMs in the pool ${POOL_ID} have been stopped and destroyed."