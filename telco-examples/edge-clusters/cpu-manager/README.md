# Example of Edge Cluster with CPU Manager

## Introduction

This is an example to demonstrate how to deploy an edge cluster with cpu manager enabled in Kubernetes for Telco using SUSE ATIP and the fully automated directed network provisioning.

## Configuration

Using the file `telco-examples/edge-clusters/cpu-manager/edge-cluster-cpu-manager.yaml` as an example, you can deploy an edge cluster with cpu manager by modifying the following parameters:

- `${EDGE_CONTROL_PLANE_IP}` -  The IP address to be used as a endpoint for the edge cluster (should match with the kubeapi-server endpoint).
- `${RESERVED_SYSTEM_CPU}` - The number of CPUs to be reserved for the system.
- `${RKE2_VERSION}` - The version of RKE2 to be installed in the edge cluster.

## Usage 

Once the cluster has been provisioned, the following pod's definition can be used to request some specific cpus:

```yaml 
apiVersion: v1
kind: Pod
metadata:
  name: cpu-reserved
spec:
  containers:
    - name: cpu-reserved
      image: registry.suse.com/bci/bci-busybox:15.6
      imagePullPolicy: IfNotPresent
      command: ["/bin/bash", "-ec", "sleep infinity"]
      resources:
       requests:
         cpu: 2
         memory: "2Gi"
       limits:
         cpu: 2
         memory: "2Gi"
```

After applying it you can check inside the container that only 2 cpu are visible and available for the pod:

```
cat /sys//fs/cgroup/cpuset/cpuset.cpus

5,69
```
