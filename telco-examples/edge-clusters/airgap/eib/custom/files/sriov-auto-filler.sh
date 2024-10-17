#!/bin/bash
cat <<- EOF > /var/sriov-networkpolicy-template.yaml
apiVersion: sriovnetwork.openshift.io/v1
kind: SriovNetworkNodePolicy
metadata:
  name: atip-RESOURCENAME
  namespace: sriov-network-operator
spec:
  nodeSelector:
    feature.node.kubernetes.io/network-sriov.capable: "true"
  resourceName: RESOURCENAME
  deviceType: DRIVER
  numVfs: NUMVF
  mtu: 1500
  nicSelector:
    pfNames: ["PFNAMES"]
    deviceID: "DEVICEID"
    vendor: "VENDOR"
    rootDevices:
      - PCIADDRESS
EOF

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml; export KUBECTL=/var/lib/rancher/rke2/bin/kubectl
while [ $(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r '.items[].status.syncStatus') != "Succeeded" ]; do sleep 1; done
input=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get cm sriov-custom-auto-config -n sriov-network-operator -ojson | jq -r '.data."config.json"')
jq -c '.[]' <<< $input | while read i; do
  interface=$(echo $i | jq -r '.interface')
  pfname=$(echo $i | jq -r '.pfname')
  pciaddress=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[].status.interfaces[]|select(.name==\"$interface\")|.pciAddress")
  vendor=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[].status.interfaces[]|select(.name==\"$interface\")|.vendor")
  deviceid=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[].status.interfaces[]|select(.name==\"$interface\")|.deviceID")
  resourceName=$(echo $i | jq -r '.resourceName')
  driver=$(echo $i | jq -r '.driver')
  sed -e "s/RESOURCENAME/$resourceName/g" \
      -e "s/DRIVER/$driver/g" \
      -e "s/PFNAMES/$pfname/g" \
      -e "s/VENDOR/$vendor/g" \
      -e "s/DEVICEID/$deviceid/g" \
      -e "s/PCIADDRESS/$pciaddress/g" \
      -e "s/NUMVF/$(echo $i | jq -r '.numVFsToCreate')/g" /var/sriov-networkpolicy-template.yaml > /var/lib/rancher/rke2/server/manifests/$resourceName.yaml
done