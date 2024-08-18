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
$ssh_public_key_path = $args[3]

$REGION_SEPARATOR = "--"
$splitted_instance = $instance_id -split $REGION_SEPARATOR
if ($splitted_instance.Length -gt 1) {
  $instance_id = $splitted_instance[0]
  $env:AWS_DEFAULT_REGION = $splitted_instance[1]
}

Write-Output "Add public key $ssh_public_key_path for $ssh_user at instance $instance_id for 60 seconds"
$ssh_public_key = (Get-Content $ssh_public_key_path | Select-Object -first 1)
aws ssm send-command `
  --instance-ids "$instance_id" `
  --document-name 'AWS-RunShellScript' `
  --comment "Add an SSH public key to authorized_keys for 60 seconds" `
  --parameters commands=@"
  \"
    set -eu
    
    mkdir -p ~$ssh_user/.ssh && cd ~$ssh_user/.ssh
    
    authorized_key='$ssh_public_key ssm-session'
    
    echo \\\"`$authorized_key\\\" >> authorized_keys
    
    sleep 60
    
    grep -v -F \\\"`$authorized_key\\\" authorized_keys > ~authorized_keys
    mv ~authorized_keys authorized_keys
  \"
  "@

Write-Output "Start ssm session to instance $instance_id"
aws ssm start-session `
  --target "$instance_id" `
  --document-name 'AWS-StartSSHSession' `
  --parameters "portNumber=$ssh_port"
