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
# Run apt/debconf without any interactive prompt
# ==================================================================
export DEBIAN_FRONTEND=noninteractive

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
# (the script runs every command as root, so we do not rely on sudo:
#  on a minimal Debian install sudo may not even be present)
# ==================================================================
if [ "$EUID" -ne 0 ]
  then echo -e "${RED}{ERROR}${ENDCOLOR} The script must be ran as root, please try again.\n"
  exit 1
fi

# ==================================================================
# Detect which cloud-init packages are installed.
# Since Ubuntu 24.10 the package was split into 'cloud-init' (a thin
# metapackage) and 'cloud-init-base' (the real implementation), so
# purging only 'cloud-init' would leave cloud-init working. Debian 13
# and Ubuntu 24.04 still ship a single 'cloud-init' package.
# ==================================================================
CI_PKGS=()
for pkg in cloud-init cloud-init-base; do
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    CI_PKGS+=("$pkg")
  fi
done

if [ ${#CI_PKGS[@]} -eq 0 ]; then
  echo -e "${YELLOW}{INFO}${ENDCOLOR} cloud-init does not appear to be installed, nothing to do.\n"
  exit 0
fi
echo -e "${YELLOW}{INFO}${ENDCOLOR} Detected cloud-init package(s): ${CI_PKGS[*]}"

# ==================================================================
# Protect netplan.io from being removed.
# On Ubuntu, cloud-init(-base) depends on netplan.io; once cloud-init
# is purged netplan.io is left orphaned and a future 'apt autoremove'
# would remove it and break networking. Marking it as manually
# installed prevents that, now and in the future.
# ==================================================================
if dpkg-query -W -f='${Status}' netplan.io 2>/dev/null | grep -q "install ok installed"; then
  echo -e "${YELLOW}{INFO}${ENDCOLOR} netplan.io is installed, marking it as manually installed so it survives future 'apt autoremove'."
  apt-mark manual netplan.io
else
  echo -e "${YELLOW}{INFO}${ENDCOLOR} netplan.io is not installed, no need to protect it."
fi

# ==================================================================
# Create an empty file to prevent the service from starting.
# This alone is the officially recommended way to disable cloud-init.
# ==================================================================
touch /etc/cloud/cloud-init.disabled

# ==================================================================
# Tell debconf to deselect every datasource ("None") so cloud-init is
# disabled before removal. The datasources question moved from the
# 'cloud-init' template to 'cloud-init-base' with the package split,
# so we set both (setting an unused template is harmless).
# ==================================================================
echo "cloud-init cloud-init/datasources multiselect None" | debconf-set-selections
echo "cloud-init-base cloud-init-base/datasources multiselect None" | debconf-set-selections

# ==================================================================
# Clean any existing cloud-init data and logs (if the CLI is present)
# ==================================================================
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean
fi

# ==================================================================
# Apply the debconf selections non-interactively
# ==================================================================
dpkg-reconfigure -fnoninteractive "${CI_PKGS[@]}"

# ==================================================================
# Uninstall the package(s) and delete the folders
# ==================================================================
apt-get purge -y "${CI_PKGS[@]}"
rm -rf /etc/cloud/ /var/lib/cloud/

# ==================================================================
# Print a message on screen
# ==================================================================
echo -e "${YELLOW}{INFO}${ENDCOLOR} cloud-init should have been uninstalled; a manual reboot is required to complete. \n"
