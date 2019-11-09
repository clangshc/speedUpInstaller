# speedUpInstaller

This script will install shadowsocks+kcptun+udp2raw, openvpn+udpspeeder+udp2raw by one step.

After install, you have three choice to connect your proxy server:

1. tcp mode: ssclient ==tcp==> ssserver.
2. udp mode: ssclient --> kcptun --> udp2raw ==fake tcp==> udp2raw --> kcptun --> ssserver
3. udp mode: openvpn --> udpspeeder --> udp2raw ==fake tcp==> udp2raw --> udpspeeder --> openvpn server

# Install

    sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/daoye/speedUpInstaller/master/install.sh)"

# Uninstall

    sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/daoye/speedUpInstaller/master/uninstall.sh)"

# Remark

This script will enable tcp bbr.

# Warning

Only tested on ubuntu 18+.

# License

MIT

