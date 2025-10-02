#!/bin/bash

set -e

# Disable interactive apt prompts
export DEBIAN_FRONTEND=noninteractive

cd /ops

CONFIGDIR=/ops/shared/config

NOMADVERSION=1.8.1

# AWS Dependencies
# sudo apt update
sudo apt-get install -y software-properties-common

sudo add-apt-repository universe && sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean


# Disable the firewall
sudo ufw disable || echo "ufw not installed"

# Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Install HashiCorp Apt Repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install HashiStack Packages
sudo apt-get update && sudo apt-get -y install \
	nomad=$NOMADVERSION*

# # Install CNI plugins
CNI_PLUGIN_VERSION=v1.8.0
ARCH_CNI=amd64
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}".tgz && \
sudo mkdir -p /opt/cni/bin && \
sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

sudo modprobe bridge

# echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
# echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
# echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
