#!/bin/bash

systemctl stop myspeeder 2>/dev/null
systemctl disable myspeeder 2>/dev/null
rm -rf /etc/systemd/system/myspeeder.service 2>/dev/null
apt remove openvpn shadowsocks-libev

rm -rf /usr/local/myspeeder 2>/dev/null
rm -rf /etc/shadowsocks-libev 2>/dev/null
rm -rf /etc/openvpn/ 2>/dev/null

echo Uninstall success.