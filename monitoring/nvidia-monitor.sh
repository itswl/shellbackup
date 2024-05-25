#!/bin/bash
source /etc/profile

cd /mnt/aps/base_service/monitoring/
helm install --name nvidia-monitor dcgm-exporter --namespace kube-system