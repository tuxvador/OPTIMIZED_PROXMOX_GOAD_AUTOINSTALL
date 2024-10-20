#!/bin/bash

apt-get update -y
apt-get install -y fish curl git ncdu vim tmux gnupg software-properties-common mkisofs jq unzip
git clone "https://github.com/oh-my-fish/oh-my-fish.git" /tmp/oh-my-fish
fish -c "/tmp/oh-my-fish/bin/install --offline --noninteractive --yes"
chsh -s /usr/bin/fish


#Install packer
# Set the Packer version
PACKER_VERSION="1.11.2"
# Download Packer
curl -O https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
# Unzip the package
unzip packer_${PACKER_VERSION}_linux_amd64.zip
# Move the binary to a directory in your PATH
sudo mv packer /usr/local/bin/
# Clean up the zip file and other extracted files
rm packer_${PACKER_VERSION}_linux_amd64.zip LICENSE.txt


# curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
# apt-add-repository -y "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
# apt update -y && apt install packer

# Install the HashiCorp GPG key.
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

# add terraform sourcelist
# echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
# https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
# tee /etc/apt/sources.list.d/hashicorp.list
# Set the Terraform version
TERRAFORM_VERSION="1.9.7"
# Download Terraform
curl -O https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
# Unzip the package
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
# Move the binary to a directory in your PATH
sudo mv terraform /usr/local/bin/
# Clean up the zip file
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip LICENSE.txt

# update apt and install terraform
apt update -y
apt install -y ansible-core

mkdir -p /root/GIT
cd /root/GIT/
git clone https://github.com/Orange-Cyberdefense/GOAD.git

cd /root/GIT/GOAD/packer/proxmox/scripts/sysprep
wget https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi

cd /root/GIT/GOAD/packer/proxmox/
cp config.auto.pkrvars.hcl.template config.auto.pkrvars.hcl