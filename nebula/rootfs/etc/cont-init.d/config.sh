#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Nebula
# Creates the interface configuration
# ==============================================================================

declare node_name
declare nebula_root_dir
declare generated_config
declare -i lighthouse_idx
declare overlay_ip
declare -i idx
declare addr
declare cidr
declare node_config_dir
declare nebula_interface_name
declare host_interface_name

### Setup basic directories and boilerplate checks

nebula_root_dir='/ssl/nebula'
node_config_dir="${nebula_root_dir}/nodes"

if ! bashio::fs.directory_exists ${node_config_dir}; then
    mkdir -p ${node_config_dir} ||
        bashio::exit.nok "Could not create nebula node storage folder! (${node_config_dir}) "
fi

if ! bashio::config.has_value 'addon_node_name'; then
    bashio::exit.nok 'You need to set a name for this node in the addon config.'
fi
node_name=$(bashio::config 'addon_node_name')

if ! bashio::fs.directory_exists "${node_config_dir}/${node_name}"; then
    mkdir -p "${node_config_dir}/${node_name}" ||
        bashio::exit.nok "Could not create node-data storage folder for this node! (${node_config_dir}/${node_name})"
fi

# TODO: Before this check is where we need to generate certs
if ! bashio::fs.file_exists "${node_config_dir}/${node_name}/${node_name}.crt" && \
    ! bashio::fs.file_exists "${node_config_dir}/${node_name}/${node_name}.key" && \
    ! bashio::fs.file_exists "${node_config_dir}/ca/ca.crt"; then
    bashio::exit.nok "Missing a host.crt, host.key, or ca.crt in ${node_config_dir}"
fi

### Generate generated_nebula_config.yaml here

# Put the base template in place
generated_config="${node_config_dir}/${node_name}/generated_nebula_config.yaml"
cp "/etc/generated_config.tmpl.yaml" "${generated_config}" ||
  bashio::exit.nok "Couldn't place nebula config template! (${generated_config})"

# Write out paths for CA, Certificate and key for this node
yq --inplace '.pki.ca = "${node_config_dir}/ca/ca.crt"' ${generated_config}
yq --inplace '.pki.cert = "${node_config_dir}/${node_name}/${node_name}.crt"' ${generated_config}
yq --inplace '.pki.key = "${node_config_dir}/${node_name}/${node_name}.key"' ${generated_config}

# Set other_lighthouses list as static_hosts
lighthouse_idx=-1 # This is a trick so if there are none the first one is popluated in the next clause
for lighthouse_idx in $(bashio::config 'other_lighthouses|keys'); do
    overlay_ip=$(bashio::config "other_lighthouses[${lighthouse_idx}].overlay_ip")
    addr=$(bashio::config "other_lighthouses[${lighthouse_idx}].public_addr_and_port")

    # TODO: This currently only supports a single address per lighthouse (though nebula supports multiple)
    # (it's because of the [0]. Needs a sub loop over each item and needs public_addr_and_port to be a list)
    index=${lighthouse_idx} overlay_ip=${overlay_ip} public_addr=${addr} \
      yq --inplace '.static_host_map.[strenv(overlay_ip)][0] = strenv(public_addr) | .static_host_map.[strenv(overlay_ip)][0] style="double"' \
      ${generated_config}
    
    # Set the list of `.lighthouse.hosts` while we're iterating over this
    if bashio::config.false 'addon_is_lighthouse'; then
        index=${lighthouse_idx} overlay_ip=${overlay_ip} yq --inplace '.lighthouse.hosts[env(index)] = strenv(overlay_ip)' ${generated_config}
    fi
done
# TODO: This may or may not break if addon_is_lighthouse is true, and there are no other_lighthouses
# (Probably fine, but it's because static_host_map is uninitialized and also not an array)

# If a lighthouse, add self to static_host_map
# TODO: This assumes this node is item 0 in the node_list AND has a defined overlay_ip
# would need another way to get generated IPs and to pick out a specific node name from the list
if bashio::config.true 'addon_is_lighthouse'; then
    for idx in $(bashio::config 'node_list|keys'); do
        overlay_ip=$(bashio::config "node_list[${idx}].overlay_ip")
        # TODO: Make this support more than the just the first advertise_addrs item
        # (loop over advertise_addrs and assign them separately)
        public_addr=$(bashio::config "advertise_addrs[0]")
        # Note, this exploits incrementing the index of the previous loop - ${lightouse}
        index=$((${lighthouse_idx}+1)) overlay_ip=${overlay_ip} public_addr=${public_addr} \
          yq --inplace '.static_host_map.[strenv(overlay_ip)][env(index) ] = strenv(public_addr) | .static_host_map.[strenv(overlay_ip)][env(index)] style="double"' \
          ${generated_config}
        break;
    done
fi

# Set lighthouse settings
if bashio::config.true 'addon_is_lighthouse'; then
    yq --inplace '.lighthouse.am_lighthouse = true' ${generated_config}

    # Delete advertise_addrs
    yq --inplace 'del(.lighthouse.advertise_addrs)' ${generated_config}
else
    # Note, the list of "other_lighthouses" is added to .lighthoues.hosts above
    yq --inplace '.lighthouse.am_lighthouse = false' ${generated_config}

    # Set each of advertise_addrs
    for idx in $(bashio::config 'advertise_addrs|keys'); do
        addr=$(bashio::config "advertise_addrs[${idx}]")
        index=${idx} addr=${addr} \
          yq --inplace '.lighthouse.advertise_addrs[env(index)] = strenv(addr) | .lighthouse.advertise_addrs[env(index)] style="double"' \
          ${generated_config}
    done
fi

# TODO: Need to make sure nebula accepts this field being empty (if not provided in config)
# Set each of preferred_ranges
for idx in $(bashio::config 'preferred_route_cidrs|keys'); do
    cidr=$(bashio::config "preferred_route_cidrs[${idx}]")
    index=${idx} cidr=${cidr} yq --inplace '.preferred_ranges[env(index)] = strenv(cidr)' ${generated_config}
done

# Render any embedded template variables
node_config_dir="${node_config_dir}" node_name="${node_name}" \
  yq --inplace '(.. | select(tag == "!!str")) |= envsubst' ${generated_config}

if bashio::fs.file_exists "${nebula_root_dir}/config.yaml"; then
    bashio::log.warning "Custom nebula config.yaml detected, ignoring generated nebula configuration!"
else
    ln -s "${nebula_root_dir}/generated_config.yaml" "${nebula_root_dir}/config.yaml"
fi

### Generate nodelist, certs and keys


### Setup the routing rules for Nebula traffic
# Set the iptables rules necessary for traffic forwarding between other devices on the network
nebula_interface_name=nebula1
host_interface_name=eth0
iptables -A FORWARD -i "${nebula_interface_name}" -j ACCEPT
iptables -A FORWARD -o "${nebula_interface_name}" -j ACCEPT
iptables -t nat -A POSTROUTING -o "${host_interface_name}" -j MASQUERADE

## Development stages
# First just point at a folder for nebula config and files named host.key, host.crt, and ca.crt
  # This could be either a lighthouse or regular node
# Second, allow this to stand itself up as a lighthouse, (or signing regular node I guess)
  # Requires User to config as either a signer, or non-signer (can still be lighthouse)
  # Generates Nebula certs and config from basic UI decisions (probably a template + yq to mutate values)
  # if config.yaml (vs generated_config.yaml) exists, use it instead of any generated values

# Ideal state:
# Can be either a signing or non-signing node, as either a lighthouse or non-lighthouse (leveraging dynamic DNS)
# In all signer-configurations can handle exporting certs to other network nodes, as well as incrementing IP management

# Configuration modes:
  # Lighthouse, or no
  # Signer of other nodes, or no
  # Provide your own config, or use a generated config