# router-use-case
Below are detailed step-by-step instructions to set up and use the tools provided in the enhanced router_device_manager.sh script on an OpenWrt router. This includes installing the script, setting up the optional web interface, configuring aliases for quick access, and scheduling tasks with cron. I’ll assume you’re starting with a fresh OpenWrt installation and have basic networking knowledge.
Step 1: Prepare Your OpenWrt Router
Access Your Router:
Connect to your router via SSH:
bash
ssh root@192.168.1.1
Default IP is 192.168.1.1. If it’s different, use your router’s IP (check via ipconfig on Windows or ifconfig/ip on Linux/macOS from a connected device).
Default password is usually blank or set during initial setup. If you haven’t set one, do so in the web interface (LuCI) under System > Administration.
Update Packages:
Ensure your package list is current:
bash
opkg update
Install Required Tools:
Install bind-host for DNS resolution (used in redirection):
bash
opkg install bind-host
iptables, arp, and dnsmasq are pre-installed in OpenWrt, so no additional installation is needed for these.
Step 2: Install the Script
Create the Script File:
Open a text editor on the router:
bash
vi /usr/bin/router_device_manager.sh
Press i to enter insert mode, then paste the entire router_device_manager.sh script from the previous response (copy from #!/bin/sh to the end).
Save and exit: Press Esc, then type :wq and hit Enter.
Make the Script Executable:
Set permissions:
bash
chmod +x /usr/bin/router_device_manager.sh
Test the Script:
List connected devices to ensure it works:
bash
/usr/bin/router_device_manager.sh list
You should see a list of devices (IP, MAC, Name, Redirect, Status). If not, ensure devices are connected and the ARP table is populated.
Step 3: Use the Basic Commands
List Devices:
Run:
bash
/usr/bin/router_device_manager.sh list
Example output:
```
Connected Devices:
IP: 192.168.1.100 | MAC: 00:11:22:33:44:55 | Name: Phone | Redirect: http://example.com | Status: Online
IP: 192.168.1.101 | MAC: 00:66:77:88:99:AA | Name: Laptop | Redirect: http://google.com | Status: Online
Block a Device:
Replace 00:11:22:33:44:55 with a real MAC from the list:
bash
/usr/bin/router_device_manager.sh block 00:11:22:33:44:55
Check the status with list to confirm it’s blocked.
Unblock a Device:
Use the same MAC:
bash
/usr/bin/router_device_manager.sh unblock 00:11:22:33:44:55
Redirect a Device:
Redirect to a specific site (e.g., example.com):
bash
/usr/bin/router_device_manager.sh redirect 00:11:22:33:44:55 example.com
Test by browsing from the device—it should redirect to example.com.
Remove Redirection:
Remove the redirect:
bash
/usr/bin/router_device_manager.sh remove_redirect 00:11:22:33:44:55
Monitor Devices:
Start monitoring (stop with Ctrl+C):
bash
/usr/bin/router_device_manager.sh monitor
Step 4: Set Up Aliases for Easier Access
Edit the Profile File:
Open the root user’s profile:
bash
vi /root/.profile
Add this line at the end:
bash
alias dm="/usr/bin/router_device_manager.sh"
Save and exit (:wq).
Apply the Alias:
Reload the profile:
bash
source /root/.profile
Use the Alias:
Now you can use dm instead of the full path:
bash
dm list
dm block 00:11:22:33:44:55
dm redirect 00:11:22:33:44:55 example.com
Step 5: Set Up the Optional Web Interface
Install Web Server and PHP:
Install uhttpd (if not already present) and php7:
bash
opkg install uhttpd php7
Create the PHP Script:
Open a new file:
bash
vi /www/control.php
Paste this code:
php
<?php
if (isset($_GET['action']) && isset($_GET['mac'])) {
    $action = $_GET['action'];
    $mac = $_GET['mac'];
    $url = $_GET['url'] ?? '';
    shell_exec("/usr/bin/router_device_manager.sh $action $mac $url");
    echo "Command executed: $action $mac $url";
} else {
    echo "Usage: ?action={list|block|unblock|redirect|remove_redirect}&mac=<MAC>&url=<URL>";
}
?>
Save and exit (:wq).
Enable the Web Server:
Ensure uhttpd is running:
bash
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start
Access the Web Interface:
From a browser on a connected device, visit:
List devices: http://192.168.1.1/control.php?action=list
Block: http://192.168.1.1/control.php?action=block&mac=00:11:22:33:44:55
Redirect: http://192.168.1.1/control.php?action=redirect&mac=00:11:22:33:44:55&url=example.com
Output will be basic text (e.g., "Command executed: redirect 00:11:22:33:44:55 example.com").
Step 6: Schedule Tasks with Cron
Edit the Cron File:
Open the crontab:
bash
crontab -e
Add scheduled tasks (examples):
bash
# Block a device every night at 10 PM
0 22 * * * /usr/bin/router_device_manager.sh block 00:11:22:33:44:55
# Unblock every morning at 7 AM
0 7 * * * /usr/bin/router_device_manager.sh unblock 00:11:22:33:44:55
# Redirect to a site at 8 PM
0 20 * * * /usr/bin/router_device_manager.sh redirect 00:11:22:33:44:55 bedtime.com
# Remove redirect at 8 AM
0 8 * * * /usr/bin/router_device_manager.sh remove_redirect 00:11:22:33:44:55
Save and exit (:wq).
Enable Cron:
Ensure the cron service is running:
bash
/etc/init.d/cron enable
/etc/init.d/cron start
Step 7: Persist iptables Rules Across Reboots
Save Current Rules:
After applying blocks, save the rules:
bash
iptables-save > /etc/iptables.rules
Edit Startup Script:
Open /etc/rc.local:
bash
vi /etc/rc.local
Add this line before exit 0:
bash
iptables-restore < /etc/iptables.rules
Save and exit (:wq).
Step 8: Customize and Troubleshoot
Edit the Config File:
View or modify /etc/device_manager.conf:
bash
vi /etc/device_manager.conf
Update device names or URLs as needed (e.g., change "Phone" to "iPhone12").
Check Logs:
View the log file for debugging:
bash
cat /tmp/device_manager.log
Test Redirection:
Redirect a device to a local server (e.g., if you have a web server at 192.168.1.10):
bash
dm redirect 00:11:22:33:44:55 192.168.1.10
Or to an external site:
bash
dm redirect 00:11:22:33:44:55 google.com
Example Workflow
List Devices: dm list to find a MAC (e.g., 00:11:22:33:44:55).
Block It: dm block 00:11:22:33:44:55.
Redirect It: dm redirect 00:11:22:33:44:55 example.com.
Check Status: dm list to confirm.
Schedule: Add a cron job to automate redirection at night.
Notes
Router IP: Replace 192.168.1.1 with your router’s actual IP if different.
Security: Set a strong SSH password and disable web access from outside your LAN in LuCI (Network > Firewall).
Performance: With many devices, DNS redirection might slow down dnsmasq. Test with a few devices first.
You’re now set to control devices easily
