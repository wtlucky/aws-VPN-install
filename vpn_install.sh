#!/bin/sh

# Set VPN user
read -p "Please set VPN username (default: vpnuser): " VPN_USER
if [ "$VPN_USER" = "" ]; then
    VPN_USER="vpnuser"
fi

# Set VPN password
read -p "Please set VPN password (default: 123): " VPN_PASSWORD
if [ "$VPN_PASSWORD" = "" ]; then
    VPN_PASSWORD="123"
fi

# Set VPN IPSEC_PSK
read -p "Please set VPN IPSEC_PSK (default: 123): " IPSEC_PSK
if [ "$IPSEC_PSK" = "" ]; then
    IPSEC_PSK="123"
fi

# Update server
apt-get update && apt-get upgrade -y
# VPN 1 - Setup L2TP-IPSEC
PRIVATE_IP=`wget -q -O - 'http://169.254.169.254/latest/meta-data/local-ipv4'`
PUBLIC_IP=`wget -q -O - 'http://169.254.169.254/latest/meta-data/public-ipv4'
apt-get install -y openswan xl2tpd
cat > /etc/ipsec.conf <<EOF
version 2.0
config setup
  dumpdir=/var/run/pluto/
  nat_traversal=yes
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v6:fd00::/8,%v6:fe80::/10
  oe=off
  protostack=netkey
  nhelpers=0
  interfaces=%defaultroute

conn vpnpsk
  auto=add
  left=$PRIVATE_IP
  leftid=$PUBLIC_IP
  leftsubnet=$PRIVATE_IP/32
  leftnexthop=%defaultroute
  leftprotoport=17/1701
  rightprotoport=17/%any
  right=%any
  rightsubnetwithin=0.0.0.0/0
  forceencaps=yes
  authby=secret
  pfs=no
  type=transport
  auth=esp
  ike=3des-sha1
  phase2alg=3des-sha1
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
EOF

cat > /etc/ipsec.secrets <<EOF
$PUBLIC_IP  %any  : PSK \"$IPSEC_PSK\"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

;debug avp = yes
;debug network = yes
;debug state = yes
;debug tunnel = yes

[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
crtscts
idle 1800
mtu 1280
mru 1280
lock
connect-delay 5000
EOF

cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client\tserver\tsecret\t\t\tIP addresses

$VPN_USER\tl2tpd   $VPN_PASSWORD   *
EOF

iptables -t nat -A POSTROUTING -s 192.168.42.0/24 -o eth0 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

iptables-save > /etc/iptables.rules

cat > /etc/network/if-pre-up.d/iptablesload <<EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
echo 1 > /proc/sys/net/ipv4/ip_forward
exit 0
EOF

chmod a+x /etc/network/if-pre-up.d/iptablesload

/etc/init.d/ipsec restart
/etc/init.d/xl2tpd restart

#VPN 2 - Setup PPTP Server
apt-get install pptpd -y
echo \"localip 10.0.0.1\" >> /etc/pptpd.conf
echo \"remoteip 10.0.0.100-200\" >> /etc/pptpd.conf
echo \"$VPN_USER pptpd $VPN_PASSWORD *\" >> /etc/ppp/chap-secrets
echo \"ms-dns 8.8.8.8\" >> /etc/ppp/pptpd-options
echo \"ms-dns 8.8.4.4\" >> /etc/ppp/pptpd-options
service pptpd restart

echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE && iptables-save