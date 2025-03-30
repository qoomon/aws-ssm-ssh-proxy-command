#!/usr/bin/env pwsh
Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

################################################################################
#
# For documentation see https://github.com/qoomon/aws-ssm-ssh-proxy-command
#
################################################################################

$instance_id = $args[0]
$ssh_user = $args[1]
$ssh_port = $args[2]
$ssh_public_key_path= $args[3]

$REGION_SEPARATOR = "--"
$splitted_instance = $instance_id -split $REGION_SEPARATOR
if ($splitted_instance.Length -gt 1) {
  $instance_id = $splitted_instance[0]
  $env:AWS_REGION = $splitted_instance[1]
}

Write-Output "Add public key $ssh_public_key_path for $ssh_user at instance $instance_id for 60 seconds"
$instance_availability_zone = (aws ec2 describe-instances `
  --instance-id "$instance_id" `
  --query "Reservations[0].Instances[0].Placement.AvailabilityZone" `
  --output text)
aws ec2-instance-connect send-ssh-public-key `
  --instance-id "$instance_id" `
  --instance-os-user "$ssh_user" `
  --ssh-public-key "file://$ssh_public_key_path" `
  --availability-zone "$instance_availability_zone"


Write-Output "Start ssm session to instance $instance_id"
aws ssm start-session `
  --target "$instance_id" `
  --document-name 'AWS-StartSSHSession' `
  --parameters "portNumber=$ssh_port"
