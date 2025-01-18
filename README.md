# SUSE Edge for Telco examples

This repository contains some examples of how to deploy SUSE Edge for Telco (formerly known as ATIP) in different environments.

##  Components

- [Management Cluster](./telco-examples/mgmt-cluster)
- [Edge Cluster](./telco-examples/edge-clusters)

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
- AARCH64 architecture (Tech Preview for full e2e, mgmt-cluster and downstream clusters using aarch64 architecture)
