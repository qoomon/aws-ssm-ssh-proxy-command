# aws-ssm-ec2-proxy-command
Open an SSH connection to your ec2 instances via AWS SSM without the need to open any ssh port in you security groups.

###### ⓘ Windows users please refere to [README.windows.md](README.windows.md)

#### Prerequisits
* Local Setup
  * [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
    * MacOS `brew install awscli`  
  * [Install AWS CLI Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
    * MacOS `brew install session-manager-plugin`   
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
  * Move proxy command script [aws-ssm-ec2-proxy-command.sh](aws-ssm-ec2-proxy-command.sh) to `~/.ssh/aws-ssm-ec2-proxy-command.sh`
  * Ensure it is executable (`chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh`)

###### Setup SSH Config [optional]
* Add ssh config entry for aws ec2 instances to your `~/.ssh/config`. Adjust key file path if needed.
  ```ssh-config
  host i-* mi-*
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub
    StrictHostKeyChecking no
  ```

#### Open SSH Connection
* Ensure AWS CLI environemnt variables are set properly e.g. 
  * `export AWS_PROFILE=default` or `AWS_PROFILE=default ssh ... <INSTACEC_USER>@<INSTANCE_ID>`
* If default region does not match instance region you need to provide it
  * e.g. `<INSTACEC_USER>@<INSTANCE_ID>--<INSTANCE_REGION>`
###### SSH Command with SSH Config Setup
`ssh <INSTACEC_USER>@<INSTANCE_ID>`
* e.g. `ssh ec2-user@i-1234567890`
###### SSH Command with ProxyCommand CLI Option
```sh
ssh <INSTACEC_USER>@<INSTANCE_ID> \
  -i "~/.ssh/id_rsa" \
  -o ProxyCommand="~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub"
```

## Alternative Implementation with `ec2-instance-connect`
The advantage from security perspective it that you don't need to grant `ssm:SendCommand` to users and there by the permission to execute everything as root.
Instead you only grant `ec2-instance-connect:SendSSHPublicKey` permission to a specific instance user e.g. `ec2-user`.
* Ensure [Prerequisits](#prerequisits)
* Follow [Install Guide](#install-ssh-proxy-command)
  * Use this [aws-ssm-ec2-proxy-command.sh](ec2-instance-connect/aws-ssm-ec2-proxy-command.sh) proxy command script instead
  * Use this [IAM Policy Example](ec2-instance-connect/aws-ssm-ec2-iam-policy.json) instead
    * `ssm:StartSession` for DocumentName: `AWS-StartSSHSession` and Target Instance
      * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
    * `ec2-instance-connect:SendSSHPublicKey`
      * [AWS Documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)
      * You may need to adjust `ec2:osuser` to match your needs. Default `osuser` is `ec2-user`

