
# Management Cluster in a single-node setup (air-gap scenario)

This is an example of using Edge Image Builder (EIB) to generate a management cluster iso image for SUSE ATIP in an air-gap scenario. The management cluster will contain the following components:
- SUSE Linux Micro 6.0 Kernel (SL Micro 6.0)
- RKE2
- CNI plugins (e.g. Multus, Cilium)
- Rancher Prime
- Neuvector
- Longhorn
- Static IPs or DHCP network configuration
- Metal3 and the CAPI provider

You need to modify the following values in the `mgmt-cluster-airgap.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `mgmt-cluster-airgap.yaml` file. The final rancher password will be configured based on the file `custom/files/basic-setup.sh`.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `mgmt-cluster-airgap.yaml` file.

> **_IMPORTANT:_**  
> Keep in mind that the `embeddedArtifactRegistry` is a set of images based on a specific helm repositories version (rancher, metal3 and rke2-capi-provider). If you want to use a different version of the helm repositories, you need to modify the `embeddedArtifactRegistry` values in the `mgmt-cluster-airgap.yaml` file.

You need to modify the following values in the `network/mgmt-cluster-network.yaml` file :

- `${MGMT_GATEWAY}` - This is the gateway IP of your management cluster network.
- `${MGMT_DNS}` - This is the DNS IP of your management cluster network.
- `${MGMT_CLUSTER_IP}` - This is the static IP of your management cluster single node.
- `${MGMT_MAC}` - This is the MAC address of your management cluster node.

You need to modify the `${MGMT_CLUSTER_IP}` with the Node IP in the following files:

- `kubernetes/helm/values/metal3.yaml`

- `kubernetes/helm/values/rancher.yaml`

> **_IMPORTANT:_**  
> Note that the `custom/scripts/99-register.sh` file is not needed in this scenario.

You need to modify the following folder:

- `base-images` - To include inside the `SL-Micro.x86_64-6.0-Default-SelfInstall-GM2.install.iso` image downloaded from the SUSE Customer Center.

## Optional modifications

### Add certificates to use HTTPS server to provide images using TLS

This is an optional step to add certificates to the management cluster to provide images using HTTPS Server (Helm Chart metal3 Version >= 0.7.1)

1. Modify the `kubernetes/helm/values/metal3.yaml` file to set to true the following value in the global section:

```yaml
global:
  additionalTrustedCAs: true
```

2. If you are deploying a mgmt-cluster from scratch using EIB, then add the secret to the manifests folder `kubernetes/manifests/metal3-cacert-secret.yaml` to automate the creation of the secret in the management cluster:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: metal3-system
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-ca-additional
  namespace: metal3-system
type: Opaque
data:
  ca-additional.crt: {{ additional_ca_cert | b64encode }}
```

3. If you want to add the secret manually, then you can use the following command to create the secret:

```bash
kubectl -n meta3-system create secret generic tls-ca-additional --from-file=ca-additional.crt=./ca-additional.crt
```

where the ca-additional.crt is the certificate file that you want to use to provide images using HTTPS.

## Building the Management Cluster Image using EIB

1. Clone this repo and navigate to the `telco-examples/mgmt-cluster/airgap/eib` directory.

2. Modify the files described above.

3. The following command has to be executed from the parent directory where you have the `eib` directory cloned from this example (`mgmt-cluster`).

```
$ cd telco-examples/mgmt-cluster/airgap
$ sudo podman run --rm --privileged -it -v $PWD:/eib \
registry.suse.com/edge/3.1/edge-image-builder:1.1.0 \
build --definition-file mgmt-cluster-airgap.yaml
```

## Deploy the Management Cluster

Once you have the iso image built using EIB into the `eib` folder, you can use it to be deployed on a VM or a baremetal server.
