#!/bin/bash

# Configuracion Internet
INET_IF="eth0"
INET_TCP_PORTS="22 80 443"
INET_UDP_PORTS="123"
PORT_FORWARDING="" # Formato: ExtPort:IntIP:IntPort

# Configuracion LAN
LAN_IF="eth1"
LAN_NET="192.168.10.0/24"
PROXY="192.168.10.1:3128"

IPTABLES=$(which iptables)

case "$1" in
	start)
    # Cargamos los modulos necesarios
    echo "Setting firewall rules..."
    echo -n " * Loading kernel modules: "
    /sbin/modprobe ip_tables
    /sbin/modprobe ip_conntrack
    /sbin/modprobe ip_conntrack_ftp
    /sbin/modprobe ip_conntrack_irc
    /sbin/modprobe iptable_nat
    /sbin/modprobe ip_nat_ftp
    echo "done"
    
    # Activamos el IP forwarding
    echo -n " * Activating IP Forwarding support: "
    echo "1" > /proc/sys/net/ipv4/ip_forward
    echo "done"
    
    # Eliminamos las reglas anteriores
    echo -n " * Deleting firewall rules: "
    $IPTABLES -F
    $IPTABLES -X
    $IPTABLES -t nat -F
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -F
    $IPTABLES -t mangle -X
    echo "done"
    
    # Ponemos que tipo de conexiones que vengan de inet aceptamos
    echo -n " * Setting firewall port rules: "
    for port in $INET_TCP_PORTS; do
      $IPTABLES -A INPUT -i $INET_IF --proto tcp --dport $port -j ACCEPT
    done
    for port in $INET_UDP_PORTS; do
      $IPTABLES -A INPUT -i $INET_IF --proto udp --dport $port -j ACCEPT
    done
    # No permito conexiones a los demas puertos desde inet
    $IPTABLES -A INPUT -i $IF_INET --proto udp --dport 1:1024 -j DROP
    $IPTABLES -A INPUT -i $IF_INET --proto tcp --dport 1:1024 -j DROP
    echo "done"
    
    echo -n " * Activating Port Forwarding: "
    if [[ -n "$PORT_FORWARDING" ]]; then
      for i in $PORT_FORWARDING; do
        extport=$(echo $i | awk -F ':' '{ print $1 }')
        intip=$(echo $i | awk -F ':' '{ print $2 }')
        intport=$(echo $i | awk -F ':' '{ print $3 }')
    
        $IPTABLES -t nat -A PREROUTING -p tcp --in-interface $INET_IF --dport $extport -j DNAT --to $intip:$intport
      done
    fi
    echo "done"
    
    # Activamos el NAT
    echo -n " * Activating NAT: "
    $IPTABLES -t nat -A POSTROUTING -o $INET_IF -j MASQUERADE
    $IPTABLES -A FORWARD -i $LAN_IF -j ACCEPT
    $IPTABLES -t mangle -A FORWARD -m tcp -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    echo "done"
    
    if [[ -n "$PROXY" ]]; then
      echo -n " * Activating Transparent Proxy: "
      $IPTABLES -t nat -A PREROUTING --in-interface $LAN_IF ! -d $LAN_NET -p tcp -m tcp --dport 80 -j DNAT --to-destination $PROXY
      echo "done"
    fi
    
    # HTB-GEN
    #echo -n " * Activating bandwidth control: "
    #/usr/local/bin/htb-gen all
    #echo "done"
    ;;

  stop)
    echo -n " * Stopping firewall: "
    $IPTABLES -F
    $IPTABLES -X
    $IPTABLES -t nat -F
    $IPTABLES -t nat -X
    $IPTABLES -t mangle -F
    $IPTABLES -t mangle -X
    echo "done"
    ;;

  restart)
    $0 stop
    echo -n " * Sleeping a few seconds before setting the rules again: "
    sleep 2
    echo "done"
    $0 start
    ;;

  status)
    $IPTABLES -L
    $IPTABLES --table nat --list --exact --verbose --numeric --line-numbers
    ;;

  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
esac
exit 0
