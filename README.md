# addon-nebula
Home Assistant addon for slackhq/nebula

This is still a heavy work in progress and hasn't really be thoroughly tested.

For the most basic of documentation if you want to try it out:
- Install the `nebula` folder in your local `/addons` folder
- Drop your nebula `config.yaml` into `/ssl/nebula/config.yaml`
- Drop your cert, key and ca cert into `/ssl/nebula/nodes/homeassistant/(host.crt|host.key|ca.crt)` and set those paths in your nebula `config.yaml` accordingly
- Restart HA, install the local addon, boot it up and see if it works!
- Let me know if something interesting, exciting or terrible happens


Required Config changes:
- In your client(s) that you want to use to access HA, you'll need to add a `unsafe_route` clause to your nebula config that includes the IPs you want to access on your network using Nebula. (for example: 192.168.1.1/24 for the whole network, or 192.168.1.25/32 for _just_ home assistant)
- For the certificate you sign to be run by the home-assistant addon, you'll need to grant it that same subnet access, using the `nebula-cert` argument like `-subnets 192.168.1.1/24` 

Note:
- This is largely a ripoff of frenck's wireguard add-on as a starting point then I built out an equivalent behavior for the nebula basics. 
- Later I'll come back and set it up as a lighthouse, cert signer automation and convert the basic config.yaml into UI configurable stuff in HA
