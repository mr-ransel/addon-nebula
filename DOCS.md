# Documentation

## Run modes:
### Quickstart - UI configured Lighthouse and Cert Authority
If you've never used nebula and don't have detailed custom configuration needs, this is where to start. 
- Turn on the `hass_is_lighthouse` and `hass_is_cert_authority` flags
- Fill in the other required fields based on the Configuration section below
- Specifically you'll need to choose:
  - The IP range for your new overlay network (`nebula_network_cidr`)
  - Any dynamic DNS or static IPs for your home assistant, as well as any ports you're forwarding from the internet (`hass_advertise_addrs`)
  - Configuration for the other nodes you want to place on your network (`node_list`)

### Slightly harder - Run your own Cert Authority or Lighthouse
#### Run your own CA
As a security best practice, it's best not to store all your keys and certificates in one place. Or perhaps you just already manage all your nebula certificates somewhere else.

- For this, you'll need to generate your own nebula certificates, keys etc elsewhere and place them in the `/ssl/nebula/nodes/{node_name}` and `/ssl/nebula/nodes/ca` folders 
- Then you can turn off the `hass_is_cert_authority` in the UI configuration
- The addon won't generate any certs, or keys, just use whatever keys you provide in the proper folders.

#### Run your own Lighthouses
If you already have your own nebula mesh running and don't want to use this add-on as a lighthouse, then you can host and configure your own lighthouse and just use this addon as a simple nebula node, or optionally use it as an easy way to generate your certificates.

- For this, all you need to do is turn off the `hass_is_lightouse` flag in the UI, and configure the `other_lighthouses` section and this node will link up to your existing lighthouses, as expected.

### Power User - Write your own config
If you already use nebula, or the existing templates just don't work for your usecase, you can always write your own config from scratch and ignore all the generated configs based on the UI.

- You may need to populate some dummy values in the UI just to get things moving
- Once you're ready, drop your config.yaml at `/ssl/nebula/config.yaml` and delete the symlink that may already be there. Any generated configs will be ignored and your configuration will take precedence.
- If you find it helpful, feel free to use the generated_config.yaml in the `nodes` folder and modify it as needed for your setup.

## Configuration
Sorry, bad news. I haven't gotten to totally documenting this yet, but you can look at the `nebula/examples/addon_config_example.yaml` and `config.yaml` files in this repo to see what the structure of the fields is and what they do.

I also haven't implemented the public_key field, so if you want to use that for cert generation, you'll need to put the public key in the `nodes` folder and reference it in the `extra_args` field instead.

## Required Config changes to forward traffic to non-nebula hosts:
- In your client(s) that you want to use to access HA, you'll need to add a `unsafe_route` clause to your nebula config that includes the IPs you want to access on your network using Nebula. (for example: `192.168.1.1/24` for the whole network, or `192.168.1.25/32` for _just_ home assistant)
- For the certificate you sign to be run by the home-assistant addon, you'll need to grant it that same subnet access, using the `nebula-cert` argument like `-subnets 192.168.1.1/24`, using `extra_args`

## Note:
- The base for this was initially frenck's wireguard add-on as a starting point then I built out an equivalent behavior for the nebula functionality.

## Handy Tooling
- There's a bash script included in `rootfs/usr/bin` that will generate and sign all the certificates you need for your nodes, as well as handle (very) rudimentary IP management on your overlay network. It reads a `hosts.txt` file and spits out folders with `.crt`,`.key` files and QR codes for easy consumption, without overwriting anything you already had in place.
