#!/bin/bash



# Run this script in a folder where you want to generate the ca and node folders

# Needs a hosts.txt in the same folder formatted like:
# node_name;optional_node_ip nebula,groups,for,this,node -any extra -args to -pass
# If not provided, each line/host gets it's own IP, in the order of the list.

# Quirk: If you don't pass any nebula groups, you can't use extra_args

#set -o xtrace

# Pull these from environment variables, otherwise fallback to some kind of default value
ca_name=${ca_name:-TestNet}
ca_duration=${ca_duration:-26280h}
ip_range=${ip_range:-192.168.99}
subnet_mask=${subnet_mask:-24}

# When you re-run, if it already exists it will just refuse to overwrite and move on
mkdir -p ca
pushd ca
(set -x; nebula-cert ca -name "${ca_name}" -duration ${ca_duration} -out-qr "ca-qr.png")
popd


# The same for these. It's safe to re-run this repeatedly as needed
index=1
while read line; do
  name=$(echo $line | cut -f1 -d" " | cut -f1 -d";")
  unset optional_ip
  optional_ip=$(echo $line | cut -f1 -d" " | cut -s -f2 -d";")
  groups=$(echo $line | cut -s -f2 -d" ")
  extra_args=$(echo $line | cut -s -f3- -d" ")
  groups_arg="-groups ${groups}"
  # TODO: there's definitely a prettier way to do a lot of this loop
  if [[ -z ${groups} ]]; then
    groups_arg=""
  fi
  out_key_arg="-out-key ${name}.key"
  node_ip=${optional_ip:-${ip_range}.${index}}
  if [[ $extra_args == *"in-pub"* ]]; then
    out_key_arg=""
  fi
  mkdir -p $name
  pushd $name
  (set -x; nebula-cert sign -name ${name} -ca-crt ../ca/ca.crt -ca-key ../ca/ca.key -ip ${node_ip}/${subnet_mask} ${groups_arg} $extra_args -out-crt ${name}.crt ${out_key_arg} -out-qr ${name}-qr.png)
  popd
  ((index++))
done < hosts.txt
