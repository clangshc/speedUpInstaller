#!/bin/bash

if [ -z '$(cat /etc/*release | grep -i Ubuntu)' ]; then
    echo 'Just support ubuntu.'
    exit 1
fi

kcptun_ver='20191107'
udp2raw_ver='20181113.0'
dir='/usr/local/myspeeder'

sspwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)
udp2rawpwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)

rm -rf $dir 2>/dev/null
mkdir $dir

systemctl stop myspeeder 2>/dev/null

apt -y update
apt -y install curl shadowsocks-libev

# install ss
rm -rf /etc/shadowsocks-libev/config.json 2>/dev/null
cat <<EOF > /etc/shadowsocks-libev/config.json
{
    "server":"0.0.0.0",
    "server_port":9555,
    "password":"${sspwd}",
    "timeout":600,
    "method":"chacha20-ietf-poly1305"
}
EOF
# Start the service
systemctl enable shadowsocks-libev


# install kcptun
curl -kLs https://github.com/xtaci/kcptun/releases/download/v${kcptun_ver}/kcptun-linux-amd64-${kcptun_ver}.tar.gz > kcptun.tar.gz
mkdir kcptun 2>/dev/null
tar -zxf kcptun.tar.gz -C kcptun
cp ./kcptun/server_linux_amd64 $dir/kcptun.s
chmod +x $dir/kcptun.s
rm -rf kcptun 2>/dev/null
rm -rf kcptun.tar.gz 2>/dev/null

# install udp2raw
curl -kLs https://github.com/wangyu-/udp2raw-tunnel/releases/download/${udp2raw_ver}/udp2raw_binaries.tar.gz > udp2raw.tar.gz
mkdir udp2raw 2>/dev/null
tar -zxf udp2raw.tar.gz  -C udp2raw
cp ./udp2raw/udp2raw_amd64 $dir/udp2raw.s
chmod +x $dir/udp2raw.s
rm -rf udp2raw 2>/dev/null
rm -rf udp2raw.tar.gz 2>/dev/null

rm -rf ${dir}/start.sh 2>/dev/null
cat <<EOF >${dir}/start.sh
#!/bin/bash
systemctl start shadowsocks-libev
${dir}/kcptun.s  -l ":9556" -t "127.0.0.1:9555" -mode fast2 -mtu 1300 &
${dir}/udp2raw.s -s  -l0.0.0.0:9557 -r 127.0.0.1:9556 -k "${udp2rawpwd}" --raw-mode faketcp -a
EOF
chmod +x ${dir}/start.sh

rm -rf ${dir}/stop.sh 2>/dev/null
cat <<EOF > ${dir}/stop.sh
#!/bin/bash
systemctl stop shadowsocks-libev
ps xf | grep -v grep | grep "kcptun.s|udp2raw.s" | while read pid _; do kill -9 "\$pid"; done
EOF
chmod +x ${dir}/stop.sh


rm -rf /etc/systemd/system/myspeeder.service 2>/dev/null
cat <<EOF > /etc/systemd/system/myspeeder.service
[Unit]
Description=MySpeeder

[Service]
ExecStart=${dir}/start.sh
ExecStop=${dir}/stop.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 664 /etc/systemd/system/myspeeder.service



systemctl daemon-reload
systemctl enable myspeeder
systemctl start myspeeder

echo .
echo This is my password, protect it.
echo shadowsocks: $sspwd udp2raw: $udp2rawpwd

