#!/bin/bash
source /etc/profile

cd /mnt/aps/base_service/monitoring/prometheus-grafana/

helm install --tls \
	--name grafana \
	--namespace monitoring \
	-f grafana-settings.yaml \
	-f grafana-dashboards.yaml \
	grafana
