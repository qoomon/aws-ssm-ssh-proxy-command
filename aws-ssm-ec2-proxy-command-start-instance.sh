#!/usr/bin/env sh
######## Source ################################################################
#
# https://github.com/qoomon/aws-ssm-ec2-proxy-command
#
######## Usage #################################################################
# https://github.com/qoomon/aws-ssm-ec2-proxy-command/blob/master/README.md
#
# Install Proxy Command
#   - Install aws-ssm-ec2-proxy-command.sh first, see 'Usage' section
#   - Move this script to ~/.ssh/aws-ssm-ec2-proxy-command-start-instance.sh
#   - Ensure it is executable (chmod +x ~/.ssh/aws-ssm-ec2-proxy-command-start-instance.sh)
# Adjust following SSH Config Entry in ~/.ssh/config
#   host i-* mi-*
#     IdentityFile ~/.ssh/id_rsa
#     ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command-start-instance-start.sh %h %r %p ~/.ssh/id_rsa.pub
#     StrictHostKeyChecking no
#
# Ensure SSM Permissions for Target Instance Profile
#   https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
#
# Open SSH Connection
#   ssh <INSTANCE_USER>@<INSTANCE_ID>
#
#   Ensure AWS CLI environment variables are set properly
#   e.g. AWS_PROFILE='default' ssh ec2-user@i-xxxxxxxxxxxxxxxx
#
#   If default region does not match instance region you need to provide it like this
#   ssh <INSTANCE_USER>@<INSTANCE_ID>--<INSTANCE_REGION>
#
################################################################################
set -eu

REGION_SEPARATOR='--'
START_INSTANCE_TIMEOUT=300
START_INSTANCE_CHECK_INTERVAL=5

ec2_instance_id="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="$4"
ssh_public_key="$(cat "${ssh_public_key_path}")"


if [[ "${ec2_instance_id}" == *"${REGION_SEPARATOR}"* ]]
then
  export AWS_DEFAULT_REGION="${ec2_instance_id##*${REGION_SEPARATOR}}"
  ec2_instance_id="${ec2_instance_id%%${REGION_SEPARATOR}*}"
fi

STATUS=`aws ssm describe-instance-information --filters Key=InstanceIds,Values=${ec2_instance_id} --output text --query 'InstanceInformationList[0].PingStatus'`
if [ $STATUS != 'Online' ]
then
  aws ec2 start-instances --instance-ids "${ec2_instance_id}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}"
  >/dev/stderr echo "Waiting for EC2 Instance ${ec2_instance_id}..."
  START_INSTANCE_START="$(date +%s)"
  while [ $(( $(date +%s) - $START_INSTANCE_START)) -le ${START_INSTANCE_TIMEOUT} ]
  do
      >/dev/stderr echo -n "."
      sleep ${START_INSTANCE_CHECK_INTERVAL}
      STATUS=`aws ssm describe-instance-information --filters Key=InstanceIds,Values=${ec2_instance_id} --output text --query 'InstanceInformationList[0].PingStatus'`
      if [ ${STATUS} == 'Online' ]
      then
          break
      fi
  done
  >/dev/stderr echo
  
  if [ $STATUS != 'Online' ]
  then
      >/dev/stderr echo "Timeout."
      exit 1
  fi
fi

 exec ~/.ssh/aws-ssm-ec2-proxy-command.sh "${ec2_instance_id}" "${ssh_user}" "${ssh_port}" "${ssh_public_key_path}"
