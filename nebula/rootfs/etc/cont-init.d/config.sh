#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Nebula
# Creates the interface configuration
# ==============================================================================

declare nebula_root_dir
declare node_config_dir
declare node_name
declare -i idx
declare overlay_ip
declare nebula_groups
declare extra_args
declare nebula_network
declare ip_base
declare subnet_mask
declare generated_config
declare -i lighthouse_idx
declare hass_overlay_ip
declare addr
declare cidr
declare nebula_interface_name
declare host_interface_name
declare hass_underlay_ip

### Setup basic directories and boilerplate checks

nebula_root_dir='/ssl/nebula'
node_config_dir="${nebula_root_dir}/nodes"

if ! bashio::fs.directory_exists ${node_config_dir}; then
    mkdir -p ${node_config_dir} ||
        bashio::exit.nok "Could not create nebula node storage folder! (${node_config_dir}) "
fi

if ! bashio::config.has_value 'hass_node_name'; then
    bashio::exit.nok 'You must set a hass_node_name for this node in the addon config.'
fi
node_name=$(bashio::config 'hass_node_name')

if ! bashio::fs.directory_exists "${node_config_dir}/${node_name}"; then
    mkdir -p "${node_config_dir}/${node_name}" ||
        bashio::exit.nok "Could not create node-data storage folder for this node! (${node_config_dir}/${node_name})"
fi

### Generate Certs from node_list

# See if we are acting as the cert authority
if bashio::config.true 'hass_is_cert_authority'; then
    pushd ${node_config_dir}

    # Build hosts.txt
    if bashio::fs.file_exists 'hosts.txt'; then
        rm hosts.txt
    fi

    bashio::log.notice 'Re-generating any missing certs for the following node configurations:'
    for idx in $(bashio::config 'node_list|keys'); do
        if bashio::config.has_value "node_list[${idx}].overlay_ip"; then
            overlay_ip=$(bashio::config "node_list[${idx}].overlay_ip")
        else
            overlay_ip=""
        fi

        if bashio::config.has_value "node_list[${idx}].groups"; then
            nebula_groups=$(bashio::config "node_list[${idx}].groups")
        else
            nebula_groups=""
        fi

        if bashio::config.has_value "node_list[${idx}].extra_args"; then
            extra_args=$(bashio::config "node_list[${idx}].extra_args")
        else
            extra_args=""
        fi

        # TODO: Add support and config for the public_key field
        # For now instead you can put it in extra-args and drop the key in the folder
        bashio::log "$(bashio::config "node_list[${idx}].name");${overlay_ip} ${nebula_groups} ${extra_args}"
        echo "$(bashio::config "node_list[${idx}].name");${overlay_ip} ${nebula_groups} ${extra_args}" >> hosts.txt
    done

    bashio::log 
    bashio::log "Generating certs..."
    nebula_network=$(bashio::config 'nebula_network_cidr')
    # TODO: This currently limits cidr ranges to beginning a subnet with X.X.X.1 - Might need real IP math one day
    ip_base=$(echo ${nebula_network} | cut -f1-3 -d.)
    subnet_mask=$(echo ${nebula_network} | cut -f2 -d/)
    
    ca_name=HassNet ca_duration=$(bashio::config 'cert_expiry_time') \
      ip_range=${ip_base} subnet_mask=${subnet_mask} \
      gen_and_sign_certs.sh

    popd
else
    bashio::log.warning \
      "Nebula add-on is not configured as certificate authority. You must generate and place certificates for this node and the CA in ${node_config_dir}/${node_name}/${node_name}.(crt|key) and /ca/ca.crt"
fi

if ! bashio::fs.file_exists "${node_config_dir}/${node_name}/${node_name}.crt" && \
    ! bashio::fs.file_exists "${node_config_dir}/${node_name}/${node_name}.key" && \
    ! bashio::fs.file_exists "${node_config_dir}/ca/ca.crt"; then
    bashio::exit.nok "Missing a ${node_name}.crt, ${node_name}.key, or ca.crt in ${node_config_dir}"
fi

### Generate generated_nebula_config.yaml here
bashio::log 'Generating a config.yaml'
# Put the base template in place
generated_config="${node_config_dir}/${node_name}/generated_nebula_config.yaml"
cp "/etc/generated_config.tmpl.yaml" "${generated_config}" ||
  bashio::exit.nok "Couldn't place nebula config template! (${generated_config})"

# Write out paths for CA, Certificate and key for this node
yq --inplace '.pki.ca = "${node_config_dir}/ca/ca.crt"' ${generated_config}
yq --inplace '.pki.cert = "${node_config_dir}/${node_name}/${node_name}.crt"' ${generated_config}
yq --inplace '.pki.key = "${node_config_dir}/${node_name}/${node_name}.key"' ${generated_config}

# Set other_lighthouses list as static_hosts
for lighthouse_idx in $(bashio::config 'other_lighthouses|keys'); do
    overlay_ip=$(bashio::config "other_lighthouses[${lighthouse_idx}].overlay_ip")
    addr=$(bashio::config "other_lighthouses[${lighthouse_idx}].public_addr_and_port")

    # TODO: This currently only supports a single address per lighthouse (though nebula supports multiple)
    # (it's because of the [0]. Needs a sub loop over each item and needs public_addr_and_port to be a list)
    index=${lighthouse_idx} overlay_ip=${overlay_ip} public_addr=${addr} \
      yq --inplace '.static_host_map.[strenv(overlay_ip)][0] = strenv(public_addr) | .static_host_map.[strenv(overlay_ip)][0] style="double"' \
      ${generated_config}
    
    # Set the list of `.lighthouse.hosts` while we're iterating over this
    if bashio::config.false 'hass_is_lighthouse'; then
        index=${lighthouse_idx} overlay_ip=${overlay_ip} yq --inplace '.lighthouse.hosts[env(index)] = strenv(overlay_ip)' ${generated_config}
    fi
done

# Set lighthouse settings
if bashio::config.true 'hass_is_lighthouse'; then
    bashio::log.notice \
      "Hass is being configured as a lighthouse. If you don't have others, make sure you've configured DynamicDNS or a static IP and port for hass_advertise_addrs"
    # Add self to the static_host_map
    # TODO: This assumes this node is item 0 in the node_list AND has a defined overlay_ip
    # Need to grab the generated IP from the nebula cert for this node instead
    for idx in $(bashio::config 'node_list|keys'); do
        hass_overlay_ip=$(bashio::config "node_list[${idx}].overlay_ip")
        # TODO: Make this support more than the just the first hass_advertise_addrs item
        # (loop over hass_advertise_addrs and assign them separately by index)
        public_addr=$(bashio::config "hass_advertise_addrs[0]")
        index=0 overlay_ip=${hass_overlay_ip} public_addr=${public_addr} \
          yq --inplace '.static_host_map.[strenv(overlay_ip)][env(index) ] = strenv(public_addr) | .static_host_map.[strenv(overlay_ip)][env(index)] style="double"' \
          ${generated_config}
        break;
    done

    yq --inplace '.lighthouse.am_lighthouse = true' ${generated_config}

    # Delete advertise_addrs
    yq --inplace 'del(.lighthouse.advertise_addrs)' ${generated_config}
else
    # Note, the list of "other_lighthouses" is added to .lighthouse.hosts above
    yq --inplace '.lighthouse.am_lighthouse = false' ${generated_config}

    # Set each of hass_advertise_addrs
    for idx in $(bashio::config 'hass_advertise_addrs|keys'); do
        addr=$(bashio::config "hass_advertise_addrs[${idx}]")
        index=${idx} addr=${addr} \
          yq --inplace '.lighthouse.advertise_addrs[env(index)] = strenv(addr) | .lighthouse.advertise_addrs[env(index)] style="double"' \
          ${generated_config}
    done
fi

# Set each of preferred_ranges (usually just the local network)
for idx in $(bashio::config 'preferred_route_cidrs|keys'); do
    cidr=$(bashio::config "preferred_route_cidrs[${idx}]")
    index=${idx} cidr=${cidr} yq --inplace '.preferred_ranges[env(index)] = strenv(cidr)' ${generated_config}
done

# Render any embedded template variables
node_config_dir="${node_config_dir}" node_name="${node_name}" \
  yq --inplace '(.. | select(tag == "!!str")) |= envsubst' ${generated_config}

if ! bashio::fs.file_exists "${nebula_root_dir}/config.yaml" && [ ! -L "${nebula_root_dir}/config.yaml" ]; then
    bashio::log.notice "No config.yaml or symlink detected; symlinking config.yaml to the node's generated_config.yaml"
    ln -s "${nebula_root_dir}/${node_name}/generated_config.yaml" "${nebula_root_dir}/config.yaml"
elif [ -L "${nebula_root_dir}/config.yaml" ]; then
    bashio::log.notice "Using the symlinked generated_config.yaml"
else
    bashio::log.notice "Custom nebula config.yaml detected, ignoring generated nebula configuration!"
fi


bashio::log "Setting up IP Forwarding and iptables rules..."
### Setup the routing rules for Nebula traffic
# Set the iptables rules necessary for traffic forwarding between other devices on the network
# TODO: Make this optionally configurable
nebula_interface_name=nebula1
host_interface_name=eth0
hass_underlay_ip=$(dig +short homeassistant)

if [[ $(</proc/sys/net/ipv4/ip_forward) -eq 0 ]]; then
    bashio::log.warning
    bashio::log.warning "IP forwarding is disabled on the host system!"
    bashio::log.warning "You can still use Nebula to access homeassistant"
    bashio::log.warning "however, you cannot access nodes on your home"
    bashio::log.warning "network that aren't running nebula themselves"
    bashio::log.warning
else
    # Accept traffic on the nebula interface not destined for this node's IPs
    iptables --append FORWARD --in-interface "${nebula_interface_name}" --jump ACCEPT
    # Accept traffic exiting the nebula interface not destined for this node's IPs
    iptables --append FORWARD --out-interface "${nebula_interface_name}" --jump ACCEPT
    # After routing, nat+masquerade the packets to their destinations on the non-nebula network
    iptables --table nat --append POSTROUTING \
      --out-interface "${host_interface_name}" \
      --jump MASQUERADE
fi

# TODO: This is annoying syntax, need a better way to look this up
for idx in $(bashio::config 'node_list|keys'); do
    hass_overlay_ip=$(bashio::config "node_list[${idx}].overlay_ip")
    break
done

# This host should route traffic coming to the nebula interface+IP to the host IP to reach hass services via the nebula IP
iptables --table nat --append PREROUTING \
  --in-interface "${nebula_interface_name}" --destination ${hass_overlay_ip} \
  --jump DNAT --to-destination ${hass_underlay_ip}
