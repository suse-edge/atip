# SUSE ATIP

This repository contains some examples of how to deploy SUSE ATIP on different environments.

##  Components

- [Management Cluster](./telco-examples/mgmt-cluster)
- [Edge Cluster](./telco-examples/edge-clusters)

## Scenarios

- Single-node Clusters
- Multi-node Clusters
- DHCP Network scenarios, single or dual-stack
- DHCP-less Network scenarios, single or dual-stack
- Air gap scenarios for management cluster
- Additional cacerts to use external TLS file server for managment cluster (to server images over HTTPS)
- Air gap scenarios for downstream clusters
- CPU Manager scenarios
- AARCH64 architecture (Tech Preview for full e2e, mgmt-cluster and downstream clusters using aarch64 architecture)
