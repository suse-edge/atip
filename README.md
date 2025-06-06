# SUSE Edge for Telco examples

This repository contains some examples of how to deploy SUSE Edge for Telco (formerly known as ATIP) in different environments.

##  Releases

This repository is organized into release branches. Each release contains a set of examples that are compatible with a specific version of SUSE Edge for Telco.
The following branches (releases) are available:

- `main`: The latest development version of SUSE Edge for Telco.
- `release-3.0`: [Release 3.0 of SUSE Edge for Telco](https://github.com/suse-edge/atip/tree/release-3.0)
- `release-3.1`: [Release 3.1 of SUSE Edge for Telco](https://github.com/suse-edge/atip/tree/release-3.1)
- `release-3.2`: [Release 3.2 of SUSE Edge for Telco](https://github.com/suse-edge/atip/tree/release-3.2)
- `release-3.3`: [Release 3.3 of SUSE Edge for Telco](https://github.com/suse-edge/atip/tree/release-3.3)

## Scenarios

Note that ipv6, dual-stack and aarch64 scenarios are currently tech-preview and not yet fully supported.

- Single-node Clusters
- Multi-node Clusters
- DHCP Network scenarios, single or dual-stack
- DHCP-less Network scenarios, single or dual-stack
- Air gap scenarios for management cluster
- Additional cacerts to use external TLS file server for managment cluster (to server images over HTTPS)
- Air gap scenarios for downstream clusters
- CPU Manager scenarios
- AARCH64 architecture:
  1. Tech Preview for full aarch64 e2e, mgmt-cluster and downstream clusters using aarch64 architecture
  2. x86_64 Management clusters to deploy only aarch64 downstream clusters
