#!/bin/bash

# Copy the scripts from combustion to the final location
mkdir -p /opt/mgmt/bin/
for script in basic-setup.sh rancher.sh metal3.sh; do
	cp ${script} /opt/mgmt/bin/
done

# Copy the systemd unit file and enable it at boot
cp mgmt-stack-setup.service /etc/systemd/system/mgmt-stack-setup.service
systemctl enable mgmt-stack-setup.service

# Extract the airgap resources
tar zxf airgap-resources.tar.gz
sleep 5

# Copy the clusterctl binary to the final location
cp airgap-resources/clusterctl /opt/mgmt/bin/ && chmod +x /opt/mgmt/bin/clusterctl

# Copy the clusterctl.yaml and override
mkdir -p /root/cluster-api
cp -r airgap-resources/clusterctl.yaml airgap-resources/overrides /root/cluster-api/
