#!/bin/bash

# Function to connect to a given VPN configuration
connect_vpn() {
    local config_file="$1"
    local auth_file="$2"
    
    echo "Connecting to VPN using $(basename "$config_file")..." >&2
    # Ensure no other OpenVPN process is running
    pkill openvpn
    sleep 3
    
    # Connect in the background with better DNS handling
    openvpn --config "$config_file" --auth-user-pass "$auth_file" --daemon    

    # Wait for the connection to establish
    echo "Waiting for connection to establish..." >&2
    sleep 10
    
    local new_ip
    new_ip=$(curl -s --max-time 10 ifconfig.me)

    # Test DNS resolution
    if nslookup google.com > /dev/null 2>&1; then
        echo "DNS resolution working" >&2
    else
        echo "DNS resolution failed" >&2
        return 1
    fi

    if [ -n "$new_ip" ]; then
        echo "VPN connected. New IP: $new_ip" >&2
    else
        echo "Could not verify new IP address. Check connection." >&2
    fi
}

# Function to disconnect from VPN
disconnect_vpn() {
    echo "Disconnecting from VPN..."
    pkill openvpn
    sleep 3
    echo "VPN disconnected."
}
