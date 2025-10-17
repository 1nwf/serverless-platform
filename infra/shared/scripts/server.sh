#!/bin/bash

set -e

CONFIGDIR=/ops/shared/config

NOMADCONFIGDIR=/etc/nomad.d
HOME_DIR=ubuntu

# Wait for network
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=(`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`)
CLOUD=$1
SERVER_COUNT=$2
RETRY_JOIN=$3
NOMAD_BINARY=$4
REGION=$5
DATACENTER=$6
CLOUD_REGION=""

# TODO: allow multiple cloud regions
if [[ $REGION == *"east"* ]]; then
  CLOUD_REGION="us-west-1"
else
  CLOUD_REGION="us-east-1"
fi


# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

# Nomad
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/nomad.hcl
sed -i "s/CLOUD_REGION/$CLOUD_REGION/g" $CONFIGDIR/nomad.hcl

sed -i "s/REGION/$REGION/g" $CONFIGDIR/nomad.hcl
sed -i "s/DATACENTER/$DATACENTER/g" $CONFIGDIR/nomad.hcl

## Replace existing Nomad binary if remote file exists
if [[ `wget -S --spider $NOMAD_BINARY  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
  curl -L $NOMAD_BINARY > nomad.zip
  sudo unzip -o nomad.zip -d /usr/local/bin
  sudo chmod 0755 /usr/local/bin/nomad
  sudo chown root:root /usr/local/bin/nomad
fi

sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR

sudo systemctl enable nomad.service
sudo systemctl start nomad.service
sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646


# Add hostname to /etc/hosts

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Set env vars for tool CLIs
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
