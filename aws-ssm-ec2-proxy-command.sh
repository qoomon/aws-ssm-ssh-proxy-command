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
MAX_ITERATION=5
SLEEP_DURATION=5

ec2_instance_id="$1"
ssh_user="$2"
ssh_port="$3"
ssh_public_key_path="$4"
ssh_public_key="$(cat "${ssh_public_key_path}")"
ssh_public_key_timeout=60



if [[ "${ec2_instance_id}" == *"${REGION_SEPARATOR}"* ]]
then
  export AWS_DEFAULT_REGION="${ec2_instance_id##*${REGION_SEPARATOR}}"
  ec2_instance_id="${ec2_instance_id%%${REGION_SEPARATOR}*}"
fi

function connect() {
 >/dev/stderr echo "\n➕  Add public key ${ssh_public_key_path} for ${ssh_user} at instance ${ec2_instance_id} for ${ssh_public_key_timeout} seconds"
  aws ssm send-command \
    --instance-ids "${ec2_instance_id}" \
    --document-name 'AWS-RunShellScript' \
    --comment "Add an SSH public key to authorized_keys for ${ssh_public_key_timeout} seconds" \
    --parameters commands="\"
      mkdir -p ~${ssh_user}/.ssh && cd ~${ssh_user}/.ssh || exit 1

      authorized_key='${ssh_public_key} ssm-session'
      echo \\\"\${authorized_key}\\\" >> authorized_keys

      sleep ${ssh_public_key_timeout}

      grep -v -F \\\"\${authorized_key}\\\" authorized_keys > .authorized_keys
      mv .authorized_keys authorized_keys
    \""

  >/dev/stderr echo "🔗  Connect to instance ${ec2_instance_id} using SSM"
  aws ssm start-session \
    --target "${ec2_instance_id}" \
    --document-name 'AWS-StartSSHSession' \
    --parameters "portNumber=${ssh_port}"
}

function start_instance(){
 # Instance is offline - start the instance
    >/dev/stderr echo "\n🚀 Starting ec2 Instance ${ec2_instance_id}"
    aws ec2 start-instances --instance-ids $ec2_instance_id --profile ${AWS_PROFILE} --region ${AWS_REGION}
    sleep ${SLEEP_DURATION}
    COUNT=0
    >/dev/stderr echo "  ⏳ Wait until ${ec2_instance_id} is running"
    while [ ${COUNT} -le ${MAX_ITERATION} ]; do
        STATUS=`aws ssm describe-instance-information --filters Key=InstanceIds,Values=${ec2_instance_id} --output text --query 'InstanceInformationList[0].PingStatus' --profile ${AWS_PROFILE} --region ${AWS_REGION}`
        if [ ${STATUS} == 'Online' ]; then
            break
        fi
        # Max attempts reached, exit
        if [ ${COUNT} -eq ${MAX_ITERATION} ]; then
            exit 1
        else
            >/dev/stderr echo "     ⁃  [${COUNT}|${MAX_ITERATION}] - retry in ${SLEEP_DURATION} seconds"
            let COUNT=COUNT+1
            sleep ${SLEEP_DURATION}
        fi
    done
}


>/dev/stderr echo "⚙️  Ec2 Proxy Command \n"
>/dev/stderr echo "🧪 Check if instance ${ec2_instance_id} is running"
STATUS=`aws ssm describe-instance-information --filters Key=InstanceIds,Values=${ec2_instance_id} --output text --query 'InstanceInformationList[0].PingStatus' --profile ${AWS_PROFILE} --region ${AWS_REGION}`

# If the instance is online, start the session
if [ $STATUS == 'Online' ]; then
  >/dev/stderr echo "   − State: 🟢 ${STATUS}"
  connect
else
  >/dev/stderr echo "   − State: 🔴 Offline"
  start_instance
  connect
fi