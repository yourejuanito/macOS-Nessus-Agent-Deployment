#!/bin/bash
# Nessus Agent: Uninstall Script (Adam-style companion)
# - Stops and unloads Nessus Agent LaunchDaemon
# - Unlinks from manager (if possible)
# - Removes Nessus Agent files, plist, and PreferencePane
# - Forgets package receipts
# - Cleans up logs and installer folder

set -euo pipefail

LOG_FILE="/var/log/nessus_uninstall.log"
DAEMON_LABEL="com.tenablesecurity.nessusagent"
DAEMON_PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
NESSUS_AGENT_DIR="/Library/NessusAgent"
PREFPANE="/Library/PreferencePanes/Nessus Agent Preferences.prefPane"
NESSUS_CLI="${NESSUS_AGENT_DIR}/run/sbin/nessuscli"
INSTALLER_DIR="/Applications/Nessus"

log() { echo "$(date '+%F %T') $*" | sudo tee -a "$LOG_FILE"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root (sudo)." | sudo tee -a "$LOG_FILE"
    exit 1
  fi
}

stop_service() {
  log "🛑 Stopping Nessus Agent service..."
  if launchctl print system/"$DAEMON_LABEL" >/dev/null 2>&1; then
    launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
  fi
  /bin/launchctl unload -w "$DAEMON_PLIST" 2>/dev/null || true
  launchctl remove "$DAEMON_LABEL" 2>/dev/null || true
}

unlink_agent() {
  if [[ -x "$NESSUS_CLI" ]]; then
    log "🔗 Unlinking Nessus Agent from manager..."
    "$NESSUS_CLI" agent unlink 2>&1 | sudo tee -a "$LOG_FILE" || true
  else
    log "⚠️ Nessus CLI not found; skipping unlink."
  fi
}

remove_files() {
  log "🧹 Removing Nessus Agent files..."
  rm -rf "$NESSUS_AGENT_DIR" 2>/dev/null || true
  rm -f "$DAEMON_PLIST" 2>/dev/null || true
  rm -rf "$PREFPANE" 2>/dev/null || true
  rm -rf "$INSTALLER_DIR" 2>/dev/null || true
}

forget_pkgs() {
  log "📦 Forgetting Nessus/Tenable pkg receipts..."
  pkgutil --pkgs | grep -iE 'tenable|nessus' | while read -r PKGID; do
    log "  -> Forgetting $PKGID"
    pkgutil --forget "$PKGID" >/dev/null 2>&1 || true
  done
}

verify_removal() {
  if [[ -d "$NESSUS_AGENT_DIR" ]] || [[ -f "$DAEMON_PLIST" ]] || [[ -d "$PREFPANE" ]]; then
    log "⚠️ Some Nessus components remain. You may need to remove them manually."
  else
    log "✅ Nessus Agent removed."
  fi
}

main() {
  require_root
  echo "Starting Nessus Agent uninstall..." | sudo tee "$LOG_FILE"

  stop_service
  unlink_agent
  remove_files
  forget_pkgs
  verify_removal

  log "Uninstall completed."
  exit 0
}

main "$@"
