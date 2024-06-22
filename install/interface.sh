#!/bin/bash

wanmask=0
wannet=""

echo "Check interface names in /etc/network/interfaces before running this script"
echo "----------------------------------------------"
echo "Create static interfaces"
echo "----------------------------------------------"

# Function to convert CIDR to netmask
cidr_to_netmask() {
    local cidr=$1
    if [[ $cidr -lt 1 || $cidr -gt 32 ]]; then
        echo "Invalid CIDR value. It must be between 1 and 32."
        return 1
    fi

    local mask=0xffffffff
    local shift=$((32 - cidr))
    mask=$((mask << shift))
    local octet1=$(( (mask & 0xff000000) >> 24 ))
    local octet2=$(( (mask & 0x00ff0000) >> 16 ))
    local octet3=$(( (mask & 0x0000ff00) >> 8 ))
    local octet4=$(( mask & 0x000000ff ))
    echo "$octet1.$octet2.$octet3.$octet4" > /tmp/mask
}

ifreload -a

# Function to perform the installation
install_function() {
  echo "Running the interactive installation process..."
  interfaces=$(grep IFACENAME goad.conf | cut -d "=" -f2)
  for interface in $interfaces; do
    echo "Processing interface: $interface"
    name=$(echo $interface | cut -d '-' -f1)
    ip=$(echo $interface | cut -d '-' -f2)
    mask=$(echo $interface | cut -d '-' -f3)
    pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -address $ip -netmask $mask
  done

  vlan_interfaces=$(grep VLANIFACE goad.conf | cut -d "=" -f2)
  for vlan_interface in $vlan_interfaces; do
    echo "Processing vlan_interface: $vlan_interface"
    name=$(echo $vlan_interface | cut -d '-' -f1)
    ids=$(echo $vlan_interface | cut -d '-' -f2)
    pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -bridge_vlan_aware yes

    IFS=','
    read -ra ADDR <<< "$ids"
    for value in "${ADDR[@]}"; do
      echo "Processing value: $value"
      pvesh create /nodes/windows-perso/network -iface "vlan$value" -type vlan -autostart true -vlan-raw-device $name
    done
    unset IFS
  done
  wanmask=$(grep WANMASK goad.conf | cut -d "=" -f2)
  wannet=$(grep WANNET goad.conf | cut -d "=" -f2)
}

default_install=$(grep DEFAULT_INSTALL goad.conf | cut -d "=" -f2 | tr -d '[:space:]')

if [ "$default_install" = "Y" ]; then
    install_function
else
    echo "DEFAULT_INSTALL is not set to Y. Proceeding with interactive install."
    while :; do
      read -p "Enter a number of interfaces you want to create between 2 and 5 (default 2): " if_number
      [[ ${if_number:=2} =~ ^[0-9]+$ ]] || { echo "Input an integer between 1 and 5"; continue; }
      if ((if_number >= 1 && if_number <= 5)); then
        break
      else
        echo "Input an integer between 1 and 5"
      fi
    done

    for i in $(seq 1 $if_number); do
      while :; do
        if [[ $i -eq 1 ]]; then
          read -p "Enter a valid IP address number $i (default: 10.0.0.1): " ip
          [[ ${ip:=10.0.0.1} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a valid IP address"; continue; }
        else
          read -p "Enter a valid IP address number $i (default: 192.168.2.1): " ip
          [[ ${ip:=192.168.2.1} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a valid IP address"; continue; }
        fi
        break
      done

      while :; do
        if [[ $i -eq 1 ]]; then
          read -p "Enter network mask between 1 and 32 (default: 30): " mask
          [[ ${mask:=30} =~ ^[0-9]+$ ]] || { echo "Input an integer between 1 and 32"; continue; }
        else
          read -p "Enter network mask between 1 and 32 (default: 24): " mask
          [[ ${mask:=24} =~ ^[0-9]+$ ]] || { echo "Input an integer between 1 and 32"; continue; }
        fi
        if (($mask >= 1 && $mask <= 32)); then
          cidr_to_netmask $mask
          netmask=$(cat "/tmp/mask")
          break
        else
          echo "Input an integer between 1 and 32"
        fi
      done

      name="vmbr"
      while :; do
        if [[ $i -eq 1 ]]; then
          read -p "Enter the bridge name to create vmbr? (default: 1): " if_name
          [[ ${if_name:=1} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        else
          read -p "Enter the bridge name to create vmbr? (default: 2): " if_name
          [[ ${if_name:=2} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        fi
        if ((if_name >= 1 && if_name <= 99)); then
          name="$name$if_name"
          break
        else
          echo "Enter a number between 0 and 99"
        fi
      done
      pvesh create /nodes/windows-perso/network -iface $name -type bridge -autostart true -address $ip -netmask $netmask
    done

    echo "----------------------------------------------"
    echo "Create raw device for VLAN"
    echo "----------------------------------------------"
    while :; do
        read -p "Enter the raw device VLAN name vmbr? (default: 3): " vlanvmbr
        [[ ${vlanvmbr:=3} =~ ^[0-9]+$ ]] || { echo "Enter a number between 0 and 99"; continue; }
        if ((vlanvmbr >= 1 && vlanvmbr <= 99)); then
          name="$vlanvmbr"
          break
        else
          echo "Enter a number between 0 and 99"
        fi
    done
    pvesh create /nodes/windows-perso/network -iface "vmbr$name" -type bridge -autostart true -bridge_vlan_aware yes

    echo "----------------------------------------------"
    echo "Create Linux VLAN devices for each VLAN"
    echo "----------------------------------------------"
    while :; do
      read -p "Enter a number of VLANs you wish to create (default: 2): " if_vlan
      [[ ${if_vlan:=2} =~ ^[0-9]+$ ]] || { echo "Input an integer between 1 and 5"; continue; }
      if ((if_vlan >= 1 && if_vlan <= 5)); then
        break
      else
        echo "Input an integer between 1 and 5"
      fi
    done

    for i in $(seq 1 $if_vlan); do
      while :; do
        if [[ $i -eq 1 ]]; then
          read -p "Enter a number corresponding to the VLAN ID (default: 10): " if_vlanid
          [[ ${if_vlanid:=10} =~ ^[0-9]+$ ]] || { echo "Input an integer"; continue; }
        else
          read -p "Enter a number corresponding to the VLAN ID (default: 20): " if_vlanid
          [[ ${if_vlanid:=20} =~ ^[0-9]+$ ]] || { echo "Input an integer"; continue; }
        fi
        break
      done
      pvesh create /nodes/windows-perso/network -iface vlan$if_vlanid -type vlan -autostart true -vlan-raw-device "vmbr$vlanvmbr"
    done

    echo "----------------------------------------------"
    echo "Enter pfSense WAN Network and mask"
    echo "----------------------------------------------"
    while :; do
      read -p "Enter the WAN network used by pfSense (default: 10.0.0.0): " wannet
      [[ ${wannet:=10.0.0.0} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a valid IP address"; continue; }
      if [[ $wannet =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
      else
        echo "Not a valid IP address"
      fi
    done

    while :; do
      read -p "Enter WAN network mask between 1 and 32 (default: 30): " wanmask
      [[ ${wanmask:=30} =~ ^[0-9]+$ ]] || { echo "Input an integer between 1 and 32"; continue; }
      if (($wanmask >= 1 && $wanmask <= 32)); then
        break
      else
        echo "Input an integer between 1 and 32"
      fi
    done
fi

cp /etc/network/interfaces.new /etc/network/interfaces
rm /etc/network/interfaces.new
ifreload -a

echo "----------------------------------------------"
echo "Configure interfaces in pfSense Terraform file"
echo "----------------------------------------------"
cp modules/pfsense/pfsense.tf.template modules/pfsense/pfsense.tf

WANIFACE=$(grep WAN-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')
LANIFACE=$(grep LAN-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')
VLANIFACE=$(grep Vlan-IFACE goad.conf | cut -d "=" -f2 | tr -d '[:space:]')

sed -i -e "s|change-to-lan-interface1|${WANIFACE}|g" \
       -e "s|change-to-lan-interface2|${LANIFACE}|g" \
       -e "s|change-to-vlan-interface1|${VLANIFACE}|g" modules/pfsense/pfsense.tf

echo "----------------------------------------------"
echo "Enable port forwarding and forward all traffic to pfSense"
echo "----------------------------------------------"

vmbr0ip=$(ip addr show vmbr0 | grep "inet " | cut -d ' ' -f 6 | cut -d/ -f 1)
pfswanip=$(grep 'PFS_WAN_IPV4_ADDRESS' goad.conf | cut -d '=' -f2)

awk -v wannet="$wannet" -v wanmask="$wanmask" -v vmbr0ip="$vmbr0ip" -v pfswanip="$pfswanip" '
/^auto vmbr0$/ { print; in_vmbr0=1; next }
in_vmbr0 && /^auto/ {
    in_vmbr0=0
    print "        #---- Enable IP forwarding"
    print "        post-up echo 1 > /proc/sys/net/ipv4/ip_forward"
    print "        post-down echo 0 > /proc/sys/net/ipv4/ip_forward"
    print ""
    print "        #---- Allow SSH access without passing through pfSense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
    print ""
    print "        #---- Allow HTTPS access without passing through pfSense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
    print ""
    print "        #---- Add static route"
    print "        post-up ip route add 192.168.10.0/24 via 10.0.0.2"
    print "        post-down ip route del 192.168.10.0/24 via 10.0.0.2"
    print ""
    print "        #---- Redirect all to pfSense"
    print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -j DNAT --to " pfswanip
    print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -j DNAT --to " pfswanip
    print ""
    print "        #---- Add SNAT WAN -> public IP"
    print "        post-up iptables -t nat -A POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
    print "        post-down iptables -t nat -D POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
    print ""
    print "        #---- Exit network with vmbr0 IP address for all machines"
    print "        # post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
    print "        # post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
    print ""
}
{ print }
END {
    if (in_vmbr0) {
        print "        #---- Enable IP forwarding"
        print "        post-up echo 1 > /proc/sys/net/ipv4/ip_forward"
        print "        post-down echo 0 > /proc/sys/net/ipv4/ip_forward"
        print ""
        print "        #---- Allow SSH access without passing through pfSense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 22 -j ACCEPT"
        print ""
        print "        #---- Allow HTTPS access without passing through pfSense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport 443 -j ACCEPT"
        print ""
        print "        #---- Add static route"
        print "        post-up ip route add 192.168.10.0/24 via 10.0.0.2"
        print "        post-down ip route del 192.168.10.0/24 via 10.0.0.2"
        print ""
        print "        #---- Redirect all to pfSense"
        print "        post-up iptables -t nat -A PREROUTING -i vmbr0 -j DNAT --to " pfswanip
        print "        post-down iptables -t nat -D PREROUTING -i vmbr0 -j DNAT --to " pfswanip
        print ""
        print "        #---- Add SNAT WAN -> public IP"
        print "        post-up iptables -t nat -A POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
        print "        post-down iptables -t nat -D POSTROUTING -o vmbr0 -j SNAT -s " wannet "/" wanmask " --to-source " vmbr0ip
        print ""
        print "        #---- Exit network with vmbr0 IP address for all machines"
        print "        # post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
        print "        # post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE"
        print ""
    }
}
' /etc/network/interfaces > temp_file && mv temp_file /etc/network/interfaces

ifreload -a

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf &> /dev/null

service networking restart

#---- Exit network with vmbr0 IP address for all machines"
# post-up   iptables -t nat -A POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE
# post-down iptables -t nat -D POSTROUTING -s " wannet "/" wanmask " -o vmbr0 -j MASQUERADE
