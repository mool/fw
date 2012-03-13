PORT_FORWARDING="2020:192.168.1.10:22 8080:192.168.1.10:80"

for port in $PORT_FORWARDING; do
  extport=$(echo $port | awk -F ':' '{ print $1 }')
  intip=$(echo $port | awk -F ':' '{ print $2 }')
  intport=$(echo $port | awk -F ':' '{ print $3 }')
  echo "$extport -> $intip:$intport"
done
