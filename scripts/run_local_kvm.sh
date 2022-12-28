#!/bin/bash
set -x

_setup_networking()
{
    sudo brctl addbr kraft0
    sudo ifconfig kraft0 172.44.0.1
    sudo ifconfig kraft0 up
}

_setup_networking
sudo dnsmasq -d \
        --log-queries \
        --bind-dynamic \
        --interface=kraft0 \
        --listen-addr=172.44.0.1 \
        --dhcp-range=172.44.0.2,172.44.0.254,255.255.255.0,12h &> $WORKDIR/dnsmasq.log &

./qemu-guest.sh disk.raw \
                -b kraft0 \
                -m 100