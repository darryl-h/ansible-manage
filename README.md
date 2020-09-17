# ansible-manage
The goal of this script is to install the Ansible software on a Debian based control node and configure it by setting the ANSIBLE_CONFIG in the .bashrc file, creating a seperate directory structure and manage the Ansible inventory and SSH keys for the target machines.

# Usage
./Ansible-manage.sh install - Install Ansible as the Control Node on this machine

./Ansible-manage.sh configure - Configure Ansible for this user

./Ansible-manage.sh add --host <IP_or_FQDN> - Add Host to hosts file and configure SSH Keys
        Optional Parameters: --username <Username> --password <Password> --group <Group_Name>

./Ansible-manage.sh listhosts - List hosts in group
        Optional Parameters: --group <Group_Name>

./Ansible-manage.sh listgroups - List all groups

./Ansible-manage.sh ping - Test connection to hosts
        Optional Parameters: --group <Group_Name>

./Ansible-manage.sh remove --host <IP_or_FQDN> - Remove Host from hosts file and revolk SSH Keys
