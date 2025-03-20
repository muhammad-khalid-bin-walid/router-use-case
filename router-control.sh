#!/bin/sh

# Enhanced script for controlling devices on an OpenWrt router
# Features: List devices, block/unblock internet, redirect traffic, manage via config file
# Requirements: OpenWrt, dnsmasq, iptables, arp, uci

# Configuration and log files
CONFIG_FILE="/etc/device_manager.conf"
LOG_FILE="/tmp/device_manager.log"
REDIRECT_IP="192.168.1.10"  # Default IP for redirection (e.g., local web server)
echo "$(date): Device Manager started" >> "$LOG_FILE"

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "# Device Manager Configuration" > "$CONFIG_FILE"
    echo "# Format: MAC|NAME|REDIRECT_URL|BLOCKED (1 or 0)" >> "$CONFIG_FILE"
    echo "00:11:22:33:44:55|Phone|http://example.com|0" >> "$CONFIG_FILE"
    echo "00:66:77:88:99:AA|Laptop|http://google.com|0" >> "$CONFIG_FILE"
fi

# Function to list connected devices with status
list_devices() {
    echo "Connected Devices:"
    echo "-----------------"
    arp -n | grep -v "incomplete" | while read -r line; do
        IP=$(echo "$line" | awk '{print $1}')
        MAC=$(echo "$line" | awk '{print $3}')
        NAME=$(grep "$MAC" "$CONFIG_FILE" | cut -d'|' -f2)
        REDIRECT=$(grep "$MAC" "$CONFIG_FILE" | cut -d'|' -f3)
        BLOCKED=$(grep "$MAC" "$CONFIG_FILE" | cut -d'|' -f4)
        STATUS="Online"
        [ "$BLOCKED" = "1" ] && STATUS="Blocked"
        [ -z "$NAME" ] && NAME="Unknown"
        [ -z "$REDIRECT" ] && REDIRECT="None"
        echo "IP: $IP | MAC: $MAC | Name: $NAME | Redirect: $REDIRECT | Status: $STATUS"
    done | tee -a "$LOG_FILE"
    echo "-----------------"
}

# Function to block internet access for a device
block_device() {
    MAC="$1"
    if [ -z "$MAC" ]; then
        echo "Error: MAC address required" | tee -a "$LOG_FILE"
        return 1
    fi

    IP=$(arp -n | grep "$MAC" | awk '{print $1}')
    if [ -z "$IP" ]; then
        echo "Error: No device found with MAC $MAC" | tee -a "$LOG_FILE"
        return 1
    fi

    iptables -A FORWARD -m mac --mac-source "$MAC" -j DROP
    sed -i "/$MAC/s/|[0-1]$/|1/" "$CONFIG_FILE"
    echo "$(date): Blocked internet for MAC $MAC (IP: $IP)" | tee -a "$LOG_FILE"
}

# Function to unblock internet access for a device
unblock_device() {
    MAC="$1"
    if [ -z "$MAC" ]; then
        echo "Error: MAC address required" | tee -a "$LOG_FILE"
        return 1
    fi

    iptables -D FORWARD -m mac --mac-source "$MAC" -j DROP 2>/dev/null
    sed -i "/$MAC/s/|[0-1]$/|0/" "$CONFIG_FILE"
    echo "$(date): Unblocked internet for MAC $MAC" | tee -a "$LOG_FILE"
}

# Function to redirect device traffic to a specific URL
redirect_device() {
    MAC="$1"
    URL="$2"
    if [ -z "$MAC" ] || [ -z "$URL" ]; then
        echo "Error: MAC address and URL required" | tee -a "$LOG_FILE"
        return 1
    fi

    # Resolve URL to IP (using host command, assumes DNS resolution works)
    REDIRECT_IP=$(host -t A "$URL" | awk '/has address/ {print $4}' | head -n 1)
    if [ -z "$REDIRECT_IP" ]; then
        echo "Error: Could not resolve URL $URL" | tee -a "$LOG_FILE"
        return 1
    fi

    # Add DNS override in dnsmasq
    echo "address=/./$REDIRECT_IP # $MAC" > "/tmp/dnsmasq_redirect_$MAC.conf"
    mv "/tmp/dnsmasq_redirect_$MAC.conf" "/etc/dnsmasq.d/redirect_$MAC.conf"
    /etc/init.d/dnsmasq restart >/dev/null 2>&1

    # Update config file
    if grep -q "$MAC" "$CONFIG_FILE"; then
        sed -i "/$MAC/s/|[^|]*|/[|$URL|/" "$CONFIG_FILE"
    else
        echo "$MAC|Unknown|$URL|0" >> "$CONFIG_FILE"
    fi
    echo "$(date): Redirected MAC $MAC to $URL (IP: $REDIRECT_IP)" | tee -a "$LOG_FILE"
}

# Function to remove redirection for a device
remove_redirect() {
    MAC="$1"
    if [ -z "$MAC" ]; then
        echo "Error: MAC address required" | tee -a "$LOG_FILE"
        return 1
    fi

    rm -f "/etc/dnsmasq.d/redirect_$MAC.conf"
    /etc/init.d/dnsmasq restart >/dev/null 2>&1
    sed -i "/$MAC/s/|[^|]*|/[|None|/" "$CONFIG_FILE"
    echo "$(date): Removed redirect for MAC $MAC" | tee -a "$LOG_FILE"
}

# Function to monitor devices
monitor_devices() {
    echo "Monitoring Devices (Ctrl+C to stop):"
    while true; do
        echo "$(date): Active Devices" | tee -a "$LOG_FILE"
        list_devices | grep -v "Connected Devices" | grep -v "-----"
        sleep 10
    done
}

# Function to display usage
usage() {
    echo "Usage: $0 {list | block <MAC> | unblock <MAC> | redirect <MAC> <URL> | remove_redirect <MAC> | monitor}"
    echo "  list          : List all connected devices with status"
    echo "  block         : Block internet for a device (e.g., block 00:11:22:33:44:55)"
    echo "  unblock       : Unblock internet for a device"
    echo "  redirect      : Redirect device traffic to a URL (e.g., redirect 00:11:22:33:44:55 example.com)"
    echo "  remove_redirect: Remove redirection for a device"
    echo "  monitor       : Continuously monitor connected devices"
}

# Main logic
case "$1" in
    "list")
        list_devices
        ;;
    "block")
        block_device "$2"
        ;;
    "unblock")
        unblock_device "$2"
        ;;
    "redirect")
        redirect_device "$2" "$3"
        ;;
    "remove_redirect")
        remove_redirect "$2"
        ;;
    "monitor")
        monitor_devices
        ;;
    *)
        usage
        ;;
esac

echo "$(date): Device Manager ended" >> "$LOG_FILE"
