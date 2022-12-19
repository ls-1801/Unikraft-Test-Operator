#!/bin/bash
set -x

_setup_networking()
{
    sudo ip link set dev virbr0 down
    sudo ip link del dev virbr0
    sudo ip link add virbr0 type bridge
    sudo ip address add 172.44.0.3/24 dev virbr0
    sudo ip link set dev virbr0 up
}

_setup_networking
kraft run -b virbr0 "netdev.ipv4_addr=172.44.0.2 netdev.ipv4_gw_addr=172.44.0.1 netdev.ipv4_subnet_mask=255.255.255.0 --"