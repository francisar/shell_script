#!/bin/bash


usage()
{
	echo "usage:"
  echo "-p  protocol(vxlan, ipip) default vxlan"
  echo "-a <ip addr> "
  echo "-i <interface> "
  echo "-c <package count> "
  echo "-C <file size> "
  echo "-w <file name> "
  echo "-w <file name> "
  echo "-h   help"
  exit 0
}


if [ $UID != 0 ]; then
    echo "You must be root to run the install script."
    exit 1;
fi

PROTOCOL='vxlan'
IP_ADDR=''
IP_HEX=''
INTERFACE="any"
PACKAGE_COUNT=""
FILE_SIZE=""
WRITE_FILE=""
SHOW_COMMAND="false"

ip_check() {
  if ipv4_check "$1"; then
     IP_HEX=$(ipv4_to_hex "$1")
     return $?
  else
     if ipv6_check "$1"; then
        IP_HEX=$(ipv6_to_hex "$1")
     else
        return $?
     fi
  fi
}

ipv4_to_hex() {
    local ip="$1"
    local hex_ip=""

    IFS='.' read -ra octets <<< "$ip"

    for octet in "${octets[@]}"; do
        hex_octet=$(printf "%02X" "$octet")
        hex_ip="${hex_ip}${hex_octet}"
    done

    echo "0x$hex_ip"
}


ipv6_to_hex() {
    local ipv6_address="$1"
    local hex_ip=""
    hex_ip=$(echo "$ipv6_address" | awk -F: '{ for(i=1; i<=NF; i++) printf "%s", $i } END { printf "\n" }')
    echo "0x$hex_ip"
}


vxlan_ipv4_capture() {
  echo "ip[12:4]=$IP_HEX or ip[16:4]=$IP_HEX or ip[62:4]=$IP_HEX or ip[64:4]=$IP_HEX"
}

ipip_ipv4_capture() {
  echo "ip[12:4]=$IP_HEX or ip[16:4]=$IP_HEX or ip[32:4]=$IP_HEX or ip[36:4]=$IP_HEX"
}


ipv6_check() {
  ipv6_regex="^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"
  [[ "$1" =~ $ipv6_regex ]] && return 0 || return 1
}


common_params() {
  local cmd=""
  if [ "$PACKAGE_COUNT" != "" ];then
      cmd="$cmd -c $PACKAGE_COUNT"
  fi
  if [ "$FILE_SIZE" != "" ];then
      cmd="$cmd -C $FILE_SIZE"
  fi
  if [ "$WRITE_FILE" != "" ];then
      cmd="$cmd -w $WRITE_FILE"
  fi
  echo "$cmd"
}


ipv4_check() {
  ipv4_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
  [[ "$1" =~ $ipv4_regex ]] && return 0 || return 1
}
OTHER_ARGS=""

while getopts "p:a:i:c:C:w:sh" opt; do
    case "$opt" in
        p)
            PROTOCOL="$OPTARG"
            ;;
        a)
            IP_ADDR="$OPTARG"
            ;;
        i)
            INTERFACE="$OPTARG"
            ;;
        c)
            PACKAGE_COUNT="$OPTARG"
            ;;
        C)
            FILE_SIZE="$OPTARG"
            ;;
        w)
            WRITE_FILE="$OPTARG"
            ;;
        s)
            SHOW_COMMAND="true"
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))


declare -a options

for arg in "$@"; do
  options+=("$arg")
done

for ((i=0; i<${#options[@]}; i++)); do
  OTHER_ARGS="$OTHER_ARGS ${options[$i]}"
done




if ! ip_check "$IP_ADDR"; then
  echo "invalid ip address: $IP_ADDR"
  usage
  exit 1
fi

BASECMD="tcpdump -Nni $INTERFACE -s0 -vvv "


case "$PROTOCOL" in
    "vxlan")
        CMD=$BASECMD" $(vxlan_ipv4_capture) $(common_params) $OTHER_ARGS"
        ;;
    "ipip")
        CMD=$BASECMD" $(ipip_ipv4_capture) $(common_params) $OTHER_ARGS"
        # 在此处编写选项 B 的逻辑
        ;;
    *)
        echo "unsupported protocol"
        usage
        ;;
esac




if [ "$SHOW_COMMAND" == "true" ];then
  echo "$CMD"
else
  ${CMD}
fi