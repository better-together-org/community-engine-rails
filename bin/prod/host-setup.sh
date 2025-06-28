#!/bin/bash
set -e

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
  printf -- "This script must be run as root. Please run it with sudo or as the root user.\n"
  exit 1
fi

#############################################
# Trap signals for clean exit
#############################################
cleanup() {
  printf -- "\nReceived termination signal. Cleaning up and exiting...\n"
  stty sane 2>/dev/null  # Restore terminal settings in case of disruption
  exit 0
}

# Trap SIGINT (Ctrl+C), SIGTERM, and SIGQUIT
trap cleanup SIGINT SIGTERM SIGQUIT

#############################################
# Global Variables (Defaults)
#############################################
VERBOSE=false
STATIC_IP_ETH=""
STATIC_IP_WLAN=""
DISABLE_WIFI=false
DISABLE_BLUETOOTH=false
MUTE_AUDIO=false
DOCKER_VERSION=""
NORDVPN_LOGIN_URL=""
NEW_HOSTNAME=""
STORAGE_PATH=""
RUN_STEP=""

#############################################
# Function: Display Detailed Usage/Help Text
#############################################
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

This setup wizard configures your Raspberry Pi (or similar device) for Better Together's Community Engine.
It does so by:
  - Setting a fixed IP address (so your device always has the same address)
  - Optionally turning off Wi-Fi and Bluetooth
  - Muting audio if desired
  - Updating the system software
  - Installing Docker, Cloudflared, NordVPN, and other useful tools
  - Hardening system security and setting up backups

Options:
  --static-ip-eth=IP       Set a fixed IP for the Ethernet interface.
  --static-ip-wlan=IP      Set a fixed IP for Wi-Fi.
  --disable-wifi           Turn off Wi-Fi.
  --disable-bluetooth      Turn off Bluetooth.
  --mute-audio             Mute audio.
  --docker-version=VER     Install a specific version of Docker.
  --nordvpn-login-url=URL  Provide the URL for NordVPN login.
  --hostname=NAME          Assign a custom hostname.
  --storage-path=PATH      Specify a folder for backups and Cosmos data.
  -v, --verbose            Enable verbose debug messages.
  --step=NAME              Run only a specific step. Valid names:
                           welcome, specs, network, hardening, backup, tweaks,
                           update, docker, cloudflared, nordvpn, hostname, storage.
  --help                   Display this help message.

EOF
  exit 0
}

#############################################
# Function: Debug Log (prints only if VERBOSE is true)
#############################################
debug() {
  if [ "$VERBOSE" = true ]; then
    # Use "$1" as the format string and the rest as substitutions.
    printf -- "[DEBUG] $1\n" "${@:2}"
  fi
}

#############################################
# Function: Parse Command-Line Arguments
#############################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --static-ip-eth=*)
        STATIC_IP_ETH="${1#*=}"
        debug "Static IP (Ethernet) set to $STATIC_IP_ETH"
        shift
        ;;
      --static-ip-wlan=*)
        STATIC_IP_WLAN="${1#*=}"
        debug "Static IP (Wi-Fi) set to $STATIC_IP_WLAN"
        shift
        ;;
      --disable-wifi)
        DISABLE_WIFI=true
        debug "Wi-Fi will be disabled."
        shift
        ;;
      --disable-bluetooth)
        DISABLE_BLUETOOTH=true
        debug "Bluetooth will be disabled."
        shift
        ;;
      --mute-audio)
        MUTE_AUDIO=true
        debug "Audio will be muted."
        shift
        ;;
      --docker-version=*)
        DOCKER_VERSION="${1#*=}"
        debug "Docker version set to $DOCKER_VERSION"
        shift
        ;;
      --nordvpn-login-url=*)
        NORDVPN_LOGIN_URL="${1#*=}"
        debug "NordVPN login URL set to $NORDVPN_LOGIN_URL"
        shift
        ;;
      --hostname=*)
        NEW_HOSTNAME="${1#*=}"
        debug "Hostname set to $NEW_HOSTNAME"
        shift
        ;;
      --storage-path=*)
        STORAGE_PATH="${1#*=}"
        debug "Storage path set to $STORAGE_PATH"
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        debug "Verbose mode enabled."
        shift
        ;;
      --step=*)
        RUN_STEP="${1#*=}"
        debug "Run only step: $RUN_STEP"
        shift
        ;;
      --help)
        usage
        ;;
      *)
        printf -- "Unknown option: %s\n" "$1"
        usage
        ;;
    esac
  done
}

#############################################
# Function: Prompt to Continue a Step
#############################################
prompt_continue() {
  local step_name="$1"
  local step_help="$2"
  printf -- "\n-------------------------------\n"
  printf -- "Step: %s\n" "$step_name"
  printf -- "-------------------------------\n"
  printf -- "%s\n\n" "$step_help"
  debug "Waiting for user input to continue at step: $step_name"
  while true; do
    printf -- "Press Enter to continue this step, s to skip this step, h for help, or type n/no to exit: "
    read -r choice
    if [ -z "$choice" ]; then
      break
    fi
    case "$choice" in
      n|no)
        debug "User chose to abort script at step: $step_name"
        exit 0
        ;;
      h|help)
        printf -- "%s\n" "$step_help"
        usage
        ;;
      s|kip)
        debug "User chose to skip step: $step_name"
        break
        ;;
      *) break ;;
    esac
  done
  debug "User chose to continue at step: $step_name"
}

#############################################
# Step 1: Welcome & Overview
#############################################
step_welcome() {
  debug "Starting step_welcome"
  printf -- "################################################\n"
  printf -- "#                                              #\n"
  printf -- "#        Welcome to Better Together!           #\n"
  printf -- "#        Community Engine Host Setup           #\n"
  printf -- "#                                              #\n"
  printf -- "################################################\n\n"
  printf -- "✨ Hello and welcome! ✨\n\n"
  printf -- "You're about to set up your system with Better Together's Community Engine.\n"
  printf -- "This platform is more than technology—it's a movement dedicated to kindness,\n"
  printf -- "connection, and cooperation, helping communities become stronger together.\n\n"
  printf -- "With this simple setup wizard, you will:\n"
  printf -- "  1. Assign a fixed internet address to easily locate your device.\n"
  printf -- "  2. Secure your system by optionally disabling Wi-Fi and Bluetooth.\n"
  printf -- "  3. Mute audio settings for a quieter, more focused environment.\n"
  printf -- "  4. Ensure your system has the latest security updates and features.\n"
  printf -- "  5. Install essential tools like Docker, Cloudflared, and NordVPN.\n"
  printf -- "  6. Strengthen security and keep your data safe.\n\n"
  printf -- "This script is optimized for systems similar to a Raspberry Pi 5 with at least 8GB RAM,\n"
  printf -- "but aims to support various hardware configurations.\n\n"
  printf -- "Let's create a more connected, resilient, and empowered community—together.\n\n"
  prompt_continue "Welcome & Overview" "When you're ready, press (y) to begin your journey."
  debug "Finished step_welcome"
}

#############################################
# Step 2: Check Host Specs
#############################################
step_check_specs() {
  debug "Starting step_check_specs"
  printf -- "################################################\n"
  printf -- "#              Checking System Specs           #\n"
  printf -- "################################################\n\n"
  printf -- "Minimum recommended specs for Community Engine:\n"
  printf -- "- CPU: 4 cores or more\n"
  printf -- "- RAM: 4GB minimum (8GB+ recommended)\n"
  printf -- "- OS: 64-bit Linux recommended\n"
  printf -- "- Storage: 64GB minimum\n\n"
  printf -- "Your current system specs:\n\n"

  cpu_model=$(grep -m 1 'model name' /proc/cpuinfo | cut -d ':' -f 2 | xargs)
  cpu_cores=$(nproc)
  ram_total=$(free -h | awk '/Mem:/ {print $2}')
  disk_total=$(df -h / | awk 'NR==2 {print $2}')
  arch=$(uname -m)

  printf -- "Hostname: %s\n" "$(hostname)"
  printf -- "CPU Model: %s\n" "${cpu_model:-Unknown}"
  printf -- "CPU Cores: %s\n" "${cpu_cores:-Unknown}"
  printf -- "Total RAM: %s\n" "${ram_total:-Unknown}"
  printf -- "Disk Space: %s\n" "${disk_total:-Unknown}"
  printf -- "System Architecture: %s\n\n" "${arch:-Unknown}"

  if [[ $(nproc) -lt 4 || $(free -m | awk '/^Mem:/ {print $2}') -lt 4000 ]]; then
    printf -- "⚠️  Your system does NOT meet the recommended minimum specs! ⚠️\n"
    printf -- "Proceeding is considered an advanced operation. Only continue if you understand\n"
    printf -- "the limitations and possible performance impacts.\n"
    prompt_continue "System Check Warning" "Your system may not perform optimally. Press (y) ONLY if you're sure you want to continue."
  else
    printf -- "✅ Your system meets the recommended minimum specs. ✅\n"
    prompt_continue "System Specifications Check" "Review your system specs above. Press (y) to continue."
  fi
  debug "Finished step_check_specs"
}

#############################################
# Function: Set Static IP (Stub)
#############################################
set_static_ip() {
  printf -- "\nStatic IP Configuration\n"
  printf -- "-------------------------\n"
  printf -- "Enter the desired static IP for eth0 (e.g., 192.168.1.100/24): "
  read -r new_ip
  printf -- "Configuring static IP %s for eth0... (this is a simulation)\n" "$new_ip"
  sleep 1
  printf -- "Static IP %s has been configured for eth0.\n" "$new_ip"
}

#############################################
# Function: Summarize Network Context
#############################################
summarize_network_context() {
  printf -- "\n------------------------------\n"
  printf -- "Network Context Summary\n"
  printf -- "------------------------------\n\n"
  
  printf -- "Hostname: %s\n\n" "$(hostname)"
  
  printf -- "Interfaces:\n"
  ip -br addr show
  printf -- "\n"
  
  printf -- "Default Gateway:\n"
  ip route | grep '^default'
  printf -- "\n"
  
  printf -- "DNS Servers:\n"
  awk '/nameserver/ {print $2}' /etc/resolv.conf
  printf -- "\n"
  
  # Check for a static IP on the Ethernet interface (eth0)
  ETH_INTERFACE="eth0"
  STATIC_IP_SET=false
  printf -- "\n"
  debug "Checking if interface %s exists..." "$ETH_INTERFACE"
  if ip addr show "$ETH_INTERFACE" &>/dev/null; then
    debug "Interface %s exists. Checking /etc/dhcpcd.conf for static configuration..." "$ETH_INTERFACE"
    if [ -f /etc/dhcpcd.conf ]; then
      STATIC_CONF=$(grep -m 1 -i -A 3 "^[[:space:]]*interface[[:space:]]\+$ETH_INTERFACE" /etc/dhcpcd.conf 2>/dev/null | grep -iv '^[[:space:]]*#' | grep -i "static ip_address")
      debug "Found /etc/dhcpcd.conf, STATIC_CONF: %s" "$STATIC_CONF"
    else
      debug "/etc/dhcpcd.conf not found. Skipping static IP file check."
      STATIC_CONF=""
    fi

    debug "STATIC_CONF: %s" "$STATIC_CONF"
    if [ -n "$STATIC_CONF" ]; then
      CONFIGURED_IP=$(echo "$STATIC_CONF" | awk -F'=' '{print $2}' | xargs)
      printf -- "A static IP is configured for %s: %s\n" "$ETH_INTERFACE" "$CONFIGURED_IP"
      debug "Static IP found: %s" "$CONFIGURED_IP"
      STATIC_IP_SET=true
    else
      debug "No static configuration found in /etc/dhcpcd.conf. Checking current IP on %s..." "$ETH_INTERFACE"
      CURRENT_IP=$(ip -4 addr show "$ETH_INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
      debug "CURRENT_IP: %s" "$CURRENT_IP"
      if [ -n "$CURRENT_IP" ]; then
        printf -- "No static IP configured for %s. Current IP (likely via DHCP): %s\n" "$ETH_INTERFACE" "$CURRENT_IP"
      else
        printf -- "No IP address found for %s.\n" "$ETH_INTERFACE"
      fi
    fi
  else
    printf -- "Ethernet interface %s not found.\n" "$ETH_INTERFACE"
    debug "Interface %s does not exist." "$ETH_INTERFACE"
  fi

  printf -- "------------------------------\n\n"
  
  if [ "$STATIC_IP_SET" = false ]; then
    debug "No static IP set for %s. Prompting user for static IP configuration." "$ETH_INTERFACE"
    printf -- "Would you like to configure a static IP address for %s? (y/n): " "$ETH_INTERFACE"
    read -r answer
    debug "User input for static IP configuration: %s" "$answer"
    case "$answer" in
      y|Y|yes)
        debug "User opted to configure a static IP."
        set_static_ip
        ;;
      *)
        printf -- "Proceeding without configuring a static IP.\n"
        debug "User opted not to configure a static IP."
        ;;
    esac
  fi
}

#############################################
# Step 3: Configure Network Settings
#############################################
configure_network() {
  debug "Starting configure_network"
  printf -- "Configuring network settings...\n"
  
  summarize_network_context
  
  if [[ -n "$STATIC_IP_ETH" ]]; then
    printf -- "Setting static IP for Ethernet to %s\n" "$STATIC_IP_ETH"
    # Insert commands to set static IP for Ethernet here.
  fi
  
  if [[ -n "$STATIC_IP_WLAN" ]]; then
    printf -- "Setting static IP for Wi-Fi to %s\n" "$STATIC_IP_WLAN"
    # Insert commands to set static IP for Wi-Fi here.
  fi
  
  prompt_continue "Network Configuration" "Network settings applied (or skipped if none provided). Press (y) to continue."
  debug "Finished configure_network"
}

#############################################
# Step 4: Security & Hardware Tweaks
#############################################
hardware_tweaks() {
  debug "Starting hardware_tweaks"
  printf -- "Applying hardware and security tweaks...\n"
  if [[ "$DISABLE_WIFI" == true ]]; then
    printf -- "Disabling Wi-Fi...\n"
  fi
  if [[ "$DISABLE_BLUETOOTH" == true ]]; then
    printf -- "Disabling Bluetooth...\n"
  fi
  if [[ "$MUTE_AUDIO" == true ]]; then
    printf -- "Muting audio...\n"
  fi
  prompt_continue "Hardware & Security Tweaks" "Hardware tweaks applied (or skipped if none provided). Press (y) to continue."
  debug "Finished hardware_tweaks"
}

#############################################
# New Step: Security Hardening
#############################################
security_hardening() {
  debug "Starting security hardening"
  printf -- "Applying security hardening measures...\n"
  # Insert your security hardening commands here.
  printf -- "Security hardening measures applied. (Placeholder)\n"
  debug "Finished security hardening"
  prompt_continue "Security Hardening" "Press Enter to continue after security hardening."
}

#############################################
# New Step: Backup Configuration
#############################################
backup_config() {
  debug "Starting backup configuration"
  printf -- "Configuring backup settings...\n"
  # Insert your backup configuration commands here.
  printf -- "Backup configuration complete. (Placeholder)\n"
  debug "Finished backup configuration"
  prompt_continue "Backup Configuration" "Press Enter to continue after backup configuration."
}

#############################################
# New Tool Installation Sub-Methods
#############################################
update_system() {
  debug "Starting system update..."
  printf -- "Updating system packages...\n"
  sudo apt update && sudo apt upgrade -y
  debug "Finished system update."
}

install_docker() {
  debug "Starting Docker installation..."
  
  # Check if Docker is present and working.
  if command -v docker &>/dev/null; then
    debug "Docker is already installed."
    printf -- "Docker is already installed and appears to be ready to use.\n"
    printf -- "Would you like to reinstall/update Docker, or skip Docker installation? (r to reinstall / s to skip): "
    read -r docker_choice
    case "$docker_choice" in
      s|skip)
        debug "User chose to skip Docker installation."
        return 0
        ;;
      r|reinstall)
        debug "User chose to reinstall/update Docker."
        ;;
      *)
        debug "No valid input received; defaulting to skip Docker installation."
        return 0
        ;;
    esac
  fi
  
  # Proceed with installation if Docker is not present or user opts to reinstall.
  if [[ -n "$DOCKER_VERSION" ]]; then
    printf -- "Installing Docker version %s...\n" "$DOCKER_VERSION"
    # Insert commands to install the specified Docker version.
  else
    printf -- "Installing latest Docker...\n"
    # Insert commands to install the latest Docker.
    
    # Add Docker's official GPG key:
    apt-get update
    apt-get install ca-certificates curl -y
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    
    apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    
    groupadd docker
    usermod -aG docker $USER
    newgrp docker
    docker run hello-world
  fi
  
  debug "Finished Docker installation."
}

install_cloudflared() {
  debug "Starting Cloudflared installation..."
  printf -- "Installing Cloudflared...\n"
  
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
  apt-get update && apt-get install cloudflared -y
  
  debug "Finished Cloudflared installation."
}

configure_nordvpn() {
  debug "Starting NordVPN configuration..."
  if command -v nordvpn &>/dev/null; then
    printf -- "NordVPN is already installed and appears to be ready to use.\n"
    printf -- "Would you like to reconfigure (login) NordVPN? (y/n): "
    read -r nordvpn_choice
    if [ "$nordvpn_choice" = "y" ] || [ "$nordvpn_choice" = "yes" ]; then
      if [[ -n "$NORDVPN_LOGIN_URL" ]]; then
        printf -- "Configuring NordVPN with login URL: %s...\n" "$NORDVPN_LOGIN_URL"
        sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
        nordvpn login --help
      else
        printf -- "No NordVPN login URL provided. Skipping NordVPN reconfiguration.\n"
      fi
    else
      printf -- "Skipping NordVPN reconfiguration.\n"
    fi
  else
    if [[ -n "$NORDVPN_LOGIN_URL" ]]; then
      printf -- "NordVPN is not installed. Configuring NordVPN with login URL: %s...\n" "$NORDVPN_LOGIN_URL"
      sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
      nordvpn login --help
    else
      printf -- "No NordVPN login URL provided. Skipping NordVPN configuration.\n"
    fi
  fi
  debug "Finished NordVPN configuration."
}

configure_hostname() {
  debug "Starting hostname configuration..."
  if [[ -n "$NEW_HOSTNAME" ]]; then
    printf -- "Changing hostname to %s...\n" "$NEW_HOSTNAME"
    # Insert commands to change the hostname.
  else
    printf -- "No new hostname provided. Skipping hostname configuration.\n"
  fi
  debug "Finished hostname configuration."
}

configure_storage() {
  debug "Starting storage configuration..."
  if [[ -n "$STORAGE_PATH" ]]; then
    printf -- "Setting storage path to %s...\n" "$STORAGE_PATH"
    # Insert commands to configure the storage path.
  else
    printf -- "No storage path provided. Skipping storage configuration.\n"
  fi
  debug "Finished storage configuration."
}

#############################################
# Step: Install Dokku
#############################################
install_dokku() {
  debug "Starting Dokku installation..."
  
  if command -v dokku &>/dev/null; then
    printf -- "✅ Dokku is already installed. Skipping installation.\n"
    
    if prompt_substep "Sub-step: Configure Dokku?\nThis will set up SSH access, global domains, and optional app creation."; then
      configure_dokku
    else
      return 0
    fi
  else
    if prompt_substep "Sub-step: Install Dokku (Platform as a Service)?\nDokku is a lightweight PaaS that runs on your server. Press Enter to proceed, or type 'skip' to skip installation."; then
  
      printf -- "📥 Installing Dokku...\n"
      wget -qO- https://dokku.com/install/v0.34.3/bootstrap.sh | DOKKU_TAG=v0.34.3 bash
      
      printf -- "✅ Dokku installation complete.\n"
      
      if prompt_substep "Sub-step: Configure Dokku?\nThis will set up SSH access, global domains, and optional app creation."; then
        configure_dokku
      fi
    fi
  fi
  
  debug "Finished Dokku installation."
}

#############################################
# Step: Configure Dokku
#############################################
configure_dokku() {
  debug "Starting Dokku configuration..."
  
  if ! command -v dokku &>/dev/null; then
    printf -- "❌ Dokku is not installed. Skipping configuration.\n"
    return 0
  fi

  # Step 1: Configure SSH Access
  printf -- "\n🔑 Configuring SSH access for Dokku...\n"

  # Determine the full path for the current user's authorized keys file
  USER_HOME=$(eval echo ~"$SUDO_USER")
  AUTH_KEYS_FILE="$USER_HOME/.ssh/authorized_keys"

  # Check if a Dokku SSH key named "admin" already exists
  if dokku ssh-keys:list | grep -q 'NAME="admin"'; then
    printf -- "✅ A Dokku SSH key named 'admin' already exists. Skipping SSH key addition.\n"
  else
    if [ -s "$AUTH_KEYS_FILE" ]; then
      printf -- "✅ Found existing SSH keys in '%s'. Adding them to Dokku...\n" "$AUTH_KEYS_FILE"
      cat "$AUTH_KEYS_FILE" | dokku ssh-keys:add admin
      printf -- "✅ SSH keys added successfully.\n"
    else
      if prompt_substep "Sub-step: Manually add an SSH key for Dokku?\nNo existing keys were found. You will need an SSH key to push applications to Dokku."; then
        printf -- "🔑 Please enter your public SSH key (or path to a key file): "
        read -r ssh_key

        if [ -f "$ssh_key" ]; then
          ssh_key_contents=$(cat "$ssh_key")
        else
          ssh_key_contents="$ssh_key"
        fi

        echo "$ssh_key_contents" | dokku ssh-keys:add admin
        printf -- "✅ SSH key added successfully.\n"
      else
        printf -- "❌ Skipping SSH key setup.\n"
      fi
    fi
  fi

  # Step 2: Set a Global Domain
  if prompt_substep "Sub-step: Set a global domain for Dokku?\nThis domain should have an A record or CNAME pointing to your server's IP."; then
    printf -- "\n🌐 Current Dokku Global Domains:\n"
    dokku domains:report --global | grep "Domains global vhosts" | cut -d ":" -f2 | xargs
    
    printf -- "\nWould you like to add another global domain? (y/n): "
    read -r add_domain

    if [[ "$add_domain" =~ ^[Yy]$ ]]; then
      printf -- "🌍 Enter the domain name you want to add as a global domain (e.g., example.com): "
      read -r dokku_domain

      if [ -n "$dokku_domain" ]; then
        dokku domains:add-global "$dokku_domain"
        printf -- "✅ Global domain '%s' added successfully.\n" "$dokku_domain"
      else
        printf -- "❌ No domain entered. Skipping global domain setup.\n"
      fi
    else
      printf -- "❌ No additional domain added.\n"
    fi
  fi

  # Step 3: Install Essential Dokku Plugins
  if prompt_substep "Sub-step: Install Dokku Plugins?\nThis will install commonly used plugins like Postgres, Redis, LetsEncrypt, and Elasticsearch."; then
    printf -- "🔧 Installing Dokku plugins...\n"
    
    dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
    dokku plugin:install https://github.com/dokku/dokku-redis.git redis
    dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
    dokku plugin:install https://github.com/dokku/dokku-elasticsearch.git elasticsearch

    printf -- "✅ Dokku plugins installed successfully.\n"
  else
    printf -- "❌ Skipping Dokku plugin installation.\n"
  fi


  debug "Finished Dokku configuration."
}


install_tools() {
  debug "Starting install_tools"
  printf -- "Starting full system update and tool installation...\n"
  
  prompt_continue "System Update" "Press Enter to update system packages."
  update_system
  
  prompt_continue "Docker Installation" "Press Enter to install Docker."
  install_docker
  
  prompt_continue "Cloudflared Installation" "Press Enter to install Cloudflared."
  install_cloudflared
  
  prompt_continue "NordVPN Configuration" "Press Enter to configure NordVPN."
  configure_nordvpn
  
  prompt_continue "Hostname Configuration" "Press Enter to configure hostname."
  configure_hostname
  
  prompt_continue "Storage Configuration" "Press Enter to configure storage."
  configure_storage
  
  prompt_continue "Tool Installation Summary" "Tools installed/updated. Press Enter to continue."
  debug "Finished install_tools"
}


#############################################
# Step: Setup Dokku App
#############################################
setup_dokku_app() {
  local app_name="$1"

  if dokku apps:exists "$app_name"; then
    printf -- "⚠️  The Dokku app '%s' already exists. Showing details:\n" "$app_name"
    dokku apps:report "$app_name"

    if prompt_substep "Sub-step: Recreate the Dokku app '$app_name'?\nThis will delete and recreate the app and all associated configurations."; then
      dokku apps:destroy "$app_name" --force
      dokku apps:create "$app_name"
      dokku docker-options:add "$app_name" build '--build-arg AWS_ACCESS_KEY_ID'
      dokku docker-options:add "$app_name" build '--build-arg AWS_SECRET_ACCESS_KEY'
      dokku docker-options:add "$app_name" build '--build-arg FOG_DIRECTORY'
      dokku docker-options:add "$app_name" build '--build-arg FOG_HOST'
      dokku docker-options:add "$app_name" build '--build-arg FOG_REGION'
      dokku docker-options:add "$app_name" build '--build-arg ASSET_HOST'
      dokku docker-options:add "$app_name" build '--build-arg CDN_DISTRIBUTION_ID'
      printf -- "✅ Dokku app '%s' recreated.\n" "$app_name"
    else
      printf -- "⏩ Skipping Dokku app creation.\n"
    fi
  else
    dokku apps:create "$app_name"
    dokku docker-options:add "$app_name" build '--build-arg AWS_ACCESS_KEY_ID'
    dokku docker-options:add "$app_name" build '--build-arg AWS_SECRET_ACCESS_KEY'
    dokku docker-options:add "$app_name" build '--build-arg FOG_DIRECTORY'
    dokku docker-options:add "$app_name" build '--build-arg FOG_HOST'
    dokku docker-options:add "$app_name" build '--build-arg FOG_REGION'
    dokku docker-options:add "$app_name" build '--build-arg ASSET_HOST'
dokku docker-options:add "$app_name" build '--build-arg CDN_DISTRIBUTION_ID'
    printf -- "✅ Dokku app '%s' created.\n" "$app_name"
  fi
}

#############################################
# Step: Setup PostgreSQL (PostGIS)
#############################################
setup_postgis_database() {
  local app_name="$1"
  local db_name="${app_name}_db"

  if dokku plugin:installed postgres; then
    printf -- "✅ Dokku Postgres plugin is installed.\n"
  else
    printf -- "🔧 Installing Dokku Postgres plugin...\n"
    dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
  fi

  if dokku postgres:exists "$db_name"; then
    printf -- "⚠️  Database '%s' already exists. Showing details:\n" "$db_name"
    dokku postgres:info "$db_name"

    if prompt_substep "Sub-step: Recreate the PostGIS database '$db_name'?\nThis will delete and recreate the database."; then
      dokku postgres:destroy "$db_name" --force
      dokku postgres:create "$db_name" --image postgis/postgis --image-version latest
      dokku postgres:link "$db_name" "$app_name"
      printf -- "✅ PostGIS database '%s' recreated and linked.\n" "$db_name"
    else
      printf -- "⏩ Skipping database creation.\n"
    fi
  else
    dokku postgres:create "$db_name" --image postgis/postgis --image-version latest
    dokku postgres:link "$db_name" "$app_name"
    printf -- "✅ PostGIS database '%s' created and linked.\n" "$db_name"
  fi
}

#############################################
# Step: Setup Redis
#############################################
setup_redis() {
  local app_name="$1"
  local redis_name="${app_name}_redis"

  if dokku plugin:installed redis; then
    printf -- "✅ Dokku Redis plugin is installed.\n"
  else
    printf -- "🔧 Installing Dokku Redis plugin...\n"
    dokku plugin:install https://github.com/dokku/dokku-redis.git redis
  fi

  if dokku redis:exists "$redis_name"; then
    printf -- "⚠️  Redis instance '%s' already exists. Showing details:\n" "$redis_name"
    dokku redis:info "$redis_name"

    if prompt_substep "Sub-step: Recreate the Redis instance '$redis_name'?\nThis will delete and recreate the Redis instance."; then
      dokku redis:destroy "$redis_name" --force
      dokku redis:create "$redis_name"
      dokku redis:link "$redis_name" "$app_name"
      printf -- "✅ Redis instance '%s' recreated and linked.\n" "$redis_name"
    else
      printf -- "⏩ Skipping Redis creation.\n"
    fi
  else
    dokku redis:create "$redis_name"
    dokku redis:link "$redis_name" "$app_name"
    printf -- "✅ Redis instance '%s' created and linked.\n" "$redis_name"
  fi
}

#############################################
# Step: Setup Let's Encrypt
#############################################
setup_letsencrypt() {
  local app_name="$1"

  if dokku plugin:installed letsencrypt; then
    printf -- "✅ Dokku Let's Encrypt plugin is installed.\n"
  else
    printf -- "🔧 Installing Dokku Let's Encrypt plugin...\n"
    dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  fi

  printf -- "🔎 Checking existing Let's Encrypt email for '%s'...\n" "$app_name"

  # Get the existing Let's Encrypt email (app-specific first, then global)
  letsencrypt_email=$(dokku config:get "$app_name" DOKKU_LETSENCRYPT_EMAIL 2>/dev/null || true)
  if [ -z "$letsencrypt_email" ]; then
    letsencrypt_email=$(dokku config:get --global DOKKU_LETSENCRYPT_EMAIL 2>/dev/null || true)
  fi

  # If no email is set, prompt the user
  if [ -z "$letsencrypt_email" ]; then
    printf -- "⚠️  No Let's Encrypt email is configured for '%s'.\n" "$app_name"
    
    if prompt_substep "Sub-step: Set a Let's Encrypt email address for '${app_name}'?\nThis email is required for SSL certificate renewal notifications."; then
      printf -- "📧 Enter your email address for Let's Encrypt notifications: "
      read -r letsencrypt_email

      if [ -n "$letsencrypt_email" ]; then
        dokku letsencrypt:set "$app_name" email "$letsencrypt_email"
        printf -- "✅ Let's Encrypt email set to '%s' for '%s'.\n" "$letsencrypt_email" "$app_name"
      else
        printf -- "❌ No email entered. Skipping email configuration.\n"
      fi
    fi
  else
    printf -- "✅ Existing Let's Encrypt email for '%s': %s\n" "$app_name" "$letsencrypt_email"
  fi

  # Check if SSL is already enabled for the app
  if dokku letsencrypt:ls | grep -q "$app_name"; then
    printf -- "⚠️  Let's Encrypt is already enabled for '%s'. Showing certificate details:\n" "$app_name"
    dokku letsencrypt:info "$app_name"

    if prompt_substep "Sub-step: Reapply Let's Encrypt SSL for '${app_name}'?\nThis will force renew the certificate."; then
      dokku letsencrypt:auto-renew "$app_name"
      printf -- "✅ Let's Encrypt SSL certificate renewed for '%s'.\n" "$app_name"
    else
      printf -- "⏩ Skipping SSL renewal.\n"
    fi
  else
    printf -- "🔐 Enabling Let's Encrypt SSL for '%s'...\n" "$app_name"
    dokku letsencrypt:enable "$app_name"
    printf -- "✅ Let's Encrypt enabled for '%s'.\n" "$app_name"
  fi
}

#############################################
# Step: Report & Add Domain for Dokku App
#############################################
report_and_add_app_domain() {
  local app_name="$1"

  printf -- "\n🌍 Retrieving existing domains for app '%s'...\n" "$app_name"
  dokku domains:report "$app_name"

  if prompt_substep "Sub-step: Add a new domain to '$app_name'?\nThis domain should have an A record or CNAME pointing to your server's IP."; then
    printf -- "🌍 Enter the domain name you want to add (e.g., example.com): "
    read -r new_domain

    if [ -n "$new_domain" ]; then
      dokku domains:set "$app_name" "$new_domain"
      printf -- "✅ Domain '%s' added successfully to '%s'.\n" "$new_domain" "$app_name"
    else
      printf -- "❌ No domain entered. Skipping domain addition.\n"
    fi
  else
    printf -- "⏩ Skipping domain addition for '%s'.\n" "$app_name"
  fi
}


#############################################
# Step: Set Up Community Engine App
#############################################
setup_community_engine_app() {
  debug "Starting Community Engine setup..."

  if ! command -v dokku &>/dev/null; then
    printf -- "❌ Dokku is not installed. Skipping Community Engine setup.\n"
    return 0
  fi

  if prompt_substep "Sub-step: Set up a new Community Engine application?"; then
    printf -- "📦 Enter your app name: "
    read -r app_name

    if [ -z "$app_name" ]; then
      printf -- "❌ No app name entered. Skipping app setup.\n"
      return 0
    fi

    setup_dokku_app "$app_name"
    setup_postgis_database "$app_name"
    setup_redis "$app_name"
    report_and_add_app_domain "$app_name"
    setup_letsencrypt "$app_name"

    printf -- "🎉 Community Engine app '%s' setup is complete!\n" "$app_name"
  fi

  debug "Finished Community Engine setup."
}

#############################################
# Main Orchestration Function
#############################################
main() {
  parse_args "$@"
  printf -- "Starting setup for %s...\n\n" "$(hostname)"
  debug "Entering main function"

  # Define a combined ordered list of all steps.
  ALL_STEPS=("welcome" "specs" "network" "hardening" "backup" "tweaks" "update" "docker" "dokku" "cloudflared" "nordvpn" "hostname" "storage" "community_engine")
  
  if [ -n "$RUN_STEP" ]; then
    debug "RUN_STEP is set to: %s" "$RUN_STEP"
    start_index=-1
    debug "Searching for step '%s' in list: %s" "$RUN_STEP" "${ALL_STEPS[*]}"
    
    # Find the index for the requested step.
    for i in "${!ALL_STEPS[@]}"; do
      debug "Checking index %s: %s" "$i" "${ALL_STEPS[$i]}"
      if [ "${ALL_STEPS[$i]}" = "$RUN_STEP" ]; then
        start_index=$i
        debug "Found step '%s' at index %s" "$RUN_STEP" "$i"
        break
      fi
    done

    if [ $start_index -eq -1 ]; then
      debug "No matching step found for '%s'" "$RUN_STEP"
      printf -- "Unknown step: %s\n" "$RUN_STEP"
      exit 1
    fi

    debug "Starting to process steps from index %s to %s" "$start_index" "$((${#ALL_STEPS[@]} - 1))"
    
    # Loop over the steps from the chosen starting step.
    for i in $(seq $start_index $((${#ALL_STEPS[@]} - 1))); do
      debug "Executing step: %s (index %s)" "${ALL_STEPS[$i]}" "$i"
      case "${ALL_STEPS[$i]}" in
        welcome) step_welcome ;;
        specs) step_check_specs ;;
        network) configure_network ;;
        hardening) security_hardening ;;
        backup) backup_config ;;
        tweaks) hardware_tweaks ;;
        update) update_system ;;
        docker) install_docker ;;
        dokku) install_dokku ;;
        cloudflared) install_cloudflared ;;
        nordvpn) configure_nordvpn ;;
        hostname) configure_hostname ;;
        storage) configure_storage ;;
        community_engine) setup_community_engine_app ;;
      esac

      debug "Finished executing step: %s (index %s)" "${ALL_STEPS[$i]}" "$i"

      # If there is a next step, prompt the user whether to continue.
      if [ $i -lt $((${#ALL_STEPS[@]} - 1)) ]; then
        debug "Prompting user to continue with next step: %s" "${ALL_STEPS[$((i+1))]}"
        printf -- "Press Enter to continue with the next step (%s), or type n/no to exit: " "${ALL_STEPS[$((i+1))]}"
        read -r next_choice
        debug "User response for continuing: %s" "$next_choice"

        if [ "$next_choice" = "n" ] || [ "$next_choice" = "no" ]; then
          debug "User chose not to continue further. Exiting."
          exit 0
        else
          debug "User chose to continue with the next step."
        fi
      fi
    done

    debug "Completed all requested steps."
    exit 0
  fi

  # Run all steps sequentially if no specific step is given.
  for step in "${ALL_STEPS[@]}"; do
    debug "Executing step: %s" "$step"
    case "$step" in
      welcome) step_welcome ;;
      specs) step_check_specs ;;
      network) configure_network ;;
      hardening) security_hardening ;;
      backup) backup_config ;;
      tweaks) hardware_tweaks ;;
      update) update_system ;;
      docker) install_docker ;;
      dokku) install_dokku ;;
      cloudflared) install_cloudflared ;;
      nordvpn) configure_nordvpn ;;
      hostname) configure_hostname ;;
      storage) configure_storage ;;
      community_engine) setup_community_engine_app ;;
    esac
    prompt_continue "$step" "Press Enter to continue."
  done

  printf -- "\n#############################################\n"
  printf -- "# 🎉 All done! Your system is now ready!   #\n"
  printf -- "#############################################\n"
  debug "Exiting main function"
}


#############################################
# New Step: Security Hardening
#############################################
#############################################
# Function: Prompt for Sub-Step Execution
#############################################
prompt_substep() {
  local sub_message="$1"
  printf -- "\n%s\n" "$sub_message"
  printf -- "Press Enter to run this sub-step, type skip to skip it, n/no to exit, h for overall help, or s to repeat this help: "
  read -r sub_choice
  case "$sub_choice" in
    n|no)
      debug "User chose to exit during sub-step prompt."
      exit 0
      ;;
    h|help)
      usage
      ;;
    s|step)
      printf -- "%s\n" "$sub_message"
      prompt_substep "$sub_message"
      return $?  # Pass along the result.
      ;;
    skip)
      return 1  # Indicate that the sub-step should be skipped.
      ;;
    *) 
      return 0  # Default: execute the sub-step.
      ;;
  esac
}

#############################################
# New Step: Security Hardening
#############################################
security_hardening() {
  debug "Starting security hardening"
  printf -- "\nApplying security hardening measures...\n"

  # Sub-step 1: Disable Unused Services
  if prompt_substep "Sub-step 1: Disable unused services (Placeholder: disabling example-service)"; then
    printf -- "Disabling unused services...\n"
    # Replace with actual command(s), e.g.:
    # systemctl disable example-service
    sleep 1
    printf -- "Unused services disabled. (Placeholder)\n\n"
  else
    printf -- "Skipping disabling unused services.\n\n"
  fi

  # Sub-step 2: Harden SSH Configuration
  if prompt_substep "Sub-step 2: Harden SSH configuration (Placeholder: modifying /etc/ssh/sshd_config)"; then
    printf -- "Hardening SSH configuration...\n"
    # Example commands to harden SSH:
    sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart ssh
    sleep 1
    printf -- "SSH configuration hardened. (Placeholder)\n\n"
  else
    printf -- "Skipping SSH hardening.\n\n"
  fi

  # Sub-step 3: Configure Firewall (UFW)
  if prompt_substep "Sub-step 3: Configure UFW firewall (Placeholder: enabling UFW and setting default rules)"; then
    printf -- "Configuring UFW firewall...\n"
    apt-get install ufw -y
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow http
    ufw allow https
    ufw limit ssh
    ufw enable
    sleep 1
    printf -- "UFW firewall configured. (Placeholder)\n\n"
  else
    printf -- "Skipping UFW firewall configuration.\n\n"
  fi

  # Sub-step 4: Setup Fail2Ban
  if prompt_substep "Sub-step 4: Setup Fail2Ban (Placeholder: installing and configuring Fail2Ban)"; then
    printf -- "Setting up Fail2Ban...\n"
    apt-get install fail2ban -y
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    systemctl restart fail2ban
    sleep 1
    printf -- "Fail2Ban setup complete. (Placeholder)\n\n"
  else
    printf -- "Skipping Fail2Ban setup.\n\n"
  fi
  
  # Sub-step 5: Setup Unattended Upgrades
  if prompt_substep "Sub-step 5: Setup Unattended Upgrades\nThis will install unattended-upgrades and enable automatic updates." ; then
    printf -- "Installing unattended-upgrades...\n"
    apt-get install unattended-upgrades -y
    printf -- "Enabling unattended-upgrades...\n"
    dpkg-reconfigure --priority=low unattended-upgrades
    sleep 1
    printf -- "Unattended upgrades configured. (Placeholder)\n\n"
  else
    printf -- "Skipping unattended upgrades configuration.\n\n"
  fi

  debug "Finished security hardening"
  prompt_continue "Security Hardening" "Press Enter to continue after security hardening."
}

#############################################
# New Step: Backup Configuration
#############################################
backup_config() {
  debug "Starting backup configuration"
  printf -- "Configuring backup settings...\n"
  
  # Sub-step 1: Install BorgBackup
  if prompt_substep "Sub-step 1: Install BorgBackup\nThis will install BorgBackup using: sudo apt-get install borgbackup -y"; then
    printf -- "Installing BorgBackup...\n"
    apt-get install borgbackup -y
    sleep 1
    printf -- "BorgBackup installed.\n\n"
  else
    printf -- "Skipping BorgBackup installation.\n\n"
  fi

  printf -- "Backup configuration complete. (Placeholder)\n"
  debug "Finished backup configuration"
  prompt_continue "Backup Configuration" "Press Enter to continue after backup configuration."
}

#############################################
# Run the Script
#############################################
main "$@"
