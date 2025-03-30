#!/usr/bin/env sh
set -eu

################################################################################
#
# For documentation see https://github.com/qoomon/aws-ssm-ssh-proxy-command
#
################################################################################

instance_id="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="$4"

REGION_SEPARATOR='--'
if echo "$instance_id" | grep -q -e "${REGION_SEPARATOR}"
then
  export AWS_REGION="${instance_id##*"$REGION_SEPARATOR"}"
  instance_id="${instance_id%%"$REGION_SEPARATOR"*}"
fi

>/dev/stderr echo "Add public key ${ssh_public_key_path} for ${ssh_user} at instance ${instance_id} for 60 seconds"
instance_availability_zone="$(aws ec2 describe-instances \
    --instance-id "$instance_id" \
    --query "Reservations[0].Instances[0].Placement.AvailabilityZone" \
    --output text)"
aws ec2-instance-connect send-ssh-public-key  \
  --instance-id "$instance_id" \
  --instance-os-user "$ssh_user" \
  --ssh-public-key "file://$ssh_public_key_path" \
  --availability-zone "$instance_availability_zone"

>/dev/stderr echo "Start ssm session to instance ${instance_id}"
aws ssm start-session \
  --target "${instance_id}" \
  --document-name 'AWS-StartSSHSession' \
  --parameters "portNumber=${ssh_port}"
