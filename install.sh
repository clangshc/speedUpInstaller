#!/bin/bash

if [ -z '$(cat /etc/*release | grep -i Ubuntu)' ]; then
    echo 'Just support ubuntu.'
    exit 1
fi

trap "rm -rf tmp EasyRSA pki" EXIT

speeder_ver='20190121.0'
kcptun_ver='20191107'
udp2raw_ver='20181113.0'
dir='/usr/local/myspeeder'

myip=$(curl ifconfig.me)

ssport=6605
ssudp2rawport=6607
ovpnudp2rawport=6610


kcptunport=45535
ovpnport=45536
speederport=45537


sspwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)
udp2rawpwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)
udpspeederpwd=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)

rm -rf $dir 2>/dev/null
mkdir $dir

systemctl stop myspeeder 2>/dev/null

# enable bbr, make sure your kernel version is greater than 4.9.
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
sysctl net.ipv4.tcp_congestion_control

# install ss and openvpn
apt -y update
apt -y install curl shadowsocks-libev openvpn

# install ss
rm -rf /etc/shadowsocks-libev/config.json 2>/dev/null
cat <<EOF > /etc/shadowsocks-libev/config.json
{
    "server":"0.0.0.0",
    "server_port":${ssport},
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

# install udpspeeder
curl -kLs https://github.com/wangyu-/UDPspeeder/releases/download/${speeder_ver}/speederv2_binaries.tar.gz > speeder.tar.gz
mkdir speeder 2>/dev/null
tar -zxf speeder.tar.gz -C speeder
cp ./speeder/speederv2_amd64 $dir/speeder.s
chmod +x $dir/speeder.s
rm -rf speeder 2>/dev/null
rm -rf speeder.tar.gz 2>/dev/null

# install udp2raw
curl -kLs https://github.com/wangyu-/udp2raw-tunnel/releases/download/${udp2raw_ver}/udp2raw_binaries.tar.gz > udp2raw.tar.gz
mkdir udp2raw 2>/dev/null
tar -zxf udp2raw.tar.gz  -C udp2raw
cp ./udp2raw/udp2raw_amd64 $dir/udp2raw.s
chmod +x $dir/udp2raw.s
rm -rf udp2raw 2>/dev/null
rm -rf udp2raw.tar.gz 2>/dev/null



curl -kLs wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.4/EasyRSA-3.0.4.tgz > EasyRSA.tgz

tar xvf EasyRSA.tgz
mv EasyRSA-3.0.4 EasyRSA

cp EasyRSA/vars.example EasyRSA/vars
echo 'set_var EASYRSA_REQ_COUNTRY    "US"' >> EasyRSA/vars
echo 'set_var EASYRSA_REQ_PROVINCE   "NewYork"' >> EasyRSA/vars
echo 'set_var EASYRSA_REQ_CITY       "New York City"' >> EasyRSA/vars
echo 'set_var EASYRSA_REQ_ORG        "NoOne"' >> EasyRSA/vars
echo 'set_var EASYRSA_REQ_EMAIL      "no@one.com"' >> EasyRSA/vars
echo 'set_var EASYRSA_REQ_OU         "Community"' >> EasyRSA/vars

# gen server key
#gen ca
EasyRSA/easyrsa init-pki
EasyRSA/easyrsa build-ca nopass

#gen server key
# EasyRSA/easyrsa init-pki
EasyRSA/easyrsa gen-req server nopass
EasyRSA/easyrsa import-req server.req server
echo yes | EasyRSA/easyrsa sign-req server server

#gen dhkey
EasyRSA/easyrsa gen-dh

cp pki/ca.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/dh.pem /etc/openvpn/



#gen client key
mkdir tmp
EasyRSA/easyrsa gen-req myclient nopass
EasyRSA/easyrsa import-req myclient.req myclient
echo yes | EasyRSA/easyrsa sign-req client myclient

cp pki/private/myclient.key tmp
cp pki/issued/myclient.crt tmp
cp pki/ca.crt tmp

cat <<EOF >/etc/openvpn/ovpn.conf
local 0.0.0.0
port ${ovpnport}
proto udp
dev tun

ca /etc/openvpn/ca.crt
key /etc/openvpn/server.key
cert /etc/openvpn/server.crt
dh /etc/openvpn/dh.pem



server 10.222.2.0 255.255.255.0
ifconfig 10.222.2.1 10.222.2.6

client-to-client
duplicate-cn 
keepalive 10 60

max-clients 50

persist-key
persist-tun

status /etc/openvpn/openvpn-status.log

verb 3
mute 20  

comp-lzo no   #this option is deprecated since openvpn2.4. For 2.4 and above, use "compress" instead
#compress

cipher none      ##### disable openvpn 's cipher and auth for maxmized peformance. 
auth none        ##### you can enable openvpn's cipher and auth,if you dont care about peformance,or you dont trust udp2raw 's encryption

fragment 1200       ##### very important    you can turn it up a bit. but,the lower the safer
mssfix 1200         ##### very important

sndbuf 2000000      ##### important
rcvbuf 2000000      ##### important
txqueuelen 4000     ##### suggested
EOF


rm -rf ${dir}/start.sh 2>/dev/null
cat <<EOF >${dir}/start.sh
#!/bin/bash
/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json & # ss server
${dir}/kcptun.s  -l ":${kcptunport}" -t "127.0.0.1:${ssport}" -mode fast2 -mtu 1300 &
${dir}/udp2raw.s -s  -l0.0.0.0:${ssudp2rawport} -r 127.0.0.1:${kcptunport} -k \"${udp2rawpwd}\" --raw-mode faketcp &

openvpn --config /etc/openvpn/ovpn.conf & # openvpn server
${dir}/speeder.s -s -l0.0.0.0:${speederport} -r127.0.0.1:${ovpnport}  -f20:10 -k \"${udpspeederpwd}\" --mode 0 &
${dir}/udp2raw.s -s  -l0.0.0.0:${ovpnudp2rawport} -r 127.0.0.1:${speederport} -k \"${udp2rawpwd}\" --raw-mode faketcp
EOF
chmod +x ${dir}/start.sh

rm -rf ${dir}/stop.sh 2>/dev/null
cat <<EOF > ${dir}/stop.sh
#!/bin/bash
systemctl stop shadowsocks-libev
ps xf | grep -v grep | grep "kcptun.s|speeder.s|udp2raw.s|openvpn|shadowsocks-libev" | while read pid _; do kill -9 "\$pid"; done
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



cat <<EOF > share.ovpn
client
dev tun100
proto udp

remote 127.0.0.1 3322  # This port is udp2raw client\'s listen port.
resolv-retry infinite 
nobind 
persist-key
persist-tun

<ca>
$(cat tmp/ca.crt)
</ca>
<key>
$(cat tmp/myclient.key)
</key>
<cert>
$(cat tmp/myclient.crt)
</cert>
# ca /root/add-on/openvpn/ca.crt
# cert /root/add-on/openvpn/client.crt
# key /root/add-on/openvpn/client.key

keepalive 3 20
verb 3
mute 20

comp-lzo no   #this option is deprecated since openvpn2.4. For 2.4 and above, use "compress" instead
#compress

cipher none      ##### disable openvpn 's cipher and auth for maxmized peformance. 
auth none        ##### you can enable openvpn's cipher and auth,if you dont care about peformance,or you dont trust udp2raw 's encryption

fragment 1200       ##### very important    you can turn it up a bit. but,the lower the safer
mssfix 1200         ##### very important

sndbuf 2000000      ##### important
rcvbuf 2000000      ##### important
txqueuelen 4000     ##### suggested
EOF



echo 
echo Be sure your firewall allow these ports: ${ssport},${ssudp2rawport},${ovpnudp2rawport}
echo ${ssport} use to shadowsocks, ${ssudp2rawport} use to shadowsocks with udp2raw, ${ovpnudp2rawport} use to openvpn with udp2raw.
echo
echo These are yours password:
echo shadowsocks: $sspwd udpspeeder: $udpspeederpwd udp2raw: $udp2rawpwd
echo 
echo Run udp2raw and kcptun for shadowsocks:
echo udp2raw_client -c -r${myip}:${ssudp2rawport} -l0.0.0.0:4000 --raw-mode faketcp -k\"${udp2rawpwd}\"
echo kcptun_client -r "127.0.0.1:4000" -l ":3322" -mode fast2 -mtu 1300
echo 
echo Then, run shadowsocks connect to 127.0.0.1:3322.
echo 
echo
echo
echo Run udp2raw and udpspeeder for openvpn:
echo udp2raw_client -c -r${myip}:${ovpnudp2rawport} -l0.0.0.0:4001 --raw-mode faketcp -k\"${udp2rawpwd}\"
echo udpspeederv2_client -c -l0.0.0.0:3333  -r127.0.0.1:4001 -f20:10 -k \"${udpspeederpwd}\"
echo
echo Then, run openvpn connect to 127.0.0.1:3333.
echo The "share.ovpn" is openvpn config file, Please download it to your local machine.
echo 
echo 
echo For more information visit:
echo udpspeeder: https://github.com/wangyu-/UDPspeeder
echo udp2raw: https://github.com/wangyu-/udp2raw-tunnel
echo kcptun: https://github.com/xtaci/kcptun
echo shadowsocks and openvpn.
