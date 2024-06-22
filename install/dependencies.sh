#!/bin/bash

# Function to print section headers
print_header() {
    echo "----------------------------------------------"
    echo "$1"
    echo "----------------------------------------------"
}

# Function to check if a package is installed
is_installed() {
    dpkg -l "$1" &> /dev/null
    return $?
}

print_header "Download HashiCorp GPG key"
wget -q -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg
sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

print_header "Update apt package list"
sudo apt-get update

print_header "Install required packages if they are not installed"
pkgs=(sshpass gnupg software-properties-common terraform ansible-core pwgen apache2-utils jq)
for pkg in "${pkgs[@]}"; do
    if ! is_installed "$pkg"; then
        sudo apt-get -y --ignore-missing install "$pkg"
    else
        echo "$pkg is already installed"
    fi
done

print_header "Install Ansible collection: pfsensible.core"
ansible-galaxy collection install pfsensible.core

print_header "END"
