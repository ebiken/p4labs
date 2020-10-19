#! /bin/bash

# This script will create(remove) veth/host attached to namespace
# and corresponding tap interface.
# Original script was written by Tohru Kitamura. Thanks!!

if [[ $(id -u) -ne 0 ]] ; then echo "Please run with sudo" ; exit 1 ; fi

set -e

if [ -n "$SUDO_UID" ]; then
    uid=$SUDO_UID
else
    uid=$UID
fi

run () {
    echo "$@"
    "$@" || exit 1
}

silent () {
    "$@" 2> /dev/null || true
}

create_network () {
    echo "create_network $NUM"
    for ((num=1; num<($NUM+1); num++))
    do
        HOST="host$num"
        VETH="veth$num"
        VTAP="vtap$num"
        echo "creating $HOST $VETH $VTAP 172.20.0.$num/24 db8::$num/64"
        # Create network namespaces
        run ip netns add $HOST
        # Create veth and assign to host
        run ip link add $VETH type veth peer name $VTAP
        run ip link set $VETH netns $HOST
        # Set MAC/IPv4/IPv6 address
        # > change mac/ipv6 $num to hex to create more than 99 interfaces
        # > for "9<$num", mac/ipv6 numbering is not sequencial: 0x10 will be used after 0x9
        run ip netns exec $HOST ip link set $VETH address 02:03:04:05:06:$num
        run ip netns exec $HOST ip addr add 172.20.0.$num/24 dev $VETH
        run ip netns exec $HOST ip -6 addr add db8::$num/64 dev $VETH
        # Link up loopback/veth/vtap
        run ip netns exec $HOST ip link set $VETH up
        run ip netns exec $HOST ifconfig lo up
        run ip link set dev $VTAP up
    done
    exit 1
}

destroy_network () {
    echo "destroy_network $NUM"
    for ((num=1; num<($NUM+1); num++))
    do
        HOST="host$num"
        #veth will be removed when pair vtap is deleted
        #VETH="veth$num"
        VTAP="vtap$num"
        run ip link del dev $VTAP
        run ip netns del $HOST
    done
    exit 1
}

while getopts "c:d:" ARGS;
do
    case $ARGS in
    c ) 
        NUM=$OPTARG
        create_network
        exit 1;;
    d ) 
        NUM=$OPTARG
        destroy_network
        exit 1;;
    esac
done

cat << EOF
usage: sudo ./$(basename $BASH_SOURCE) <option>
option:
    -c <num> : create_network with <num> hosts
    -d <num>: destroy_network with <num> hosts
Note:
    IPv4 address will be 172.20.0.<num>/24
    Max number of <num> is 99
EOF
