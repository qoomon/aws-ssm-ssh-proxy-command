#!/usr/bin/env sh
######## Source ################################################################
#
# https://github.com/qoomon/aws-ssm-ec2-proxy-command
#
######## Usage #################################################################
# https://github.com/qoomon/aws-ssm-ec2-proxy-command/blob/master/README.md
#
# Install Proxy Command
#   - Move this script to ~/.ssh/aws-ssm-ec2-proxy-command.sh
#   - Ensure it is executable (chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh)
#
# Add following SSH Config Entry to ~/.ssh/config
#   host i-* mi-*
#     IdentityFile ~/.ssh/id_rsa
#     ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub
#     StrictHostKeyChecking no
#
# Ensure SSM Permissions for Target Instance Profile
#   https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
#
# Open SSH Connection
#   ssh <INSTACEC_USER>@<INSTANCE_ID>
#   
#   Ensure AWS CLI environemnt variables are set properly
#   e.g. AWS_PROFILE='default' ssh ec2-user@i-xxxxxxxxxxxxxxxx
#
#   If default region does not match instance region you need to provide it like this
#   ssh <INSTACEC_USER>@<INSTANCE_ID>--<INSTANCE_REGION>
#
################################################################################
set -eu

REGION_SEPARATOR='--'

ec2_instance_id="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="$4"

if [[ "${ec2_instance_id}" = *${REGION_SEPARATOR}* ]]
then
  export AWS_DEFAULT_REGION="${ec2_instance_id##*${REGION_SEPARATOR}}"
  ec2_instance_id="${ec2_instance_id%%${REGION_SEPARATOR}*}"
fi

instance_availability_zone="$(aws ec2 describe-instances \
    --instance-id "$ec2_instance_id" \
    --query "Reservations[0].Instances[0].Placement.AvailabilityZone" \
    --output text)"

if [ -t 2 ]; then 
  >/dev/tty echo "Add public key ${ssh_public_key_path} to instance ${ec2_instance_id} for 60 seconds"
fi
aws ec2-instance-connect send-ssh-public-key  \
  --instance-id "$ec2_instance_id" \
  --instance-os-user "$ssh_user" \
  --ssh-public-key "file://$ssh_public_key_path" \
  --availability-zone "$instance_availability_zone"

if [ -t 2 ]; then 
  >/dev/tty echo "Start ssm session to instance ${ec2_instance_id}"
fi
aws ssm start-session \
  --target "${ec2_instance_id}" \
  --document-name 'AWS-StartSSHSession' \
  --parameters "portNumber=${ssh_port}"
