#!/bin/bash

# Deregister / Uninstall FortiClient, Uninstall Bitdefender, remove /opt/trimblesw, Uninstall CrashPlan, Delete certs, change helpdesk_local password, and log actions

LOG_FILE2="/var/log/maverickrem.log"
#TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S") #  Timestamp now inside logme
RECIPIENT="adrian_budimir@trimble.com"
SUBJECT="Maverick Rem Log"

logme() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  MESSAGE="$1"
  HOSTNAME=$(hostname)

  # Prepare JSON data
  LOG_DATA=$(jq -n \
    --arg timestamp "$TIMESTAMP" \
    --arg message "$MESSAGE" \
    --arg hostname "$HOSTNAME" \
    '{timestamp: $timestamp, message: $message, hostname: $hostname}')

  # Send data to the Google Apps Script Web App
  WEB_APP_URL="https://script.google.com/a/macros/trimble.com/s/AKfycby6JCwob6RTV5DxgoajnBWb25XeJPTZ3v16SKd5GQYZKaYuOOf16c-1f0y4fxmYQKhx/exec"  # Your provided Web App URL

  curl -X POST \
    -H "Content-Type: application/json" \
    -d "$LOG_DATA" \
    "$WEB_APP_URL"

  if [ $? -ne 0 ]; then
    echo "Failed to send log entry to Google Sheets via Webhook." >&2
    #  Consider what to do if sending to Google Sheets fails.
    #  You might want to log this error to the local file.
    echo "$TIMESTAMP: ERROR: Failed to send log entry to Google Sheets via Webhook." >> "$LOG_FILE2"
  else
    echo "Log entry sent to Google Sheets via Webhook."
  fi

  #  Write to local log (as before)
  echo "$TIMESTAMP: $MESSAGE" >> "$LOG_FILE2"
  echo "$TIMESTAMP: $MESSAGE"   # Also print to console
}

# Install curl (if not already installed)
logme "Checking and installing curl..."
if ! command -v curl &> /dev/null; then
  if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y curl
    if [ $? -eq 0 ]; then
      logme "curl installed successfully."
    else
      logme "Failed to install curl."
      exit 1 # Exit if installation fails
    fi
  else
    logme "Package manager (apt-get) not found. Cannot install curl."
    exit 1 # Exit if no package manager found
  fi
else
    logme "curl already installed."
fi

# Install jq (if not already installed)
logme "Checking and installing jq..."
if ! command -v jq &> /dev/null; then
  if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y jq
    if [ $? -eq 0 ]; then
      logme "jq installed successfully."
    else
      logme "Failed to install jq."
      exit 1 # Exit if installation fails
    fi
  else
    logme "Package manager (apt-get) not found. Cannot install jq."
    exit 1 # Exit if no package manager found
  fi
else
    logme "jq already installed."
fi

# Gather System Information
HOSTNAME=$(hostname)
VENDOR=$(sudo dmidecode -s system-manufacturer)
SERIAL=$(sudo dmidecode -s system-serial-number)

# Log System Information
logme "Hostname: $HOSTNAME"
logme "Vendor: $VENDOR"
logme "Serial Number: $SERIAL"

# Uninstall Crowdstrike
if command -v /opt/crowdstrike/falconctl &> /dev/null; then
  logme "Crowdstrike Falcon detected. Uninstalling..."
  sudo apt remove falcon-sensor -y
  if [ $? -eq 0 ]; then
    logme "Crowdstrike Falcon uninstalled successfully."
  else
    logme "Crowdstrike Falcon uninstallation failed."
  fi
elif command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet falcon-sensor; then
        logme "Crowdstrike Falcon service active. Attempting systemctl stop and uninstall."
        sudo systemctl stop falcon-sensor
        if [ $? -eq 0 ]; then
          sudo /opt/crowdstrike/falconctl --uninstall --remove-sensor
          if [ $? -eq 0 ]; then
            logme "Crowdstrike Falcon uninstalled successfully after systemctl stop."
          else
            logme "Crowdstrike Falcon uninstallation failed after systemctl stop."
          fi
        else
          logme "Failed to stop falcon-sensor service."
        fi
    else
        logme "Crowdstrike Falcon service not active. Attempting direct uninstall."
        sudo apt-get purge falcon-sensor
        if [ $? -eq 0 ]; then
            logme "Crowdstrike Falcon uninstalled successfully."
        else
            logme "Crowdstrike Falcon uninstallation failed."
        fi
    fi
else
  logme "Crowdstrike Falcon not found or falconctl not accessible. Skipping uninstallation."
fi

# Deregister FortiClient
if command -v /opt/forticlient/epctrl &> /dev/null; then
  sudo /opt/forticlient/epctrl -u
  logme "FortiClient deregistered."

  # Purge FortiClient
  if command -v apt-get &> /dev/null; then
    sudo apt-get purge -y forticlient*
    if [ $? -eq 0 ]; then
      logme "FortiClient purged."
      # Delete FortiClient repo file
      for file in /etc/apt/sources.list.d/repo.forticlien*; do
        if [ -f "$file" ]; then
          sudo rm "$file"
          if [ $? -eq 0 ]; then
            logme "FortiClient repo file deleted."
          else
            logme "Failed to delete FortiClient repo file."
          fi
        else
          logme "FortiClient repo file $file not found."
        fi
      done

    else
      logme "Failed to purge FortiClient."
    fi
  else
    logme "apt-get not found. Skipping purge."
  fi

else
  logme "FortiClient not found. Skipping deregistration and purge."
fi

# Remove Bitdefender GravityZone
if [ -f "/opt/bitdefender-security-tools/bin/uninstall" ]; then
  sudo /opt/bitdefender-security-tools/bin/uninstall
  if [ $? -eq 0 ]; then
    logme "Bitdefender GravityZone uninstalled via script."
  else
    logme "Uninstall Failed or does not exist, Bitdefender GravityZone via script."
  fi
elif command -v apt-get &> /dev/null; then
    sudo apt-get purge -y bitdefender-security-tools
    if [ $? -eq 0 ]; then
      logme "Bitdefender GravityZone purged via apt."
    else
      logme "Failed to purge Bitdefender GravityZone via apt."
    fi
  else
    logme "Bitdefender GravityZone uninstall script and apt-get not found. Skipping Bitdefender removal."
  fi

# Remove /opt/trimblesw
if [ -d "/opt/trimblesw" ]; then
  sudo rm -rf /opt/trimblesw
  if [ $? -eq 0 ]; then
    logme "/opt/trimblesw removed."
  else
    logme "Failed to remove /opt/trimblesw."
  fi
else
  logme "/opt/trimblesw directory not found. Skipping removal."
fi

# Delete Certificates
CERTIFICATES="/etc/ssl/certs/Trimble-CA2.pem /etc/ssl/certs/Trimble-CA3.pem /etc/ssl/certs/Trimble-CA.pem /etc/ssl/certs/Trimble-CAs.pem /etc/ssl/certs/Trimble-SCCM-CA.pem"

for cert in $CERTIFICATES; do
    if [ -f "$cert" ]; then
        sudo rm "$cert"
        if [ $? -eq 0 ]; then
            logme "Certificate $cert deleted."
        else
            logme "Failed to delete certificate $cert."
        fi
    else
        logme "Certificate $cert not found. Skipping deletion."
    fi
done

# Removing Crashplan
if [ -d "/usr/local/crashplan" ]; then
  logme "CrashPlan found in /usr/local/crashplan. Downloading and running uninstaller."

  # Download the uninstaller
  wget https://raw.githubusercontent.com/AdrianBudimir/detr/refs/heads/main/uninstallcp.sh -O uninstallcp.sh
  if [ $? -eq 0 ]; then
    logme "CrashPlan uninstaller downloaded successfully."
    # Make the script executable
    chmod +x uninstallcp.sh
    if [ $? -eq 0 ]; then
       logme "Crashplan uninstaller made executable"
       # Run the uninstaller
       sudo ./uninstallcp.sh -i /usr/local/crashplan -y
       if [ $? -eq 0 ]; then
          logme "CrashPlan uninstalled successfully."
       else
          logme "CrashPlan uninstallation failed."
       fi
    else
       logme "Failed to make Crashplan uninstaller executable"
    fi
  else
    logme "Failed to download CrashPlan uninstaller."
  fi
else
    logme "CrashPlan not found in /usr/local/crashplan. Skipping uninstallation."
fi

# Change helpdesk_local password
if getent passwd helpdesk_local &> /dev/null; then
  logme "Changing helpdesk_local password..."
  sudo bash -c "echo 'helpdesk_local:byebyetrimble' | chpasswd"
  if [ $? -eq 0 ]; then
    logme "helpdesk_local password changed successfully."
  else
    logme "Failed to change helpdesk_local password."
  fi

else
  logme "helpdesk_local user not found. Skipping password change."
fi

# Install JumpCloud
logme "Installing JumpCloud..."
curl --tlsv1.2 --silent --show-error --header 'x-connect-key: 54038b4423e41d5b9641ce4eaec83c837e775e99' https://kickstart.jumpcloud.com/Kickstart | sudo bash
if [ $? -eq 0 ]; then
  logme "JumpCloud installed successfully."
else
  logme "JumpCloud installation failed."
fi

exit 0
