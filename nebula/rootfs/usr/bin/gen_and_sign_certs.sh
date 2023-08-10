#!/bin/bash

# This is an approximate draft of what the cert generation and signing process will look like. See the temporary hosts.txt format at the bottom to use.

# Run this script in a folder you want to generate the ca and node folders in

set -o xtrace

# Made up values for testing, later these will come from Hass config
ca_name=${ca_name:-TestNet}
ca_duration=${ca_duration:-26280h}
ip_range=${ip_range:-192.168.99}
subnet_mask=${subnet_mask:-24}

# When you re-run, if it already exists it will just refuse to overwrite and move on
mkdir -p ca
pushd ca
nebula-cert ca -name "${ca_name}" -duration ${ca_duration}
popd

# The same for these. It's safe to re-run this repeatedly as needed
index=1
while read line; do
  name=$(echo $line | cut -f1 -d" " | cut -f1 -d";")
  unset optional_ip
  optional_ip=$(echo $line | cut -f1 -d" " | cut -f2 -d";")
  groups=$(echo $line | cut -f2 -d" ")
  extra_args=$(echo $line | cut -f3- -d" ")
  out_key_arg="-out-key ${name}.key"
  node_ip=${optional_ip:-${ip_range}.${index}}
  if [[ $extra_args == *"in-pub"* ]]; then
    out_key_arg=""
  fi
  mkdir -p $name
  pushd $name
  nebula-cert sign -name ${name} -ca-crt ../ca/ca.crt -ca-key ../ca/ca.key -ip ${ip_range}.${index}/${subnet_mask} -groups ${groups} $extra_args -out-crt ${name}.crt ${out_key_arg} -out-qr ${name}-qr.png
  popd
  ((index++))
done < hosts.txt

# Needs a hosts.txt formatted like:
# node_name;optional_node_ip nebula,groups,for,this,node -any extra -args to -pass
# Each line gets it's own IP, in order by the order of the list. 

# Again this is all still for testing, later it will be config-based.
