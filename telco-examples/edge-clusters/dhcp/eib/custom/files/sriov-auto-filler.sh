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

MACHINE_ID=$(cat /etc/machine-id)
NODE_NAME=""
while true; do
  NODE_NAME=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get nodes -o json | jq -r ".items[] | select(.status.nodeInfo.machineID==\"${MACHINE_ID}\") | .metadata.name")
  syncStatus=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[] | select(.metadata.name==\"${NODE_NAME}\") | .status.syncStatus")
  if [ -z "$syncStatus" ] || [ "$syncStatus" != "Succeeded" ]; then
    sleep 10
  else
    break
  fi
done

input=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get cm sriov-custom-auto-config -n sriov-network-operator -ojson | jq -r '.data."config.json"')
jq -c '.[]' <<< $input | while read i; do
  interface=$(echo $i | jq -r '.interface')
  pfname=$(echo $i | jq -r '.pfname')
  resourceName=$(echo $i | jq -r '.resourceName')

  # Check if the resource already exists
  if ${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodepolicy.sriovnetwork.openshift.io "atip-$resourceName" -n sriov-network-operator &>/dev/null; then
    echo "Resource $resourceName already exists, skipping."
    continue
  fi

  pciaddress=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[] | select(.metadata.name==\"${NODE_NAME}\") | .status.interfaces[] | select(.name==\"$interface\") | .pciAddress")
  vendor=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[] | select(.metadata.name==\"${NODE_NAME}\") | .status.interfaces[] | select(.name==\"$interface\") | .vendor")
  deviceid=$(${KUBECTL} --kubeconfig=${KUBECONFIG} get sriovnetworknodestates.sriovnetwork.openshift.io -n sriov-network-operator -ojson | jq -r ".items[] | select(.metadata.name==\"${NODE_NAME}\") | .status.interfaces[] | select(.name==\"$interface\") | .deviceID")
  driver=$(echo $i | jq -r '.driver')

  yamlContent=$(sed -e "s/RESOURCENAME/$resourceName/g" \
                  -e "s/DRIVER/$driver/g" \
                  -e "s/PFNAMES/$pfname/g" \
                  -e "s/VENDOR/$vendor/g" \
                  -e "s/DEVICEID/$deviceid/g" \
                  -e "s/PCIADDRESS/$pciaddress/g" \
                  -e "s/NUMVF/$(echo $i | jq -r '.numVFsToCreate')/g" /var/sriov-networkpolicy-template.yaml)

  echo "$yamlContent" | ${KUBECTL} --kubeconfig=${KUBECONFIG} apply -f -
done