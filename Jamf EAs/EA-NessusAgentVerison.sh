#!/bin/sh
#
# Jamf Extension Attribute Configuration below in comments. 
#
# Display Name
# -> [Security] - Nessus Agent Version 
#
# Description
# -> This EA will signal if the Nessus agent status whether its running or stopped. 
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
 echo "<result>N/A</result>"
else 
 nessusAgentVersion="$(/Library/NessusAgent/run/sbin/nessuscli -v | awk 'NR==1{print$4" "$5 $6}')"
 echo "<result>$NessusAgentVersion</result>"
fi