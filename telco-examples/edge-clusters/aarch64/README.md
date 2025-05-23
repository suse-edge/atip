# AARCH64 Downstream Clusters

## Introduction

This is an example to demonstrate how to deploy an edge cluster for Telco using SUSE ATIP and the fully automated directed network provisioning using aaarch64 architecture.

There are two steps to deploy an edge cluster:

- Create the image for the edge cluster with Kiwi (to create the base image) + Edge Image Builder to customize it including all the packages, dependencies and requirements.
- Deploy the edge cluster using metal3 and the image created in the previous step.

Important notes:

* In the following examples, we will assume that the management cluster is already deployed and running. If you want to deploy the management cluster, please refer to the [Management Cluster example](../../mgmt-cluster/aarch64/README.md).
  1. Tech Preview for full aarch64 e2e, mgmt-cluster and downstream clusters using aarch64 architecture. You can follow the steps in the [Management Cluster example](../../mgmt-cluster/aarch64/README.md) to deploy a management cluster using aarch64 architecture following this document.
  2. x86_64 Management clusters to deploy only aarch64 downstream clusters. You can follow the steps in the rest of the mgmt-cluster folders to deploy a management cluster using x86_64 architecture (following the section `Optional modifications / Add aarch64 architecture support` to enable the arm64 feature) and then deploy the edge cluster using aarch64 architecture following this document.
* In the following examples, we are assuming that the edge cluster will use Baremetal Servers. If you want to deploy the full workflow using virtual machines, please refer to the [metal3-demo repo](https://github.com/suse-edge/metal3-demo)

## Create the image for the edge cluster

### Prerequisites

Using the example folder `telco-examples/edge-clusters/aarch64/eib`, we will create the basic structure in order to build the image for the edge cluster: 

You need to modify the following values in the `telco-edge-cluster-aarch64.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `telco-edge-cluster.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `telco-edge-cluster.yaml` file.

You need to modify the following folder:

- `base-images` - To include the raw image generated by Kiwi as:

```
mkdir output
sudo podman run --privileged -v /etc/zypp/repos.d:/micro-sdk/repos/ -v $(pwd)/output:/tmp/output -it registry.suse.com/edge/3.3/kiwi-builder:10.2.12.0 build-image -p Base-RT-SelfInstall
```

The resulting raw image needs to be copied over to the `base-image` folder and used as a reference in the `eib/telco-edge-cluster.yaml` file:

```
cp $(pwd)/output/*.raw base-images/
```

> **_Note:_** For more information about this process you can follow the [full guide instructions in official docs](https://documentation.suse.com/suse-edge/3.3/html/edge/guides-kiwi-builder-images.html)

### Building the Edge Cluster Image using EIB

All the following commands in this section could be executed using any linux laptop/server aarch64 with podman installed. You don't need to have a specific environment to build the image.

#### Generate the image with our configuration for Telco profile

```
$ cd telco-examples/edge-clusters/aarch64/eib
$ sudo podman run --rm --privileged -it -v $PWD:/eib \
registry.suse.com/edge/3.3/edge-image-builder:1.2.0 \
build --definition-file telco-edge-cluster-aarch64.yaml
```

## Deploy the Edge Clusters

All the following steps have to be executed from the management cluster in order to deploy the edge clusters.

### Example 1 - Deploy a single-node Edge Cluster with the image generated and Telco profiles using aarch64 architecture

There are 2 steps to deploy a single-node edge cluster with all Telco Capabilities enabled:

- Enroll the new Baremetal host in the management cluster.
- Provision the new host using the CAPI manifests and the image generated in the previous step. There are two possible manifests to be used:
  - `capi-minimal.yaml`: This manifest is a template to be used in case you want to deploy a basic rke2 cluster with the image generated.
  - `capi-telco-aarch64.yaml`: This manifest is a template to be used in case you want to deploy some telco profiles and capabilities in the edge cluster.

#### Enroll the new Baremetal host

Using the folder `telco-examples/aarch64` we will create the components required to deploy a single-node edge cluster using the image generated in the previous step and the telco profiles configured.

The first step is to enroll the new Baremetal host in the management cluster. To do that, you need to modify the `bmh-example.yaml` file and replace the following with your values:

- `${BMC_USERNAME}` - The username for the BMC of the new Baremetal host.
- `${BMC_PASSWORD}` - The password for the BMC of the new Baremetal host.
- `${BMC_MAC}` - The MAC address of the new Baremetal host to be used.
- `${BMC_ADDRESS}` - The URL for the Baremetal host BMC (e.g `redfish-virtualmedia://192.168.200.75/redfish/v1/Systems/1/`). If you want to know more about the different options available depending on your hardware provider, please check the following [link](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md).

In case you want to use a dhcp-less environment, you will need to configure and replace also the following parameters:

- `${CONTROLPLANE_INTERFACE}` - The control plane interface to be used for the edge cluster (e.g `eth0`).
- `${CONTROLPLANE_IP}` - The IP address to be used as a endpoint for the edge cluster (should match with the kubeapi-server endpoint).
- `${CONTROLPLANE_PREFIX}` - The CIDR to be used for the edge cluster (e.g `24` in case you want `/24` or `255.255.255.0`).
- `${CONTROLPLANE_GATEWAY}` - The gateway to be used for the edge cluster (e.g `192.168.100.1`).
- `${CONTROLPLANE_MAC}` - The MAC address to be used for the control plane interface (e.g `00:0c:29:3e:3e:3e`).
- `${DNS_SERVER}` - The DNS to be used for the edge cluster (e.g `192.168.100.2`).

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f bmh-example.yaml
```

The new Baremetal host will be enrolled changing the state from registering to inspecting and available. You could check the status using the following command:

``` 
$ kubectl get bmh
```

#### Provision the new host using the CAPI manifests and the image generated

Once the new Baremetal host is available, you need to provision the new host using the CAPI manifests and the image generated in the previous step.

The first thing is to modify the `capi-telco-aarch64.yaml` file and replace the following with your values:

- `${EDGE_CONTROL_PLANE_IP}` - The IP address to be used as a endpoint for the edge cluster (should match with the kubeapi-server endpoint).
- `${RESOURCE_NAME1}` - The resource name to be used in order to identify the VFs to be used for the workloads in Kubernetes.
- `${SRIOV-NIC-NAME1}` - The network interface to be used for creating the VFs (e.g `eth0` which means the first network interface in the server. You can get that info using `ip link` command to list the network interfaces).
- `${PF_NAME1}` - The network interface or physical function (usually filters in the network interface) to be used for the SRIOV.
- `${DRIVER_NAME1}` - The driver to be used for the interface and VFs (e.g `vfio-pci`).
- `${NUM_VFS1}` - The number of VFs to be created for the network interface (e.g `2`).
- `${ISOLATED_CPU_CORES}` - The isolated CPU cores to be used for workloads pinning some specific cpu cores. You could get that info using `lscpu` command to list the CPU cores and then, select the cores to be used for the edge cluster in case you need cpu pinning for your workloads. For example, `1-18,21-38` could be used for the isolated cores.
- `${NON-ISOLATED_CPU_CORES}` - The cores listed could be used shared for the rest of the process running on the edge cluster. For example, `0,20,21,39` could be used for the non-isolated cores.
- `${CPU_FREQUENCY}` - The frequency to be used for the CPU cores. For example, `2500000` represents 2.5Ghz configuration and it could be used to set the CPU cores to the max performance.

You can also modify any other parameter in the `capi-telco-aarch64.yaml` file to match with your requirements e.g. DPDK configuration, number of VFs to generate, number of SRIOV interfaces, etc. This is basically a template to be used for the edge cluster deployment.

** Note: Remember to locate the `eibimage-slmicro-rt-telco-arm.raw` file generated in the "[Create the image for the edge cluster](#create-the-image-for-the-edge-cluster)" step into the management cluster httpd cache folder to be used during the edge cluster provision step.

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f capi-telco-aarch64.yaml
```
