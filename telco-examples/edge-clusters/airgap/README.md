# Edge clusters for Telco

## Introduction

This is an example to demonstrate how to deploy an air-gap downstream/edge cluster for Telco using SUSE ATIP and the fully automated directed network provisioning.

There are two steps to deploy an edge cluster:

- Create the image for the edge cluster using the Edge Image Builder in order to prepare all the package dependencies and the requirements for the edge cluster.
- Deploy the edge cluster using metal3 and the image created in the previous step.

Important notes:

* In the following examples, we will assume that the management cluster is already deployed and running. If you want to deploy the management cluster, please refer to the [Management Cluster example](../../mgmt-cluster).
* In the following examples, we are assuming that the edge cluster will use baremetal Servers. If you want to deploy the full workflow using virtual machines, please refer to the [metal3-demo repo](https://github.com/suse-edge/metal3-demo)
* In the following examples, as we're creating an air-gap scenario, we are assuming that you have a local private registry deployed in the same network. 

## Create the image for the edge cluster

### Prerequisites

To prepare an airgap environment, we will use a private local registry (already deployed and configured) to store some images (helm-chart oci images and some other images), and we will use the Edge Image Builder to include the rke2-images artifacts which are a requirement to use the cluster-api provider for rke2.

Using the example folder `telco-examples/edge-clusters/airgap/eib` we will create the basic structure in order to build the image for the edge cluster: 

You need to modify the following values in the `telco-edge-airgap-cluster.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the edge cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `telco-edge-cluster.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `telco-edge-cluster.yaml` file.

You need to modify the following folder:

- `base-images` - To include inside the `SL-Micro.x86_64-6.0-Base-RT-GM2.raw` image downloaded from the SUSE Customer Center.

### Preparing the airgap artifacts

The following steps are required to prepare the airgap artifacts:

1.Include the rke2 release images to the `custom/files` folder to be consumed by EIB during the build process. 
  - You can use the [following script](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-save-rke2-images.sh) and the list of images [here](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-release-rke2-images.txt) to generate the artifacts required to be included in `custom/files`. 
  ```
  $ ./edge-save-rke2-images.sh -o ~/telco-examples/edge-clusters/airgap/eib/custom/files -l ~/edge-release-rke2-images.txt
  ...
  $ tree ~/telco-examples/edge-clusters/airgap/eib/custom/files
  .
  |-- install.sh
  |-- rke2-images-cilium.linux-amd64.tar.zst
  |-- rke2-images-core.linux-amd64.tar.zst
  |-- rke2-images-multus.linux-amd64.tar.zst
  |-- rke2-images.linux-amd64.tar.zst
  |-- rke2.linux-amd64.tar.gz
  `-- sha256sum-amd64.txt
  ```

2. Preload your registry with the helm-chart oci images required for the edge cluster. 
  - You need to create a list with the Helm charts required for the edge cluster. For example, for telco scenarios, you can use the following list:
    ``` 
    $ cat > edge-release-helm-oci-artifacts.txt <<EOF
    edge/sriov-network-operator-chart:1.3.0
    edge/sriov-crd-chart:1.3.0
    EOF
    ```
  - Using the [following script](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-save-oci-artefacts.sh) and the list created above, you can generate a tarball containing all necessary Helm charts locally.
    ```
    $ ./edge-save-oci-artefacts.sh -al ./edge-release-helm-oci-artifacts.txt -s registry.suse.com
    Pulled: registry.suse.com/edge/sriov-network-operator-chart:1.3.0
    Pulled: registry.suse.com/edge/sriov-crd-chart:1.3.0
    a edge-release-oci-tgz-20241016
    a edge-release-oci-tgz-20241016/sriov-network-operator-chart-1.3.0.tgz
    a edge-release-oci-tgz-20241016/sriov-crd-chart-1.3.0.tgz
    ```
  - Upload your tarball to your private registry to preload with the helm chart oci images downloaded using the [following script](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-load-oci-artefacts.sh):
    ```
    $ tar zxvf edge-release-oci-tgz-20241016.tgz
    $ ./edge-load-oci-artefacts.sh -ad edge-release-oci-tgz-20241016 -r myregistry:5000
    ```

3. Preload your registry with the necessary container images (including your workload ones) required for the edge cluster. 
  - In this example, we need to include the sriov container images for telco workload (you can get the images from the [helm-chart values](https://github.com/suse-edge/charts/blob/main/charts/sriov-network-operator/1.3.0/values.yaml))
    ``` 
    $ cat > edge-release-images.txt <<EOF
    rancher/hardened-sriov-network-operator:v1.3.0-build20240816
    rancher/hardened-sriov-network-config-daemon:v1.3.0-build20240816
    rancher/hardened-sriov-cni:v2.8.1-build20240820
    rancher/hardened-ib-sriov-cni:v1.1.1-build20240816
    rancher/hardened-sriov-network-device-plugin:v3.7.0-build20240816
    rancher/hardened-sriov-network-resources-injector:v1.6.0-build20240816
    rancher/hardened-sriov-network-webhook:v1.3.0-build20240816
    EOF
    ```
  - Using the [following script](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-save-images.sh) and the list created above, you can generate in local the tarball with the images required for the edge cluster.
    ```
    $ ./edge-save-images.sh -l ./edge-release-images.txt -s registry.suse.com
    Image pull success: registry.suse.com/rancher/hardened-sriov-network-operator:v1.3.0-build20240816
    Image pull success: registry.suse.com/rancher/hardened-sriov-network-config-daemon:v1.3.0-build20240816
    Image pull success: registry.suse.com/rancher/hardened-sriov-cni:v2.8.1-build20240820
    Image pull success: registry.suse.com/rancher/hardened-ib-sriov-cni:v1.1.1-build20240816
    Image pull success: registry.suse.com/rancher/hardened-sriov-network-device-plugin:v3.7.0-build20240816
    Image pull success: registry.suse.com/rancher/hardened-sriov-network-resources-injector:v1.6.0-build20240816
    Image pull success: registry.suse.com/rancher/hardened-sriov-network-webhook:v1.3.0-build20240816
    Creating edge-images.tar.gz with 7 images
    ```
    
  - Upload your tarball to your private registry to preload with the images downloaded in the previous step using the [following script](https://github.com/suse-edge/fleet-examples/blob/release-3.1/scripts/day2/edge-load-images.sh)


### Building the Edge Cluster Image using EIB

All the following commands in this section could be executed on any x86_64 Linux-based environment with Podman installed. There are no other prerequisites or dependencies for building the image.

#### Generate the image with our configuration for Telco profile

```
$ cd telco-examples/edge-clusters
$ sudo podman run --rm --privileged -it -v $PWD:/eib \
registry.suse.com/edge/3.1/edge-image-builder:1.1.0 \
build --definition-file telco-edge-airgap-cluster.yaml
```

## Deploy the Edge Clusters

### Deploy a single-node Edge Cluster with the image generated and Telco profiles in an air-gap environment

There are 2 steps to deploy a single-node edge cluster with all Telco Capabilities enabled:

- Enroll the new baremetal host in the management cluster.
- Provision the new host using the CAPI manifests and the image generated in the previous step. 

Remember, that working with an air-gap environment requires a local private registry, some additional [preparation steps](#preparing-the-airgap-aritfacts) and the artifacts required to deploy the edge cluster.

#### Enroll the new baremetal host

Using the folder `telco-examples/airgap` we will create the components required to deploy an edge cluster using the image generated in the previous step and the telco profiles configured.

The first step is to enroll the new baremetal host in the management cluster. To do that, you need to modify the `bmh-example.yaml` file and replace the following with your values:

- `${BMC_USERNAME}` - The username for the BMC of the new baremetal host.
- `${BMC_PASSWORD}` - The password for the BMC of the new baremetal host.
- `${BMC_MAC}` - The MAC address of the new baremetal host to be used.
- `${BMC_ADDRESS}` - The URL for the baremetal host BMC (e.g `redfish-virtualmedia://192.168.200.75/redfish/v1/Systems/1/`). If you want to know more about the different options available depending on your hardware provider, please check the following [link](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md).

In case you want to use a dhcp-less environment, you will need to configure and replace also the following parameters:

- `${CONTROLPLANE_INTERFACE}` - The control plane interface to be used for the edge cluster (e.g `eth0`).
- `${CONTROLPLANE_IP}` - The IP address to be used as an endpoint for the edge cluster (should match the kubeapi-server endpoint).
- `${CONTROLPLANE_PREFIX}` - The CIDR to be used for the edge cluster (e.g `24` in case you want `/24` or `255.255.255.0`).
- `${CONTROLPLANE_GATEWAY}` - The gateway to be used for the edge cluster (e.g `192.168.100.1`).
- `${CONTROLPLANE_MAC}` - The MAC address to be used for the control plane interface (e.g `00:0c:29:3e:3e:3e`).
- `${DNS_SERVER}` - The DNS to be used for the edge cluster (e.g `192.168.100.2`).

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f bmh-example.yaml
```

The new baremetal host will be enrolled changing its state from registering to inspecting and available. You can monitor the status using the following command:

``` 
$ kubectl get bmh
```

#### Provision the new host using the CAPI manifests

Once the new baremetal host is available, you need to provision the new host using the CAPI manifests and the image generated in the previous step.

The first thing is to modify the `telco-capi-airgap.yaml` file and replace the following with your values:

- `${TLS_BASE64_CERT}` and `${TLS_BASE64_KEY}` - In case your private registry contains a client certificate and key, you should encode them in base64 format and replace these variables.
- `${CA_BASE64_CERT}` - In case your private registry enables TLS, you need to encode a CA certificate in base64 format and replace this variable.
- `${CA_CERT}` - Same value as `${CA_BASE64_CERT}` but without encoding.
- `${REGISTRY_AUTH_DOCKERCONFIGJSON}` - In case your private registry enables the basic auth mechanism, you need to encode the username and password in base64 format and replace this variable. As a reference, you can use the following command to generate the value:
  ```
  $ echo -n '{"auths":{"myregistry:5000":{"username":"${REGISTRY_USERNAME}","password":"${REGISTRY_PASSWORD}","email":"none"}}}' | base64
  ```
  or following the [official documentation](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials).
- `${REGISTRY_USERNAME}` and `${REGISTRY_PASSWORD}` - In the case your private registry enables the basic auth mechanism, you need to include the username and password to be used for the private registry. You need to encode those in base64 format and replace the variables.
- `${EDGE_CONTROL_PLANE_IP}` - The IP address to be used as a endpoint for the edge cluster (should match the kubeapi-server endpoint).
- `${PRIVATE_REGISTRY_URL}` - The URL for the private registry to be used for the edge cluster (e.g `myregistry:5000`).
- `${RESOURCE_NAME1}` - The resource name to be used in order to identify the VFs to be used for the workloads in Kubernetes.
- `${SRIOV-NIC-NAME1}` - The network interface to be used for creating the VFs (e.g `eth0` which means the first network interface in the server. You can get that info using `ip link` command to list the network interfaces).
- `${PF_NAME1}` - The network interface or physical function (usually filters in the network interface) to be used for the SRIOV.
- `${DRIVER_NAME1}` - The driver to be used for the interface and VFs (e.g `vfio-pci`).
- `${NUM_VFS1}` - The number of VFs to be created for the network interface (e.g `2`).
- `${SRIOV_CRD_VERSION}` - The version of the SRIOV CRD chart to be used for the edge cluster, for example `1.3.0`.
- `${SRIOV_OPERATOR_VERSION}` - The version of the SRIOV Operator chart to be used for the edge cluster, for example, `1.3.0`.
- `${ISOLATED_CPU_CORES}` - The isolated CPU cores to be used for workloads pinning some specific ones. You could get that info using `lscpu` command to list the CPU cores and then, select the cores to be used for the edge cluster in case you need CPU pinning for your workloads. For example, `1-18,21-38` could be used for the isolated cores.
- `${NON-ISOLATED_CPU_CORES}` - The cores listed could be used shared for the rest of the process running on the edge cluster. For example, `0,20,21,39` could be used for the non-isolated cores.
- `${CPU_FREQUENCY}` - The frequency to be used for the CPU cores. For example, `2500000` represents 2.5Ghz configuration and it could be used to set the CPU cores to the max performance.
- `${RKE2_VERSION}` - The RKE2 version to be used for the edge cluster. For example, `1.30.3+rke2r1` could be used for the edge cluster.

You can also modify any other parameter in the `telco-capi-airgap.yaml` file to match with your requirements e.g. DPDK configuration, number of VFs to generate, number of SRIOV interfaces, etc. This is basically a template to be used for the edge cluster deployment.

** Note: Remember to locate the `eibimage-slmicro60rt-telco.raw` file generated in [Create the image for the edge cluster](#create-the-image-for-the-edge-cluster) into the management cluster httpd cache folder to be used during the edge cluster provisioning step.

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f telco-capi-single-node.yaml
```
