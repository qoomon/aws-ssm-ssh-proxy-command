#!/usr/bin/env sh
######## Source ################################################################
#
# https://github.com/qoomon/aws-ssm-ec2-proxy-command
#
######## Usage #################################################################
# https://github.com/qoomon/aws-ssm-ec2-proxy-command/blob/master/README.md
#
# Install Proxy Command
#   - Move this script to ~/.ssh/aws-ssm-ec2-proxy-command.ps1
#   - Ensure you are allowed to execute powershell scripts (see Set-ExecutionPolicy command)
#
# Add following SSH Config Entry to ~/.ssh/config
#   host i-* mi-*
#     IdentityFile ~/.ssh/id_rsa
#     ProxyCommand powershell.exe ~/.ssh/aws-ssm-ec2-proxy-command.ps1 %h %r %p ~/.ssh/id_rsa.pub
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
$ErrorActionPreference = "Stop"

$REGION_SEPARATOR = "--"

$ec2_instance_id = $args[0]
$ssh_user = $args[1]
$ssh_port = $args[2]
$ssh_public_key_path= $args[3]

$splitted_instance = $ec2_instance_id -split $REGION_SEPARATOR

if ($splitted_instance.Length -gt 1)
{
  $ec2_instance_id = $splitted_instance[0]
  $env:AWS_DEFAULT_REGION = $splitted_instance[1]
}

$instance_availability_zone = (
  aws ec2 describe-instances `
  --instance-id "$ec2_instance_id" `
  --query "Reservations[0].Instances[0].Placement.AvailabilityZone" `
  --output text `
)
if($LASTEXITCODE -ne 0) { Write-Error "Failed to get availability zone for instance $ec2_instance_id" }

Write-Output "Add public key $ssh_public_key_path for $ssh_user at instance $ec2_instance_id for 60 seconds"
aws ec2-instance-connect send-ssh-public-key `
  --instance-id "$ec2_instance_id" `
  --instance-os-user "$ssh_user" `
  --ssh-public-key "file://$ssh_public_key_path" `
  --availability-zone "$instance_availability_zone"
if($LASTEXITCODE -ne 0) { Write-Error "Failed to add public key for $ssh_user at instance $ec2_instance_id" }

Write-Output "Start ssm session to instance $ec2_instance_id"
aws ssm start-session `
  --target "$ec2_instance_id" `
  --document-name 'AWS-StartSSHSession' `
  --parameters "portNumber=$ssh_port"
if($LASTEXITCODE -ne 0) { Write-Error "Failed to start ssm session to instance $ec2_instance_id" }
