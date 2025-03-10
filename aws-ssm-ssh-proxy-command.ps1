#!/usr/bin/env pwsh
Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

################################################################################
#
# For documentation see https://github.com/qoomon/aws-ssm-ssh-proxy-command
#
################################################################################

#
# Set ExecutionPolicy in Powershell:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Unblock-File -Path $HOME\.ssh\aws-ssm-ssh-proxy-command.ps1
#

function Get-InstanceId {
    param (
        [string]$instanceName
    )

    $instanceId = aws ec2 describe-instances --filters "Name=tag:Name,Values=$instanceName" --query "Reservations[].Instances[?State.Name == 'running'].InstanceId" --output text

	return $instanceId
}

$instance_name = $args[0]
$ssh_user = $args[1]
$ssh_port = $args[2]
$ssh_public_key_path = $args[3]

$ec2InstanceIdPattern = '^i-[0-9a-f]{8,17}$'
if ($instance_name -match $ec2InstanceIdPattern) {
    $instance_id = $instance_name
} else {
    $instance_id = Get-InstanceId -instanceName $instance_name

	if (-not $instance_id) {
		Write-Output 'Found no running instances with name "' + $instance_name + '".'
		Exit
	} else {
		Write-Output 'Instance ID for "' + $instance_name + '": "' + $instance_id + '"'
	}
}

$REGION_SEPARATOR = "--"
$splitted_instance = $instance_id -split $REGION_SEPARATOR
if ($splitted_instance.Length -gt 1) {
  $instance_id = $splitted_instance[0]
  $env:AWS_DEFAULT_REGION = $splitted_instance[1]
}

Write-Output "Add public key $ssh_public_key_path for $ssh_user at instance $instance_id for 10 seconds"
$ssh_public_key = (Get-Content $ssh_public_key_path | Select-Object -first 1) + ' ssm-session'

$command = 'aws ssm send-command ' +
           '--instance-ids "' + $instance_id + '" ' +
           '--document-name "AWS-RunShellScript" ' +
           '--comment "Add an SSH public key to authorized_keys for 10 seconds" ' +
           '--parameters commands="
		   set -eu

           mkdir -p ~$ssh_user/.ssh && cd ~$ssh_user/.ssh

		   echo $ssh_public_key >> authorized_keys

		   sleep 10

		   (grep -v -F ssm-session authorized_keys || true) > authorized_keys~
		   mv authorized_keys~ authorized_keys
		   "'

Invoke-Expression $command


Write-Output "Start ssm session to instance $instance_id"
aws ssm start-session `
  --target "$instance_id" `
  --document-name 'AWS-StartSSHSession' `
  --parameters "portNumber=$ssh_port"
