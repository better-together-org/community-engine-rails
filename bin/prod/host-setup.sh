#!/bin/bash
set -e

# Ensure the script is run as root.
require_root() {
  if [ "$EUID" -ne 0 ]; then
    printf -- "This script must be run as root. Please run it with sudo or as the root user.\n"
    exit 1
  fi
}

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
WITH_ELASTICSEARCH=false
VERSIONS_FILE=""
DRY_RUN=false
WITH_CLOUDFLARED=false
WITH_NORDVPN=false
WITH_FLEET_BASELINE=false
FLEET_EXTENSION=""
STORAGE_BACKEND="local"
S3_ENDPOINT_ARG=""
S3_BUCKET_ARG=""
S3_REGION_ARG=""
FAIL2BAN_IGNOREIP=""
SKIP_FIREWALL=false
OS_ID=""
OS_VERSION=""
OS_CODENAME=""
DPKG_ARCH=""

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
  --versions-file=PATH     Version manifest (default: host-setup.versions next to
                           this script). Every pinned version comes from it.
  --with-cloudflared       Also install Cloudflared (off by default).
  --with-nordvpn           Also install NordVPN (off by default).
  --with-fleet-baseline    Also run the BTS fleet baseline through a sourced
                           extension; needs --fleet-extension=FILE.
  --fleet-extension=FILE   Root-owned file defining fleet_baseline_run.
  --storage-backend=NAME   local (default), garage or aws. Settings only; keys
                           are never read or stored by this script.
  --s3-endpoint=URL --s3-bucket=NAME --s3-region=NAME
                           Garage or AWS bucket settings.
  --skip-firewall          Leave the firewall alone (implied by --with-fleet-baseline,
                           whose managed profile owns it).
  --fail2ban-ignoreip=LIST Space-separated addresses fail2ban must never ban.
  --with-elasticsearch     Also install the Elasticsearch plugin. Off by default:
                           search uses Postgres (SEARCH_BACKEND=pg_search).
  --step=NAME              Run a specific step and the steps after it. Valid names:
                           welcome, specs, os_check, network, hardening, backup, tweaks,
                           update, docker, dokku, hostname, storage, community_engine;
                           optional: elasticsearch, cloudflared, nordvpn,
                           fleet_baseline.
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
      --with-cloudflared) WITH_CLOUDFLARED=true; shift ;;
      --with-nordvpn) WITH_NORDVPN=true; shift ;;
      --with-fleet-baseline) WITH_FLEET_BASELINE=true; shift ;;
      --fleet-extension=*) FLEET_EXTENSION="${1#*=}"; shift ;;
      --storage-backend=*) STORAGE_BACKEND="${1#*=}"; shift ;;
      --s3-endpoint=*) S3_ENDPOINT_ARG="${1#*=}"; shift ;;
      --s3-bucket=*) S3_BUCKET_ARG="${1#*=}"; shift ;;
      --s3-region=*) S3_REGION_ARG="${1#*=}"; shift ;;
      --skip-firewall) SKIP_FIREWALL=true; shift ;;
      --fail2ban-ignoreip=*) FAIL2BAN_IGNOREIP="${1#*=}"; shift ;;
      --versions-file=*)
        VERSIONS_FILE="${1#*=}"
        shift
        ;;
      --with-elasticsearch)
        WITH_ELASTICSEARCH=true
        debug "Elasticsearch plugin step enabled."
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
# Version manifest and OS detection
#############################################
MANIFEST_KEYS="DOKKU_TAG DOKKU_BOOTSTRAP_SHA256 DOKKU_POSTGRES_TAG DOKKU_REDIS_TAG
DOKKU_LETSENCRYPT_TAG DOKKU_ELASTICSEARCH_TAG POSTGIS_IMAGE POSTGIS_IMAGE_VERSION
REDIS_IMAGE REDIS_IMAGE_VERSION ELASTICSEARCH_IMAGE ELASTICSEARCH_IMAGE_VERSION
DOCKER_ENGINE_VERSION CLOUDFLARED_VERSION BORG_VERSION"

# Parses KEY=value lines; the file is never sourced, so it cannot run code.
load_versions() {
  local file="${VERSIONS_FILE:-$(dirname "${BASH_SOURCE[0]}")/host-setup.versions}"
  local line key value
  if [ ! -r "$file" ]; then
    printf -- "Version manifest not found: %s\n" "$file" >&2
    exit 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    if [[ ! "$line" =~ ^([A-Z0-9_]+)=([A-Za-z0-9._:/@+~-]*)$ ]]; then
      printf -- "Invalid line in %s: %s\n" "$file" "$line" >&2
      exit 1
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case " ${MANIFEST_KEYS//$'\n'/ } " in
      *" $key "*) printf -v "$key" '%s' "$value" ;;
      *) printf -- "Unknown manifest key: %s\n" "$key" >&2; exit 1 ;;
    esac
  done < "$file"
  for key in ${MANIFEST_KEYS//$'\n'/ }; do
    if [ -z "${!key:-}" ]; then
      printf -- "Manifest key %s is missing or empty in %s\n" "$key" "$file" >&2
      exit 1
    fi
  done
  debug "Loaded version manifest %s" "$file"
}

# Sets OS_ID, OS_VERSION, OS_CODENAME and DPKG_ARCH, or stops on an unsupported host.
detect_os() {
  if [ ! -r /etc/os-release ]; then
    printf -- "Cannot read /etc/os-release; unsupported host.\n" >&2
    exit 1
  fi
  OS_ID="$(. /etc/os-release && echo "${ID:-}")"
  OS_VERSION="$(. /etc/os-release && echo "${VERSION_ID:-}")"
  OS_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  DPKG_ARCH="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
  case "$DPKG_ARCH" in
    amd64|arm64) ;;
    *) printf -- "Unsupported architecture: %s (need amd64 or arm64).\n" "$DPKG_ARCH" >&2; exit 1 ;;
  esac
  case "$OS_ID:$OS_VERSION" in
    debian:12|debian:13|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04) ;;
    *) printf -- "Unsupported OS: %s %s (supported: Debian 12/13, Ubuntu 22.04/24.04/26.04).\n" "$OS_ID" "$OS_VERSION" >&2; exit 1 ;;
  esac
  debug "Detected OS %s %s (%s) on %s" "$OS_ID" "$OS_VERSION" "$OS_CODENAME" "$DPKG_ARCH"
}

step_os_check() {
  detect_os
  printf -- "OS check passed: %s %s (%s), %s.\n" "$OS_ID" "$OS_VERSION" "$OS_CODENAME" "$DPKG_ARCH"
  if [ "$OS_ID:$OS_VERSION" = "ubuntu:26.04" ]; then
    printf -- "Note: Ubuntu 26.04 is supported by Dokku; the Docker repository for it is unverified.\n"
  fi
}

#############################################
# Command helpers (a dry run prints instead of acting)
#############################################
run() {
  if [ "$DRY_RUN" = true ]; then
    printf -- "[dry-run]"
    printf -- " %q" "$@"
    printf -- "\n"
    return 0
  fi
  "$@"
}

# Writes stdin to a file with the given mode; prints it on a dry run.
write_file() {
  local path="$1" mode="${2:-0644}"
  if [ "$DRY_RUN" = true ]; then
    printf -- "[dry-run] write %s (mode %s):\n" "$path" "$mode"
    sed 's/^/    /'
    return 0
  fi
  install -m "$mode" /dev/stdin "$path"
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
  printf -- "This platform is more than technology, it's a movement dedicated to kindness,\n"
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
  printf -- "Let's create a more connected, resilient, and empowered community, together.\n\n"
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
  detect_os

  if command -v docker &>/dev/null; then
    printf -- "Docker is already installed (%s). Leaving it unchanged.\n" "$(docker --version)"
    printf -- "Engine upgrades are a guided operation; see the fleet-upgrade procedure.\n"
    return 0
  fi

  local want="${DOCKER_VERSION:-$DOCKER_ENGINE_VERSION}"
  local repo_os="$OS_ID"

  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${repo_os}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${repo_os}
Suites: ${OS_CODENAME}
Components: stable
Architectures: ${DPKG_ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update

  local pkg_version
  pkg_version="$(apt-cache madison docker-ce | awk -v v="$want" 'index($3, "5:" v "-") == 1 {print $3; exit}')"
  if [ -z "$pkg_version" ]; then
    printf -- "No docker-ce package matches version %s in the Docker repository.\n" "$want" >&2
    exit 1
  fi
  printf -- "Installing Docker Engine %s...\n" "$pkg_version"
  apt-get install -y "docker-ce=$pkg_version" "docker-ce-cli=$pkg_version" containerd.io docker-buildx-plugin docker-compose-plugin

  if [ -n "${SUDO_USER:-}" ]; then
    usermod -aG docker "$SUDO_USER"
    printf -- "Added %s to the docker group; log out and back in to use it.\n" "$SUDO_USER"
  fi
  docker run --rm hello-world
  debug "Finished Docker installation."
}

install_cloudflared() {
  debug "Starting Cloudflared installation..."
  run mkdir -p --mode=0755 /usr/share/keyrings
  run curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" |
    write_file /etc/apt/sources.list.d/cloudflared.list
  run apt-get update
  run apt-get install -y "cloudflared=${CLOUDFLARED_VERSION}"
  debug "Finished Cloudflared installation."
}

# Uses NordVPN's signed apt repository instead of piping their installer to a shell.
configure_nordvpn() {
  debug "Starting NordVPN configuration..."
  if command -v nordvpn &>/dev/null; then
    printf -- "NordVPN is already installed. Leaving it unchanged.\n"
    return 0
  fi
  run curl -fsSL https://repo.nordvpn.com/gpg/nordvpn_public.asc -o /usr/share/keyrings/nordvpn.asc
  echo "deb [signed-by=/usr/share/keyrings/nordvpn.asc] https://repo.nordvpn.com/deb/nordvpn/debian stable main" |
    write_file /etc/apt/sources.list.d/nordvpn.list
  run apt-get update
  run apt-get install -y nordvpn
  if [[ -n "$NORDVPN_LOGIN_URL" ]]; then
    run nordvpn login --callback "$NORDVPN_LOGIN_URL"
  else
    printf -- "Run 'nordvpn login' yourself to finish.\n"
  fi
  debug "Finished NordVPN configuration."
}

configure_hostname() {
  debug "Starting hostname configuration..."
  if [[ -z "$NEW_HOSTNAME" ]]; then
    printf -- "No new hostname provided. Skipping hostname configuration.\n"
    return 0
  fi
  if [[ ! "$NEW_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    printf -- "Invalid hostname: %s\n" "$NEW_HOSTNAME" >&2
    exit 1
  fi
  printf -- "Changing hostname to %s...\n" "$NEW_HOSTNAME"
  run hostnamectl set-hostname "$NEW_HOSTNAME"
  debug "Finished hostname configuration."
}

# Validates the storage choice and prepares a host directory when one is given.
configure_storage() {
  debug "Starting storage configuration..."
  case "$STORAGE_BACKEND" in
    local|garage|aws) ;;
    *) printf -- "Unknown --storage-backend: %s (use local, garage or aws).\n" "$STORAGE_BACKEND" >&2; exit 1 ;;
  esac
  printf -- "Storage backend: %s\n" "$STORAGE_BACKEND"
  if [[ -n "$STORAGE_PATH" ]]; then
    printf -- "Preparing storage path %s...\n" "$STORAGE_PATH"
    run mkdir -p "$STORAGE_PATH"
  fi
  if [ "$STORAGE_BACKEND" = "garage" ]; then
    printf -- "Garage needs a per-client bucket and key; create them with the Garage\n"
    printf -- "bucket provisioning procedure first. Keys are not handled by this script.\n"
  fi
  debug "Finished storage configuration."
}

# Applies non-secret storage settings to an app. Key pairs are set by the operator.
configure_app_storage() {
  local app_name="$1"
  case "$STORAGE_BACKEND" in
    garage|aws)
      if [ -z "$S3_BUCKET_ARG" ] || { [ "$STORAGE_BACKEND" = "garage" ] && [ -z "$S3_ENDPOINT_ARG" ]; }; then
        printf -- "Storage backend %s needs --s3-bucket (and --s3-endpoint for garage).\n" "$STORAGE_BACKEND" >&2
        exit 1
      fi
      ;;
  esac
  case "$STORAGE_BACKEND" in
    garage)
      run dokku config:set --no-restart "$app_name" \
        ACTIVE_STORAGE_SERVICE=s3_compatible ACTIVE_STORAGE_ROUTE=proxy \
        "S3_ENDPOINT=$S3_ENDPOINT_ARG" "S3_BUCKET_NAME=$S3_BUCKET_ARG" "S3_REGION=${S3_REGION_ARG:-garage}" \
        AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
      printf -- "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for %s yourself (never on a command line).\n" "$app_name"
      ;;
    aws)
      run dokku config:set --no-restart "$app_name" \
        ACTIVE_STORAGE_SERVICE=amazon ACTIVE_STORAGE_ROUTE=proxy \
        "S3_BUCKET_NAME=$S3_BUCKET_ARG" "S3_REGION=${S3_REGION_ARG:-us-east-1}"
      printf -- "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for %s yourself (never on a command line).\n" "$app_name"
      ;;
    local)
      run dokku storage:ensure-directory "$app_name/storage"
      run dokku storage:mount "$app_name" "/var/lib/dokku/data/storage/$app_name/storage:/bt/storage"
      run dokku config:set --no-restart "$app_name" ACTIVE_STORAGE_SERVICE=local
      ;;
  esac
}

# Downloads the pinned bootstrap script, verifies its checksum, then runs it.
install_dokku_bootstrap() {
  local dir script
  dir="$(mktemp -d)"
  script="$dir/bootstrap.sh"
  curl -fsSL "https://dokku.com/install/${DOKKU_TAG}/bootstrap.sh" -o "$script"
  if ! echo "${DOKKU_BOOTSTRAP_SHA256}  $script" | sha256sum -c --quiet -; then
    printf -- "Dokku bootstrap checksum mismatch; not running it.\n" >&2
    rm -rf "$dir"
    exit 1
  fi
  DOKKU_TAG="$DOKKU_TAG" bash "$script"
  rm -rf "$dir"
}

# Installs a Dokku plugin at a pinned tag; leaves an installed plugin untouched.
install_dokku_plugin() {
  local name="$1" url="$2" tag="$3"
  if dokku plugin:installed "$name" &>/dev/null; then
    printf -- "Dokku plugin %s already installed (manifest pins %s).\n" "$name" "$tag"
    return 0
  fi
  dokku plugin:install "$url" --committish "$tag" --name "$name"
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
      install_dokku_bootstrap
      
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
  if prompt_substep "Sub-step: Install Dokku Plugins?\nThis will install the Postgres, Redis and LetsEncrypt plugins. Elasticsearch is optional (--with-elasticsearch)."; then
    printf -- "🔧 Installing Dokku plugins...\n"
    
    install_dokku_plugin postgres https://github.com/dokku/dokku-postgres.git "$DOKKU_POSTGRES_TAG"
    install_dokku_plugin redis https://github.com/dokku/dokku-redis.git "$DOKKU_REDIS_TAG"
    install_dokku_plugin letsencrypt https://github.com/dokku/dokku-letsencrypt.git "$DOKKU_LETSENCRYPT_TAG"

    printf -- "✅ Dokku plugins installed successfully.\n"
  else
    printf -- "❌ Skipping Dokku plugin installation.\n"
  fi


  debug "Finished Dokku configuration."
}


#############################################
# Step: Setup Dokku App
#############################################
# AWS builds read the old AWS/FOG build args; Garage and local builds need none.
configure_build_args() {
  local app_name="$1" arg
  if [ "$STORAGE_BACKEND" != "aws" ]; then return 0; fi
  for arg in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY FOG_DIRECTORY FOG_HOST FOG_REGION ASSET_HOST CDN_DISTRIBUTION_ID; do
    run dokku docker-options:add "$app_name" build "--build-arg $arg"
  done
}

create_dokku_app() {
  local app_name="$1"
  run dokku apps:create "$app_name"
  configure_build_args "$app_name"
  configure_app_storage "$app_name"
}

setup_dokku_app() {
  local app_name="$1"

  if dokku apps:exists "$app_name"; then
    printf -- "⚠️  The Dokku app '%s' already exists. Showing details:\n" "$app_name"
    dokku apps:report "$app_name"

    if prompt_substep "Sub-step: Recreate the Dokku app '$app_name'?\nThis will delete and recreate the app and all associated configurations."; then
      dokku apps:destroy "$app_name" --force
      create_dokku_app "$app_name"
      printf -- "✅ Dokku app '%s' recreated.\n" "$app_name"
    else
      printf -- "⏩ Skipping Dokku app creation.\n"
    fi
  else
    create_dokku_app "$app_name"
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
    install_dokku_plugin postgres https://github.com/dokku/dokku-postgres.git "$DOKKU_POSTGRES_TAG"
  fi

  if dokku postgres:exists "$db_name"; then
    printf -- "⚠️  Database '%s' already exists. Showing details:\n" "$db_name"
    dokku postgres:info "$db_name"

    if prompt_substep "Sub-step: Recreate the PostGIS database '$db_name'?\nThis will delete and recreate the database."; then
      dokku postgres:destroy "$db_name" --force
      dokku postgres:create "$db_name" --image "$POSTGIS_IMAGE" --image-version "$POSTGIS_IMAGE_VERSION"
      dokku postgres:link "$db_name" "$app_name"
      printf -- "✅ PostGIS database '%s' recreated and linked.\n" "$db_name"
    else
      printf -- "⏩ Skipping database creation.\n"
    fi
  else
    dokku postgres:create "$db_name" --image "$POSTGIS_IMAGE" --image-version "$POSTGIS_IMAGE_VERSION"
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
    install_dokku_plugin redis https://github.com/dokku/dokku-redis.git "$DOKKU_REDIS_TAG"
  fi

  if dokku redis:exists "$redis_name"; then
    printf -- "⚠️  Redis instance '%s' already exists. Showing details:\n" "$redis_name"
    dokku redis:info "$redis_name"

    if prompt_substep "Sub-step: Recreate the Redis instance '$redis_name'?\nThis will delete and recreate the Redis instance."; then
      dokku redis:destroy "$redis_name" --force
      dokku redis:create "$redis_name" --image "$REDIS_IMAGE" --image-version "$REDIS_IMAGE_VERSION"
      dokku redis:link "$redis_name" "$app_name"
      printf -- "✅ Redis instance '%s' recreated and linked.\n" "$redis_name"
    else
      printf -- "⏩ Skipping Redis creation.\n"
    fi
  else
    dokku redis:create "$redis_name" --image "$REDIS_IMAGE" --image-version "$REDIS_IMAGE_VERSION"
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
    install_dokku_plugin letsencrypt https://github.com/dokku/dokku-letsencrypt.git "$DOKKU_LETSENCRYPT_TAG"
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
# Optional Step: Elasticsearch plugin
#############################################
install_elasticsearch() {
  debug "Starting install_elasticsearch"
  if ! command -v dokku &>/dev/null; then
    printf -- "Dokku is not installed. Run the dokku step first.\n"
    return 1
  fi
  if dokku plugin:installed elasticsearch &>/dev/null; then
    printf -- "Elasticsearch plugin is already installed.\n"
  else
    install_dokku_plugin elasticsearch https://github.com/dokku/dokku-elasticsearch.git "$DOKKU_ELASTICSEARCH_TAG"
  fi
  printf -- "The plugin alone changes nothing for your app. To use it you also need\n"
  printf -- "SEARCH_BACKEND=elasticsearch and the better_together-elasticsearch gem.\n"
  printf -- "The default search backend is Postgres (pg_search).\n"
  debug "Finished install_elasticsearch"
}

#############################################
# Run one step by name
#############################################
run_step() {
  case "$1" in
    welcome) step_welcome ;;
    specs) step_check_specs ;;
    os_check) step_os_check ;;
    network) configure_network ;;
    hardening) security_hardening ;;
    backup) backup_config ;;
    tweaks) hardware_tweaks ;;
    update) update_system ;;
    docker) install_docker ;;
    dokku) install_dokku ;;
    elasticsearch) install_elasticsearch ;;
    cloudflared) install_cloudflared ;;
    fleet_baseline) step_fleet_baseline ;;
    nordvpn) configure_nordvpn ;;
    hostname) configure_hostname ;;
    storage) configure_storage ;;
    community_engine) setup_community_engine_app ;;
  esac
}

#############################################
# Main Orchestration Function
#############################################
main() {
  parse_args "$@"
  require_root
  load_versions
  printf -- "Starting setup for %s...\n\n" "$(hostname)"
  debug "Entering main function"

  # Define a combined ordered list of all steps.
  # Naming the optional step explicitly implies its flag.
  case "$RUN_STEP" in
    elasticsearch) WITH_ELASTICSEARCH=true ;;
    cloudflared) WITH_CLOUDFLARED=true ;;
    nordvpn) WITH_NORDVPN=true ;;
    fleet_baseline) WITH_FLEET_BASELINE=true ;;
  esac
  ALL_STEPS=("welcome" "specs" "os_check" "network" "hardening" "backup" "tweaks" "update" "docker" "dokku")
  if [ "$WITH_ELASTICSEARCH" = true ]; then ALL_STEPS+=("elasticsearch"); fi
  ALL_STEPS+=("hostname" "storage" "community_engine")
  if [ "$WITH_CLOUDFLARED" = true ]; then ALL_STEPS+=("cloudflared"); fi
  if [ "$WITH_NORDVPN" = true ]; then ALL_STEPS+=("nordvpn"); fi
  if [ "$WITH_FLEET_BASELINE" = true ]; then ALL_STEPS+=("fleet_baseline"); fi
  
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
      run_step "${ALL_STEPS[$i]}"

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
    run_step "$step"
    prompt_continue "$step" "Press Enter to continue."
  done

  printf -- "\n#############################################\n"
  printf -- "# 🎉 All done! Your system is now ready!   #\n"
  printf -- "#############################################\n"
  debug "Exiting main function"
}


#############################################
# Optional Step: BTS fleet baseline (sourced extension)
#############################################
step_fleet_baseline() {
  local ext="$FLEET_EXTENSION" owner mode
  if [ -z "$ext" ] || [ ! -f "$ext" ]; then
    printf -- "--fleet-extension=FILE is required for the fleet_baseline step.\n" >&2
    exit 1
  fi
  read -r owner mode < <(stat -c '%u %a' "$ext")
  if [ "$owner" != "0" ] || [ $((8#$mode & 8#022)) -ne 0 ]; then
    printf -- "Refusing %s: it is sourced as root, so it must be root-owned and not group or world writable.\n" "$ext" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$ext"
  if ! declare -F fleet_baseline_run >/dev/null; then
    printf -- "%s does not define fleet_baseline_run.\n" "$ext" >&2
    exit 1
  fi
  DRY_RUN="$DRY_RUN" fleet_baseline_run
}

#############################################
# Step: Security hardening
#############################################
prompt_substep() {
  local sub_message="$1"
  printf -- "\n%s\n" "$sub_message"
  printf -- "Press Enter to run this sub-step, type skip to skip it, n/no to exit, h for overall help, or s to repeat this help: "
  read -r sub_choice
  case "$sub_choice" in
    n|no) debug "User chose to exit during sub-step prompt."; exit 0 ;;
    h|help) usage ;;
    s|step) printf -- "%s\n" "$sub_message"; prompt_substep "$sub_message"; return $? ;;
    skip) return 1 ;;
    *) return 0 ;;
  esac
}

# True when the invoking user (or root) has at least one authorized ssh key.
ssh_keys_present() {
  local home
  home="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
  [ -s "$home/.ssh/authorized_keys" ] || [ -s /root/.ssh/authorized_keys ]
}

harden_ssh() {
  if ! ssh_keys_present; then
    printf -- "No authorized ssh keys found for %s or root; not disabling password login.\n" "${SUDO_USER:-root}" >&2
    return 1
  fi
  run mkdir -p /etc/ssh/sshd_config.d
  write_file /etc/ssh/sshd_config.d/90-ce-hardening.conf 0644 <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
  if [ "$DRY_RUN" != true ]; then
    if ! sshd -t; then
      rm -f /etc/ssh/sshd_config.d/90-ce-hardening.conf
      printf -- "sshd rejected the hardening file; removed it.\n" >&2
      return 1
    fi
  fi
  run systemctl reload ssh
}

setup_firewall() {
  run apt-get install -y ufw
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw allow 22/tcp
  run ufw allow 80/tcp
  run ufw allow 443/tcp
  run ufw --force enable
  printf -- "Note: ports published by Docker bypass ufw; Dokku proxies through nginx on 80/443.\n"
}

setup_fail2ban() {
  run apt-get install -y fail2ban
  {
    printf -- "[sshd]\nenabled = true\nbackend = systemd\nmaxretry = 5\nbantime = 1h\n"
    if [ -n "$FAIL2BAN_IGNOREIP" ]; then
      printf -- "ignoreip = 127.0.0.1/8 ::1 %s\n" "$FAIL2BAN_IGNOREIP"
    fi
  } | write_file /etc/fail2ban/jail.d/ce-sshd.local
  run systemctl enable --now fail2ban
  run systemctl restart fail2ban
}

setup_unattended_upgrades() {
  run apt-get install -y unattended-upgrades
  write_file /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  printf -- "Distribution defaults apply: security origins only; Docker and Dokku stay manual.\n"
}

security_hardening() {
  debug "Starting security hardening"
  if [ "$SKIP_FIREWALL" = true ] || [ "$WITH_FLEET_BASELINE" = true ]; then
    printf -- "Skipping the ufw sub-step (--skip-firewall or fleet baseline owns the firewall).\n"
  elif prompt_substep "Sub-step 1: Firewall (ufw)\nDefault deny incoming; allow ssh, http, https; then enable."; then
    setup_firewall
  fi
  if prompt_substep "Sub-step 2: ssh key-only login\nOnly applied when an authorized key exists; the config is validated before reload."; then
    harden_ssh || true
  fi
  if prompt_substep "Sub-step 3: fail2ban for ssh"; then
    setup_fail2ban
  fi
  if prompt_substep "Sub-step 4: unattended security upgrades"; then
    setup_unattended_upgrades
  fi
  debug "Finished security hardening"
}

backup_config() {
  debug "Starting backup configuration"
  if prompt_substep "Sub-step: Install the BorgBackup client\nNo repository or schedule is configured; the fleet layer or you do that."; then
    run apt-get install -y borgbackup
    if [ "$DRY_RUN" != true ]; then
      printf -- "BorgBackup installed: %s (manifest reference %s).\n" "$(borg --version 2>/dev/null || echo unknown)" "$BORG_VERSION"
    fi
  fi
  debug "Finished backup configuration"
}

# Run only when executed, so tests can source the functions.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
