#!/usr/bin/env sh
set -eu

################################################################################
#
# For documentation see https://github.com/qoomon/aws-ssm-ssh-proxy-command
#
################################################################################

getInstanceId() {
  local instance_name="$1"
  local instance_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${instance_name}" --query "Reservations[].Instances[?State.Name == 'running'].InstanceId" --output text)

  echo "${instance_id}"
}

instance_name="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="$4"

ec2InstanceIdPattern='^m?i-[0-9a-f]{8,17}$'
if [[ $instance_name =~ $ec2InstanceIdPattern ]]; then
  instance_id=$instance_name
else
  instance_id=$( getInstanceId "$instance_name" )

  if [[ -z $instance_id ]]; then
    echo "Found no running instances with name \"${instance_name}\"."
    exit 1
  else
    echo "Instance ID for \"${instance_name}\": \"${instance_id}\""
  fi
fi

REGION_SEPARATOR='--'
if echo "$instance_id" | grep -q -e "${REGION_SEPARATOR}" 
then
  export AWS_REGION="${instance_id##*"${REGION_SEPARATOR}"}"
  instance_id="${instance_id%%"$REGION_SEPARATOR"*}"
fi

>/dev/stderr echo "Add public key ${ssh_public_key_path} for ${ssh_user} at instance ${instance_id} for 10 seconds"
ssh_public_key="$(cat "${ssh_public_key_path}")"
aws ssm send-command \
  --instance-ids "${instance_id}" \
  --document-name 'AWS-RunShellScript' \
  --comment "Add an SSH public key to authorized_keys for 10 seconds" \
  --parameters commands="
  \"
    set -eu
    
    mkdir -p ~${ssh_user}/.ssh && cd ~${ssh_user}/.ssh

    authorized_key='${ssh_public_key} ssm-session'
    
    echo \\\"\${authorized_key}\\\" >> authorized_keys
    
    sleep 10
    
    (grep -v -F \\\"\${authorized_key}\\\" authorized_keys || true) > authorized_keys~
    mv authorized_keys~ authorized_keys
  \"
  "

>/dev/stderr echo "Start ssm session to instance ${instance_id}"
aws ssm start-session \
  --target "${instance_id}" \
  --document-name 'AWS-StartSSHSession' \
  --parameters "portNumber=${ssh_port}"
