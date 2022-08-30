# addon-nebula
Home Assistant addon for slackhq/nebula

This is still a heavy work in progress and hasn't really be thoroughly tested.

For the most basic of documentation if you want to try it out:
- Install the `nebula` folder in your local `/addons` folder
- Drop your nebula `config.yaml` into `/ssl/nebula/config.yaml`
- Drop your cert, key and ca cert into `/ssl/nebula/nodes/homeassistant/(host.crt|host.key|ca.crt)` and set those paths in your nebula `config.yaml` accordingly
- Restart HA, install the local addon, boot it up and see if it works!
- Let me know if something interesting, exciting or terrible happens
