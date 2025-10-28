#!/bin/bash
#
# Created by Juan Garcia
#
# v1.0
# 
# Nessus Agent: download DMG, install, link, clean up
# - Downloads the latest Nessus Agent DMG to /Applications/Nessus
# - Mounts and installs directly from the mounted volume (avoids missing resource errors)
# - Uses -allowUntrusted optionally to bypass trust failures
# - Links agent using Jamf parameters (or defaults)
# - Starts LaunchDaemon and verifies status
# - Cleans up all working files (DMG + /Applications/Nessus folder) after success

set -euo pipefail

# -------------------------
# Config (defaults + Jamf params)
# -------------------------
INSTALL_DIR="/Applications/Nessus"                  # Working directory for DMG
DMG_FILE="${INSTALL_DIR}/NessusAgent-latest.dmg"    # We will download here
MOUNT_POINT="/Volumes/Nessus Agent Install"         # Fixed mount point
NESSUS_AGENT_PATH="/Library/NessusAgent/run/sbin/nessuscli"
DAEMON_PLIST="/Library/LaunchDaemons/com.tenablesecurity.nessusagent.plist"
LOG_FILE="/var/log/nessus_install.log"

# Tenable sometimes ships a hidden .NessusAgent.pkg; we will discover dynamically
NESSUS_PKG_DEFAULT="Install Nessus Agent.pkg"

# Jamf Parameters
LINK_KEY="$4"
GROUPS="$5"
# If you want to use the host and port uncomment line 34 & 35 and scroll down to line 150 and use that line and remove line 151
#HOST="$6"
#PORT="$7"

# Toggle to pass -allowUntrusted to installer (1 = on)
ALLOW_UNTRUSTED="${ALLOW_UNTRUSTED:-1}"

# Tenable download URL (latest macOS agent)
DMG_URL="https://www.tenable.com/downloads/api/v2/pages/nessus-agents/files/NessusAgent-latest.dmg"

# -------------------------
# Helpers
# -------------------------
log() { echo "$(date '+%F %T') $*" | sudo tee -a "$LOG_FILE"; }

require_root() {
if [[ $EUID -ne 0 ]];
    then
        echo "Please run as root (sudo)." | sudo tee -a "$LOG_FILE"
exit 1
  fi
}

ensure_dirs() {
    sudo mkdir -p "$INSTALL_DIR"
}

download_dmg() {
  log "⬇️  Downloading Nessus Agent DMG to $DMG_FILE..."
  /usr/bin/curl -fL -o "$DMG_FILE" "$DMG_URL"
  if [[ ! -s "$DMG_FILE" ]]; then
    log "❌ DMG not found or empty at $DMG_FILE"
    exit 1
  fi
  # Clear quarantine if present
  if /usr/bin/xattr -p com.apple.quarantine "$DMG_FILE" >/dev/null 2>&1; then
    log "🧹 Clearing quarantine attribute on DMG..."
    /usr/bin/xattr -dr com.apple.quarantine "$DMG_FILE" || true
  fi
}

mount_dmg() {
  log "💿 Mounting $DMG_FILE at $MOUNT_POINT..."
  # Clean any stale mount first
  if /sbin/mount | /usr/bin/grep -q "$MOUNT_POINT"; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
    /bin/sleep 1
  fi
  /usr/bin/hdiutil attach "$DMG_FILE" -nobrowse -quiet -mountpoint "$MOUNT_POINT" || {
    log "❌ Failed to mount $DMG_FILE at $MOUNT_POINT"
    exit 1
  }
  log "$DMG_FILE mounted successfully."
}

find_pkg_on_volume() {
  # Discover the actual pkg inside the mounted volume
  # (Fix: use command substitution $(...) not arithmetic expansion $((...)))
  PKG_ON_VOL="$(/usr/bin/find "$MOUNT_POINT" -maxdepth 2 -type f \
    \( -name ".NessusAgent.pkg" -o -name "Install Nessus Agent.pkg" -o -name "Tenable Nessus Agent.pkg" -o -name "*.pkg" \) \
    -print | /usr/bin/head -1)"

  if [[ -z "${PKG_ON_VOL}" ]]; then
    # Helpful debug if nothing matched
    log "No pkg auto-discovered. Listing contents of $MOUNT_POINT:"
    /bin/ls -la "$MOUNT_POINT" | sudo tee -a "$LOG_FILE" || true
    PKG_ON_VOL="$MOUNT_POINT/$NESSUS_PKG_DEFAULT"
  fi

  if [[ ! -f "${PKG_ON_VOL}" ]]; then
    log "❌ Could not locate an installer pkg inside $MOUNT_POINT"
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
    exit 1
  fi
  log "📦 Using package: ${PKG_ON_VOL}"
}

install_pkg() {
  log "⚙️  Installing Nessus Agent from mounted volume..."
  if [[ "$ALLOW_UNTRUSTED" == "1" ]]; then
    /usr/sbin/installer -allowUntrusted -pkg "${PKG_ON_VOL}" -target / 2>&1 | sudo tee -a "$LOG_FILE"
  else
    /usr/sbin/installer -pkg "${PKG_ON_VOL}" -target / 2>&1 | sudo tee -a "$LOG_FILE"
  fi
  INSTALL_RC=${PIPESTATUS[0]}
  if [[ $INSTALL_RC -ne 0 ]]; then
    log "❌ Installer exited with code $INSTALL_RC"
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
    exit $INSTALL_RC
  fi
  log "Nessus Agent installed successfully."
}

unmount_dmg() {
  log "⏏️  Unmounting $MOUNT_POINT..."
  /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
}

ensure_cli() {
  if [[ ! -x "$NESSUS_AGENT_PATH" ]]; then
    log "❌ Nessus Agent CLI not found at $NESSUS_AGENT_PATH. Please check the installation."
    exit 1
  fi
  log "Nessus Agent CLI found. Proceeding to link the agent."
}

link_agent() {
  # Unlink first if already linked
  if "$NESSUS_AGENT_PATH" agent status 2>/dev/null | /usr/bin/grep -qi "Linked to"; then
    log "Agent appears linked; unlinking first..."
    "$NESSUS_AGENT_PATH" agent unlink 2>/dev/null | sudo tee -a "$LOG_FILE" || true
    /bin/sleep 2
  fi

  log "Linking Nessus Agent to management server..."

  # In order for agents to link appropriately to the correct group the group optional command needs to be at the end of the agent link command ... Line 151 is for cloud host utilizations. 
  #sudo "$NESSUS_AGENT_PATH" agent link --key="$LINK_KEY" --host="$HOST" --port="$PORT" --groups="$GROUPS" | sudo tee -a "$LOG_FILE"
  sudo "$NESSUS_AGENT_PATH" agent link --key="$LINK_KEY" --cloud --groups="$GROUPS" | sudo tee -a "$LOG_FILE"
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    log "❌ Failed to link Nessus Agent."
    exit 1
  fi
  log "Nessus Agent link command sent successfully."
}

start_daemon() {
  if [[ -f "$DAEMON_PLIST" ]]; then
    /bin/chmod 0644 "$DAEMON_PLIST" || true
    /bin/launchctl load -w "$DAEMON_PLIST" 2>/dev/null || true
    /bin/launchctl kickstart -k system/com.tenablesecurity.nessusagent 2>/dev/null || true
  fi
}

verify_running() {
  /bin/sleep 5
  if "$NESSUS_AGENT_PATH" agent status 2>/dev/null | /usr/bin/grep -qi "Linked to"; then
    log "🎉 Nessus Agent is installed and linked."
  else
    log "⚠️  Agent installed, but link status not yet confirmed (may take a minute)."
  fi
}

cleanup() {
  log "🧽 Cleaning up working files..."
  # Unmount if still mounted, then remove DMG and folder
  if /sbin/mount | /usr/bin/grep -q "$MOUNT_POINT"; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  /bin/rm -f "$DMG_FILE" 2>/dev/null || true
  /bin/rm -rf "$INSTALL_DIR" 2>/dev/null || true
  log "Cleanup complete."
}

main() {
  require_root
  echo "Starting Nessus Agent installation and configuration." | sudo tee "$LOG_FILE"

  if [[ -z "$LINK_KEY" ]]; then
    log "Activation key (Param4) is required."
    exit 1
  fi

  ensure_dirs
  download_dmg
  mount_dmg
  find_pkg_on_volume
  install_pkg
  unmount_dmg
  ensure_cli
  link_agent
  start_daemon
  verify_running
  cleanup

  log "Installation and configuration script completed."
  exit 0
}

main "$@"
