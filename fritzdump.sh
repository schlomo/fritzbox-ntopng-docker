#!/bin/bash

# TODO: https

test -r /etc/fritzbox-internet-ticket.conf && source /etc/fritzbox-internet-ticket.conf

export ${!FRITZBOX_*}

# Fritzbox credentials must be given either via environment variables
FRITZBOX_PASSWORD="${FRITZBOX_PASSWORD:-$1}"
FRITZBOX_USERNAME="${FRITZBOX_USERNAME:-$2}"
# This is the address of the router
FRITZBOX_HOST=${FRITZBOX_HOST:-fritz.box}

# Lan Interface is default, otherwise you don't see which host causes the traffic
FRITZBOX_INTERFACE="${FRITZBOX_INTERFACE:-1-lan}"

FRITZBOX_IP=( $(getent hosts fritz.box) )

if [ -z "$FRITZBOX_PASSWORD" ] ; then echo "Password empty, please set at least FRITZBOX_PASSWORD environment variable. Usage: $0 [ntopng args ...]" ; exit 1; fi

echo "Trying to login into $FRITZBOX_HOST"

# Request challenge token from Fritz!Box
CHALLENGE=$(curl --insecure --silent $FRITZBOX_IP/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)

# Very proprieatry way of AVM: Create a authentication token by hashing challenge token with password
HASH=$(perl -MPOSIX -e '
    use Digest::MD5 "md5_hex";
    my $ch_Pw = "$ARGV[0]-$ARGV[1]";
    $ch_Pw =~ s/(.)/$1 . chr(0)/eg;
    my $md5 = lc(md5_hex($ch_Pw));
    print $md5;
  ' -- "$CHALLENGE" "$FRITZBOX_PASSWORD" )
SID=$(
  curl --insecure --silent "$FRITZBOX_IP/login_sid.lua" -d "response=$CHALLENGE-$HASH" \
  -d 'username='${FRITZBOX_USERNAME} | grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2 )

# Check for successfull authentification
if [[ $SID =~ ^0+$ ]] ; then echo "Login failed. Did you create & use explicit Fritz!Box users?" ; exit 1 ; fi

echo "Capturing traffic on Fritz!Box interface $IFACE ..." 1>&2

# In case you want to use tshark instead of ntopng
#wget --no-check-certificate -qO- $FRITZIP/cgi-bin/capture_notimeout?ifaceorminor=$IFACE\&snaplen=\&capture=Start\&sid=$SID | wireshark -i - ; exit 0

FIFO=$(mktemp -u -t ${0##*/}.fifo.XXXXXXXXXXXXXXX)
mkfifo $FIFO
trap "rm -f $FIFO" EXIT

{ sleep 3 ; xdg-open http://localhost:3000 </dev/null ; } &

curl --insecure --silent --no-buffer --output $FIFO \
"$FRITZBOX_IP/cgi-bin/capture_notimeout?ifaceorminor=$FRITZBOX_INTERFACE&snaplen=&capture=Start&sid=$SID" &

# I didn't manage to connect the curl and the docker directly so that the data would stream into ntopng. The FIFO is my workaround.

docker run --name ntopng --dns $FRITZBOX_IP -v $FIFO:/tmp/fritz.fifo --rm -p 3000:3000 schlomo/ntopng-docker \
  --community --dns 1 --local-networks $FRITZBOX_IP/24 --disable-login 1 --shutdown-when-done --interface /tmp/fritz.fifo "$@"
