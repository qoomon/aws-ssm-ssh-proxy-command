# aws-ssm-ec2-proxy-command (Windows)

Open an SSH connection to your ec2 instances via AWS SSM without the need to open any ssh port in you security groups.

###### ⓘ Unix users please refere to [README.md](README.md)

#### Prerequisits

* Local Setup
  * [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
    * Windows `winget install Amazon.AWSCLI`
  * [Install AWS CLI Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
    * Windows `winget install Amazon.SessionManagerPlugin`
* Ensure Your IAM Permissions
  * [IAM Policy Example](aws-ssm-ec2-iam-policy.json)
  * `ssm:StartSession` for DocumentName: `AWS-StartSSHSession` and Target Instance
    * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
  * `ssm:SendCommand` for DocumentName: `AWS-RunShellScript` and Target Instance
    * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)
* Target Instance Setup
  * [Ensure SSM Permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html) fo Target Instance Profile
  * Ensure SSM Agent is installed (preinstalled on all AWS Linux AMIs already)
    * [Install SSM Agent on Linux Instances](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-ssm-agent.html)
      * `yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm & service amazon-ssm-agent restart`
    * [SSM Agent on Windows Instances](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-ssm-win.html)

#### Install SSH Proxy Command

- Move proxy command script [aws-ssm-ec2-proxy-command.ps1](aws-ssm-ec2-proxy-command.ps1) to `~/.ssh/aws-ssm-ec2-proxy-command.ps1`

- Ensure you are allowed to execute powershell scripts (see [Set-ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy) command)

Unfortunately on Windows is not possible to show output while running ProxyCommand, script output is interpreted as SSH banner which is available with SSH verbose options.

##### Setup SSH Config [optional]

* Add ssh config entry for aws ec2 instances to your `~/.ssh/config`. Adjust key file path if needed.

```ssh-config
host i-* mi-*
  IdentityFile ~/.ssh/id_rsa
  ProxyCommand powershell.exe ~/.ssh/aws-ssm-ec2-proxy-command.ps1 %h %r %p ~/.ssh/id_rsa.pub
  StrictHostKeyChecking no
```

#### Open SSH Connection

* Ensure AWS CLI environemnt variables are set properly e.g. 
  * `export AWS_PROFILE=default` or `AWS_PROFILE=default ssh ... <INSTACEC_USER>@<INSTANCE_ID>`
* If default region does not match instance region you need to provide it
  * e.g. `<INSTACEC_USER>@<INSTANCE_ID>--<INSTANCE_REGION>`

###### SSH Command with SSH Config Setup

`ssh.exe <INSTACEC_USER>@<INSTANCE_ID>`

* e.g. `ssh.exe ec2-user@i-1234567890`

###### SSH Command with ProxyCommand CLI Option

```powershell
ssh.exe <INSTACEC_USER>@<INSTANCE_ID> `
-i "~/.ssh/id_rsa" `
-o ProxyCommand="powershell.exe ~/.ssh/aws-ssm-ec2-proxy-command.ps1 %h %r %p ~/.ssh/id_rsa.pub"
```

## Alternative Implementation with `ec2-instance-connect`

The advantage from security perspective it that you don't need to grant `ssm:SendCommand` to users and there by the permission to execute everything as root.
Instead you only grant `ec2-instance-connect:SendSSHPublicKey` permission to a specific instance user e.g. `ec2-user`.

* Ensure [Prerequisits](#prerequisits)
* Use this [aws-ssm-ec2-proxy-command.ps1](ec2-instance-connect/aws-ssm-ec2-proxy-command.ps1) proxy command script instead
* Use this [IAM Policy Example](ec2-instance-connect/aws-ssm-ec2-iam-policy.json) instead
  * `ssm:StartSession` for DocumentName: `AWS-StartSSHSession` and Target Instance
    * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
  * `ec2-instance-connect:SendSSHPublicKey`
    * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)
    * You may need to adjust `ec2:osuser` to match your needs. Default osuser is `ec2-user`
* Follow [Install Guide](#install-ssh-proxy-command)
