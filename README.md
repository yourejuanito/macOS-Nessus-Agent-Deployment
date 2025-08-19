# Nessus Agent for macOS – Install & Uninstall Scripts

This repository contains **two shell scripts** for deploying and removing [Tenable’s Nessus Agent](https://www.tenable.com/products/nessus) on macOS endpoints.

## Scripts

### 1. `nessus-install-script.sh`
Automates the full installation and configuration of the Nessus Agent:
- Downloads the latest DMG from Tenable.
- Mounts the DMG and installs the `.pkg` (with optional `-allowUntrusted`).
- Links the agent to a Nessus Manager or Tenable.io using your license key, host, port, and groups.
- Starts the LaunchDaemon and verifies the agent’s status.
- Cleans up all temporary files after installation.

### 2. `nessus-uninstall.sh`
Safely removes the Nessus Agent from macOS:
- Stops and unloads the Nessus Agent LaunchDaemon.
- Optionally unlinks the agent from the manager.
- Removes all Nessus Agent files, plist, and PreferencePane.
- Forgets related package receipts.
- Cleans up installer folders.

---

## Requirements
- Admin/root privileges.
- Outbound network access to your Nessus Manager or Tenable.io.
- License key and configuration details for linking.

---

## Jamf Pro Deployment

### Install Script – Parameter Mapping
| Parameter # | Description | Example |
|-------------|-------------|---------|
| 4           | License Key | `1234567890ABCDEF1234567890ABCDEF` |
| 5           | Groups      | `Mac - Endpoints` |
| 6           | Host        | `sensor.cloud.tenable.com` |
| 7           | Port        | `443` |

**Jamf Policy Setup:**
1. Upload `nessus-install-script.sh` to Jamf Pro **Scripts**.
2. Add the script to a **Policy** targeting your desired Macs.
3. Pass your License Key, Group, Host, and Port via Script Parameters 4–7.
4. (Optional) Add to **Self Service** with a friendly name like “Install Nessus Agent”.

---

### Uninstall Script – Jamf Usage
The uninstall script requires no parameters.

**Jamf Policy Setup:**
1. Upload `nessus-uninstall.sh` to Jamf Pro **Scripts**.
2. Create a new Policy with an **Script** payload.
3. Optionally add it to Self Service as “Uninstall Nessus Agent” and scoping to a smart group that will look for the Nessus Agent to be installed. Alternatively, it could be scoped to the Support Team for troubleshoothing purposes. 

---