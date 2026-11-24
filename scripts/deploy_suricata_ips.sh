#!/usr/bin/env bash
# ==============================================================================
# Script: deploy_suricata_ips.sh
# Description: Automated deployment of Suricata 7.0.x IPS Inline Mode (AF-PACKET)
#              on Ubuntu Gateway (ens33 <-> ens37) for Ransomware Detection/Drop
# Authors: Tiêu Hoàng Phúc (2280602483) & Nguyễn Phú Đạt (2280619006) — HUTECH
# ==============================================================================
set -euo pipefail

WAN_IFACE="${1:-ens33}"
LAN_IFACE="${2:-ens37}"

echo "[1/5] Preparing /etc/suricata directories & backing up default config..."
sudo mkdir -p /etc/suricata/rules /var/log/suricata
sudo cp -n /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak 2>/dev/null || true

echo "[2/5] Installing custom Ransomware IDS/IPS rules & inline configuration..."
sudo cp rules/ips_demo.rules /etc/suricata/rules/
sudo cp rules/ransomware.rules /etc/suricata/rules/
sudo cp configs/suricata-inline.yaml /etc/suricata/suricata.yaml

echo "[3/5] Tuning network interfaces ($WAN_IFACE <-> $LAN_IFACE) for AF-PACKET Inline IPS..."
sudo ip link set "$WAN_IFACE" promisc on || true
sudo ip link set "$LAN_IFACE" promisc on || true
if command -v ethtool >/dev/null 2>&1; then
    sudo ethtool -K "$WAN_IFACE" gro off lro off tso off gso off 2>/dev/null || true
    sudo ethtool -K "$LAN_IFACE" gro off lro off tso off gso off 2>/dev/null || true
fi

echo "[4/5] Validating Suricata configuration & rule syntax..."
sudo suricata -T -c /etc/suricata/suricata.yaml -v

echo "[5/5] Restarting Suricata in AF-PACKET IPS Inline daemon mode..."
sudo pkill suricata 2>/dev/null || true
sudo rm -f /var/run/suricata.pid
sudo suricata -c /etc/suricata/suricata.yaml --af-packet -D

sleep 1
ps aux | grep "[s]uricata"
echo "=============================================================================="
echo "[+] Suricata IPS Inline is ACTIVE across $WAN_IFACE <-> $LAN_IFACE!"
echo "    - Monitor real-time alerts/drops : sudo tail -f /var/log/suricata/fast.log"
echo "    - Filter only IPS DROP events    : sudo grep -i '\[Drop\]' /var/log/suricata/fast.log"
echo "    - Inspect structured JSON logs   : sudo tail -f /var/log/suricata/eve.json"
echo "=============================================================================="
