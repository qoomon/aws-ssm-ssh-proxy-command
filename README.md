# aws-ssm-ec2-proxy-command

#### Prerequisits
* Local Setup
  * [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
  * [Install AWS CLI Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
* Ensure Your IAM Permissions
  * `ssm:StartSession` - [IAM Policy Examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html)
  * `ssm:SendCommand` - [IAM Policy Examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-rc-setting-up.html)
* Target Instance Setup
  * [Ensure SSM Permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html) fo Target Instance Profile
  * Ensure SSM Agent is installed (preinstalled on all AWS Linux AMIs already)
    * [Install SSM Agent on Linux Instances](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-ssm-agent.html)
      * `yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm & service amazon-ssm-agent restart`
    * [SSM Agent on Windows Instances](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-install-ssm-win.html)
  
#### Install SSH Proxy Command
  * Move proxy command script [aws-ssm-ec2-proxy-command.sh](aws-ssm-ec2-proxy-command.sh) to `~/.ssh/aws-ssm-ec2-proxy-command.sh`
  * Ensure it is executable (`chmod +x ~/.ssh/aws-ssm-ec2-proxy-command.sh`)

##### Setup SSH Config
* Add ssh config entry for aws ec2 instances to your `~/.ssh/config`. Adjust key file path if needed.
  ```ssh-config
  host i-* mi-*
    IdentityFile ~/.ssh/id_rsa
    ProxyCommand ~/.ssh/aws-ssm-ec2-proxy-command.sh %h %r %p ~/.ssh/id_rsa.pub
    StrictHostKeyChecking no
  ```

#### Open SSH Connection
* `ssh <INSTACEC_USER>@<INSTANCE_ID>`
* Ensure AWS CLI environemnt variables are set properly
  * e.g. `AWS_PROFILE='default' ssh ec2-user@i-xxxxxxxxxxxxxxxx`
  * If default region does not match instance region you need to provide it like this
  * `AWS_PROFILE='default' ssh <INSTACEC_USER>@<INSTANCE_ID>--<INSTANCE_REGION>`

## TODO
Add variant to send ssh key by ec2-instance-connect:SendSSHPublicKey
* https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-set-up.html
