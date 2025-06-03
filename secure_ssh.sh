#!/bin/bash
# secure_ssh.sh – Secure SSH with custom port & IP access using iptables (Ubuntu only)
# Author: YOUR NAME

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root."
  exit 1
fi

apt update -y
apt install -y iptables iptables-persistent

read -p "Enter SSH port (1024–65535): " SSH_PORT
read -p "Enter your trusted IP: " TRUSTED_IP

if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1024 ] || [ "$SSH_PORT" -gt 65535 ]; then
  echo "❌ Invalid port."
  exit 1
fi

if ! [[ "$TRUSTED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid IP."
  exit 1
fi

# Backup and update SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i "/^#Port /c\Port $SSH_PORT" /etc/ssh/sshd_config
sed -i "/^Port /c\Port $SSH_PORT" /etc/ssh/sshd_config

# Flush existing iptables rules
iptables -F
iptables -X

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH from trusted IP on custom port
iptables -A INPUT -p tcp -s "$TRUSTED_IP" --dport "$SSH_PORT" -m conntrack --ctstate NEW -j ACCEPT

# Allow ICMP (ping)
iptables -A INPUT -p icmp -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Restart SSH
systemctl restart ssh

echo "✅ SSH secured: port $SSH_PORT, allowed IP $TRUSTED_IP"
