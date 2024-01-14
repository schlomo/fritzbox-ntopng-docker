#!/bin/bash

if ! which >/dev/null 2>&1 iconv; then
  echo 1>&2 "Error: 'iconv' is not installed"
  exit 1
fi
if ! which >/dev/null 2>&1 curl; then
  echo 1>&2 "Error: 'curl' is not installed"
  exit 1
fi

# TODO: https

if test -r /etc/fritzbox-internet-ticket.conf; then
  echo "Sourcing /etc/fritzbox-internet-ticket.conf"
  source /etc/fritzbox-internet-ticket.conf
fi

export ${!FRITZBOX_*}

# Fritzbox credentials must be given either via environment variables
FRITZBOX_PASSWORD="${FRITZBOX_PASSWORD:-$1}"
FRITZBOX_USERNAME="${FRITZBOX_USERNAME:-$2}"
# This is the address of the router
FRITZBOX_HOST=${FRITZBOX_HOST:-fritz.box}

# Lan Interface is default, otherwise you don't see which host causes the traffic
FRITZBOX_INTERFACE="${FRITZBOX_INTERFACE:-1-lan}"

DOCKER_IMAGE="${DOCKER_IMAGE:-ntop/ntopng:stable}"

FRITZBOX_IP=($(getent hosts $FRITZBOX_HOST))

if [[ -z "$FRITZBOX_IP" ]]; then
  echo "Could not resolve $FRITZBOX_HOST"
  exit 1
fi

if [[ "$FRITZBOX_IP" =~ : ]]; then
  FRITZBOX_URL="http://[$FRITZBOX_IP]"
else
  FRITZBOX_URL="http://$FRITZBOX_IP"
fi

if [ -z "$FRITZBOX_PASSWORD" ]; then
  echo "Password empty, please set at least FRITZBOX_PASSWORD environment variable. Usage: $0 [ntopng args ...]"
  exit 1
fi

echo "Trying to login into $FRITZBOX_URL"

# get current session id and challenge
resp=$(curl -s "$FRITZBOX_URL/login_sid.lua")

if [[ "$resp" =~ \<SID\>(0+)\</SID\> ]]; then
  # SID=0 => not logged in
  if [[ "$resp" =~ \<BlockTime\>([0-9a-fA-F]+)\</BlockTime\> ]]; then
    BLOCKTIME="${BASH_REMATCH[1]}"
    if [[ "${BLOCKTIME}" -gt "0" ]]; then
      echo 1>&2 "BlockTime=${BLOCKTIME}, sleeping until finished"
      sleep $((${BLOCKTIME} + 1))
    fi
  fi
  if [[ "$resp" =~ \<Challenge\>([0-9a-fA-F]+)\</Challenge\> ]]; then
    CHALLENGE="${BASH_REMATCH[1]}"

    # replace all Unicode codepoints >255 by '.' because of a bug in the Fritz!Box.
    # Newer Fritz!Box OS versions don't allow to enter such characters.
    # This requires that the locale environment is setup to UTF8, but on my Mac this doesn't work
    #FRITZ_PASSWORD=$(export LC_CTYPE=UTF-8 ; echo "${FRITZ_PASSWORD}" | sed $'s/[\u0100-\U0010ffff]/./g')
    #FRITZ_PASSWORD=$(export LC_CTYPE=UTF-8 ; echo "${FRITZ_PASSWORD}" | tr $'\u0100-\U0010ffff' '.')

    if which >/dev/null 2>&1 md5; then
      MD5=$(echo -n "${CHALLENGE}-${FRITZBOX_PASSWORD}" | iconv --from-code=UTF-8 --to-code=UTF-16LE | md5)
    elif which >/dev/null 2>&1 md5sum; then
      MD5=$(echo -n "${CHALLENGE}-${FRITZBOX_PASSWORD}" | iconv --from-code=UTF-8 --to-code UTF-16LE | md5sum | cut -f1 -d ' ')
    else
      echo 1>&2 "Error: neither 'md5' nor 'md5sum' are installed"
      exit 1
    fi
    RESPONSE="${CHALLENGE}-${MD5}"
    resp=$(curl -s -G -d "response=${RESPONSE}" -d "username=${FRITZBOX_USERNAME}" "${FRITZBOX_URL}/login_sid.lua")
  fi
fi

if ! [[ "$resp" =~ \<SID\>(0+)\</SID\> ]] && [[ "$resp" =~ \<SID\>([0-9a-fA-F]+)\</SID\> ]]; then
  # either SID was already non-zero (authentication disabled) or login succeeded
  SID="${BASH_REMATCH[1]}"
  echo 1>&2 "SessionID=$SID"
fi

# Check for successfull authentification
if [[ -z "$SID" || $SID =~ ^0+$ ]]; then
  echo "Login failed. Did you create & use explicit Fritz!Box users?"
  exit 1
fi

echo "Capturing traffic on Fritz!Box interface $FRITZBOX_INTERFACE ..." 1>&2

function stopAll {
  echo "Stopping all captures on Fritz!Box..." 1>&2
  curl --insecure "$FRITZBOX_URL/cgi-bin/capture_notimeout?iface=undefined&minor=undefined&type=&capture=Stop&sid=$SID&useajax=1&xhr=1&t1705245314318=nocache" 1>&2
  curl --insecure "$FRITZBOX_URL/cgi-bin/capture_notimeout?iface=stopall&capture=Stop&sid=$SID&useajax=1&xhr=1&t1705245314319=nocache" 1>&2
}

trap stopAll INT TERM EXIT

# In case you want to use Wireshark instead of ntopng set WIRESHARK=1
if [ "$WIRESHARK" ]; then
  echo "Starting Wireshark ..."
  curl --insecure --verbose --no-buffer "$FRITZBOX_URL/cgi-bin/capture_notimeout?sid=$SID&capture=Start&snaplen=1600&filter=&ifaceorminor=$FRITZBOX_INTERFACE" | wireshark -k -i -
  exit 0
fi

docker pull $DOCKER_IMAGE

FIFO=$(mktemp -u -t ${0##*/}.fifo.XXXXXXXXXXXXXXX)
mkfifo $FIFO
trap "rm -f $FIFO" EXIT

{
  sleep 5
  xdg-open http://localhost:3000 </dev/null
} &

curl --insecure --silent --no-buffer --output $FIFO \
  "$FRITZBOX_URL/cgi-bin/capture_notimeout?ifaceorminor=$FRITZBOX_INTERFACE&snaplen=&capture=Start&sid=$SID" &

# I didn't manage to connect the curl and the docker directly so that the data would stream into ntopng. The FIFO is my workaround.

echo "Press Ctrl-C to stop capturing and exit" 1>&2

docker run \
  --name ntopng \
  --dns $FRITZBOX_IP \
  -v $FIFO:/tmp/fritz.fifo \
  --rm -it \
  -p '3000:3000' \
  $DOCKER_IMAGE \
  --community \
  --dns-mode 1 \
  --local-networks $FRITZBOX_IP/24 \
  --disable-login 1 \
  --shutdown-when-done \
  --no-promisc \
  --interface \
  /tmp/fritz.fifo \
  "$@"
