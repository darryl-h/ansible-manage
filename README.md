# ansible-manage
The goal of this script is to install the Ansible software on a Debian based control node and configure it by setting the ANSIBLE_CONFIG in the .bashrc file, creating a seperate directory structure and manage the Ansible inventory and SSH keys for the target machines.

# Configuration
It is expected that the specified user has sudo access.  
In modern Ubuntu machines, to add an `ansible_user` user to the system and the sudoers file you would:  
1) Create the user (`useradd --create-home --shell /bin/bash ansible_user`)  
2) Add the user to sudoers (`echo -e 'ansible_user\tALL=(ALL)\tNOPASSWD:\tALL' > /etc/sudoers.d/ansible_user`)  

Modify the Default_SudoUser variables in the script to reflect these, or specify them at the command line  
`Default_SudoUser_Name='osimages'`  
`Default_SudoUser_Password='Osimages123!'`  

# Usage
`./Ansible-manage.sh install` - Install Ansible as the Control Node on this machine  

`./Ansible-manage.sh configure` - Configure Ansible for this user  

`./Ansible-manage.sh add --host <IP_or_FQDN>` - Add Host to hosts file and configure SSH Keys  
        Optional Parameters: `--username <Username> --password <Password> --group <Group_Name>`  

`./Ansible-manage.sh listhosts` - List hosts in group  
        Optional Parameters: `--group <Group_Name>`  

`./Ansible-manage.sh listgroups` - List all groups  

`./Ansible-manage.sh ping` - Test connection to hosts  
        Optional Parameters: `--group <Group_Name>`  

`./Ansible-manage.sh remove --host <IP_or_FQDN>` - Remove Host from hosts file and revolk SSH Keys  
