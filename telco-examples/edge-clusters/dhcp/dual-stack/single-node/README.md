# Edge clusters with dual-stack networking

## Introduction

This directory contains some sample CAPI manifest files that enable the creation of Edge clusters where the bare metal hosts, and the executing containers on top, are connected through both IPv4 and IPv6, with the following characteristics:
- single host scenario
- DHCP autoconfiguration for IPv4
- various autoconfiguration approaches for IPv6

This implies provisioning a bare metal host with a dual-stack network configuration first, through one of the provided BareMetalHost definitions, and a properly configured Kubernetes cluster, through Cluster and RKE2ControlPlane definitions according to the desidered CNI provider and setup. Both aspects are covered in the following two sections.


## BareMetalHost (BMH) examples

The BMH definitions can be found within the `bmh-example_*.yaml` files. While the same DHCP configuration is applied for IPv4, each file provides different IPv6 configuration approaches (which may require mode specific information), as described below:

- `bmh-example_v4dhcp-v6dhcp+route.yaml` - use in environments where Router Advertisements (RAs) are not enabled in the network (or should not be used) and IPv6 should only rely on DHCP for the address and DNS servers; note that a default route must also be provided.
    Requires:
        - `${CONTROLPLANE_GATEWAY_V6}` - the IPv6 address of the gateway for the traffic matching the default route
        - `${CONTROLPLANE_INTERFACE}` - the name of the interface to be used for the egressing traffic matching the default route

- `bmh-example_v4dhcp-v6ra+dhcp.yaml` - both RAs and DHCP are enabled for autoconfiguration, resulting in a SLAAC deduced address and default route assignments, and DNS reception from DHCP (when not optionally provided by the RAs); this is most likely the only configuration you will ever need, as no further input is required.

- `bmh-example_v4dhcp-v6ra+dhcp_v4v6dns.yaml` - this configuration is identical to the `bmh-example_v4dhcp-v6ra+dhcp.yaml` above, with the exception of statically provided DNS servers; it can be useful in networks where only RAs are avaiable but with no DNS option.
     Requires:
         - `${DNS_SERVER_V4}` and/or `${DNS_SERVER_V6}` - the IP address(es) of the DNS server(s) to use, as a single or multiple entries; both IPv4 and/or IPv6 addresses can be specified

**Note**:
 * Due to limitations in [nmstate](https://nmstate.io/devel/yaml_api.html#ipv6-autoconf), it is not possible to enable SLAAC but disable DHCPv6; for this reason DHCP will always be enabled in the provided examples.
 * The network configuration will only apply to the provisioned BMH and not yet on the inspection phase of the host to gather hardware information. This is due to a bug that will force the use of DHCP and RA for IPv4 and IPv6 respectively with the default settings; a resolution is espected in the coming weeks.

Once the required BMH file has been selected and refined, in order for it to work, it must also be filled with some values common to all the BMH definitions in addition to the network specific ones previously mentioned. For more information on these values or on how to enroll a Bare Metal Host, please refer to the main Edge Cluster documentation for single host deployments [here](https://github.com/suse-edge/atip/tree/main/telco-examples/edge-clusters#example-1---deploy-a-single-node-edge-cluster-with-the-image-generated-and-telco-profiles).


## Cluster definitions

The CAPI cluster definitions to be applied once the bare metal host has been inspected and is available for provisioning, are organized into two directories, depending on whether a single CNI plugin is sufficient or if multihomed Pods are required, through the use of the [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) meta-plugin. Note that the use of the SR-IOV plugin along with Multus is of course possible but not covered, as it doesn't require any specific IPAM configuration.

The definition files come with any CNI plugin specific configuration that may be required and are organized as follow:

- `single-cni`:
    | Filename                               | Primary CNI | Primary IPAM |
    |:---------------------------------------|:-----------:|:------------:|
    | `cluster-v4v6-calico.yaml`             |    Calico   |    Calico    |
    | `cluster-v4v6-canal.yaml`              |    Canal    |     Canal    |
    | `cluster-v4v6-cilium.yaml`             |    Cilium   |    Cilium    |

- `multus-cni`:
    | Filename                               | Primary CNI | Primary IPAM | Secondary CNI | Secondary IPAM |
    |:---------------------------------------|:-----------:|:------------:|:-------------:|:--------------:|
    | `cluster-v4v6-calico_hostlocal.yaml`   |    Calico   |    Calico    |      PTP      |   host-local   |
    | `cluster-v4v6-calico_whereabouts.yaml` |    Calico   |    Calico    |      PTP      |   whereabouts  |
    | `cluster-v4v6-canal_hostlocal.yaml`    |    Canal    |     Canal    |      PTP      |   host-local   |
    | `cluster-v4v6-canal_whereabouts.yaml`  |    Canal    |     Canal    |      PTP      |   whereabouts  |
    | `cluster-v4v6-cilium_hostlocal.yaml`   |    Cilium   |    Cilium    |      PTP      |   host-local   |
    | `cluster-v4v6-cilium_whereabouts.yaml` |    Cilium   |    Cilium    |      PTP      |   whereabouts  |

    **Note**:
    * The Multus examples leverage the [Point-to-Point plugin](https://www.cni.dev/plugins/current/main/ptp/) for the secondary interface due to its simplicity and ease of testing. Do not forget to replace the CNI configuration within the manifest according to your operational needs.
    * Regardless of the address management method for the secondary interface, make sure to update the network blocks within the manifest according to your operational needs.

Regardless of the selected file, it should be edited to define at least the following values:
- `${EDGE_CONTROL_PLANE_IP_V4}` - the IPv4 address to be used as the endpoint for the edge cluster (should match with the kubeapi-server endpoint)
- `${EDGE_CONTROL_PLANE_IP_V6}` - the additional IPv6 address the edge cluster is reacheable from (should match with the kubeapi-server endpoint)
- `${RKE2_VERSION}` - the RKE2 version to be installed during the provisioning by CAPI
- `http://imagecache.local:8080/eibimage-slmicro60rt.raw` - the URL where the generated EIB image can be located and downloaded during the provisioning; the checksum URL must be updated accordingly as well

It is also recommended that you change the following items:

- `RKE2ControlPlane.spec.agentConfig.nodeName` - the hostname that will be set on the host
- `Cluster.spec.clusterNetwork.pods.cidrBlocks` - a list containing the IPv4 and IPv6 networks that will be used for assigning addresses to PODs; the examples use RFC1918 and ULA ranges for IPv4 and IPv6 respectively, which may or may not be suitable for your environment
- `Cluster.spec.clusterNetwork.services.cidrBlocks` - a list containing the IPv4 and IPv6 networks that will be used for assigning addresses to Kubernetes Services; the examples use RFC1918 and ULA ranges for IPv4 and IPv6 respectively, which may or may not be suitable for your environment

**Note**:
* in a dual-stack scenario IPv4 CIDRs should always be provided as the first item of the list; this is due Kubernetes limitations.
* make sure to use Metal3 version 0.9.0 or higher on the management cluster

Note that containers will be provided with the `resolv.conf` file included in the manifest, you are invited to replace the nameservers according to your preferences or network infrastructure.

In addition to the above settings, the configurations files leveraging Multus are provided with a NetworkAttachmentDefinition that uses private addresses and should be configured with the correct networks for your environment.

Once the file has been modified the cluster can be deployed by running:

`$ kubectl apply -f modified-v4v6-cluster.yaml`

You can then test the new Kubernetes cluster by creating a Pod or a Deployment and a dual-stack Service. If you are using Multus, do not forget annotate your Pod or Deployment with the following, in order to reference the NetworkAttachmentDefinition:

`k8s.v1.cni.cncf.io/networks: nad-test-conf`

For more information on the files provided to the cluster file at RKE2 install time and related configurations, you can review the "Networking" section of the [RKE2 documentation](https://docs.rke2.io/networking/basic_network_options?CNIplugin=Canal+CNI+plugin#dual-stack-configuration).