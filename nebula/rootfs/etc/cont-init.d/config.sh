#!/command/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Nebula
# Creates the interface configuration
# ==============================================================================

declare node_name
declare nebula_root_dir
declare node_config_dir

nebula_root_dir='/ssl/nebula'
node_config_dir="${nebula_root_dir}/nodes"

if ! bashio::fs.directory_exists ${node_config_dir}; then
    mkdir -p ${node_config_dir} ||
        bashio::exit.nok "Could not create nebula node storage folder!"
fi

if ! bashio::fs.file_exists "${nebula_root_dir}/config.yaml"; then
    bashio::exit.nok "Missing a nebula config.yaml!"
fi

if ! bashio::config.has_value 'node_name'; then
    bashio::exit.nok 'You need to set a name for this node in the addon config.'
fi
node_name=$(bashio::config 'node_name')

if ! bashio::fs.directory_exists "${node_config_dir}/${node_name}"; then
    mkdir -p "${node_config_dir}/${node_name}" ||
        bashio::exit.nok 'Could not create node-data storage folder for this node!'
fi

if ! bashio::fs.file_exists "${node_config_dir}/${node_name}/host.crt" && \
    ! bashio::fs.file_exists "${node_config_dir}/${node_name}/host.key" && \
    ! bashio::fs.file_exists "${node_config_dir}/${node_name}/ca.crt"; then
    bashio::exit.nok "Missing a host.crt, host.key, or ca.crt in this nodes data folder"
fi

## Things we'll need
# Nebula config yaml
# Host Key
# Host Certificate
# CA Certificate




## Development stages
# First just point at a folder for nebula config and files named host.key, host.crt, and ca.crt
  # This could be either a lighthouse or regular node
# Second, allow this to stand itself up as a lighthouse, (or signing regular node I guess)
  # Requires User to config as either a signer, or non-signer (can still be either rlighthouse)
  # Generates Nebula certs and config from basic UI decisions (probably a template + yq to mutate values)
  # if config.yaml (vs generated_config.yaml) exists, use it instead of any generated values


# Ideal state:
# Can be either a signing or non-signing node, as either a lighthouse or non-lighthouse (leveraging dynamic DNS)
# In all signer-configurations can handle exporting certs to other network nodes, as well as incrementing IP management

# Configuration modes:
  # Lighthouse, or no
  # Signer of other nodes, or no
  # Provide your own config, or use a generated config