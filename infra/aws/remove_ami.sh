#!/bin/bash

region=$1
ami=$(aws ec2 describe-images --owners "self" --query "Images[].ImageId" --region $region --output text)
echo "ami:" $ami

aws ec2 deregister-image --image-id $ami --region $region

snap_id=$(aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].{ID:SnapshotId}" --region $region --output text)

echo "snap-id:" $snap_id
aws ec2 delete-snapshot --snapshot-id $snap_id --region $region
