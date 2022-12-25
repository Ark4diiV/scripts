#!/bin/bash
#Generator for wireguard client config
qr=0
ipregex='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'

# Help
case "$1" in
  "-h")
    echo "Usage: wggen -a <address>... -c <client>...

Options:
  -a      ip address of client
  -c      client name
  -q      print qr code for mobile add
  -h      display this help message

Examples:
  wggen -a 172.16.2.10 -c Ivan
  wggen -a 172.16.2.11 -c Stanislav -q"
    exit 0
    ;;
esac

# Options
while getopts "a:c:q" opt
do
  case "${opt}" in
    a) address=${OPTARG};;
    c) client=${OPTARG};;
    q) qr=1;;
    \?) echo "Error: invalid option -$OPTARG" >&2 && exit 1;;
  esac
done

# Shift the options to the left, so the remaining arguments can be accessed with $1, $2, etc.
shift $((OPTIND-1))

# Required argument(s) not provided
[ -z ${address} ] || [ -z ${client} ] && echo "Error: Required argument(s) not provided" >&2 && exit 1

# Is an IP address valid?
[[ ! $address =~ $ipregex ]] && echo "IP ${address} is not valid" && exit 1

# Is an IP address in a config?
if grep -q "${address}" /etc/wireguard/wg0.conf; then
  echo "This IP ${address} is exist on wg0.conf. Choose another one"
  exit 1
fi

# Generate client's private and public keys
wg genkey | tee privkey | wg pubkey > publickey
cp /etc/wireguard/client.conf client.conf
sed -i '2i\PrivateKey = '$(cat privkey)'' client.conf #Insert private key to client config
sed -i '3i\Address = '${address}'/32' client.conf     #Insert IP address to client config

# Generate a QR code if need
[ ${qr} -eq 1 ] && qrencode -r client.conf -t UTF8

# Backup wg0.conf
cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf_$(date "+%Y%m%d_%H%M%S")

# Update wg0.conf
cat << EOF >> /etc/wireguard/wg0.conf

[Peer] #${client}
AllowedIPs = ${address}/32
PublicKey = $(cat publickey)
EOF

echo "Client configuration:"
echo ""
cat client.conf
echo ""

# Restart wireguard daemon
systemctl restart wg-quick@wg0.service

# Cleaning
rm -f privkey
rm -f publickey
rm client.conf