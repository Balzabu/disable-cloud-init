#!/bin/bash
#===================================================================
# HEADER
#===================================================================
#  DESCRIPTION
#     Automate the process of disabling cloud-init in a
#     non-interactive way.
#     Based on https://gist.github.com/zoilomora/f862f76335f5f53644a1b8e55fe98320
#===================================================================
#  IMPLEMENTATION
#     Author          Balzabu
#     Copyright       Copyright (c) https://www.balzabu.io
#     License         MIT
#     Github          https://github.com/balzabu
#===================================================================
# END_OF_HEADER
#===================================================================

# ==================================================================
# Useful ANSI codes 
# ==================================================================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
WHITE="\e[97m"
ENDCOLOR="\e[0m"

# ==================================================================
# Credits
# ==================================================================
echo -e "\n.-------------------------."
echo -e "|   ${RED}disable${WHITE}-cloud-init${ENDCOLOR}    |"
echo -e "| Made with ${RED}<3${ENDCOLOR} by ${GREEN}Balzabu${ENDCOLOR} |"
echo -e "'-------------------------'\n"

# ==================================================================
# Check if the script is run as root
# ==================================================================
if [ "$EUID" -ne 0 ]
  then echo -e "${RED}{ERROR}${ENDCOLOR} The script must be ran as root, please try again.\n"
  exit
fi

# ==================================================================
# Create an empty file to prevent the service from starting
# ==================================================================
sudo touch /etc/cloud/cloud-init.disabled

# ==================================================================
# Create a preseed file that deselects "-" all services expect the
# 'None' in /tmp
# ==================================================================
echo "cloud-init cloud-init/datasources multiselect None -NoCloud -ConfigDrive -OpenNebula -DigitalOcean -Azure -AltCloud -OVF -MAAS -GCE -OpenStack -CloudSigma -SmartOS -Bigstep -Scaleway -AliYun -Ec2 -CloudStack -Hetzner -IBMCloud -Oracle -Exoscale -RbxCloud -UpCloud -VMware -Vultr -LXD -NWCS -Akamai" > /tmp/cloud-init.preseed

# ==================================================================
# Load the preseed file from /tmp
# ==================================================================
sudo debconf-set-selections /tmp/cloud-init.preseed

# ==================================================================
# Clean any existing cloud-init data and logs
# ==================================================================
sudo cloud-init clean

# ==================================================================
# Run dpkg-configure in a noninteractive mode
# ==================================================================
sudo dpkg-reconfigure -fnoninteractive cloud-init

# ==================================================================
# Uninstall the package and delete the folders
# ==================================================================
sudo apt-get purge cloud-init
sudo rm -rf /etc/cloud/ && sudo rm -rf /var/lib/cloud/

# ==================================================================
# Print a message on screen
# ==================================================================
echo -e "${YELLOW}{INFO}${ENDCOLOR} cloud-init should have been uninstalled; a manual reboot is required to complete. \n"
