#!/usr/bin/env sh
set -eu

instance_id="$1"

REGION_SEPARATOR='--'
if echo "$instance_id" | grep -q -e "${REGION_SEPARATOR}" 
then
  export AWS_DEFAULT_REGION="${instance_id##*"$REGION_SEPARATOR"}"
  instance_id="${instance_id%%"$REGION_SEPARATOR"*}"
fi

START_INSTANCE_TIMEOUT=300
START_INSTANCE_CHECK_INTERVAL=5
STATUS=$(aws ssm describe-instance-information --filters Key=InstanceIds,Values="$instance_id" --output text --query 'InstanceInformationList[0].PingStatus')
if [ "$STATUS" != 'Online' ]
then
  aws ec2 start-instances --instance-ids "${instance_id}" --profile "${AWS_PROFILE}" --region "${AWS_REGION}"
  >/dev/stderr echo "Waiting for EC2 Instance ${instance_id}..."
  START_INSTANCE_START="$(date +%s)"
  while [ $(( $(date +%s) - "$START_INSTANCE_START")) -le ${START_INSTANCE_TIMEOUT} ]
  do
      >/dev/stderr printf "."
      sleep ${START_INSTANCE_CHECK_INTERVAL}
      STATUS=$(aws ssm describe-instance-information --filters Key=InstanceIds,Values="$instance_id" --output text --query 'InstanceInformationList[0].PingStatus')
      if [ "$STATUS" = 'Online' ]
      then
          break
      fi
  done
  >/dev/stderr echo
  
  if [ "$STATUS" != 'Online' ]
  then
      >/dev/stderr echo "Timeout."
      exit 1
  fi
fi

exec "$PWD/${0%/*}/aws-ssm-ssh-proxy-command.sh" "$@"
