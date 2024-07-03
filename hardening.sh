#!/bin/bash

# Default SSH public key (replace this with your actual default public key)
default_ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAvWzZB8aKtvpTrX+7EzoZ0K5y6g3G/vn9Q8fMVUzNVU5UkcX/WGZEmdbV8pqDH5g5Cw7Rh8/UY8ytkaKbNqptfWZbXQuu4ltAQBu0/pYRpK4F5L1B6+xJWRHV7uKoRY8oE1QsQphK1D1L8+Q0o7+2a5PqM8ktMHB3xzY7zScUwV2xYk/W29Zsa6rr9YsbioIaXwvXy4dt3W7T6b+FCZP9v5dFi53kdEFZm32ar2dT3V0thbH2Zsl2dc3p65G/zMBXowmMOexPAPCxW5UPYUpRQHdS7BHeQXb2DhO+mVZxyhCZIlcsMDOEuA6E1z1N2LBC4fN5G4bcblCZ23Z5L0sfvPe9IAw== your_default_key_comment"

# Function to prompt user for SSH port
prompt_for_ssh_port() {
    while true; do
        read -p "Enter the desired SSH port: " ssh_port
        if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [ "$ssh_port" -gt 0 ] && [ "$ssh_port" -le 65535 ]; then
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

# Set SSH port and disable password authentication
echo "Configuring SSH..."

if grep -q "^#Port 22" /etc/ssh/sshd_config; then
    sudo sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
elif grep -q "^Port 22" /etc/ssh/sshd_config; then
    sudo sed -i "s/Port 22/Port $ssh_port/" /etc/ssh/sshd_config
else
    echo "Port $ssh_port" | sudo tee -a /etc/ssh/sshd_config
fi

sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd

echo "SSH port has been set to $ssh_port and password authentication disabled."

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

        # Start and enable Docker service
        sudo systemctl start docker
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
