#!/bin/bash
# Pre-requisites. Cluster already running
export KUBECTL="/var/lib/rancher/rke2/bin/kubectl"
export KUBECONFIG="/etc/rancher/rke2/rke2.yaml"

##################
# METAL3 DETAILS #
##################
export METAL3_CHART_TARGETNAMESPACE="metal3-system"
export METAL3_CLUSTERCTLVERSION="1.6.2"
export METAL3_CAPICOREVERSION="1.6.2"
export METAL3_CAPIMETAL3VERSION="1.6.0"
export METAL3_CAPIRKE2VERSION="0.2.6"
export METAL3_CAPIPROVIDER="rke2"
export METAL3_CAPISYSTEMNAMESPACE="capi-system"
export METAL3_RKE2BOOTSTRAPNAMESPACE="rke2-bootstrap-system"
export METAL3_CAPM3NAMESPACE="capm3-system"
export METAL3_RKE2CONTROLPLANENAMESPACE="rke2-control-plane-system"
# Use "false" to avoid creating the ~/.cluster-api/clusterctl.yaml file
# The upstream one is: registry.opensuse.org/isv/suse/edge/clusterapi/containerfile/suse
export METAL3_CAPI_IMAGES="registry.suse.com/edge"
export RANCHER_TURTLES_TARGETNAMESPACE="rancher-turtles-system"
export RANCHER_TURTLES_VERSION="0.1.0+up0.9.1"

###########
# METALLB #
###########
export METALLBNAMESPACE="metallb-system"

###########
# RANCHER #
###########
export RANCHER_CHART_TARGETNAMESPACE="cattle-system"
export RANCHER_FINALPASSWORD="adminadminadmin"

die(){
  echo ${1} 1>&2
  exit ${2}
}