# Jamf Extension Attribute Configuration below in comments. 
#
# Display Name
# -> [Security] - Nessus Agent Status 
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
# Check to see if Nessus Agent is running
nessusAgentRunning="$(sudo launchctl list com.tenablesecurity.nessusagent | grep "PID" | awk '{ print $1 }' | tr -d '"')"
if [ "$nessusAgentRunning" = "PID" ]
then
 echo "<result>Running</result>"
else
 echo "<result>Stopped</result>"
fi