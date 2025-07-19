#!/bin/bash

# Function to connect to a given VPN configuration
connect_vpn() {
    local config_file="$1"
    local auth_file="$2"
    
    echo "🔄 Connecting to VPN using $(basename "$config_file")..."
    # Ensure no other OpenVPN process is running
    pkill openvpn
    sleep 2
    
    # Connect in the background with better DNS handling
    openvpn --config "$config_file" --auth-user-pass "$auth_file" --daemon    

    # Wait for the connection to establish
    echo "Waiting for connection to establish..."
    sleep 10
    
    local new_ip
    new_ip=$(curl -s --max-time 10 ifconfig.me)

    # Test DNS resolution
    if nslookup google.com > /dev/null 2>&1; then
        echo "✅ DNS resolution working"
    else
        echo "⚠️  DNS resolution failed"
        return 1
    fi

    if [ -n "$new_ip" ]; then
        echo "✅ VPN connected. New IP: $new_ip"
    else
        echo "⚠️  Could not verify new IP address. Check connection."
    fi
}

# Function to disconnect from VPN
disconnect_vpn() {
    echo "🛑 Disconnecting from VPN..."
    pkill openvpn
    sleep 2
    echo "✅ VPN disconnected."
}
