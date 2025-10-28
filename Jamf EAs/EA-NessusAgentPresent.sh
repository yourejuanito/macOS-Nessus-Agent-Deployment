#!/bin/sh
#
# Jamf Extension Attribute Configuration below in comments. 
#
# Display Name
# -> [Security] - Nessus Agent Status 
#
# Description
# -> This EA will signal if the Nessus agent is either installed or not installed. 
#
# Data Type
# -> String
# 
# Inventory Display
# -> Extension attributes
#
# Input Type
# -> Script
#
# Check to see if Nessus Agent is installed
nessusAgentInstalled="$(ls /Library/NessusAgent/run/sbin/ | grep nessuscli)"
if [ "$nessusAgentInstalled" != "nessuscli" ] 
then
 echo "<result>Not Installed</result>"
else 
 echo "<result>Installed</result>"
fi