# aws-ssm-ssh-proxy-command [![Sparkline](https://stars.medv.io/qoomon/aws-ssm-ssh-proxy-command.svg?cachebuster)](https://stars.medv.io/qoomon/aws-ssm-ssh-proxy-command.svg)

Open an SSH connection to your AWS SSM connected instances without the need to open any ssh port in you security groups.

> [!Tip]
> If you only need to connect to AWS EC2 instances you could use the `ec2-instance-connect` variant of this proxy command.
> This variant allows you to manage wich IAM identity can connect to which OS user on the target instance.
> See [EC2 Only Variant](#ec2-only-variant)

## Prerequisits
- Local Setup
  - Install AWS CLI
    - [AWS Docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
    - **MacOS** `brew install awscli`  
  - Install AWS CLI Session Manager Plugin
    - [AWS Docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
    - **MacOS** `brew install session-manager-plugin` 
  - Install the SSM SSH Proxy Command Script
    - **Linux & MacOS**
      - Copy [aws-ssm-ssh-proxy-command.sh](aws-ssm-ssh-proxy-command.sh) into `~/.ssh/aws-ssm-ssh-proxy-command.sh`
      - Ensure it is executable (`chmod +x ~/.ssh/aws-ssm-ssh-proxy-command.sh`)
    - **Windows**
      - Copy [aws-ssm-ssh-proxy-command.ps1](aws-ssm-ssh-proxy-command.ps1) into `~/.ssh/aws-ssm-ssh-proxy-command.ps1`
      - Ensure you are allowed to execute powershell scripts (see [Set-ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy) command)
  - `recommended` Setup SSH Config
    - Add ssh config entry AWS instances to your `~/.ssh/config`. 
      - **Linux & MacOS**
        ```ssh-config
        host i-* mi-*
          IdentityFile ~/.ssh/id_ed25519
          ProxyCommand ~/.ssh/aws-ssm-ssh-proxy-command.sh %h %r %p ~/.ssh/id_ed25519.pub
          StrictHostKeyChecking no
        ```
      - **Windows**
        ```ssh-config
        host i-* mi-*
          IdentityFile ~/.ssh/id_ed25519
          ProxyCommand powershell.exe ~/.ssh/aws-ssm-ssh-proxy-command.ps1 %h %r %p ~/.ssh/id_ed25519.pub
          StrictHostKeyChecking no
        ```
    - Adjust `IdentityFile` and corresponding publickey (last argument of `ProxyCommand`) if needed.
    
- AWS IAM Setup    
  - Ensure IAM Permissions for Your IAM Identity
    - [IAM Policy Template](aws-ssm-ssh-iam-policy.json)
      - `ssm:StartSession` for DocumentName: `AWS-StartSSHSession` and Target Instance
        - [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
      - `ssm:SendCommand` for DocumentName: `AWS-RunShellScript` and Target Instance
        - [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)

- Target Instance Setup
    - Ensure IAM Permissions for SSM Agent
      - [AWS Docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up.html)
      - For EC2 Instances use [Instance Profiles](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html)
    - Install SSM Agent on Linux Instances
      - Already preinstalled on all AWS Linux AMIs
      - [AWS Docs - Linux](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-managed-linux.html)
      - [AWS Docs - Windows](https://docs.aws.amazon.com/systems-manager/latest/userguide/hybrid-multicloud-ssm-agent-install-windows.html)

## Usage
- Ensure AWS CLI environemnt variables are set properly 
  - **Linux & MacOS** `export AWS_PROFILE=...` or `AWS_PROFILE=... ssh...`
  - **Windows** `$env:AWS_PROFILE = ...` or `$env:AWS_PROFILE = ...; ssh.exe...`
- Open SSH Connection to AWS SSM connected instance
  - **Linux & MacOS** `ssh <INSTACEC_USER>@<INSTANCE_ID>` e.g. `ssh ec2-user@i-1234567890`
  - **Windows** `ssh.exe <INSTACEC_USER>@<INSTANCE_ID>` e.g. `ssh.exe ec2-user@i-1234567890`
    - ⚠️ Unfortunately on Windows is not possible to show output while running ProxyCommand, script output is interpreted as SSH banner which is available with SSH verbose options.
- [EC2 Intances Only] If default region does not match instance region you need to provide it as part of hostname
  - `<INSTACEC_USER>@<INSTANCE_ID>--<INSTANCE_REGION>`
  - e.g. `ec2-user@i-1234567890--eu-central-1`
  
#### Usage without SSH Config
If you have not setup an SSH Config you can use the following ssh command options to use this proxy command.
- **Linux & MacOS** `ssh -i "~/.ssh/id_ed25519" -o ProxyCommand="~/.ssh/aws-ssm-ssh-proxy-command.sh %h %r %p ~/.ssh/id_ed25519.pub" ...`
- **Windows** `ssh.exe -i "~/.ssh/id_ed25519" -o ProxyCommand="powershell.exe ~/.ssh/aws-ssm-ssh-proxy-command.ps1 %h %r %p ~/.ssh/id_ed25519.pub" ...`

## EC2 Only Variant
If you only want to connect to EC2 instances you can make use of EC2 Instance Connect `SendSSHPublicKey` command as a drop in replacement for the SSM `SendCommand` to temporary add your public key to the target instance.

The advantage from this variant is that you don't need to grant `ssm:SendCommand` to users and there by the permission to execute everything as `ssm-user` or `root`.
Instead you grant `ec2-instance-connect:SendSSHPublicKey` permission and optionaly restrict it to a specific OS user e.g. `ec2-user`.

To do so just use **Proxy Command Script** and **IAM Policy Template** from the [ec2-instance-connect folder](ec2-instance-connect) instead.
- Proxy Command Script
  - **Linux & MacOS** [aws-ssm-ssh-proxy-command.sh](ec2-instance-connect/aws-ssm-ssh-proxy-command.sh)
  - **Windows** [aws-ssm-ssh-proxy-command.ps1](ec2-instance-connect/aws-ssm-ssh-proxy-command.ps1)
- [IAM Policy Template](ec2-instance-connect/aws-ssm-ssh-iam-policy.json)
  - `ssm:StartSession` for DocumentName: `AWS-StartSSHSession` and Target Instance
    - [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
  - `ec2-instance-connect:SendSSHPublicKey`
    - [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)
    - You may need to adjust `ec2:osuser` to match your needs. Default is `ec2-user`

