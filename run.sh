#!/bin/bash

# Global vars
PROG_NAME='DockerTinyproxy'
PROXY_CONF='/etc/tinyproxy/tinyproxy.conf'
TINYPROXY_TAIL_LOG='/var/log/tinyproxy/tinyproxy.log'
OPENVPN_TAIL_LOG="/var/log/openvpn/openvpn.log"
GATEWAY=$(ip route | grep default | cut -f 3 -d' ')
VPN_CONFIG_DIR="/openvpn"
ARGS="$@"
VPN_PID=0

# Accessing a named argument
namedArg() {
	echo "$ARGS" | awk -F "$1" '{print $2}' | cut -d' ' -f2
}

# Usage: screenOut STATUS message
screenOut() {
    timestamp=$(date +"%H:%M:%S")
    
    if [ "$#" -ne 2 ]; then
        status='INFO'
        message="$1"
    else
        status="$1"
        message="$2"
    fi

    echo -e "[$PROG_NAME][$status][$timestamp]: $message"
}

# Usage: checkStatus $? "Error message" "Success message"
checkStatus() {
    case $1 in
        0)
            screenOut "SUCCESS" "$3"
            ;;
        1)
            screenOut "ERROR" "$2 - Exiting..."
            exit 1
            ;;
        *)
            screenOut "ERROR" "Unrecognised return code."
            ;;
    esac
}

displayUsage() {
    echo
    echo '  Usage:'
    echo "      docker run -d -ti --cap-add=NET_ADMIN --device=/dev/net/tun --name='usavpn' -v "/path/to/vpn.ovpn:/openvpn/config.ovpn" freereacts/openvpnproxy:latest -u username -p mysecurepassword -i 10.1.0.0/24"
    echo 
    echo "      [-u username] Username for the VPN connection."
    echo "      [-p password] Password for the VPN connection."
    echo "      -i ip_range IP Address range of your host network."
}

stopService() {
    screenOut "Checking for running Tinyproxy service..."
    if [ "$(pidof tinyproxy)" ]; then
        screenOut "Found. Stopping Tinyproxy service for pre-configuration..."
        killall tinyproxy
        checkStatus $? "Could not stop Tinyproxy service." \
                       "Tinyproxy service stopped successfully."
    else
        screenOut "Tinyproxy service not running."
    fi

    screenOut "Checking for running openvpn service..."
    if [ "$(pidof openvpn)" ]; then
        screenOut "Found. Stopping openvpn service for pre-configuration..."
        killall openvpn
        checkStatus $? "Could not stop openvpn service." \
                       "openvpn service stopped successfully."
    else
        screenOut "openvpn service not running."
    fi

}

enableLogFile() {
	sed -i -e"s,^#LogFile,LogFile," $PROXY_CONF
}

setAccess() {
	namedArg "-u"
	sed -i "s/^Allow 127.0.0.1/Allow $GATEWAY/g" $PROXY_CONF
}

setAuth() {
    if [ -n "${BASIC_AUTH_USER}"  ] && [ -n "${BASIC_AUTH_PASSWORD}" ]; then
        screenOut "Setting up basic auth credentials."
        sed -i -e"s/#BasicAuth user password/BasicAuth ${BASIC_AUTH_USER} ${BASIC_AUTH_PASSWORD}/" $PROXY_CONF
    fi
}

setTimeout() {
    if [ -n "${TIMEOUT}"  ]; then
        screenOut "Setting up Timeout."
        sed -i -e"s/Timeout 600/Timeout ${TIMEOUT}/" $PROXY_CONF
    fi
}

setCredentials() {
    USERNAME=$(namedArg "-u")
    PASSWORD=$(namedArg "-p")

    if [ -n "$USERNAME" ]; then
        echo "$USERNAME" >> "$VPN_CONFIG_DIR/auth.txt"
    fi

    if [ -n "$PASSWORD" ]; then
	echo "$PASSWORD" >> "$VPN_CONFIG_DIR/auth.txt"
    fi
}

startProxy() {
    screenOut "Starting Tinyproxy service..."
    /usr/bin/tinyproxy
    checkStatus $? "Could not start Tinyproxy service." \
                   "Tinyproxy service started successfully."
}

tailLog() {
    touch /var/log/tinyproxy/tinyproxy.log

    screenOut "Tailing tinyproxy and openvpn log..."
    tail -f $TINYPROXY_TAIL_LOG &
    TP_TAIL_PID=$!
    TP_TAIL_STATUS=$?

    wait $VPN_PID

    checkStatus $? "Could not connect to the VPN connection" \
	           "VPN connection stopped"

    checkStatus $TP_TAIL_STATUS "Could not tail $TAIL_LOG" \
                   "Stopped tailing $TAIL_LOG"

    kill $TP_TAIL_PID
}

startVPN(){
    /usr/sbin/openvpn --config "$VPN_CONFIG_DIR/config.ovpn" --auth-user-pass "$VPN_CONFIG_DIR/auth.txt" &
    VPN_PID=$!    
    ip route add $IP_ADDRESS via $(ip r | grep "default" | awk -F'[ ]+' '{{print $3}}') dev eth0
}

IP_ADDRESS=$(namedArg "-i")
# Display Usage
if  [ -n "$IP_ADDRESS"]; then
	screenOut "Please provide a ip address."
	displayUsage
	exit 1
fi

# Display Usage
if [ ! -f "$VPN_CONFIG_DIR/config.ovpn" ]; then
	screenOut "Please provide an openvpn config file."
	displayUsage
	exit 1
fi

# Start script
echo && screenOut "$PROG_NAME script started..."
# Stop Tinyproxy and openvpn if running
stopService
# Allowing host PC to access
setAccess
# Set openvpn credentials
setCredentials
# Enable basic auth (if any)
setAuth
# Set Timeout (if any)
setTimeout
# Enable log to file
enableLogFile
# Start Tinyproxy
startProxy
# Start OpenVPN
startVPN
# Tail Tinyproxy log
tailLog
# End
screenOut "$PROG_NAME script ended." && echo
exit 0
