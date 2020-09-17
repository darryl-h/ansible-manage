#!/bin/bash
# Author: Darryl H (https://github.com/darryl-h)
# Purpose: The goal of this script is to install the Ansible software on the
#          control node and configure it by setting the ANSIBLE_CONFIG in the 
#          .bashrc file, creating a seperate directory structure and manage the
#          Ansible inventory and SSH keys for the target machines. 
#
# ToDo: Host removal from the hosts file is not implimented
#
## USER CONFIGURATION
# Specify the username that we will connect via SSH as to the target machine as
# NOTE: This user MUST have sudo access. 
Default_SudoUser_Name='osimages'
# In modern Ubuntu machines, to add an 'ansible_user' user to the system and the sudoers file you would:
# 1) Create the user (useradd --create-home --shell /bin/bash ansible_user)
# 2) Add the user to sudoers (echo -e `ansible_user\tALL=(ALL)\tNOPASSWD:\tALL` > /etc/sudoers.d/ansible_user)
# Specify the password that we will use to connect to the target machine as
Default_SudoUser_Password='Osimages123!'

## INTERNAL VARIABLES (Should not need to tune these)
Script_Version=0.0582
Default_GroupName='all_hosts'
Default_Ansible_Config_Directory="$HOME/ansible"
NetworkTimeout=30
LogFile="${HOME}/ansible-manage.log"
Colour_Notice=$(tput setaf 6) # Cyan
Colour_Warning=$(tput setaf 3) # Yellow
Colour_Fatal=$(tput setaf 1) # Red
Colour_Reset=$(tput sgr0)
Colour_Bold=$(tput bold) # This is addative to the current color

# Make sure we are NOT running as root
if [[ ${EUID} -eq 0 ]]; then
  echo "ERROR: I'm sorry Dave, you are trying to run this as root."
  exit 1
fi

function DisplayBanner () {
  echo -e ${Colour_Notice}
  echo '           __     __        ___                          __   ___ '
  echo ' /\  |\ | /__` | |__) |    |__      |\/|  /\  |\ |  /\  / _` |__  '
  echo '/~~\ | \| .__/ | |__) |___ |___     |  | /~~\ | \| /~~\ \__> |___ '
  echo -e ${Colour_Bold}
  echo "                         Version ${Script_Version}                           "
  echo -e ${Colour_Reset}
}

function DisplaySyntax () {
  echo -e "${Colour_Bold}$0 install ${Colour_Reset}- Install Ansible as the Control Node on this machine" # simple grep
  echo
  echo -e "${Colour_Bold}$0 configure ${Colour_Reset}- Configure Ansible for this user" # simple grep
  echo
  echo -e "${Colour_Bold}$0 add --host <IP_or_FQDN> ${Colour_Reset}- Add Host to hosts file and configure SSH Keys"
  echo -e "\tOptional Parameters: --username <Username> --password <Password> --group <Group_Name>"
  echo
  echo -e "${Colour_Bold}$0 listhosts ${Colour_Reset}- List hosts in group" # grep between
  echo -e "\tOptional Parameters: --group <Group_Name>"
  echo
  echo -e "${Colour_Bold}$0 listgroups ${Colour_Reset}- List all groups" # simple grep
  echo
  echo -e "${Colour_Bold}$0 ping ${Colour_Reset}- Test connection to hosts"
  echo -e "\tOptional Parameters: --group <Group_Name>"
  echo
  echo -e "${Colour_Bold}$0 remove --host <IP_or_FQDN> ${Colour_Reset}- Remove Host from hosts file and revolk SSH Keys"
}

function VerifyRSAKeyPair () {
	if ! [ -f $HOME/.ssh/id_rsa ]; then
		echo -e "${Colour_Warning}WARNING:${Colour_Reset} Removing ${HOME}/.ssh/known_hosts"
		rm $HOME/.ssh/known_hosts
		echo "Generating local rsa key"
    # Create a new RSA Type (-t rsa) with an empty passphrase (-N) and place it in the file (-f) $HOME/ssh/id_rsa
    ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa >> ${LogFile} 2>&1
	else
		echo -e "${Colour_Notice}NOTICE:${Colour_Reset} Located ${HOME}/.ssh/id_rsa"
	fi
}

function AddMachineToGroup () {
  POSITIONAL=()
  while [[ $# -gt 0 ]] ; do
    key="$1"
    case $key in
      -h|--host)
      TargetMachine="$2"
      shift
      shift
      ;;
      -u|--username)
      SudoUser_Name="$2"
      shift
      shift
      ;;
      -p|--password)
      SudoUser_Password="$2"
      shift
      shift
      ;;
      -g|--group)
      GroupName="$2"
      shift
      shift
      ;;
      *)
      POSITIONAL+=("$1")
      shift
      ;;
    esac
  done
  set -- "${POSITIONAL[@]}" # restore positional parameters
  if [ -z ${TargetMachine} ] ; then
    echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Missing Host FQDN or IP"
    DisplaySyntax
    exit 1
  fi
  if [ -z ${SudoUser_Name} ] ; then
    echo -e "${Colour_Notice}NOTICE:${Colour_Reset} --username not supplied, using default username"
    SudoUser_Name=${Default_SudoUser_Name}
  fi
  if [ -z ${GroupName} ] ; then
    echo -e "${Colour_Notice}NOTICE:${Colour_Reset} --group not supplied, using default Groupname"
    GroupName=${Default_GroupName}
  fi
  if [ -z ${SudoUser_Password} ] ; then
    echo -e "${Colour_Notice}NOTICE:${Colour_Reset} --password not supplied, using default password"
    SudoUser_Password=${Default_SudoUser_Password}
  fi
  # ToDo: If the host is already in the group, do nothing
  # ToDo: If the host is already in the file, just add it to the group
  VerifyRSAKeyPair 
  # Validate network connection to machine
  ValidateNetworkAddressReachable ${TargetMachine}
  # Send the SSH key to the remote machine
  echo "Verifying this host in ${HOME}/.ssh/known_hosts"
  ssh-keygen -F ${TargetMachine} >> ${LogFile} 2>&1
  if [ $? -ne 0 ]; then
    echo "Adding this host to ${HOME}/.ssh/known_hosts and sending keys"
    sshpass -p ${SudoUser_Password} ssh-copy-id -o StrictHostKeyChecking=no ${SudoUser_Name}@${TargetMachine} >> ${LogFile} 2>&1  
    if [ $? -eq 5 ]; then
      echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Permission denied from target system."
      echo "    Suggestion: Verify the username and password"
    elif [ $? -ne 0 ]; then
      sshpass -p ${SudoUser_Password} ssh-copy-id -o StrictHostKeyChecking=no ${SudoUser_Name}@${TargetMachine} 2>&1 | grep --quiet "already exist"
      if [ $? -eq 0 ]; then
        echo -e "${Colour_Warning}WARNING:${Colour_Reset} SSH Keys already exist on the remote system."
      else
        echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Connecting to ${TargetMachine} failed."
        echo "    Suggestion: Verify the IP/FQDN, username and password"
        exit 1
      fi
    fi
  fi
  # See if group exists, if not, add it and notify the user
  AddGroup 
  # Add machine to hosts file in group, if they don't exist already
  echo "Adding Host ${TargetMachine} to Group ${GroupName}"
  sed -i "/^\[${GroupName}]/a ${TargetMachine}" ${Default_Ansible_Config_Directory}/hosts
}

function RemoveMachineFromGroups () {
    local TargetMachine="$2"
    POSITIONAL=()
    while [[ $# -gt 0 ]] ; do
      key="$1"
      case $key in
        -h|--host)
          TargetMachine="$2"
          shift
          shift
        ;;
        *)
          POSITIONAL+=("$1")
          shift
        ;;
      esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters
    if [ -z ${TargetMachine} ] ; then
      echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Missing Host FQDN or IP"
      DisplaySyntax
      exit 1
    fi
    ValidateHostsFile
    echo "Removing ${TargetMachine} from ${Default_Ansible_Config_Directory}/hosts"
    # ToDo: This removes from ALL groups, should only remove from specified group
    sed -i "/${TargetMachine}/d" ${Default_Ansible_Config_Directory}/hosts >> ${LogFile} 2>&1
    # ToDo: IF the host no longer exists in the hosts file, then remove from known_hosts
    ssh-keygen -F ${TargetMachine} >> ${LogFile} 2>&1
    if [ $? -eq 0 ] ; then
      echo "Removing ${TargetMachine} from ${HOME}/.ssh/known_hosts"
      known_hosts_line=$(ssh-keygen -F ${TargetMachine} | grep found | awk -F"line " '{print $2}')
      sed -i "${known_hosts_line}d" ${HOME}/.ssh/known_hosts
    else 
      echo -e "${Colour_Warning}WARNING:${Colour_Reset} Cannot find ${TargetMachine} in ${HOME}/.ssh/known_hosts"
    fi
}

function Ansible_Ping () {
  POSITIONAL=()
  while [[ $# -gt 0 ]] ; do
    key="$1"
    case $key in
      -g|--group)
        Default_GroupName="$2"
        shift
        shift
      ;;
      *)
        POSITIONAL+=("$1")
        shift
      ;;
    esac
  done
  if [ -z ${GroupName} ] ; then
    echo -e "${Colour_Notice}NOTICE:${Colour_Reset} --group not supplied, using default Groupname"
    GroupName=${Default_GroupName}
  fi
  ansible -i ${Default_Ansible_Config_Directory}/hosts -m ping ${GroupName}
}

function AddGroup () {
  if [ -z ${GroupName} ] ; then
    echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Missing group parameter!"
    exit 1
  fi
  grep --quiet "\[${GroupName}]" ${Default_Ansible_Config_Directory}/hosts
  if [ $? -ne 0 ]; then
    echo "Group does not exist! Adding ${GroupName}"
    echo "[${GroupName}]" >> ${Default_Ansible_Config_Directory}/hosts
  else
    echo -e "${Colour_Notice}NOTICE:${Colour_Reset} Group ${GroupName} already exists!"
  fi
}

function ValidateNetworkAddressReachable () {
  NetworkDomain=$1
  timeout ${NetworkTimeout} nc -z -v -w5 ${NetworkDomain} 22 >> ${LogFile} 2>&1
  if [ $? -ne 0 ] ; then
    echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Cannot reach ${NetworkDomain} on TCP port 22 (SSH)"
    echo "    Suggestion: Review your OS, Proxy and Network firewalls"
    exit 1
  fi
}

function ValidateHostsFile () {
  if ! [ -f "${Default_Ansible_Config_Directory}/hosts" ]; then
    echo -e "${Colour_Fatal}FATAL ERROR:${Colour_Reset} Cannot find ${Default_Ansible_Config_Directory}/hosts file"
    echo "    Suggestion: Please run the configure method if you have not already"
    exit 1
  fi
}

function InstallAnsible () {
  # Check if installation directory already exists, if so, exit
  echo "Installing Ansible as Control Node on this machine"
  sudo apt-add-repository ppa:ansible/ansible
  sudo apt update
  sudo apt install --quiet --assume-yes ansible
}

function ConfigureAnsible () {
  echo "Configuring Ansible for this user ($USER)"
  if ! [ -d "$Default_Ansible_Config_Directory" ]; then
    mkdir -p ${Default_Ansible_Config_Directory}
    cp -R /etc/ansible/* ${Default_Ansible_Config_Directory}/
  fi
  # Set the inventory variable in the ansible.cfg file regardless if it's commented out
  sed -i "/^#*inventory *=/c\inventory       = ${Default_Ansible_Config_Directory}/hosts" ${Default_Ansible_Config_Directory}/ansible.cfg
  # Add/Update ANSIBLE_CONFIG environment variable
  if [ $? -ne 0 ]; then
    echo "Adding ANSIBLE_CONFIG to ${HOME}/.bashrc"
    echo "export ANSIBLE_CONFIG=${Default_Ansible_Config_Directory}/ansible.cfg" >> ${HOME}/.bashrc
    echo "You will need to login again to complete"
  else
    echo "Updating ANSIBLE_CONFIG in ${HOME}/.bashrc"
    sed -i "/^export ANSIBLE_CONFIG=/c\ANSIBLE_CONFIG=${Default_Ansible_Config_Directory}/ansible.cfg" ${HOME}/.bashrc
  fi
  echo 
}

case "$1" in
  "add")
    shift 1
    DisplayBanner
    ValidateHostsFile
    AddMachineToGroup "$@"
  ;;
  "remove")
    shift 1
    DisplayBanner
    ValidateHostsFile
    RemoveMachineFromGroups "$@"
  ;;
  "listhosts")
    shift 1
    DisplayBanner
    ValidateHostsFile
    echo -e "${Colour_Bold}Displaying all Groups and Hosts ${Colour_Reset}"
    echo
    grep -v "#" ${Default_Ansible_Config_Directory}/hosts | sed '/^$/d'

  ;;
  "listgroups")
    shift 1
    DisplayBanner
    ValidateHostsFile
    echo -e "${Colour_Bold}Displaying all Groups ${Colour_Reset}"
    echo
    grep "^\[" ${Default_Ansible_Config_Directory}/hosts | cut -d "[" -f 2 | cut -d "]" -f 1
  ;;
  "ping")
    shift 1
    DisplayBanner
    ValidateHostsFile
    echo -e "${Colour_Bold} Pinging hosts ${Colour_Reset}"
    echo
    Ansible_Ping "$@"
  ;;
  "install")
    DisplayBanner
    InstallAnsible
  ;;    
  "configure")
    DisplayBanner
    ConfigureAnsible
  ;;
  *)
    DisplayBanner
    DisplaySyntax
    exit 1
  ;;
esac
