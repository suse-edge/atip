# Edge clusters with IPv6 networking

## Introduction

This directory contains some sample CAPI manifest files that enable the creation of Edge clusters where the bare metal hosts, and the executing containers on top, are exclusively connected through IPv6, with the following characteristics:
- single host cluster
- various autoconfiguration approaches for the network configuration

This implies provisioning a bare metal host with an IPv6 network configuration first, through one of the provided BareMetalHost definitions, and a properly configured Kubernetes cluster, through Cluster and RKE2ControlPlane definitions according to the desidered CNI provider and setup. Both aspects are covered in the following two sections.


## BareMetalHost (BMH) examples

The BMH definitions can be found within the `bmh-example_*.yaml` files. Each file provides different IPv6 configuration approaches (which may require mode specific information), as described below:

- `bmh-example_dhcp+route.yaml` - use in environments where Router Advertisements (RAs) are not enabled in the network (or should not be used) and IPv6 should only rely on DHCP for the address and DNS servers; note that a default route must also be provided.
    Requires:
        - `${CONTROLPLANE_GATEWAY}` - the IPv6 address of the gateway for the traffic matching the default route
        - `${CONTROLPLANE_INTERFACE}` - the name of the interface to assign the address to and to use for the egressing traffic matching the default route

- `bmh-example_slaac+dhcp.yaml` - both RAs and DHCP are enabled for autoconfiguration, resulting in stateless address and default route assignments, and DHCP provided DNS information (when not optionally provided by the RAs); this is most likely the only configuration you will ever need, as no further input is required.

- `bmh-example_slaac+dhcp+dns.yaml` - this configuration is identical to the `bmh-example_slaac+dhcp.yaml` above, with the exception of statically provided DNS servers; it can be useful in networks where only RAs are avaiable (and no DNS option configured).
     Requires:
         - `${DNS_SERVER}` - the IPv6 address(es) of the DNS server(s) to use, as a single or multiple entries

**Note**:
 * Due to limitations in [nmstate](https://nmstate.io/devel/yaml_api.html#ipv6-autoconf), it is not possible to enable SLAAC but disable DHCPv6; for this reason DHCP will always be enabled in the provided examples.
 * The network configuration will only apply to the provisioned BMH and not yet on the inspection phase of the host to gather hardware information. This is due to a bug that will force the use of RA/DHCP with the default settings; a resolution is expected soon.

Once the required BMH file has been selected and refined, in order for it to work, it must also be filled with some values common to all the BMH definitions in addition to the network specific ones previously mentioned. For more information on these values or on how to enroll a Bare Metal Host, please refer to the main Edge Cluster documentation for single host deployments [here](https://github.com/suse-edge/atip/tree/main/telco-examples/edge-clusters#example-1---deploy-a-single-node-edge-cluster-with-the-image-generated-and-telco-profiles).


## Cluster definitions

The CAPI cluster definitions to be applied once the bare metal host has been inspected and is available for provisioning, are organized into two directories, depending on whether a single CNI plugin is sufficient or if multihomed Pods are required, through the use of the [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) meta-plugin. Note that the use of the SR-IOV plugin along with Multus is of course possible but not covered, as it doesn't require any specific IPAM configuration.

The definition files come with any CNI plugin specific configuration that may be required and are organized as follow:

- `single-cni`:
    | Filename                                | Primary CNI | Primary IPAM |
    |:----------------------------------------|:-----------:|:------------:|
    | `Telco-capi-v6-calico.yaml`             |    Calico   |    Calico    |
    | `Telco-capi-v6-canal.yaml`              |    Canal    |     Canal    |
    | `Telco-capi-v6-cilium.yaml`             |    Cilium   |    Cilium    |

- `multus-cni`:
    | Filename                                | Primary CNI | Primary IPAM | Secondary CNI | Secondary IPAM |
    |:----------------------------------------|:-----------:|:------------:|:-------------:|:--------------:|
    | `Telco-capi-v6-calico_hostlocal.yaml`   |    Calico   |    Calico    |      PTP      |   host-local   |
    | `Telco-capi-v6-calico_whereabouts.yaml` |    Calico   |    Calico    |      PTP      |   whereabouts  |
    | `Telco-capi-v6-canal_hostlocal.yaml`    |    Canal    |     Canal    |      PTP      |   host-local   |
    | `Telco-capi-v6-canal_whereabouts.yaml`  |    Canal    |     Canal    |      PTP      |   whereabouts  |
    | `Telco-capi-v6-cilium_hostlocal.yaml`   |    Cilium   |    Cilium    |      PTP      |   host-local   |
    | `Telco-capi-v6-cilium_whereabouts.yaml` |    Cilium   |    Cilium    |      PTP      |   whereabouts  |

    **Note**:
    * The Multus examples leverage the [Point-to-Point plugin](https://www.cni.dev/plugins/current/main/ptp/) for the secondary interface due to its simplicity and ease of testing. Do not forget to replace the CNI configuration within the manifest according to your operational needs.
    * Regardless of the address management method for the secondary interface, make sure to update the network blocks within the manifest according to your operational needs.

Regardless of the selected file, it should be edited to define at least the following values:
- `${EDGE_CONTROL_PLANE_IP}` - the additional IPv6 address the edge cluster is reacheable from (should match with the kubeapi-server endpoint)
- `${RKE2_VERSION}` - the RKE2 version to be installed during the provisioning by CAPI
- `http://imagecache.local:8080/eibimage-slmicro60rt.raw` - the URL where the generated EIB image can be located and downloaded during the provisioning; the checksum URL must be updated accordingly as well.

It is also recommended that you change the following items:
- `Cluster.spec.clusterNetwork.pods.cidrBlocks` - a list containing the IPv6 network that will be used for assigning addresses to PODs; the examples use a ULA range, which may or may not be suitable for your environment.
- `Cluster.spec.clusterNetwork.services.cidrBlocks` - a list containing IPv6 network that will be used for assigning addresses to Kubernetes Services; the examples use a ULA range, which may or may not be suitable for your environment.

Note that containers will be provided with the `resolv.conf` file included in the manifest, you are invited to replace the nameservers according to your preferences or network infrastructure.

In addition to the above settings, the configurations files leveraging Multus are provided with a NetworkAttachmentDefinition that uses private addresses and should be configured with the correct networks for your environment.

Once the file has been modified the cluster can be deployed by running:

`$ kubectl apply -f modified-v4v6-cluster.yaml`

You can then test the new Kubernetes cluster by creating a Pod or a Deployment and a dual-stack Service. If you are using Multus, in order to reference the NetworkAttachmentDefinition, do not forget to add the following annotation to your Pod or Deployment:

`k8s.v1.cni.cncf.io/networks: nad-test-conf`

For more information on the files provided to the cluster file at RKE2 install time and related configurations, you can review the "Networking" section of the [RKE2 documentation](https://docs.rke2.io/networking/basic_network_options?CNIplugin=Canal+CNI+plugin#dual-stack-configuration).
