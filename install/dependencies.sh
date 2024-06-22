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

print_header "Download HashiCorp GPG key if not present"
if [ ! -f /tmp/hashicorp.gpg ]; then
    wget -q -O /tmp/hashicorp.gpg https://apt.releases.hashicorp.com/gpg
    if [ $? -eq 0 ]; then
        echo "HashiCorp GPG key downloaded successfully."
    else
        echo "Failed to download HashiCorp GPG key."
        exit 1
    fi
else
    echo "HashiCorp GPG key already exists at /tmp/hashicorp.gpg."
fi

print_header "Configure HashiCorp apt repository"
if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.gpg
    echo "HashiCorp GPG key added to keyring."
else
    echo "HashiCorp GPG keyring already exists at /usr/share/keyrings/hashicorp-archive-keyring.gpg."
fi

REPO_LINE="deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
if ! grep -Fxq "$REPO_LINE" /etc/apt/sources.list.d/hashicorp.list 2>/dev/null; then
    echo "$REPO_LINE" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    echo "HashiCorp apt repository added."
else
    echo "HashiCorp apt repository already present."
fi

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
