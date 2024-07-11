#!/bin/bash

# Default SSH public key (replace this with your actual default public key)
default_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDVsGMmAd0LVN0cvAFLHJXtYn0yEraSS1BV3yPXwXVUxeFd7mWToBqUYB0Jbz+Pl+IDC/pwlhcvhaSYzDGjiD+qJXK/6y9CpXjhbDXTLDXVPAroOTR65mz5vrJtaWFNXcmDSpzVDx2MERsaKlLiircXiAzB8DbMEFPQFbfXITIpcKXV/yoaqJ5TIQACWwGfMtkTlg0ALZHO4ifAP0XhSHD4XHb8qu9eAtsPDJqkP/ZoyLs22ABNB+5ulrZiGm74r56VcZoQ9YiWdTAZiv3rh1x4HQZVnpITuPH/Gkh8x0EGKDT0cCFJjacTVOwYZE7gnd3ySz0LORrgbZvsvTNRq1WochcqRC3m81y586ojxev46qUdAWPm9qUNyVZDlsKMEQaeEx70JXCg3+BGVcMrRxhMgEZeIGIfOaES02YPrvwHcDDoWB0Fh8OMhuHDz39SChmXnYGE9eirqoLrcBvBOeHxVd1CMReDZymv18qWb4SJE7HRQm5UVsXVjCy5JWwXRG0= arash@BrdPC"


# Time Variable Section --------------------------------------
HOUR=`date +%H`
WEEK=`date +%A`
MONTH=`date +%Y-%d`
DAY=`date +%Y-%m-%d`
NOW="$(date +"%Y-%m-%d_%H-%M-%S")"
prompt_for_ssh_port() {
    while true; do
        read -p "Enter the desired SSH port: " ssh_port1
        if [[ "$ssh_port1" =~ ^[0-9]+$ ]] && [ "$ssh_port1" -gt 0 ] && [ "$ssh_port1" -le 65535 ]; then
            break
        else
            echo "Invalid port number. Please enter a number between 1 and 65535."
        fi
    done
}

# Get the current non-root user (the one who invoked sudo)
if [ -n "$SUDO_USER" ]; then
    CURRENT_USER="$SUDO_USER"
else
    CURRENT_USER="$USER"
fi

# Prompt for SSH port
prompt_for_ssh_port

# Prompt for SSH public key
read -p "Enter your SSH public key (leave empty to use default): " ssh_public_key

# Use default SSH public key if no input provided
if [ -z "$ssh_public_key" ]; then
    ssh_public_key="$default_ssh_public_key"
fi

# Add SSH public key to authorized_keys
echo "Adding SSH public key..."
sudo -u $CURRENT_USER mkdir -p /home/$CURRENT_USER/.ssh
sudo -u $CURRENT_USER bash -c "echo '$ssh_public_key' >> /home/$CURRENT_USER/.ssh/authorized_keys"
sudo chmod 600 /home/$CURRENT_USER/.ssh/authorized_keys
sudo chmod 700 /home/$CURRENT_USER/.ssh
sudo chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.ssh

echo "SSH public key added."

prompt_for_timeout_config() {
    while true;do
read -p "Enter your Timeout Config as seconds[1-3600]: " TIMEOUT_CONFIG

# Use default SSH public key if no input provided
# if [ -z "$TIMEOUT_CONFIG" ]; then
    if [[ "$TIMEOUT_CONFIG" =~ ^[0-9]+$ ]] && [ "$TIMEOUT_CONFIG" -gt 0 ] && [ "$TIMEOUT_CONFIG" -le 3600 ]; then
        # TIMEOUT_CONFIG="$TIMEOUT_CONFIG"
        echo -e '#!/bin/bash\n### $TIMEOUT_CONFIG seconds == $TIMEOUT_CONFIG/60 minutes ##\nTMOUT=$TIMEOUT_CONFIG\nreadonly TMOUT\nexport TMOUT' > /etc/profile.d/timout-settings.sh
        break
    # fi
else
 echo "Invalid Timeout config!"
# echo -e '#!/bin/bash\n### 300 seconds == 5 minutes ##\nTMOUT=300\nreadonly TMOUT\nexport TMOUT' > /etc/profile.d/timout-settings.sh

fi
done
cat /etc/profile.d/timout-settings.sh
}



prompt_for_domain_name() {
    while true; do

        read -p "Enter a domain name: " DOMAIN_NAME

        # Validate domain name
        validate="^(?=^.{5,254}$)(?:(?!\\d+\\.)[a-zA-Z0-9_\\-]{1,63}\\.?)+(?:[a-zA-Z]{2,})$"

        # If user doesn't enter anything
        if [ -z "$DOMAIN_NAME" ]; then
            echo "You must enter a domain"
            continue
        fi

        # Validate using grep -P for Perl-compatible regex
        if echo "$DOMAIN_NAME" | grep -Pq "$validate"; then
            echo "Valid $DOMAIN_NAME name."
            break
        else
            echo "Not valid $DOMAIN_NAME name."
        fi
    done
}



# Prompt for Doamin name
prompt_for_domain_name

# Variable Section -------------------------------------------
HostName=$DOMAIN_NAME
SSH_PORT=$ssh_port1
BAC_DIR=/opt/backup/files_$NOW
# docker config destination
DOCKER_DEST=/etc/systemd/system/docker.service.d/
MIRROR_REGISTRY=https://docker.jamko.ir


#-------------------------------------------------------------

echo "Info: ------------------------------------"
echo -e "DNS Address:\n`cat /etc/resolv.conf`"
echo -e "Hostname: $HOSTNAME"
echo -e "OS Info:\n`lsb_release -a`"
echo -e "ssh port: $SSH_PORT"
echo "------------------------------------------"
# create directory backup ------------------------------------
if [ -d $BAC_DIR ] ; then
   echo "backup directory is exist"
else
   mkdir -p $BAC_DIR
fi 
#!/bin/bash

read -p "Do you want to change apt sources list? (yes/no): " SOURCE_LIST

if [[ "$SOURCE_LIST" == "yes" ]]; then
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        # Backup existing sources.list
        echo "Backing up existing sources.list..."
        sudo cp /etc/apt/sources.list.d/ubuntu.sources $BAC_DIR/ubuntu.sources.backup
    else
        echo "No existing ubuntu.sources found, skipping backup."
fi

# Write new sources.list using ArvanCloud mirror
echo "Updating sources.list with ArvanCloud mirror..."
sudo bash -c 'cat > /etc/apt/sources.list.d/ubuntu.sources <<EOL
# ArvanCloud mirror
Types: deb
URIs: http://mirror.arvancloud.ir/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
EOL'
fi


# Preparing os ----------------------------------------------------
# Update package lists
echo "Updating package lists..."
sudo apt update

# Upgrade packages
echo "Upgrading packages..."
sudo apt upgrade -y

echo "Done."



# Remove unuse package
apt remove -y snapd && apt purge -y snapd

# install tools
apt install -y wget git vim nano bash-completion curl htop iftop jq ncdu unzip net-tools dnsutils \
               atop sudo ntp fail2ban software-properties-common apache2-utils tcpdump telnet axel
# Host Configuration ------------------------------------------
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mHostname Configuration \e[0m"
hostnamectl set-hostname $HostName
echo "Hostname Configuration Done."


# Timeout Config -----------------------------------------------
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mTimeout Setting \e[0m"
# Prompt for Timeout Config

prompt_for_timeout_config
echo "Timeout Setting Done."

#config sysctl.conf: -----------------------------------------
cp /etc/sysctl.conf $BAC_DIR
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mSysctl Configuration \e[0m"
cat <<EOT >> /etc/sysctl.conf
# Decrease TIME_WAIT seconds
net.ipv4.tcp_fin_timeout = 30

# Recycle and Reuse TIME_WAIT sockets faster
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1

# Decrease ESTABLISHED seconds
net.netfilter.nf_conntrack_tcp_timeout_established=3600

# Maximum Number Of Open Files
fs.file-max = 500000

# 
vm.max_map_count=262144

net.ipv4.ip_nonlocal_bind = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1

#Kernel Hardening
fs.suid_dumpable = 0
kernel.core_uses_pid = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.sysrq = 0 
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

#New Kernel Hardening
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0

# Disable Ipv6
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv4.conf.all.rp_filter=1
kernel.yama.ptrace_scope=1
EOT
echo "root soft nofile 65535" >  /etc/security/limits.conf
echo "root hard nofile 65535" >> /etc/security/limits.conf
echo "root soft nproc 65535" >> /etc/security/limits.conf
echo "root hard nproc 65535" >> /etc/security/limits.conf

echo "* soft nofile 2048" >  /etc/security/limits.conf
echo "* hard nofile 2048" >> /etc/security/limits.conf
echo "* soft nproc  2048" >> /etc/security/limits.conf
echo "* hard nproc  2048" >> /etc/security/limits.conf
modprobe br_netfilter

# sysctl config apply 
sysctl -p
#-------------------------------------------------------------
# postfix Service: disable, stop and mask
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mpostfix Service: disable, stop and mask \e[0m"
systemctl stop postfix
systemctl disable postfix
systemctl mask postfix
#-------------------------------------------------------------
# firewalld Service: disable, stop and mask
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mfirewalld Service: disable, stop and mask \e[0m"
systemctl stop firewalld
systemctl disable firewalld
systemctl mask firewalld
#-------------------------------------------------------------
# ufw Service: disable, stop and mask
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mufw Service: disable, stop and mask \e[0m"
systemctl stop ufw
systemctl disable ufw
systemctl mask ufw
# create ssh banner -------------------------------------------
cat <<EOT > /etc/issue.net
------------------------------------------------------------------------------
* WARNING.....                                                               *
* You are accessing a secured system and your actions will be logged along   *
* with identifying information. Disconnect immediately if you are not an     *
* authorized user of this system.                                            *
------------------------------------------------------------------------------
EOT
# sshd_config edit this parameters ------------------------------
cp /etc/ssh/sshd_config $BAC_DIR
cat <<EOT > /etc/ssh/sshd_config
Port $SSH_PORT
ListenAddress 0.0.0.0

# Logging
LogLevel VERBOSE

# Authentication:
#LoginGraceTime 2m
PermitRootLogin yes
#PermitRootLogin without-password
#StrictModes yes
MaxAuthTries 3
MaxSessions 2
PubkeyAuthentication yes

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication yes
#PermitEmptyPasswords no

ChallengeResponseAuthentication no

# GSSAPI options
GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

UsePAM yes

AllowAgentForwarding no
AllowTcpForwarding no
#GatewayPorts no
X11Forwarding no
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
TCPKeepAlive no
#UseLogin no
#PermitUserEnvironment no
Compression no
ClientAliveInterval 10
ClientAliveCountMax 10
UseDNS no

# no default banner path
Banner /etc/issue.net

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

AllowUsers root 
AllowGroups root
EOT

#sshd config test
sshd -t

#ssh service: enable, restart and status
{
systemctl enable sshd.service 
systemctl restart sshd.service 
systemctl is-active --quiet sshd && echo -e "\e[1m \e[96m sshd service: \e[92m Active \e[0m" || echo -e "\e[1m \e[96m sshd service: \e[91m Inactive \e[0m"
}
#config user root ------------------------------------------------
echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mConfigure root user \e[0m"
sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
usermod --password $(echo root123 | openssl passwd -1 -stdin) root
#--------------------------------

# Ask if user wants to change DNS settings
read -p "Do you want to change DNS settings? (yes/no): " change_dns

if [[ "$change_dns" == "yes" ]]; then
    read -p "Enter the first DNS server: " dns1
    read -p "Enter the second DNS server: " dns2
    echo "Changing DNS settings to $dns1 and $dns2..."
    sudo bash -c "cat > /etc/resolv.conf <<EOL
nameserver $dns1
nameserver $dns2
EOL"
else
    echo "Using default DNS settings."
fi
# Ask if user wants to install Docker
read -p "Do you want to install Docker? (yes/no): " install_docker

if [[ "$install_docker" == "yes" ]]; then
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."

        # Update the package list
        sudo apt update

        # Install prerequisite packages
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker's official APT repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Update the package list again
        sudo apt update

        # Install Docker
        sudo apt install -y docker-ce docker-ce-cli containerd.io

        sudo systemctl start docker
        #Configuration docker registry mirror ---------------------------
        echo -e " \e[30;48;5;56m \e[1m \e[38;5;15mDocker Configuration: Add Registry Mirror \e[0m"
        mkdir -p $DOCKER_DEST
        cat <<EOT > $DOCKER_DEST/docker.conf
        [Service]
        ExecStart=
        ExecStart=/usr/bin/dockerd --registry-mirror=$MIRROR_REGISTRY
EOT
        # Start and enable Docker service
        systemctl daemon-reload
        systemctl restart docker
        sudo systemctl enable docker


        # Verify Docker installation
        if command -v docker &> /dev/null; then
            echo "Docker was installed successfully."
        else
            echo "Failed to install Docker."
        fi
    else
        echo "Docker is already installed."
    fi
else
    echo "Docker installation skipped."
fi

echo "Script executed successfully."
exit 0
